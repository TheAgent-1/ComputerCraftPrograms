-- ============================================================
--  todo.lua  |  CC:Tweaked Todo App
--  Terminal : keyboard navigation (list, view, add, edit)
--  Monitor  : click-based detail view with status buttons
-- ============================================================

local SERVER   = "192.168.1.41:5005"   -- <<< CHANGE THIS to your server IP:port
local API_BASE = "http://" .. SERVER .. "/todo/api"

-- Set to the side your monitor is on ("top","left","right","bottom","front","back")
-- Set to nil to run without a monitor
local MONITOR_SIDE = "top"

-- --- Status config -------------------------------------------
local STATUS_LABELS = { todo = "To Do", inprogress = "In Progress", done = "Done" }
local STATUS_COLORS = { todo = colors.yellow, inprogress = colors.orange, done = colors.lime }
local STATUS_ORDER  = { "todo", "inprogress", "done" }

-- --- State ---------------------------------------------------
local todos      = {}
local selected   = 1
local screen     = "list"   -- "list" | "view"
local status_msg = ""
local mon        = nil

-- --- Monitor Setup -------------------------------------------
local function setupMonitor()
    if not MONITOR_SIDE then return end
    if peripheral.isPresent(MONITOR_SIDE)
    and peripheral.getType(MONITOR_SIDE) == "monitor" then
        mon = peripheral.wrap(MONITOR_SIDE)
        mon.setTextScale(0.5)
    end
end

-- --- HTTP Helpers --------------------------------------------
local function httpGet(url)
    local ok, resp = pcall(http.get, url)
    if not ok or not resp then return nil end
    local body = resp.readAll()
    resp.close()
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
    local body = resp.readAll()
    resp.close()
    return textutils.unserialiseJSON(body)
end

-- --- API Calls -----------------------------------------------
local function fetchTodos()
    local data = httpGet(API_BASE)
    if data and data.todos then
        todos = data.todos
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

-- --- Terminal Drawing ----------------------------------------
local tw, th = term.getSize()

