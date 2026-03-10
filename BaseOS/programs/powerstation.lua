-- ============================================================================
-- BaseOS  |  programs/powerstation.lua
-- Powerstation dashboard — windowed version for BaseOS
-- TODO: full integration of Powerstation_Client.lua data into this UI
-- ============================================================================

local Powerstation = {}

local CONFIG = {
    API_URL    = "http://192.168.1.40:5005/powerstation/api",
    STATUS_URL = "http://192.168.1.40:5005/powerstation/api/status",
    POLL_EVERY = 3,  -- seconds between auto-refresh
}

local function wWrite(win, x, y, text, fg, bg)
    win.setCursorPos(x, y)
    if bg then win.setBackgroundColor(bg) end
    if fg then win.setTextColor(fg) end
    win.write(text)
end

local function drawBtn(win, x, y, label, fg, bg)
    local btn = "[ " .. label .. " ]"
    wWrite(win, x, y, btn, fg, bg)
    return x + #btn + 1
end

local function fetchStatus()
    local ok, resp = pcall(http.get, CONFIG.STATUS_URL)
    if not ok or not resp then return nil end
    local body = resp.readAll(); resp.close()
    return textutils.unserialiseJSON(body)
end

local function sendCommand(action, value)
    local ok, resp = pcall(
        http.post,
        CONFIG.API_URL,
        textutils.serialiseJSON({ action = action, value = value }),
        { ["Content-Type"] = "application/json" }
    )
    if ok and resp then resp.close() end
end

function Powerstation.main(win)
    local w, h = win.getSize()

    local state   = nil
    local lastPoll = 0
    local btns    = {}  -- touch targets

    local function drawBar(win, x, y, barW, value, maxVal, fg, bg)
        local filled = math.floor((value / maxVal) * barW)
        win.setCursorPos(x, y)
        win.setBackgroundColor(fg)
        win.write(string.rep(" ", filled))
        win.setBackgroundColor(bg)
        win.write(string.rep(" ", barW - filled))
    end

    local function draw()
        win.setBackgroundColor(colors.black)
        win.clear()
        btns = {}

        if not state then
            wWrite(win, 2, 2, "Connecting to Powerstation API\x85", colors.yellow, colors.black)
            wWrite(win, 2, 4, CONFIG.STATUS_URL, colors.gray, colors.black)
            return
        end

        -- ── Relay status ──
        local relayOn  = state.relayState == "on"
        local relayCol = relayOn and colors.lime or colors.red
        local relayStr = relayOn and "ON" or "OFF"
        wWrite(win, 2, 2, "Relay:", colors.lightGray, colors.black)
        wWrite(win, 10, 2, relayStr, relayCol, colors.black)

        -- Toggle relay button
        local toggleLabel = relayOn and "Turn OFF" or "Turn ON"
        local toggleCol   = relayOn and colors.red  or colors.lime
        btns[#btns + 1] = { x1 = 2, x2 = 2 + #("[ " .. toggleLabel .. " ]") - 1, y = 3,
                            action = relayOn and "set-relay:off" or "set-relay:on" }
        drawBtn(win, 2, 3, toggleLabel, colors.black, toggleCol)

        -- ── RSC speed ──
        local rsc = state.rotationSpeedController or 0
        wWrite(win, 2, 5, "RSC Speed: " .. rsc .. " RPM", colors.white, colors.black)

        -- Speed control buttons
        local sx = 2
        for _, speed in ipairs({64, 128, 256, 512}) do
            local active = (rsc == speed)
            local fg = active and colors.black or colors.white
            local bg = active and colors.yellow or colors.gray
            local lbl = tostring(speed)
            btns[#btns + 1] = { x1 = sx, x2 = sx + #("[ " .. lbl .. " ]") - 1, y = 6,
                                action = "set-rsc:" .. speed }
            sx = drawBtn(win, sx, 6, lbl, fg, bg)
        end

        -- ── Stress level ──
        local stress = state.stressLevel or 0
        wWrite(win, 2, 8, "Network Stress:", colors.lightGray, colors.black)
        local stressCol = stress > 80 and colors.red or (stress > 50 and colors.orange or colors.lime)
        drawBar(win, 2, 9, math.floor(w * 0.6), stress, 100, stressCol, colors.gray)
        wWrite(win, math.floor(w * 0.6) + 4, 9, stress .. "%", stressCol, colors.black)

        -- ── Power reserves ──
        local reserves = state.powerReserves or 0
        wWrite(win, 2, 11, "Power Reserves:", colors.lightGray, colors.black)
        local resMax = state.maxPowerReserves or math.max(reserves, 100000)
        drawBar(win, 2, 12, math.floor(w * 0.6), reserves, resMax, colors.cyan, colors.gray)
        local resPct = math.floor((reserves / resMax) * 100)
        wWrite(win, math.floor(w * 0.6) + 4, 12, resPct .. "%", colors.cyan, colors.black)

        -- ── Refresh button ──
        btns[#btns + 1] = { x1 = 2, x2 = 14, y = h, action = "refresh" }
        local bx = drawBtn(win, 2, h, "\x1d Refresh", colors.white, colors.gray)
        win.setCursorPos(bx, h)
        win.setBackgroundColor(colors.gray)
        win.setTextColor(colors.lightGray)
        win.write("  Last: " .. (os.date and os.date("%H:%M:%S") or "?"))
    end

    -- ── Boot ────────────────────────────────────────────────
    draw()

    -- ── Event loop ──────────────────────────────────────────
    while true do
        -- Auto-poll via timer
        if os.clock() - lastPoll > CONFIG.POLL_EVERY then
            state    = fetchStatus()
            lastPoll = os.clock()
            draw()
        end

        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "monitor_touch" then
            for _, btn in ipairs(btns) do
                if p3 == btn.y and p2 >= btn.x1 and p2 <= btn.x2 then
                    local a = btn.action
                    if a == "refresh" then
                        state    = fetchStatus()
                        lastPoll = os.clock()
                        draw()
                    elseif a:sub(1, 10) == "set-relay:" then
                        sendCommand("set-relay", a:sub(11))
                        os.sleep(0.3)
                        state    = fetchStatus()
                        lastPoll = os.clock()
                        draw()
                    elseif a:sub(1, 8) == "set-rsc:" then
                        sendCommand("set-rsc", tonumber(a:sub(9)))
                        os.sleep(0.3)
                        state    = fetchStatus()
                        lastPoll = os.clock()
                        draw()
                    end
                    break
                end
            end

        elseif ev == "timer" then
            state    = fetchStatus()
            lastPoll = os.clock()
            draw()
        end
    end
end

return Powerstation
