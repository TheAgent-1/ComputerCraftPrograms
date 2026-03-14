-- ============================================================================
-- BaseOS  |  programs/infoboard.lua
-- Live Information Board - Create_DisplayLink output, API-driven pages
--
-- Pages are defined and managed from the web API - add, remove, reorder,
-- and edit page content from a webpage without touching this file.
--
-- The BaseOS content window (win) is the status/control panel - colours OK.
-- The Create_DisplayLink is text-only - no colour calls at all.
--
-- API expected endpoints:
--   GET  /infoboard/api/pages   -> list of page definitions
--   WS   /infoboard/ws         -> push updates
--
-- Page object shape (from API):
--   {
--     id       = "announcements",
--     label    = "Announcements",
--     type     = "announcements" | "powerstation" | "todo" | "custom",
--     duration = 10,
--     data     = { ... }
--   }
-- ============================================================================

local InfoBoard = {}

-- Config
local CONFIG = {
    SERVER        = "192.168.1.41:5005",
    COMPANY_NAME  = "Spectre Inc.",
    PAGES_API     = "http://192.168.1.41:5005/infoboard/api/pages",
    WS_URL        = "ws://192.168.1.41:5005/infoboard/ws",
    REFRESH_EVERY = 60,
    FADE_STEPS    = 4,
    FADE_DELAY    = 0.02,
}

-- HTTP helper
local function httpGet(url)
    local ok, resp = pcall(http.get, url)
    if not ok or not resp then return nil end
    local body = resp.readAll(); resp.close()
    local pOk, data = pcall(textutils.unserialiseJSON, body)
    return pOk and data or nil
end

