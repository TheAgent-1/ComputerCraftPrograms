-- ============================================================================
-- BaseOS  |  kernel.lua
-- Coroutine-based windowed OS for CC:Tweaked
-- Programs live in /programs/, each returns a module with a main(win) function.
-- The OS owns the header bar; programs render into a content window below it.
-- ============================================================================

local OS_NAME    = "BaseOS"
local OS_COMPANY = "Spectre Inc."
local VERSION    = "1.0"

-- ─── Layout constants ────────────────────────────────────────────────────────
local HEADER_H  = 2   -- rows the OS header occupies (row 1 = title, row 2 = accent)
local TILE_COLS = 4   -- columns in the program grid
local TILE_H    = 6   -- height of each program tile (rows)
local TILE_GAP  = 1   -- 1-col right gap between tiles (visual separator)

-- ─── Monitor setup ───────────────────────────────────────────────────────────
local mon = peripheral.find("monitor")
if not mon then
    error("[BaseOS] No monitor attached. Attach a monitor and restart.")
end
mon.setTextScale(0.5)
mon.clear()
local mw, mh = mon.getSize()

-- ─── Content window ──────────────────────────────────────────────────────────
-- Programs only see this window; they use it exactly like `mon`.
local contentWin = window.create(mon, 1, HEADER_H + 1, mw, mh - HEADER_H, true)
local cw, ch     = contentWin.getSize()

-- ─── Registry ────────────────────────────────────────────────────────────────
local registry = dofile("registry.lua")

-- ─── OS state ────────────────────────────────────────────────────────────────
local activeEntry = nil   -- registry entry currently running (nil = home screen)
local activeCoro  = nil   -- coroutine wrapping the active program

-- ─── Drawing helpers ─────────────────────────────────────────────────────────
local function monFill(y, bg)
    mon.setCursorPos(1, y)
    mon.setBackgroundColor(bg)
    mon.write(string.rep(" ", mw))
end

local function monWrite(x, y, text, fg, bg)
    mon.setCursorPos(x, y)
    if bg then mon.setBackgroundColor(bg) end
    if fg then mon.setTextColor(fg)       end
    mon.write(text)
end

-- ─── Header ──────────────────────────────────────────────────────────────────
-- Touch zone for the Home button (row 1, columns 2-8 → " Home ")
local HOME_X1, HOME_X2 = 2, 8

