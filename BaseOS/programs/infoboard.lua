-- ============================================================================
-- BaseOS  |  programs/infoboard.lua
-- Live Information Board — Create_DisplayLink output, API-driven pages
--
-- Pages are defined and managed from the web API — add, remove, reorder,
-- and edit page content from a webpage without touching this file.
--
-- The BaseOS content window acts as a status/control panel.
-- The Create_DisplayLink shows the actual board content.
--
-- API expected endpoints:
--   GET  /infoboard/api/pages          → list of page definitions
--   GET  /infoboard/api/pages/<id>     → single page data
--   WS   /infoboard/ws                 → push updates
--
-- Page object shape (from API):
--   {
--     id       = "announcements",
--     label    = "Announcements",
--     type     = "announcements" | "powerstation" | "todo" | "custom",
--     duration = 10,              -- seconds to display
--     data     = { ... }          -- type-specific content (see renderers)
--   }
-- ============================================================================

local InfoBoard = {}

-- --- Config ------------------------------------------------------------------
local CONFIG = {
    SERVER        = "192.168.1.41:5005",
    COMPANY_NAME  = "Spectre Inc.",
    PAGES_API     = "http://192.168.1.41:5005/infoboard/api/pages",
    WS_URL        = "ws://192.168.1.41:5005/infoboard/ws",
    REFRESH_EVERY = 60,   -- seconds between full page list refreshes
    FADE_STEPS    = 4,    -- rows cleared per fade frame
    FADE_DELAY    = 0.02, -- seconds between fade frames
}

-- --- HTTP helper -------------------------------------------------------------
local function httpGet(url)
    local ok, resp = pcall(http.get, url)
    if not ok or not resp then return nil end
    local body = resp.readAll(); resp.close()
    local pOk, data = pcall(textutils.unserialiseJSON, body)
    return pOk and data or nil
end

