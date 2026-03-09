-- ============================================================================
-- BaseOS  |  programs/gatedialer.lua
-- Stargate Dialing Computer — BaseOS windowed version
-- Based on GateDialFull-WS.lua (v5.0 WS Edition)
--
-- Original used parallel.waitForAny(statusUpdateLoop, inputLoop, wsLoop).
-- In BaseOS we run as a single coroutine, so all three loops collapse into
-- one event loop. WS messages arrive as "websocket_message" events, status
-- polling is driven by a repeating os.startTimer(), and touch input is normal.
-- ============================================================================

local GateDial = {}

-- ─── Config ──────────────────────────────────────────────────────────────────
local CONFIG = {
    STARGATE_NAME    = "Earth",
    STARGATE_ADDRESS = {1, 2, 3, 4, 5, 6, 0},
    API_URL          = "http://croul1.duckdns.org:5005/stargate/api",
    API_STATUS_URL   = "http://croul1.duckdns.org:5005/stargate/api/status",
    WS_URL           = "ws://croul1.duckdns.org:5005/stargate/ws/",
    POLL_INTERVAL    = 0.5,   -- seconds between gate status polls
    DEST_REFRESH     = 30,    -- seconds between destination list refreshes
    DEBUG_MODE       = false,
}

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function hasMethod(obj, name)
    return obj ~= nil and type(obj[name]) == "function"
end