local function termDrawText(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(text)
end

local function drawHeader(title)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write("  " .. title)
    term.setBackgroundColor(colors.black)
end

local function drawFooter(hints)
    term.setCursorPos(1, th)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    term.write("  " .. hints)
    term.setBackgroundColor(colors.black)
end

local function drawStatusMsg()
    term.setCursorPos(1, th - 1)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    if status_msg ~= "" then
        termDrawText(1, th - 1, "  " .. status_msg, colors.yellow, colors.black)
    end
end

local function drawList()
    term.setBackgroundColor(colors.black)
    term.clear()

    local done_c = 0
    for _, t in ipairs(todos) do
        if t.status == "done" then done_c = done_c + 1 end
    end
    drawHeader("TODO  [" .. done_c .. "/" .. #todos .. " done]")

    local list_h = th - 3
    local scroll = math.max(0, selected - list_h)

    for row = 1, list_h do
        local idx = row + scroll
        term.setCursorPos(1, row + 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()

        if idx <= #todos then
            local t      = todos[idx]
            local is_sel = (idx == selected)
            term.setBackgroundColor(is_sel and colors.gray or colors.black)

            -- Status indicator
            local marker = " "
            if t.status == "inprogress" then marker = "~"
            elseif t.status == "done"   then marker = "x"
            end
            local sc = STATUS_COLORS[t.status] or colors.white

            term.setTextColor(sc)
            term.write(" [" .. marker .. "] ")

            -- Title (truncated)
            local max_len = tw - 7
            local title = t.title or "Untitled"
            if #title > max_len then title = title:sub(1, max_len - 2) .. ".." end
            term.setTextColor(t.status == "done" and colors.gray or colors.white)
            term.write(title)
        end

        term.setBackgroundColor(colors.black)
    end

    drawStatusMsg()
    drawFooter("Enter=view  A=add  D=delete  R=refresh  Q=quit")
end

local function drawView()
    if not todos[selected] then
        screen = "list"
        drawList()
        return
    end

    local t = todos[selected]
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader("TASK DETAILS  [" .. selected .. "/" .. #todos .. "]")

    -- Title
    termDrawText(1, 3,  "  Title:",       colors.lightGray, colors.black)
    termDrawText(1, 4,  "  " .. (t.title or "Untitled"), colors.white, colors.black)

    -- Description (simple wrap)
    termDrawText(1, 6,  "  Description:", colors.lightGray, colors.black)
    local desc    = t.description or "No description"
    local max_w   = tw - 4
    termDrawText(1, 7,  "  " .. desc:sub(1, max_w), colors.white, colors.black)
    if #desc > max_w then
        termDrawText(1, 8, "  " .. desc:sub(max_w + 1, max_w * 2), colors.white, colors.black)
    end

    -- Status
    local sc = STATUS_COLORS[t.status] or colors.white
    local sl = STATUS_LABELS[t.status]  or t.status
    termDrawText(1, 10, "  Status:",      colors.lightGray, colors.black)
    termDrawText(1, 11, "  " .. sl,       sc,              colors.black)

    drawStatusMsg()
    drawFooter("E=edit  S=cycle status  D=delete  `=back")
end

local function draw()
    if     screen == "list" then drawList()
    elseif screen == "view" then drawView()
    end
end

-- --- Monitor Drawing -----------------------------------------
local function monDrawText(x, y, text, fg, bg)
    mon.setCursorPos(x, y)
    if fg then mon.setTextColor(fg) end
    if bg then mon.setBackgroundColor(bg) end
    mon.write(text)
end

local function monDrawButton(x, y, label, active, activeColor)
    local fg = active and colors.black  or activeColor
    local bg = active and activeColor   or colors.gray
    monDrawText(x, y, "[ " .. label .. " ]", fg, bg)
end

local function drawMonitor()
    if not mon then return end
    local mw, mh = mon.getSize()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    if #todos == 0 or not todos[selected] then
        monDrawText(1, 1, "No task selected", colors.gray, colors.black)
        return
    end

    local t  = todos[selected]
    local sc = STATUS_COLORS[t.status] or colors.white
    local sl = STATUS_LABELS[t.status] or t.status

    -- Header bar
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.clearLine()
    monDrawText(2, 1, "TASK DETAILS", colors.white, colors.blue)
    mon.setBackgroundColor(colors.black)

    -- Title
    monDrawText(1, 3, "Title:",      colors.lightGray, colors.black)
    monDrawText(1, 4, " " .. (t.title or "Untitled"):sub(1, mw - 2), colors.white, colors.black)

    -- Description
    monDrawText(1, 6, "Description:", colors.lightGray, colors.black)
    local desc = t.description or "No description"
    monDrawText(1, 7, " " .. desc:sub(1, mw - 2), colors.white, colors.black)
    if #desc > mw - 2 then
        monDrawText(1, 8, " " .. desc:sub(mw - 1, (mw - 2) * 2), colors.white, colors.black)
    end

    -- Status
    monDrawText(1, 10, "Status:", colors.lightGray, colors.black)
    monDrawText(1, 11, " " .. sl,  sc,             colors.black)

    -- Divider
    mon.setCursorPos(1, mh - 2)
    mon.setTextColor(colors.gray)
    mon.write(string.rep("-", mw))

    -- Status buttons on last line (click targets)
    monDrawText(1, mh - 1, "Set status:", colors.lightGray, colors.black)
    monDrawButton(1,  mh, "TODO", t.status == "todo",       colors.yellow)
    monDrawButton(10, mh, "WIP",  t.status == "inprogress", colors.orange)
    monDrawButton(18, mh, "DONE", t.status == "done",       colors.lime)

    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
end

-- --- Actions -------------------------------------------------
local function doAdd()
    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader("NEW TASK")

    termDrawText(1, 3, "  Title: ", colors.white, colors.black)
    term.setCursorPos(11, 3)
    os.sleep(0)  -- flush pending key events before accepting input
    local title = read()

    termDrawText(1, 5, "  Description: ", colors.white, colors.black)
    term.setCursorPos(17, 5)
    os.sleep(0)
    local desc = read()

    if title and #title > 0 then
        status_msg = "Adding..."
        apiAdd(title, desc or "")
        fetchTodos()
        selected   = #todos
        status_msg = "Task added!"
    else
        status_msg = "Cancelled"
    end

    screen = "list"
    draw()
    drawMonitor()
end

local function doEdit()
    if not todos[selected] then return end
    local t = todos[selected]

    term.setBackgroundColor(colors.black)
    term.clear()
    drawHeader("EDIT TASK")

    termDrawText(1, 3, "  Leave blank to keep current value", colors.lightGray, colors.black)

    termDrawText(1, 5, "  Title:", colors.white, colors.black)
    termDrawText(1, 6, "  [" .. (t.title or "") .. "]", colors.gray, colors.black)
    termDrawText(1, 7, "  New: ", colors.white, colors.black)
    term.setCursorPos(9, 7)
    os.sleep(0)  -- flush pending key events before accepting input
    local new_title = read()

    termDrawText(1, 9, "  Description:", colors.white, colors.black)
    termDrawText(1, 10, "  [" .. (t.description or "") .. "]", colors.gray, colors.black)
    termDrawText(1, 11, "  New: ", colors.white, colors.black)
    term.setCursorPos(9, 11)
    os.sleep(0)
    local new_desc = read()

    if new_title and #new_title > 0 then
        apiModify(t.id, "title", new_title)
    end
    if new_desc and #new_desc > 0 then
        apiModify(t.id, "description", new_desc)
    end

    fetchTodos()
    status_msg = "Task updated!"
    screen     = "view"
    draw()
    drawMonitor()
end

local function doCycleStatus()
    if not todos[selected] then return end
    local t   = todos[selected]
    local cur = t.status or "todo"

    local next_s = STATUS_ORDER[1]
    for i, s in ipairs(STATUS_ORDER) do
        if s == cur then
            next_s = STATUS_ORDER[(i % #STATUS_ORDER) + 1]
            break
        end
    end

    apiModify(t.id, "status", next_s)
    fetchTodos()
    status_msg = "Status → " .. (STATUS_LABELS[next_s] or next_s)
    draw()
    drawMonitor()
end

local function doDelete()
    if not todos[selected] then return end
    local id = todos[selected].id
    apiDelete(id)
    fetchTodos()
    selected   = math.max(1, math.min(selected, #todos))
    status_msg = "Task deleted"
    screen     = "list"
    draw()
    drawMonitor()
end

-- --- Keyboard Handler ----------------------------------------
-- Returns false to signal quit
local function handleKey(key)
    local n = #todos

    if screen == "list" then
        if key == keys.up then
            selected = math.max(1, selected - 1)
            draw(); drawMonitor()

        elseif key == keys.down then
            selected = math.min(n, selected + 1)
            draw(); drawMonitor()

        elseif key == keys.enter and n > 0 then
            screen = "view"; draw(); drawMonitor()

        elseif key == keys.a then
            doAdd()

        elseif key == keys.d and n > 0 then
            doDelete()

        elseif key == keys.r and n > 0 then
            fetchTodos()
            selected = math.max(1, math.min(selected, #todos))
            status_msg = "Tasks refreshed"
            draw(); drawMonitor()

        elseif key == keys.q then
            return false
        end

    elseif screen == "view" then
        if key == keys.e then
            doEdit()

        elseif key == keys.s then
            doCycleStatus()

        elseif key == keys.d then
            doDelete()

        elseif key == keys.backspace or key == keys.grave then
            status_msg = ""
            screen     = "list"
            draw(); drawMonitor()
        end
    end

    return true
end

-- --- Monitor Click Handler ------------------------------------
local function handleMonitorClick(x, y)
    if not mon or not todos[selected] then return end
    local _, mh = mon.getSize()
    local t = todos[selected]

    -- Status buttons are on the last row
    if y == mh then
        local new_status = nil

        if     x >= 1  and x <= 8  then new_status = "todo"
        elseif x >= 10 and x <= 16 then new_status = "inprogress"
        elseif x >= 18             then new_status = "done"
        end

        if new_status and new_status ~= t.status then
            apiModify(t.id, "status", new_status)
            fetchTodos()
            draw()
            drawMonitor()
        end
    end
end

-- --- Main -----------------------------------------------------
setupMonitor()

status_msg = "Loading..."
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
term.write(status_msg)

fetchTodos()
selected   = math.max(1, math.min(selected, #todos))
status_msg = ""

draw()
drawMonitor()

while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "key" then
        if not handleKey(p1) then break end

    elseif ev == "monitor_touch" then
        -- p1 = side, p2 = x, p3 = y
        handleMonitorClick(p2, p3)
    end
end

-- Cleanup
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Todo closed.")
os.sleep(0.5)