local function drawHeader()
    -- Row 1: main bar with Home button + centred title
    monFill(1, colors.purple)
    monWrite(HOME_X1, 1, "\xab Home", colors.white, colors.purple)

    local title = activeEntry
        and ("\x10 " .. activeEntry.label)
        or  (OS_NAME .. "  \x07  " .. OS_COMPANY)
    local tx = math.max(HOME_X2 + 2, math.floor((mw - #title) / 2) + 1)
    monWrite(tx, 1, title, colors.white, colors.purple)

    -- Row 2: thin info bar
    monFill(2, colors.gray)
    local sub = activeEntry
        and (activeEntry.desc or "")
        or  ("v" .. VERSION .. "  \x1a\x1b  " .. #registry .. " programs installed")
    monWrite(3, 2, sub, colors.lightGray, colors.gray)

    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
end

-- ─── Home grid ───────────────────────────────────────────────────────────────
local tileW = math.floor(cw / TILE_COLS)

-- Returns the top-left (x, y) and dimensions (w, h) of tile at index idx
-- All coords are in contentWin space.
local function tileRegion(idx)
    local col = (idx - 1) % TILE_COLS
    local row = math.floor((idx - 1) / TILE_COLS)
    return col * tileW + 1, row * TILE_H + 1, tileW - TILE_GAP, TILE_H
end

local function drawTile(idx, entry)
    local x, y, w, h = tileRegion(idx)
    local bg = entry.color or colors.blue

    -- Tile background
    for dy = 0, h - 1 do
        contentWin.setCursorPos(x, y + dy)
        contentWin.setBackgroundColor(bg)
        contentWin.write(string.rep(" ", w))
    end

    -- Icon (centred, 2 rows from top)
    local icon = entry.icon or "\x0f"
    local ix = x + math.floor((w - #icon) / 2)
    contentWin.setCursorPos(ix, y + 1)
    contentWin.setTextColor(colors.white)
    contentWin.setBackgroundColor(bg)
    contentWin.write(icon)

    -- Label (centred, below icon)
    local label = entry.label or "?"
    local lx = x + math.floor((w - #label) / 2)
    contentWin.setCursorPos(lx, y + 2)
    contentWin.setTextColor(colors.white)
    contentWin.write(label)

    -- Desc (centred, faint)
    if entry.desc then
        local desc = entry.desc
        if #desc > w - 2 then desc = desc:sub(1, w - 4) .. ".." end
        local dx = x + math.floor((w - #desc) / 2)
        contentWin.setCursorPos(dx, y + 3)
        contentWin.setTextColor(colors.lightGray)
        contentWin.write(desc)
    end
end

local function drawHomeGrid()
    contentWin.setBackgroundColor(colors.black)
    contentWin.clear()
    for i, entry in ipairs(registry) do
        -- Only draw tiles that fit vertically
        local _, ty = tileRegion(i)
        if ty + TILE_H - 1 <= ch then
            drawTile(i, entry)
        end
    end
end

-- Returns the registry index of the tile at contentWin coords (cx, cy), or nil
local function tileAt(cx, cy)
    local col = math.floor((cx - 1) / tileW)
    local row = math.floor((cy - 1) / TILE_H)
    local idx = row * TILE_COLS + col + 1
    if registry[idx] then
        -- Confirm click is within the tile body (not the gap)
        local tx, ty, tw, th = tileRegion(idx)
        if cx >= tx and cx <= tx + tw - 1
        and cy >= ty and cy <= ty + th - 1 then
            return idx
        end
    end
    return nil
end

-- ─── Program lifecycle ───────────────────────────────────────────────────────
local function goHome()
    activeEntry = nil
    activeCoro  = nil
    contentWin.setBackgroundColor(colors.black)
    contentWin.clear()
    drawHeader()
    drawHomeGrid()
end

local function showError(msg, detail)
    contentWin.setBackgroundColor(colors.red)
    contentWin.clear()
    contentWin.setCursorPos(1, 1)
    contentWin.setTextColor(colors.white)
    contentWin.write(msg)
    if detail then
        contentWin.setCursorPos(1, 2)
        contentWin.setTextColor(colors.yellow)
        contentWin.write(tostring(detail):sub(1, cw))
    end
    contentWin.setCursorPos(1, 4)
    contentWin.setTextColor(colors.lightGray)
    contentWin.write("Touch Home to continue.")
end

local function launchProgram(entry)
    -- Load module from file
    local ok, mod = pcall(dofile, entry.file)
    if not ok then
        activeEntry = entry
        drawHeader()
        showError("Load error: " .. entry.label, mod)
        return
    end
    if type(mod) ~= "table" or type(mod.main) ~= "function" then
        activeEntry = entry
        drawHeader()
        showError("Bad module: " .. entry.label, "Missing main() function")
        return
    end

    activeEntry = entry
    drawHeader()
    contentWin.setBackgroundColor(colors.black)
    contentWin.clear()

    -- Wrap main(win) in a coroutine
    activeCoro = coroutine.create(function()
        mod.main(contentWin)
    end)

    -- Initial run (program runs until its first os.pullEvent())
    local ok2, err = coroutine.resume(activeCoro)
    if not ok2 then
        showError("Runtime error: " .. entry.label, err)
        activeCoro = nil
    elseif coroutine.status(activeCoro) == "dead" then
        -- Program returned immediately (unusual but valid)
        goHome()
    end
end

-- ─── Event forwarding ────────────────────────────────────────────────────────
-- Resumes the active coroutine with an event.
-- If the coroutine crashes or returns, falls back to home.
local function forwardEvent(...)
    if not activeCoro or coroutine.status(activeCoro) ~= "suspended" then return end

    local ok, err = coroutine.resume(activeCoro, ...)

    if not ok then
        -- Runtime crash
        showError("Crash: " .. (activeEntry and activeEntry.label or "?"), err)
        activeCoro = nil
        -- Leave header intact so user can press Home
    elseif coroutine.status(activeCoro) == "dead" then
        -- Program exited cleanly via return
        goHome()
    end
end

-- ─── Header touch ────────────────────────────────────────────────────────────
-- Called when the user touches anywhere in the header rows (y <= HEADER_H).
local function handleHeaderTouch(x, y)
    if y == 1 and x >= HOME_X1 and x <= HOME_X2 + 2 then
        goHome()
    end
end

-- ─── Boot ────────────────────────────────────────────────────────────────────
drawHeader()
drawHomeGrid()

-- ─── Main event loop ─────────────────────────────────────────────────────────
while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "monitor_touch" then
        -- p1 = side, p2 = x, p3 = y  (absolute monitor coords)
        local mx, my = p2, p3

        if my <= HEADER_H then
            -- Header is always owned by the OS
            handleHeaderTouch(mx, my)

        elseif activeEntry then
            -- Translate y into contentWin-local coords before forwarding
            forwardEvent(ev, p1, mx, my - HEADER_H)

        else
            -- Home screen: check if a tile was clicked
            local idx = tileAt(mx, my - HEADER_H)
            if idx then
                launchProgram(registry[idx])
            end
        end

    elseif activeCoro then
        -- Forward every other event (key, char, http_success, etc.) unmodified
        forwardEvent(ev, p1, p2, p3)
    end
end
