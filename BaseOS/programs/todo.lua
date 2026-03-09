-- ============================================================================
-- BaseOS  |  programs/todo.lua
-- Task manager — windowed, touch-driven, runs inside the BaseOS kernel.
-- Receives a CC window object (win) as its only argument.
-- Text input (add / edit) falls through to the physical terminal since
-- CC:Tweaked has no monitor keyboard; the user types on the computer.
-- ============================================================================

local Todo = {}

-- ─── Config ──────────────────────────────────────────────────────────────────
local SERVER   = "192.168.1.41:5005"
local API_BASE = "http://" .. SERVER .. "/todo/api"

-- ─── Status metadata ─────────────────────────────────────────────────────────
local STATUS_LABELS = { todo = "To Do", inprogress = "In Progress", done = "Done" }
local STATUS_COLORS = { todo = colors.yellow, inprogress = colors.orange, done = colors.lime }
local STATUS_ORDER  = { "todo", "inprogress", "done" }

-- ─── HTTP helpers ────────────────────────────────────────────────────────────
local function httpGet(url)
    local ok, resp = pcall(http.get, url)
    if not ok or not resp then return nil end
    local body = resp.readAll(); resp.close()
    return textutils.unserialiseJSON(body)
end

local function httpPost(endpoint, payload)
    local ok, resp = pcall(
        http.post,
        API_BASE .. endpoint,
        textutils.serialiseJSON(payload),
        { ["Content-Type"] = "application/json" }
    )
    if not ok or not resp then return nil end
    local body = resp.readAll(); resp.close()
    return textutils.unserialiseJSON(body)
end