-- --- main(win) ---------------------------------------------------------------
function InfoBoard.main(win)
    local sw, sh = win.getSize()   -- BaseOS status panel dimensions

    -- -- Find the Display Link --------------------------------------
    local display = peripheral.find("Create_DisplayLink")

    -- -- Status panel helpers (BaseOS content window) ---------------
    local function sWrite(x, y, text, fg, bg)
        win.setCursorPos(x, y)
        if bg then win.setBackgroundColor(bg) end
        if fg then win.setTextColor(fg) end
        win.write(tostring(text):sub(1, sw - x + 1))
    end

    local function sFill(y, bg)
        win.setCursorPos(1, y)
        win.setBackgroundColor(bg)
        win.write(string.rep(" ", sw))
    end

    local function drawStatusPanel(state)
        win.setBackgroundColor(colors.black)
        win.clear()

        sFill(1, colors.gray)
        sWrite(2, 1, "InfoBoard", colors.white, colors.gray)

        -- Display Link status
        local dlStr = display and "Display OK" or "No Display!"
        local dlCol = display and colors.lime or colors.red
        sWrite(2, 3, "Display Link:", colors.lightGray, colors.black)
        sWrite(2, 4, dlStr, dlCol, colors.black)

        -- WS status
        sWrite(2, 6, "WebSocket:", colors.lightGray, colors.black)
        sWrite(2, 7, state.wsStr, state.wsCol, colors.black)

        -- Current page
        sWrite(2, 9, "Page:", colors.lightGray, colors.black)
        sWrite(2, 10, state.pageLabel, colors.white, colors.black)
        sWrite(2, 11, state.pageNum, colors.gray, colors.black)

        -- Page count
        sWrite(2, 13, "Total pages:", colors.lightGray, colors.black)
        sWrite(2, 14, tostring(state.total), colors.white, colors.black)

        -- Last refresh
        sWrite(2, 16, "Last sync:", colors.lightGray, colors.black)
        sWrite(2, 17, state.lastSync, colors.gray, colors.black)

        -- Touch hint
        sFill(sh, colors.gray)
        sWrite(2, sh, "Touch to skip page", colors.lightGray, colors.gray)
    end

    -- -- Display Link helpers ---------------------------------------
    local dw, dh = 51, 19  -- fallback; overwritten once display is found
    local dwin   = nil     -- window wrapping the display

    local function setupDisplay()
        if not display then return false end
        dw, dh = display.getSize()
        -- Create a full-surface window on the display
        dwin = window.create(display, 1, 1, dw, dh, true)
        return true
    end

    local function dWrite(x, y, text, fg, bg)
        if not dwin then return end
        if y < 1 or y > dh then return end
        dwin.setCursorPos(x, y)
        if bg then dwin.setBackgroundColor(bg) end
        if fg then dwin.setTextColor(fg) end
        dwin.write(tostring(text):sub(1, dw - x + 1))
    end

    local function dFill(y, bg, char)
        if not dwin then return end
        if y < 1 or y > dh then return end
        dwin.setCursorPos(1, y)
        dwin.setBackgroundColor(bg)
        dwin.write(string.rep(char or " ", dw))
    end

    local function dProgressBar(x, y, barW, val, maxVal, fg, bg)
        if not dwin then return end
        val    = val    or 0
        maxVal = (maxVal and maxVal > 0) and maxVal or 1
        local filled = math.floor(barW * math.min(val / maxVal, 1))
        dwin.setCursorPos(x, y)
        dwin.setBackgroundColor(fg); dwin.write(string.rep("\x7f", filled))
        dwin.setBackgroundColor(bg); dwin.write(string.rep("-", barW - filled))
        dwin.setBackgroundColor(colors.black)
    end

    local function pushDisplay()
        if display then display.update() end
    end

    -- -- Page header on the display (row 1) ------------------------
    local function drawDisplayHeader(label, idx, total)
        if not dwin then return end
        dFill(1, colors.gray)
        local pageNum = idx .. "/" .. total
        dWrite(2, 1, CONFIG.COMPANY_NAME, colors.white, colors.gray)
        local lx = math.max(#CONFIG.COMPANY_NAME + 3,
                            math.floor((dw - #label) / 2) + 1)
        dWrite(lx, 1, label, colors.lightGray, colors.gray)
        dWrite(dw - #pageNum, 1, pageNum, colors.white, colors.gray)
    end

    -- -- Fade transition --------------------------------------------
    local function fadeOut()
        if not dwin then return end
        local row = dh
        while row >= 2 do
            for i = 0, CONFIG.FADE_STEPS - 1 do
                local r = row - i
                if r >= 2 then dFill(r, colors.black) end
            end
            pushDisplay()
            row = row - CONFIG.FADE_STEPS
            os.sleep(CONFIG.FADE_DELAY)
        end
    end

    -- -- Page renderers ---------------------------------------------
    -- Each receives the page's `data` field and draws into rows 2..dh.

    local function renderAnnouncements(data)
        if not data or not data.announcements or #data.announcements == 0 then
            dWrite(2, 3, "No announcements.", colors.gray, colors.black)
            return
        end

        local y = 2
        for _, msg in ipairs(data.announcements) do
            if y > dh then break end

            local col = colors.white
            if     msg.priority == "high"   then col = colors.red
            elseif msg.priority == "medium" then col = colors.yellow
            elseif msg.priority == "low"    then col = colors.lightGray
            end

            -- Author bar
            local meta = msg.author or "System"
            if msg.time then meta = meta .. "  " .. msg.time end
            dFill(y, colors.gray)
            dWrite(2, y, meta, colors.lightGray, colors.gray)
            y = y + 1

            -- Body with simple word wrap
            local text = msg.text or ""
            while #text > 0 and y <= dh do
                local line = text:sub(1, dw - 3)
                if #text > dw - 3 then
                    local cut = line:match("^(.+)%s")
                    if cut then line = cut end
                end
                dWrite(2, y, line, col, colors.black)
                text = text:sub(#line + 1):gsub("^%s+", "")
                y = y + 1
            end
            y = y + 1
        end
    end

    local function renderPowerstation(data)
        if not data then
            dWrite(2, 3, "Cannot reach Powerstation API", colors.red, colors.black)
            return
        end

        local y = 2
        local barW = math.floor(dw * 0.5)

        -- Relay
        local relayOn  = data.relayState == "on"
        local relayCol = relayOn and colors.lime or colors.red
        dWrite(2, y, "Relay:", colors.lightGray, colors.black)
        dWrite(10, y, relayOn and "ONLINE" or "OFFLINE", relayCol, colors.black)
        y = y + 2

        -- RSC speed
        local rsc = data.rotationSpeedController or 0
        dWrite(2, y, "RSC Speed:", colors.lightGray, colors.black)
        dWrite(14, y, rsc .. " RPM", colors.white, colors.black)
        y = y + 2

        -- Stress
        local stress = data.stressLevel or 0
        local stressCol = stress > 80 and colors.red
                       or stress > 50 and colors.orange
                       or colors.lime
        dWrite(2, y, "Network Stress:", colors.lightGray, colors.black)
        y = y + 1
        dProgressBar(2, y, barW, stress, 100, stressCol, colors.gray)
        dWrite(barW + 4, y, stress .. "%", stressCol, colors.black)
        y = y + 2

        -- Power reserves
        local reserves = data.powerReserves    or 0
        local maxRes   = data.maxPowerReserves or math.max(reserves, 1)
        local resPct   = math.floor(reserves / maxRes * 100)
        dWrite(2, y, "Power Reserves:", colors.lightGray, colors.black)
        y = y + 1
        dProgressBar(2, y, barW, reserves, maxRes, colors.cyan, colors.gray)
        dWrite(barW + 4, y, resPct .. "%", colors.cyan, colors.black)
    end

    local function renderTodo(data)
        if not data or not data.todos or #data.todos == 0 then
            dWrite(2, 3, "No tasks found.", colors.gray, colors.black)
            return
        end

        local STATUS_LABELS = { todo="To Do", inprogress="In Progress", done="Done" }
        local STATUS_COLORS = { todo=colors.yellow, inprogress=colors.orange, done=colors.lime }

        local y = 2
        local done_c = 0
        for _, t in ipairs(data.todos) do
            if t.status == "done" then done_c = done_c + 1 end
        end

        -- Summary bar
        dFill(y, colors.gray)
        local summary = done_c .. "/" .. #data.todos .. " complete"
        dWrite(2, y, summary, colors.white, colors.gray)
        y = y + 2

        for _, t in ipairs(data.todos) do
            if y > dh then break end
            local sc  = STATUS_COLORS[t.status] or colors.white
            local sl  = STATUS_LABELS[t.status] or t.status
            local marker = t.status == "done" and "\xfb"
                        or t.status == "inprogress" and "~"
                        or " "
            local titleCol = t.status == "done" and colors.gray or colors.white
            dWrite(2, y,  "[" .. marker .. "]", sc,       colors.black)
            dWrite(6, y,  (t.title or "?"):sub(1, dw - 14), titleCol, colors.black)
            dWrite(dw - #sl - 1, y, sl, sc, colors.black)
            y = y + 1
        end
    end

    local function renderCustom(data)
        -- Generic renderer for web-authored content.
        -- data.lines = array of { text, color?, bold? }
        if not data or not data.lines or #data.lines == 0 then
            dWrite(2, 3, "No content.", colors.gray, colors.black)
            return
        end

        local y = 2
        for _, line in ipairs(data.lines) do
            if y > dh then break end
            local col = colors.white
            if line.color then
                -- Accept color names: "red", "lime", "yellow" etc.
                col = colors[line.color] or colors.white
            end
            dWrite(2, y, (line.text or ""):sub(1, dw - 2), col, colors.black)
            y = y + 1
        end
    end

    -- Dispatcher
    local renderers = {
        announcements = renderAnnouncements,
        powerstation  = renderPowerstation,
        todo          = renderTodo,
        custom        = renderCustom,
    }

    local function renderPage(page, idx, total)
        if not dwin then return end
        dwin.setBackgroundColor(colors.black)
        dwin.clear()
        drawDisplayHeader(page.label or "?", idx, total)

        local renderer = renderers[page.type]
        if renderer then
            renderer(page.data)
        else
            dWrite(2, 3, "Unknown page type: " .. tostring(page.type),
                   colors.red, colors.black)
        end
        pushDisplay()
    end

    -- -- Page list management ---------------------------------------
    local pages       = {}
    local lastRefresh = 0

    local function fetchPages()
        local data = httpGet(CONFIG.PAGES_API)
        if data and type(data) == "table" then
            pages = data
            lastRefresh = os.clock()
            return true
        end
        return false
    end

    -- -- WS connection ----------------------------------------------
    local wsConnection  = nil
    local wsReconTimer  = nil

    local function wsDisconnect(reason)
        if wsConnection then
            pcall(wsConnection.close, wsConnection)
            wsConnection = nil
        end
    end

    local function connectWS()
        wsDisconnect()
        local ws, err = http.websocket(CONFIG.WS_URL)
        if ws then
            wsConnection = ws
        else
            wsReconTimer = os.startTimer(10)
        end
    end

    -- -- State for status panel -------------------------------------
    local function panelState(pageIdx, wsConn)
        local page = pages[pageIdx]
        return {
            wsStr    = wsConn and "\x07 Connected" or "  Disconnected",
            wsCol    = wsConn and colors.lime or colors.red,
            pageLabel= page and (page.label or "?") or "—",
            pageNum  = #pages > 0 and (pageIdx .. "/" .. #pages) or "—",
            total    = #pages,
            lastSync = lastRefresh > 0
                and textutils.formatTime(os.time(), true) or "Never",
        }
    end

    -- -- Boot -------------------------------------------------------
    if not setupDisplay() then
        win.setBackgroundColor(colors.red); win.clear()
        win.setCursorPos(2,2)
        win.setTextColor(colors.white)
        win.write("No Create_DisplayLink found!")
        win.setCursorPos(2,3)
        win.setTextColor(colors.yellow)
        win.write("Attach one and relaunch.")
        while true do os.pullEvent("monitor_touch") end
    end

    -- Show boot message on the display board
    dwin.setBackgroundColor(colors.black); dwin.clear()
    dFill(1, colors.gray)
    dWrite(2, 1, CONFIG.COMPANY_NAME, colors.white, colors.gray)
    dWrite(2, 3, "Connecting\x85", colors.yellow, colors.black)
    pushDisplay()

    fetchPages()
    connectWS()

    local pageIndex = 1
    local flipTimer = os.startTimer(
        (#pages > 0 and pages[1].duration or 10)
    )

    drawStatusPanel(panelState(pageIndex, wsConnection))

    -- Render first page immediately
    if #pages > 0 then
        renderPage(pages[pageIndex], pageIndex, #pages)
    else
        dwin.setBackgroundColor(colors.black); dwin.clear()
        dFill(1, colors.gray)
        dWrite(2, 1, CONFIG.COMPANY_NAME, colors.white, colors.gray)
        dWrite(2, 3, "No pages configured.", colors.gray, colors.black)
        dWrite(2, 4, "Add pages via the web interface.", colors.lightGray, colors.black)
        pushDisplay()
    end

    -- -- Event loop -------------------------------------------------
    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        -- -- Page flip timer --------------------------------------
        if ev == "timer" and p1 == flipTimer then
            if #pages > 0 then
                -- Advance page
                local nextIndex = (pageIndex % #pages) + 1

                -- Fade out current page, render next
                fadeOut()
                pageIndex = nextIndex
                renderPage(pages[pageIndex], pageIndex, #pages)

                -- Schedule next flip
                local dur = pages[pageIndex].duration or 10
                flipTimer = os.startTimer(dur)
                drawStatusPanel(panelState(pageIndex, wsConnection))
            else
                flipTimer = os.startTimer(10)
            end

            -- Periodic full refresh of page list
            if os.clock() - lastRefresh > CONFIG.REFRESH_EVERY then
                fetchPages()
                drawStatusPanel(panelState(pageIndex, wsConnection))
            end

        -- -- WS reconnect timer -----------------------------------
        elseif ev == "timer" and p1 == wsReconTimer then
            connectWS()
            drawStatusPanel(panelState(pageIndex, wsConnection))

        -- -- WS message — server pushed an update -----------------
        elseif ev == "websocket_message" then
            local ok, msg = pcall(textutils.unserialiseJSON, p2 or "")
            if ok and msg then
                if msg.type == "pages_updated" then
                    -- Full page list changed — re-fetch and re-render
                    fetchPages()
                    if #pages > 0 then
                        pageIndex = 1
                        fadeOut()
                        renderPage(pages[pageIndex], pageIndex, #pages)
                        local dur = pages[pageIndex].duration or 10
                        flipTimer = os.startTimer(dur)
                    end
                    drawStatusPanel(panelState(pageIndex, wsConnection))

                elseif msg.type == "page_data_updated" and msg.id then
                    -- A single page's data changed — update it in place
                    for i, page in ipairs(pages) do
                        if page.id == msg.id then
                            pages[i].data = msg.data or pages[i].data
                            -- If it's the currently showing page, re-render immediately
                            if i == pageIndex then
                                renderPage(pages[pageIndex], pageIndex, #pages)
                            end
                            break
                        end
                    end

                elseif msg.type == "goto_page" and msg.id then
                    -- Server tells us to jump to a specific page
                    for i, page in ipairs(pages) do
                        if page.id == msg.id then
                            fadeOut()
                            pageIndex = i
                            renderPage(pages[pageIndex], pageIndex, #pages)
                            local dur = pages[pageIndex].duration or 10
                            flipTimer = os.startTimer(dur)
                            drawStatusPanel(panelState(pageIndex, wsConnection))
                            break
                        end
                    end
                end
            end

        -- -- WS dropped -------------------------------------------
        elseif ev == "websocket_closed" or ev == "websocket_failure" then
            wsDisconnect()
            wsReconTimer = os.startTimer(10)
            drawStatusPanel(panelState(pageIndex, wsConnection))

        -- -- Touch on BaseOS panel — skip to next page -------------
        elseif ev == "monitor_touch" then
            if #pages > 0 then
                os.cancelTimer(flipTimer)
                local nextIndex = (pageIndex % #pages) + 1
                fadeOut()
                pageIndex = nextIndex
                renderPage(pages[pageIndex], pageIndex, #pages)
                local dur = pages[pageIndex].duration or 10
                flipTimer = os.startTimer(dur)
                drawStatusPanel(panelState(pageIndex, wsConnection))
            end
        end
    end
end

return InfoBoard