-- ─── main(win) ───────────────────────────────────────────────────────────────
function GateDial.main(win)
    local w, h = win.getSize()

    -- ── State ──────────────────────────────────────────────────────
    local interface     = nil
    local interfaceType = "Unknown"

    local gState = {
        gateType              = "Unknown",
        hasIris               = false,
        irisClosed            = false,
        irisProgress          = 0,
        status                = "Initializing...",
        chevrons              = {false,false,false,false,false,false,false,false,false},
        energy                = 0,
        energyMax             = 1,
        connectedAddress      = nil,
        dialing               = false,
        incoming              = false,
        currentDialingAddress = nil,
    }

    local DESTINATIONS          = {}
    local lastDestinationUpdate = 0
    local wsConnection          = nil
    local currentScreen         = "main"
    local eventLog              = {}
    local pollTimer             = nil
    local wsReconnectTimer      = nil

    -- ── Window helpers ─────────────────────────────────────────────
    local function wWrite(x, y, text, fg, bg)
        win.setCursorPos(x, y)
        if bg then win.setBackgroundColor(bg) end
        if fg then win.setTextColor(fg) end
        win.write(text)
    end

    local function wFill(y, bg)
        win.setCursorPos(1, y)
        win.setBackgroundColor(bg)
        win.write(string.rep(" ", w))
    end

    -- Register + draw a button; return x position after it
    local function regBtn(tbl, x, y, label, action, fg, bg)
        local btn = "[ " .. label .. " ]"
        tbl[#tbl + 1] = { x1 = x, x2 = x + #btn - 1, y = y, action = action }
        win.setCursorPos(x, y)
        win.setBackgroundColor(bg)
        win.setTextColor(fg)
        win.write(btn)
        win.setBackgroundColor(colors.black)
        return x + #btn + 1
    end

    local function drawProgressBar(x, y, barW, current, maxVal, fg, bg)
        current = current or 0
        maxVal  = (maxVal and maxVal > 0) and maxVal or 1
        local filled = math.floor(barW * math.min(current / maxVal, 1))
        win.setCursorPos(x, y)
        win.setBackgroundColor(fg); win.write(string.rep(" ", filled))
        win.setBackgroundColor(bg); win.write(string.rep(" ", barW - filled))
        win.setBackgroundColor(colors.black)
    end

    -- ── Event log ──────────────────────────────────────────────────
    local function log(msg, col)
        table.insert(eventLog, 1, {
            message = msg, color = col or colors.white,
            time = textutils.formatTime(os.time(), true)
        })
        while #eventLog > 6 do table.remove(eventLog) end
        if CONFIG.DEBUG_MODE then print("[GateDial] " .. msg) end
    end

    -- ── Peripheral detection ───────────────────────────────────────
    local function findInterface()
        for _, t in ipairs({"advanced_crystal_interface","crystal_interface","basic_interface"}) do
            local p = peripheral.find(t)
            if p then return p, t end
        end
        return nil, nil
    end

    local function refreshPeripherals()
        interface, interfaceType = findInterface()
        return interface ~= nil
    end

    local function detectGateInfo()
        if not interface then return end
        if hasMethod(interface, "getStargateType") then
            gState.gateType = interface.getStargateType() or "Unknown"
        elseif hasMethod(interface, "getVariant") then
            gState.gateType = interface.getVariant() or "Unknown"
        else
            gState.gateType = (interfaceType == "basic_interface") and "Milky Way" or "Universe/Pegasus"
        end

        gState.hasIris = hasMethod(interface, "getIrisProgress")
                      or hasMethod(interface, "closeIris")
                      or hasMethod(interface, "openIris")

        if gState.hasIris and hasMethod(interface, "getIrisProgress") then
            local prog = interface.getIrisProgress() or 0
            gState.irisProgress = prog
            gState.irisClosed   = prog > 29
        end
        log("Gate: " .. gState.gateType, colors.cyan)
        log("Iris: " .. (gState.hasIris and "detected" or "none"), colors.lightGray)
    end

    -- ── API / WS ───────────────────────────────────────────────────
    local function buildStatusPayload()
        local ownAddr  = table.concat(CONFIG.STARGATE_ADDRESS, ",")
        local dialAddr = ""
        if gState.dialing and gState.currentDialingAddress then
            dialAddr = table.concat(gState.currentDialingAddress, ",")
        elseif gState.status == "CONNECTED" and gState.connectedAddress then
            dialAddr = type(gState.connectedAddress) == "table"
                and table.concat(gState.connectedAddress, ",")
                or  tostring(gState.connectedAddress)
        end

        local apiStatus = "idle"
        if     gState.status == "CONNECTED"         then apiStatus = "connected"
        elseif gState.status == "DIALING..."        then apiStatus = "dialing"
        elseif gState.status == "INCOMING WORMHOLE" then apiStatus = "incoming"
        end

        local irisState = not gState.hasIris and "n/a"
            or (gState.irisClosed and "closed" or "open")

        local locked = 0
        if hasMethod(interface, "getChevronsEngaged") then
            locked = interface.getChevronsEngaged() or 0
        else
            for i = 1, 9 do if gState.chevrons[i] then locked = locked + 1 end end
        end

        return {
            gate = CONFIG.STARGATE_NAME, address = ownAddr,
            dialed_address = dialAddr,   status  = apiStatus,
            iris = irisState,            locked_chevrons = locked,
        }
    end

    local function reportStatus()
        local p = buildStatusPayload()
        if wsConnection then
            local payload = textutils.serializeJSON({
                type = "status", gate = p.gate, address = p.address,
                dialed_address = p.dialed_address, status = p.status,
                iris = p.iris, locked_chevrons = p.locked_chevrons,
            })
            local ok = pcall(wsConnection.send, wsConnection, payload)
            if ok then return end
            wsConnection = nil
        end
        local qs = string.format(
            "?gate=%s&address=%s&dialed_address=%s&status=%s&iris=%s&locked_chevrons=%d",
            textutils.urlEncode(p.gate), textutils.urlEncode(p.address),
            textutils.urlEncode(p.dialed_address), textutils.urlEncode(p.status),
            textutils.urlEncode(p.iris), p.locked_chevrons)
        pcall(function()
            local r = http.post(CONFIG.API_STATUS_URL .. qs, "")
            if r then r.close() end
        end)
    end

    local function fetchDestinations()
        local ok, resp = pcall(http.get, CONFIG.API_STATUS_URL)
        if not ok or not resp then return end
        local body = resp.readAll(); resp.close()
        local pOk, list = pcall(textutils.unserializeJSON, body)
        if not pOk or type(list) ~= "table" then return end
        DESTINATIONS = {}
        for _, gd in ipairs(list) do
            if gd.gate and gd.gate ~= CONFIG.STARGATE_NAME and gd.address then
                local addr = {}
                for s in gd.address:gmatch("[^,]+") do
                    local n = tonumber(s:match("^%s*(.-)%s*$"))
                    if n then addr[#addr+1] = n end
                end
                if #addr > 0 then DESTINATIONS[gd.gate] = addr end
            end
        end
        lastDestinationUpdate = os.clock()
        log("Loaded destinations", colors.green)
    end

    -- ── Gate status polling ────────────────────────────────────────
    local function updateGateStatus()
        if not interface then return end
        local fresh = peripheral.find(interfaceType)
        if fresh then interface = fresh end

        if hasMethod(interface, "getEnergy") then
            gState.energy = interface.getEnergy() or 0
            for _, m in ipairs({"getEnergyCapacity","getMaxEnergy","getEnergyTarget"}) do
                if hasMethod(interface, m) then
                    local v = interface[m]()
                    if v and v > 0 then gState.energyMax = v; break end
                end
            end
        end

        local connected = hasMethod(interface,"isStargateConnected") and interface.isStargateConnected()
        local dialing   = (hasMethod(interface,"isDialingOut") and interface.isDialingOut())
                       or (hasMethod(interface,"isStargateDialingOut") and interface.isStargateDialingOut())
        local wormhole  = hasMethod(interface,"isWormholeOpen") and interface.isWormholeOpen()

        if connected then
            gState.status = "CONNECTED"
            if hasMethod(interface,"getDialedAddress") then
                gState.connectedAddress = interface.getDialedAddress()
            elseif hasMethod(interface,"getConnectedAddress") then
                gState.connectedAddress = interface.getConnectedAddress()
            end
        elseif dialing then
            gState.status = "DIALING..."
        elseif wormhole and not connected then
            gState.status  = "INCOMING WORMHOLE"
            gState.incoming = true
        else
            gState.status          = "IDLE"
            gState.connectedAddress = nil
            gState.incoming         = false
            if not gState.dialing then
                for i = 1, 9 do gState.chevrons[i] = false end
            end
        end

        if gState.hasIris and hasMethod(interface,"getIrisProgress") then
            local prog = interface.getIrisProgress() or 0
            gState.irisProgress = prog
            if     prog == 0  then gState.irisClosed = false
            elseif prog == 58 then gState.irisClosed = true
            else                    gState.irisClosed = prog > 29 end
        end
    end

    -- ── Gate control ───────────────────────────────────────────────
    local function openIris()
        if not gState.hasIris then log("No iris", colors.red); return end
        if gState.irisProgress == 0 then log("Already open", colors.yellow); return end
        if hasMethod(interface,"openIris") then
            local ok, err = pcall(interface.openIris, interface)
            if ok then log("IRIS OPENING", colors.lime); reportStatus()
            else log("Error: " .. tostring(err), colors.red) end
        end
    end

    local function closeIris()
        if not gState.hasIris then log("No iris", colors.red); return end
        if gState.irisProgress == 58 then log("Already closed", colors.yellow); return end
        if hasMethod(interface,"closeIris") then
            local ok, err = pcall(interface.closeIris, interface)
            if ok then log("IRIS CLOSING", colors.red); reportStatus()
            else log("Error: " .. tostring(err), colors.red) end
        end
    end

    local function disconnectGate()
        if gState.status == "IDLE" then log("Already idle", colors.yellow); return end
        local disc = hasMethod(interface,"disconnectStargate") and "disconnectStargate"
                  or hasMethod(interface,"disconnect") and "disconnect"
        if disc then
            interface[disc](interface)
            log("DISCONNECTING", colors.orange)
            for i = 1, 9 do gState.chevrons[i] = false end
            reportStatus()
        else
            log("No disconnect method!", colors.red)
        end
    end

    -- ── Dialing ────────────────────────────────────────────────────
    local function dialCrystal(address)
        gState.dialing = true
        gState.currentDialingAddress = address
        log("Crystal dial start", colors.cyan)

        local method = hasMethod(interface,"engageSymbol") and "engageSymbol"
                    or hasMethod(interface,"engage") and "engage"

        if not method then
            if hasMethod(interface,"dialAddress") then
                interface.dialAddress(interface, address)
                gState.dialing = false; reportStatus(); return true
            end
            log("No crystal dial method!", colors.red)
            gState.dialing = false; return false
        end

        for i, symbol in ipairs(address) do
            if i > 9 then break end
            log("Chevron " .. i .. " -> " .. symbol, colors.lightBlue)
            local ok, err = pcall(interface[method], interface, symbol)
            if not ok then
                log("Error: " .. tostring(err), colors.red)
                gState.dialing = false; return false
            end
            gState.chevrons[i] = true
            os.sleep(1.5)
            if gState.incoming then
                log("INCOMING - ABORT", colors.red)
                gState.dialing = false; return false
            end
        end

        gState.dialing = false
        log("Crystal dial complete", colors.green)
        reportStatus(); return true
    end

    local function dialBasic(address)
        gState.dialing = true
        gState.currentDialingAddress = address
        log("Basic dial start", colors.cyan)

        if not (hasMethod(interface,"isCurrentSymbol")
            and hasMethod(interface,"openChevron")
            and hasMethod(interface,"encodeChevron")) then
            log("Missing basic interface methods!", colors.red)
            gState.dialing = false; return false
        end

        local direction = "clockwise"
        for i, symbol in ipairs(address) do
            if i > 7 then break end
            log("=== Chevron " .. i .. " ===", colors.yellow)

            if direction == "clockwise" and hasMethod(interface,"rotateClockwise") then
                interface.rotateClockwise(interface, symbol)
            elseif hasMethod(interface,"rotateAntiClockwise") then
                interface.rotateAntiClockwise(interface, symbol)
            else
                log("No rotation method!", colors.red)
                gState.dialing = false; return false
            end

            local waited = 0
            while not interface.isCurrentSymbol(interface, symbol) and waited < 10 do
                os.sleep(0.1); waited = waited + 0.1
                if gState.incoming then
                    log("INCOMING - ABORT", colors.red)
                    gState.dialing = false; return false
                end
            end
            if waited >= 10 then
                log("Rotation timeout!", colors.red)
                gState.dialing = false; return false
            end

            local ok1 = pcall(interface.openChevron, interface)
            if not ok1 then log("openChevron failed", colors.red); gState.dialing = false; return false end
            os.sleep(1)
            local ok2 = pcall(interface.encodeChevron, interface)
            if not ok2 then log("encodeChevron failed", colors.red); gState.dialing = false; return false end
            os.sleep(0.2)

            if hasMethod(interface,"isChevronOpen") and hasMethod(interface,"closeChevron") then
                if interface.isChevronOpen(interface) then
                    pcall(interface.closeChevron, interface)
                end
            end

            os.sleep(0.2)
            gState.chevrons[i] = true
            log("Chevron " .. i .. " locked!", colors.green)
            direction = direction == "clockwise" and "anticlockwise" or "clockwise"
        end

        gState.dialing = false
        log("Basic dial complete!", colors.green)
        reportStatus(); return true
    end

    local function dialAddress(address)
        if gState.status ~= "IDLE"  then log("Gate busy!", colors.red);     return false end
        if gState.dialing            then log("Already dialing!", colors.red); return false end
        if not refreshPeripherals()  then log("Interface lost!", colors.red);  return false end
        log("Starting dial...", colors.yellow)
        if interfaceType == "basic_interface" then
            return dialBasic(address)
        else
            return dialCrystal(address)
        end
    end

    -- ── WS command handler ─────────────────────────────────────────
    local function handleCommand(data)
        if not data or not data.action or data.action == "null" then return end
        if data.from ~= CONFIG.STARGATE_NAME then return end
        log("WS cmd: " .. data.action, colors.cyan)
        if data.action == "open" and data.to then
            local addr = DESTINATIONS[data.to]
            if addr then dialAddress(addr)
            else log("Unknown dest: " .. data.to, colors.red) end
        elseif data.action == "close"      then disconnectGate()
        elseif data.action == "iris-open"  then openIris()
        elseif data.action == "iris-close" then closeIris()
        end
    end

    -- ── WS connection ──────────────────────────────────────────────
    local function connectWS()
        if wsConnection then pcall(wsConnection.close, wsConnection); wsConnection = nil end
        local ws, err = http.websocket(CONFIG.WS_URL .. CONFIG.STARGATE_NAME)
        if ws then
            wsConnection = ws
            log("WS: Connected", colors.lime)
        else
            log("WS: Failed (" .. tostring(err) .. ")", colors.orange)
            wsReconnectTimer = os.startTimer(10)
        end
    end

    -- ── Rendering ──────────────────────────────────────────────────
    local btns = {}

    local function renderMain()
        win.setBackgroundColor(colors.black)
        win.clear()
        btns = {}

        wWrite(2, 1, "Gate: " .. gState.gateType,  colors.cyan,      colors.black)
        wWrite(2, 2, "Type: " .. interfaceType,     colors.lightGray, colors.black)

        local sc = colors.yellow
        if     gState.status == "CONNECTED"         then sc = colors.lime
        elseif gState.status == "INCOMING WORMHOLE" then sc = colors.red
        elseif gState.status == "IDLE"              then sc = colors.lightGray end
        wWrite(2, 3, "Status: ",   colors.lightGray, colors.black)
        wWrite(10, 3, gState.status, sc,             colors.black)

        if gState.connectedAddress then
            local addr = type(gState.connectedAddress) == "table"
                and table.concat(gState.connectedAddress, "-")
                or  tostring(gState.connectedAddress)
            wWrite(2, 4, "To: " .. addr:sub(1, w - 5), colors.lightBlue, colors.black)
        end

        wWrite(2, 5, "Energy:", colors.orange, colors.black)
        local barW = math.max(4, math.floor(w * 0.45))
        drawProgressBar(10, 5, barW, gState.energy, gState.energyMax, colors.lime, colors.gray)
        local pct = gState.energyMax > 0
            and math.min(math.floor(gState.energy / gState.energyMax * 100), 100) or 0
        wWrite(10 + barW + 1, 5, pct .. "%", colors.orange, colors.black)

        wWrite(2, 6, "Chev:", colors.cyan, colors.black)
        for i = 1, 7 do
            local sym = gState.chevrons[i] and "<\x04>" or "< >"
            local col = gState.chevrons[i] and colors.lime or colors.gray
            wWrite(8 + (i - 1) * 4, 6, sym, col, colors.black)
        end

        local irisText, irisCol
        if not gState.hasIris then
            irisText, irisCol = "N/A", colors.gray
        elseif gState.irisProgress == 0  then irisText, irisCol = "OPEN",   colors.lime
        elseif gState.irisProgress == 58 then irisText, irisCol = "CLOSED", colors.red
        else irisText, irisCol = "MOVING (" .. gState.irisProgress .. "/58)", colors.yellow end
        wWrite(2, 7, "Iris: ", colors.lightGray, colors.black)
        wWrite(8, 7, irisText, irisCol, colors.black)

        local wsStr = wsConnection and "\x07 WS" or "  WS"
        local wsCol = wsConnection and colors.lime or colors.red
        wWrite(w - 4, 1, wsStr, wsCol, colors.black)

        local brow = 9
        local bx   = 2
        bx = regBtn(btns, bx, brow, "Dial",       "dial",       colors.lime, colors.gray)
        bx = regBtn(btns, bx, brow, "Disconnect", "disconnect", colors.red,  colors.gray)
        if gState.hasIris then
            brow = brow + 1; bx = 2
            bx = regBtn(btns, bx, brow, "Open Iris",  "iris-open",  colors.lime, colors.gray)
            bx = regBtn(btns, bx, brow, "Close Iris", "iris-close", colors.red,  colors.gray)
        end

        local logStart = brow + 2
        wWrite(2, logStart, "Event log:", colors.white, colors.black)
        for i, entry in ipairs(eventLog) do
            if logStart + i > h then break end
            wWrite(2, logStart + i,
                (entry.time .. " " .. entry.message):sub(1, w - 2),
                entry.color, colors.black)
        end
    end

    local function renderDestinations()
        win.setBackgroundColor(colors.black)
        win.clear()
        btns = {}

        wWrite(2, 1, "Select Destination", colors.yellow, colors.black)
        wFill(2, colors.gray)

        local destList = {}
        for name in pairs(DESTINATIONS) do destList[#destList + 1] = name end
        table.sort(destList)

        if #destList == 0 then
            wWrite(3, 4, "No destinations available", colors.red,    colors.black)
            wWrite(3, 5, "Waiting for gate network\x85", colors.yellow, colors.black)
            regBtn(btns, 3, 7, "Cancel", "cancel", colors.white, colors.red)
            return
        end

        local y = 3
        for _, name in ipairs(destList) do
            if y > h - 2 then break end
            local addr    = DESTINATIONS[name]
            local addrStr = type(addr) == "table" and table.concat(addr, "-") or "?"
            local lbl     = name .. "  " .. addrStr:sub(1, w - 8 - #name)
            regBtn(btns, 3, y, lbl, "dial:" .. name, colors.white, colors.cyan)
            y = y + 2
        end
        regBtn(btns, 3, y + 1, "Cancel", "cancel", colors.white, colors.red)
    end

    local function render()
        if currentScreen == "main" then renderMain()
        else renderDestinations() end
    end

    -- ── Touch handling ─────────────────────────────────────────────
    local function handleTouch(x, y)
        for _, btn in ipairs(btns) do
            if y == btn.y and x >= btn.x1 and x <= btn.x2 then
                local a = btn.action
                if     a == "dial"       then currentScreen = "destinations"; render()
                elseif a == "disconnect" then disconnectGate(); render()
                elseif a == "iris-open"  then openIris();       render()
                elseif a == "iris-close" then closeIris();      render()
                elseif a == "cancel"     then currentScreen = "main"; render()
                elseif a:sub(1,5) == "dial:" then
                    local dest = a:sub(6)
                    local addr = DESTINATIONS[dest]
                    if addr then
                        log("Dialing " .. dest, colors.green)
                        currentScreen = "main"; render()
                        dialAddress(addr); render()
                    end
                end
                return
            end
        end
    end

    -- ── Boot ───────────────────────────────────────────────────────
    if not refreshPeripherals() then
        win.setBackgroundColor(colors.red); win.clear()
        wWrite(2, 2, "No Stargate interface found!", colors.white,  colors.red)
        wWrite(2, 4, "Attach an interface and",      colors.yellow, colors.red)
        wWrite(2, 5, "relaunch GateDial.",            colors.yellow, colors.red)
        while true do os.pullEvent("monitor_touch") end
    end

    detectGateInfo()
    fetchDestinations()
    reportStatus()
    connectWS()
    pollTimer = os.startTimer(CONFIG.POLL_INTERVAL)
    render()

    -- ── Event loop ─────────────────────────────────────────────────
    while true do
        local ev, p1, p2, p3 = os.pullEvent()

        if ev == "monitor_touch" then
            handleTouch(p2, p3)

        elseif ev == "timer" then
            if p1 == pollTimer then
                updateGateStatus()
                reportStatus()
                if os.clock() - lastDestinationUpdate > CONFIG.DEST_REFRESH then
                    fetchDestinations()
                end
                if currentScreen == "main" then render() end
                pollTimer = os.startTimer(CONFIG.POLL_INTERVAL)
            elseif p1 == wsReconnectTimer then
                connectWS()
            end

        elseif ev == "websocket_message" then
            local ok, data = pcall(textutils.unserializeJSON, p2 or "")
            if ok and data and data.type == "command" then
                handleCommand(data); render()
            end

        elseif ev == "websocket_closed" or ev == "websocket_failure" then
            wsConnection = nil
            log("WS: Lost, retry in 10s", colors.orange)
            wsReconnectTimer = os.startTimer(10)
            if currentScreen == "main" then render() end
        end
    end
end

return GateDial