-- ─── main(win) ───────────────────────────────────────────────────────────────
function Todo.main(win)
    local w, h = win.getSize()

    -- ── State ──────────────────────────────────────────────────
    local todos    = {}
    local scroll   = 0     -- first visible item index (0-based)
    local selected = 1     -- 1-based index into todos
    local screen   = "list"  -- "list" | "view"
    local status   = ""    -- status message shown at bottom of list

    -- ── Drawing helpers ────────────────────────────────────────
    local function fill(y, bg)
        win.setCursorPos(1, y)
        win.setBackgroundColor(bg)
        win.write(string.rep(" ", w))
    end

    local function wWrite(x, y, text, fg, bg)
        win.setCursorPos(x, y)
        if bg then win.setBackgroundColor(bg) end
        if fg then win.setTextColor(fg)       end
        win.write(text)
    end

    -- Draw a button: returns the x coordinate AFTER the button
    local function drawBtn(x, y, label, fg, bg)
        local btn = "[ " .. label .. " ]"
        wWrite(x, y, btn, fg, bg)
        return x + #btn + 1
    end

    -- ── API calls ──────────────────────────────────────────────
    local function fetchTodos()
        status = "Loading\x85"
        win.setCursorPos(2, h)
        win.setBackgroundColor(colors.black)
        win.setTextColor(colors.yellow)
        win.write(status)
        local data = httpGet(API_BASE)
        if data and data.todos then
            todos = data.todos
        else
            status = "Failed to fetch tasks"
        end
    end

    local function apiAdd(title, desc)
        return httpPost("/add", { title = title, description = desc })
    end

    local function apiModify(id, field, value)
        return httpPost("/modify", { id = id, fieldToModify = field, newValue = value })
    end

    local function apiDelete(id)
        return httpPost("/delete", { id = id })
    end

    -- ── List screen ────────────────────────────────────────────
    -- Touch targets recorded per draw for hit-testing
    local listItemRows = {}  -- [row_y] = todos index

    local function drawList()
        win.setBackgroundColor(colors.black)
        win.clear()
        listItemRows = {}

        -- ── Toolbar (row 1) ──
        local done_c = 0
        for _, t in ipairs(todos) do
            if t.status == "done" then done_c = done_c + 1 end
        end

        fill(1, colors.gray)
        local bx = 2
        bx = drawBtn(bx, 1, "+ Add",    colors.lime,    colors.gray)
        bx = drawBtn(bx, 1, "\x1d Ref", colors.cyan,    colors.gray)
        local counter = "[" .. done_c .. "/" .. #todos .. "]"
        wWrite(w - #counter, 1, counter, colors.lightGray, colors.gray)

        -- ── Items ──
        local ITEM_H   = 2      -- rows per item (title + status)
        local listTop  = 2
        local listBot  = h - 1  -- last usable row (h = status bar)
        local visible  = math.floor((listBot - listTop + 1) / ITEM_H)

        -- Clamp scroll
        scroll = math.max(0, math.min(scroll, #todos - visible))

        for i = 1, visible do
            local idx   = i + scroll
            local row_y = listTop + (i - 1) * ITEM_H
            if idx > #todos then break end

            local t      = todos[idx]
            local is_sel = (idx == selected)
            local bg     = is_sel and colors.gray or colors.black

            fill(row_y,     bg)
            fill(row_y + 1, bg)

            -- Status marker
            local marker = (t.status == "inprogress") and "~"
                        or (t.status == "done")        and "\xfb"
                        or " "
            local sc = STATUS_COLORS[t.status] or colors.white

            wWrite(2, row_y, "[" .. marker .. "]", sc, bg)

            -- Title
            local maxlen = w - 7
            local title  = (t.title or "Untitled"):sub(1, maxlen)
            wWrite(6, row_y, title,
                t.status == "done" and colors.gray or colors.white, bg)

            -- Status label (row below)
            local sl = STATUS_LABELS[t.status] or t.status
            wWrite(6, row_y + 1, sl, sc, bg)

            -- Record touch target
            listItemRows[row_y]     = idx
            listItemRows[row_y + 1] = idx
        end

        -- ── Scroll indicators ──
        if scroll > 0 then
            wWrite(w - 1, listTop, "\x1e", colors.white, colors.black)
        end
        if scroll + visible < #todos then
            wWrite(w - 1, listBot, "\x1f", colors.white, colors.black)
        end

        -- ── Status bar ──
        fill(h, colors.gray)
        wWrite(2, h, status ~= "" and status or "Touch a task to open", colors.lightGray, colors.gray)
    end

    -- ── View screen ────────────────────────────────────────────
    -- Button touch zones recorded per draw
    local viewBtns = {}  -- list of { x1,x2, y, action }

    local function recordBtn(x, y, label, action)
        viewBtns[#viewBtns + 1] = { x1 = x, x2 = x + #("[ " .. label .. " ]") - 1, y = y, action = action }
    end

    local function drawView()
        if not todos[selected] then screen = "list"; return end
        local t = todos[selected]
        viewBtns = {}

        win.setBackgroundColor(colors.black)
        win.clear()

        -- ── Toolbar ──
        fill(1, colors.gray)
        local bx = 2
        recordBtn(bx, 1, "\xab Back", "back")
        bx = drawBtn(bx, 1, "\xab Back",   colors.white,  colors.gray)
        recordBtn(bx, 1, "Del", "delete")
        bx = drawBtn(bx, 1, "Del",        colors.red,    colors.gray)
        wWrite(w - 12, 1, selected .. "/" .. #todos, colors.lightGray, colors.gray)

        -- ── Content ──
        wWrite(2, 3,  "Title",        colors.lightGray, colors.black)
        wWrite(2, 4,  (t.title or "Untitled"):sub(1, w - 3), colors.white, colors.black)

        wWrite(2, 6,  "Description",  colors.lightGray, colors.black)
        local desc = t.description or "—"
        wWrite(2, 7,  desc:sub(1, w - 3), colors.white, colors.black)
        if #desc > w - 3 then
            wWrite(2, 8, desc:sub(w - 2, (w - 3) * 2), colors.white, colors.black)
        end

        wWrite(2, 10, "Status",       colors.lightGray, colors.black)
        local sc = STATUS_COLORS[t.status] or colors.white
        local sl = STATUS_LABELS[t.status] or t.status
        wWrite(2, 11, sl,             sc,               colors.black)

        -- ── Status buttons ──
        wWrite(2, 13, "Set status:",  colors.lightGray, colors.black)
        local sbx = 2
        for _, s in ipairs(STATUS_ORDER) do
            local active = (t.status == s)
            local fg = active and colors.black  or STATUS_COLORS[s]
            local bg = active and STATUS_COLORS[s] or colors.gray
            local lbl = STATUS_LABELS[s]
            recordBtn(sbx, 14, lbl, "status:" .. s)
            sbx = drawBtn(sbx, 14, lbl, fg, bg)
        end

        -- ── Edit button ──
        wWrite(2, 16, "Edit:",        colors.lightGray, colors.black)
        recordBtn(2, 17, "Edit Title", "edit:title")
        local ex = drawBtn(2, 17, "Edit Title", colors.white, colors.gray)
        recordBtn(ex, 17, "Edit Desc",  "edit:desc")
        drawBtn(ex, 17,  "Edit Desc",  colors.white, colors.gray)

        -- ── Status bar ──
        fill(h, colors.gray)
        wWrite(2, h, status ~= "" and status or " ", colors.lightGray, colors.gray)
    end

    -- ── Redraw dispatcher ──────────────────────────────────────
    local function draw()
        if screen == "list" then drawList()
        else                     drawView() end
    end

    -- ── Text input via terminal ────────────────────────────────
    -- Since monitors have no keyboard, we fall back to the computer terminal.
    local function termInput(prompt)
        -- Tell the user on the monitor
        fill(h, colors.yellow)
        wWrite(2, h, "Type on terminal: " .. prompt, colors.black, colors.yellow)

        -- Read from terminal
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.clear()
        term.write("BaseOS \x10 " .. (activeEntry and activeEntry.label or "?"))
        term.setCursorPos(1, 3)
        term.setTextColor(colors.white)
        term.write(prompt .. ": ")
        local input = read()
        term.clear(); term.setCursorPos(1,1)
        return input
    end

    -- ── Actions ────────────────────────────────────────────────
    local function doAdd()
        local title = termInput("New task title")
        if title and #title > 0 then
            local desc = termInput("Description (optional)")
            apiAdd(title, desc or "")
            fetchTodos()
            selected = #todos
            status   = "Task added!"
        else
            status = "Cancelled"
        end
        screen = "list"
        draw()
    end

    local function doDelete()
        if not todos[selected] then return end
        local id = todos[selected].id
        apiDelete(id)
        fetchTodos()
        selected = math.max(1, math.min(selected, #todos))
        status   = "Task deleted"
        screen   = "list"
        draw()
    end

    local function doSetStatus(new_s)
        if not todos[selected] then return end
        apiModify(todos[selected].id, "status", new_s)
        fetchTodos()
        status = "Status \x10 " .. (STATUS_LABELS[new_s] or new_s)
        draw()
    end

    local function doEdit(field)
        if not todos[selected] then return end
        local t   = todos[selected]
        local cur = field == "title" and t.title or t.description
        local val = termInput("New " .. field .. " [" .. (cur or "") .. "]")
        if val and #val > 0 then
            apiModify(t.id, field, val)
            fetchTodos()
            status = field:sub(1,1):upper() .. field:sub(2) .. " updated"
        else
            status = "No change"
        end
        draw()
    end

    -- ── Touch handlers ─────────────────────────────────────────
    local ADD_BTN   = { x1 = 2, x2 = 9 }   -- "[ + Add ]" width = 9
    local REF_BTN   = { x1 = 11, x2 = 19 } -- "[ \x1d Ref ]"

    local ITEM_H  = 2
    local listTop = 2

    local function handleListTouch(x, y)
        -- Toolbar row
        if y == 1 then
            if x >= ADD_BTN.x1 and x <= ADD_BTN.x2 then
                doAdd()
            elseif x >= REF_BTN.x1 and x <= REF_BTN.x2 then
                fetchTodos()
                selected = math.max(1, math.min(selected, #todos))
                status   = "Refreshed"
                draw()
            end
            return
        end

        -- Item rows
        local idx = listItemRows[y]
        if idx then
            if idx == selected then
                -- Second tap opens view
                screen = "view"
                draw()
            else
                selected = idx
                draw()
            end
        end
    end

    local function handleViewTouch(x, y)
        for _, btn in ipairs(viewBtns) do
            if y == btn.y and x >= btn.x1 and x <= btn.x2 then
                local action = btn.action
                if     action == "back"   then screen = "list"; status = ""; draw()
                elseif action == "delete" then doDelete()
                elseif action:sub(1,7) == "status:" then doSetStatus(action:sub(8))
                elseif action:sub(1,5) == "edit:"   then doEdit(action:sub(6))
                end
                return
            end
        end
    end

    -- ── Boot ───────────────────────────────────────────────────
    fetchTodos()
    selected = math.max(1, math.min(1, #todos))
    status   = ""
    draw()

    -- ── Event loop ─────────────────────────────────────────────
    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "monitor_touch" then
            -- p2 = x, p3 = y  (already in contentWin coords from kernel)
            if screen == "list" then handleListTouch(p2, p3)
            else                     handleViewTouch(p2, p3)
            end

        elseif ev == "key" then
            -- Keyboard shortcuts still work on the physical terminal
            if screen == "list" then
                if     p1 == keys.up    then scroll = math.max(0, scroll - 1); draw()
                elseif p1 == keys.down  then scroll = scroll + 1; draw()
                elseif p1 == keys.a     then doAdd()
                elseif p1 == keys.r     then fetchTodos(); status = "Refreshed"; draw()
                elseif p1 == keys.q     then return  -- exits back to BaseOS home
                end
            elseif screen == "view" then
                if     p1 == keys.backspace or p1 == keys.grave then screen = "list"; status = ""; draw()
                elseif p1 == keys.s  then
                    if todos[selected] then
                        local cur = todos[selected].status or "todo"
                        for i, s in ipairs(STATUS_ORDER) do
                            if s == cur then doSetStatus(STATUS_ORDER[(i % #STATUS_ORDER) + 1]); break end
                        end
                    end
                elseif p1 == keys.d then doDelete()
                end
            end
        end
    end
end

return Todo