-- main(win)
function InfoBoard.main(win)
    local sw, sh = win.getSize()

    -- Find the Display Link
    local display = peripheral.find("Create_DisplayLink")

    -- ===========================================================
    -- STATUS PANEL - BaseOS content window, colours allowed
    -- ===========================================================

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

        local dlStr = display and "Display OK" or "No Display!"
        local dlCol = display and colors.lime or colors.red
        sWrite(2, 3,  "Display Link:",  colors.lightGray, colors.black)
        sWrite(2, 4,  dlStr,            dlCol,            colors.black)

        sWrite(2, 6,  "WebSocket:",     colors.lightGray, colors.black)
        sWrite(2, 7,  state.wsStr,      state.wsCol,      colors.black)

        sWrite(2, 9,  "Page:",          colors.lightGray, colors.black)
        sWrite(2, 10, state.pageLabel,  colors.white,     colors.black)
        sWrite(2, 11, state.pageNum,    colors.gray,      colors.black)

        sWrite(2, 13, "Total pages:",   colors.lightGray, colors.black)
        sWrite(2, 14, tostring(state.total), colors.white, colors.black)

        sWrite(2, 16, "Last sync:",     colors.lightGray, colors.black)
        sWrite(2, 17, state.lastSync,   colors.gray,      colors.black)

        sFill(sh, colors.gray)
        sWrite(2, sh, "Touch to skip page", colors.lightGray, colors.gray)
    end

    -- ===========================================================
    -- DISPLAY BOARD - text only, no colour calls whatsoever
    -- ===========================================================

    local dw, dh = 51, 19

    local function setupDisplay()
        if not display then return false end
        dw, dh = display.getSize()
        return true
    end

    local function dWrite(x, y, text)
        if not display then return end
        if y < 1 or y > dh then return end
        display.setCursorPos(x, y)
        display.write(tostring(text):sub(1, dw - x + 1))
    end

    local function dFill(y, char)
        if not display then return end
        if y < 1 or y > dh then return end
        display.setCursorPos(1, y)
        display.write(string.rep(char or " ", dw))
    end

    local function dProgressBar(x, y, barW, val, maxVal)
        if not display then return end
        val    = val    or 0
        maxVal = (maxVal and maxVal > 0) and maxVal or 1
        local filled = math.floor(barW * math.min(val / maxVal, 1))
        local bar = "[" .. string.rep("#", filled)
                       .. string.rep("-", barW - filled) .. "]"
        dWrite(x, y, bar)
    end

    local function pushDisplay()
        if display then display.update() end
    end

    -- Header row: ruled line with company, label, page number inset
    local function drawDisplayHeader(label, idx, total)
        if not display then return end
        dFill(1, "-")
        local pageNum = idx .. "/" .. total
        dWrite(2,                   1, " " .. CONFIG.COMPANY_NAME .. " ")
        local lx = math.max(#CONFIG.COMPANY_NAME + 5,
                            math.floor((dw - #label) / 2) + 1)
        dWrite(lx,                  1, " " .. label .. " ")
        dWrite(dw - #pageNum - 1,   1, " " .. pageNum .. " ")
    end

    local function fadeOut()
        if not display then return end
        local row = dh
        while row >= 2 do
            for i = 0, CONFIG.FADE_STEPS - 1 do
                local r = row - i
                if r >= 2 then dFill(r) end
            end
            pushDisplay()
            row = row - CONFIG.FADE_STEPS
            os.sleep(CONFIG.FADE_DELAY)
        end
    end

    -- ===========================================================
    -- PAGE RENDERERS - text only
    -- ===========================================================

    local PRIORITY_PREFIX = { high = "[!!] ", medium = "[!]  ", low = "[-]  " }

    local function renderAnnouncements(data)
        if not data or not data.announcements or #data.announcements == 0 then
            dWrite(2, 3, "No announcements.")
            return
        end

        local y = 2
        for _, msg in ipairs(data.announcements) do
            if y > dh then break end

            local prefix = PRIORITY_PREFIX[msg.priority] or "[ ]  "
            local meta   = (msg.author or "System")
            if msg.time then meta = meta .. "  " .. msg.time end

            dFill(y, "-"); y = y + 1
            if y > dh then break end
            dWrite(2, y, meta); y = y + 1

            local text = prefix .. (msg.text or "")
            while #text > 0 and y <= dh do
                local line = text:sub(1, dw - 2)
                if #text > dw - 2 then
                    local cut = line:match("^(.+)%s")
                    if cut then line = cut end
                end
                dWrite(2, y, line)
                text = text:sub(#line + 1):gsub("^%s+", "")
                y = y + 1
            end
            y = y + 1
        end
    end

    local function renderPowerstation(data)
        if not data then
            dWrite(2, 3, "[ERROR] Cannot reach Powerstation API")
            return
        end

        local y  = 2
        local barW = math.floor(dw * 0.45)

        dWrite(2, y, "Relay:  " .. (data.relayState == "on" and "ONLINE" or "OFFLINE"))
        y = y + 2

        dWrite(2, y, "RSC Speed:  " .. (data.rotationSpeedController or 0) .. " RPM")
        y = y + 2

        local stress = data.stressLevel or 0
        dWrite(2, y, "Network Stress:  " .. stress .. "%")
        y = y + 1
        dProgressBar(2, y, barW, stress, 100)
        y = y + 2

        local reserves = data.powerReserves    or 0
        local maxRes   = data.maxPowerReserves or math.max(reserves, 1)
        local resPct   = math.floor(reserves / maxRes * 100)
        dWrite(2, y, "Power Reserves:  " .. resPct .. "%")
        y = y + 1
        dProgressBar(2, y, barW, reserves, maxRes)
    end

    local function renderTodo(data)
        if not data or not data.todos or #data.todos == 0 then
            dWrite(2, 3, "No tasks found.")
            return
        end

        local STATUS_LABELS = { todo="Todo", inprogress="In Progress", done="Done" }
        local STATUS_MARKER = { todo="[ ]", inprogress="[~]", done="[x]" }

        local y = 2
        local done_c = 0
        for _, t in ipairs(data.todos) do
            if t.status == "done" then done_c = done_c + 1 end
        end

        dWrite(2, y, "Tasks: " .. done_c .. "/" .. #data.todos .. " complete")
        dFill(y + 1, "-")
        y = y + 2

        for _, t in ipairs(data.todos) do
            if y > dh then break end
            local marker = STATUS_MARKER[t.status] or "[ ]"
            local label  = STATUS_LABELS[t.status] or t.status
            local maxTitleW = dw - #marker - #label - 5
            local title = (t.title or "?"):sub(1, maxTitleW)
            dWrite(2, y, marker .. " " .. title)
            dWrite(dw - #label - 1, y, label)
            y = y + 1
        end
    end

    local function renderCustom(data)
        if not data or not data.lines or #data.lines == 0 then
            dWrite(2, 3, "No content.")
            return
        end
        local y = 2
        for _, line in ipairs(data.lines) do
            if y > dh then break end
            local prefix = line.prefix or ""
            dWrite(2, y, (prefix .. (line.text or "")):sub(1, dw - 2))
            y = y + 1
        end
    end

    local renderers = {
        announcements = renderAnnouncements,
        powerstation  = renderPowerstation,
        todo          = renderTodo,
        custom        = renderCustom,
    }

    local function renderPage(page, idx, total)
        if not display then return end
        display.clear()
        drawDisplayHeader(page.label or "?", idx, total)
        local renderer = renderers[page.type]
        if renderer then
            renderer(page.data)
        else
            dWrite(2, 3, "[ERROR] Unknown page type: " .. tostring(page.type))
        end
        pushDisplay()
    end

    -- ===========================================================
    -- PAGE LIST + WS
    -- ===========================================================

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

    local wsConnection = nil
    local wsReconTimer = nil

    local function wsDisconnect()
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

    local function panelState(pageIdx, wsConn)
        local page = pages[pageIdx]
        return {
            wsStr     = wsConn and "\x07 Connected" or "  Disconnected",
            wsCol     = wsConn and colors.lime or colors.red,
            pageLabel = page and (page.label or "?") or "-",
            pageNum   = #pages > 0 and (pageIdx .. "/" .. #pages) or "-",
            total     = #pages,
            lastSync  = lastRefresh > 0
                and textutils.formatTime(os.time(), true) or "Never",
        }
    end

    -- ===========================================================
    -- BOOT
    -- ===========================================================

    if not setupDisplay() then
        win.setBackgroundColor(colors.red); win.clear()
        win.setCursorPos(2, 2)
        win.setTextColor(colors.white)
        win.write("No Create_DisplayLink found!")
        win.setCursorPos(2, 3)
        win.setTextColor(colors.yellow)
        win.write("Attach one and relaunch.")
        while true do os.pullEvent("monitor_touch") end
    end

    display.clear()
    dFill(1, "-")
    dWrite(2, 1, " " .. CONFIG.COMPANY_NAME .. " ")
    dWrite(2, 3, "Connecting...")
    pushDisplay()

    fetchPages()
    connectWS()

    local pageIndex = 1
    local flipTimer = os.startTimer(#pages > 0 and pages[1].duration or 10)

    drawStatusPanel(panelState(pageIndex, wsConnection))

    if #pages > 0 then
        renderPage(pages[pageIndex], pageIndex, #pages)
    else
        display.clear()
        dFill(1, "-")
        dWrite(2, 1, " " .. CONFIG.COMPANY_NAME .. " ")
        dWrite(2, 3, "No pages configured.")
        dWrite(2, 4, "Add pages via the web interface.")
        pushDisplay()
    end

    -- ===========================================================
    -- EVENT LOOP
    -- ===========================================================

    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "timer" and p1 == flipTimer then
            if #pages > 0 then
                fadeOut()
                pageIndex = (pageIndex % #pages) + 1
                renderPage(pages[pageIndex], pageIndex, #pages)
                flipTimer = os.startTimer(pages[pageIndex].duration or 10)
                drawStatusPanel(panelState(pageIndex, wsConnection))
            else
                flipTimer = os.startTimer(10)
            end
            if os.clock() - lastRefresh > CONFIG.REFRESH_EVERY then
                fetchPages()
                drawStatusPanel(panelState(pageIndex, wsConnection))
            end

        elseif ev == "timer" and p1 == wsReconTimer then
            connectWS()
            drawStatusPanel(panelState(pageIndex, wsConnection))

        elseif ev == "websocket_message" then
            local ok, msg = pcall(textutils.unserialiseJSON, p2 or "")
            if ok and msg then
                if msg.type == "pages_updated" then
                    fetchPages()
                    if #pages > 0 then
                        pageIndex = 1
                        fadeOut()
                        renderPage(pages[pageIndex], pageIndex, #pages)
                        flipTimer = os.startTimer(pages[pageIndex].duration or 10)
                    end
                    drawStatusPanel(panelState(pageIndex, wsConnection))

                elseif msg.type == "page_data_updated" and msg.id then
                    for i, page in ipairs(pages) do
                        if page.id == msg.id then
                            pages[i].data = msg.data or pages[i].data
                            if i == pageIndex then
                                renderPage(pages[pageIndex], pageIndex, #pages)
                            end
                            break
                        end
                    end

                elseif msg.type == "goto_page" and msg.id then
                    for i, page in ipairs(pages) do
                        if page.id == msg.id then
                            fadeOut()
                            pageIndex = i
                            renderPage(pages[pageIndex], pageIndex, #pages)
                            flipTimer = os.startTimer(pages[pageIndex].duration or 10)
                            drawStatusPanel(panelState(pageIndex, wsConnection))
                            break
                        end
                    end
                end
            end

        elseif ev == "websocket_closed" or ev == "websocket_failure" then
            wsDisconnect()
            wsReconTimer = os.startTimer(10)
            drawStatusPanel(panelState(pageIndex, wsConnection))

        elseif ev == "monitor_touch" then
            if #pages > 0 then
                os.cancelTimer(flipTimer)
                pageIndex = (pageIndex % #pages) + 1
                fadeOut()
                renderPage(pages[pageIndex], pageIndex, #pages)
                flipTimer = os.startTimer(pages[pageIndex].duration or 10)
                drawStatusPanel(panelState(pageIndex, wsConnection))
            end
        end
    end
end

return InfoBoard