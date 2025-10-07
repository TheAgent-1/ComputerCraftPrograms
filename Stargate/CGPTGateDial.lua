--[[
==========================================
  STARGATE DIALING COMPUTER v4.3
  FIX: Using CORRECT rotation API!
==========================================
]]

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    STARGATE_NAME = "Earth",
    API_URL = "http://192.168.1.41:5005/sg-command",
    API_ENABLED = true,
    DEBUG_MODE = true
}

local DESTINATIONS = {
    ["Abydos"] = {26, 6, 14, 31, 11, 29, 0},
    ["Chulak"] = {8, 1, 22, 14, 36, 19, 0},
    ["P3X-984"] = {2, 31, 20, 13, 25, 1, 0}
}

-- ============================================
-- GLOBALS & STATE
-- ============================================
local monitor = nil
local interface = nil

local state = {
    gateType = "Unknown",
    interfaceType = "Unknown",
    hasIris = false,
    irisClosed = false,
    status = "Initializing...",
    chevrons = {false, false, false, false, false, false, false, false, false},
    energy = 0,
    energyMax = 1,
    connectedAddress = nil,
    dialing = false,
    incoming = false
}

local eventLog = {}
local currentScreen = "main"

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function log(message, color)
    local timestamp = textutils.formatTime(os.time(), true)
    local entry = {
        time = timestamp,
        message = message,
        color = color or colors.white
    }
    
    table.insert(eventLog, 1, entry)
    if #eventLog > 7 then
        table.remove(eventLog)
    end
    
    if CONFIG.DEBUG_MODE then
        print("[" .. timestamp .. "] " .. message)
    end
end

local function hasMethod(obj, methodName)
    if obj == nil then 
        return false 
    end
    return type(obj[methodName]) == "function"
end

-- ============================================
-- HARDWARE DETECTION
-- ============================================

local function refreshPeripherals()
    interface = nil
    monitor = nil
    
    monitor = peripheral.find("monitor")
    if not monitor then
        error("[FATAL] No monitor found!")
    end
    
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    
    local interfaceTypes = {
        "advanced_crystal_interface",
        "crystal_interface", 
        "basic_interface"
    }
    
    for _, iType in ipairs(interfaceTypes) do
        local found = peripheral.find(iType)
        if found then
            interface = found
            state.interfaceType = iType
            log("Found: " .. iType, colors.green)
            return true
        end
    end
    
    error("[FATAL] No Stargate interface found!")
end

local function detectGateType()
    if hasMethod(interface, "getStargateType") then
        state.gateType = interface.getStargateType() or "Unknown"
    elseif hasMethod(interface, "getVariant") then
        state.gateType = interface.getVariant() or "Unknown"
    else
        if state.interfaceType == "basic_interface" then
            state.gateType = "Milky Way"
        else
            state.gateType = "Universe/Pegasus"
        end
    end
    
    log("Gate Type: " .. state.gateType, colors.cyan)
end

local function detectIris()
    state.hasIris = hasMethod(interface, "closeIris") or hasMethod(interface, "openIris")
    
    if state.hasIris then
        log("Iris: DETECTED", colors.green)
        
        if hasMethod(interface, "isIrisClosed") then
            state.irisClosed = interface.isIrisClosed()
        end
    else
        log("Iris: NOT FOUND", colors.yellow)
    end
end

local function listAvailableMethods()
    if not CONFIG.DEBUG_MODE then 
        return 
    end
    
    local methods = peripheral.getMethods(peripheral.getName(interface))
    
    print("\n========== INTERFACE METHODS ==========")
    for i, method in ipairs(methods) do
        print(string.format("%2d. %s", i, method))
    end
    print("========================================\n")
end

local function selfCheck()
    log("=== SELF-CHECK START ===", colors.yellow)
    
    refreshPeripherals()
    detectGateType()
    detectIris()
    listAvailableMethods()
    
    log("=== SELF-CHECK COMPLETE ===", colors.green)
    state.status = "Idle"
    os.sleep(2)
end

-- ============================================
-- STARGATE STATUS MONITORING
-- ============================================

local function updateEnergy()
    if hasMethod(interface, "getEnergy") then
        state.energy = interface.getEnergy() or 0
        
        if hasMethod(interface, "getEnergyTarget") then
            state.energyMax = interface.getEnergyTarget() or 1
        elseif hasMethod(interface, "getMaxEnergy") then
            state.energyMax = interface.getMaxEnergy() or 1
        elseif hasMethod(interface, "getEnergyCapacity") then
            state.energyMax = interface.getEnergyCapacity() or 1
        else
            state.energyMax = 1000000
        end
    else
        -- No energy methods - set defaults
        state.energy = 0
        state.energyMax = 1
    end
end

local function updateGateStatus()
    local testInterface = peripheral.find(state.interfaceType)
    if testInterface ~= nil then
        interface = testInterface
    end
    
    updateEnergy()
    
    local isConnected = hasMethod(interface, "isStargateConnected") and interface.isStargateConnected()
    
    local isDialing = (hasMethod(interface, "isDialingOut") and interface.isDialingOut()) or
                      (hasMethod(interface, "isStargateDialingOut") and interface.isStargateDialingOut())
    
    local isWormholeOpen = hasMethod(interface, "isWormholeOpen") and interface.isWormholeOpen()
    
    if isConnected then
        state.status = "CONNECTED"
        
        if hasMethod(interface, "getDialedAddress") then
            state.connectedAddress = interface.getDialedAddress()
        elseif hasMethod(interface, "getConnectedAddress") then
            state.connectedAddress = interface.getConnectedAddress()
        end
        
    elseif isDialing then
        state.status = "DIALING..."
        
    elseif isWormholeOpen and not isConnected then
        state.status = "INCOMING WORMHOLE"
        state.incoming = true
        
    else
        state.status = "IDLE"
        state.connectedAddress = nil
        state.incoming = false
        
        if not state.dialing then
            for i = 1, 9 do
                state.chevrons[i] = false
            end
        end
    end
    
    if state.hasIris and hasMethod(interface, "isIrisClosed") then
        state.irisClosed = interface.isIrisClosed()
    end
end

-- ============================================
-- GATE CONTROL FUNCTIONS
-- ============================================

local function toggleIris()
    if not state.hasIris then
        log("No iris installed!", colors.red)
        return
    end
    
    if state.irisClosed then
        if hasMethod(interface, "openIris") then
            interface.openIris()
            log("IRIS OPENING", colors.green)
        end
    else
        if hasMethod(interface, "closeIris") then
            interface.closeIris()
            log("IRIS CLOSING", colors.red)
        end
    end
end

local function disconnectGate()
    if state.status == "IDLE" then
        log("Gate already idle", colors.yellow)
        return
    end
    
    if hasMethod(interface, "disconnectStargate") then
        interface.disconnectStargate()
        log("DISCONNECTING GATE", colors.orange)
    elseif hasMethod(interface, "disconnect") then
        interface.disconnect()
        log("DISCONNECTING GATE", colors.orange)
    else
        log("ERROR: No disconnect method", colors.red)
    end
    
    for i = 1, 9 do
        state.chevrons[i] = false
    end
end

-- ============================================
-- DIALING SYSTEM - CRYSTAL INTERFACE
-- ============================================

local function dialCrystalInterface(address)
    state.dialing = true
    log("CRYSTAL DIAL START", colors.cyan)
    
    local dialMethod = nil
    
    if hasMethod(interface, "engageSymbol") then
        dialMethod = "engageSymbol"
    elseif hasMethod(interface, "engage") then
        dialMethod = "engage"
    elseif hasMethod(interface, "dialAddress") then
        log("Using direct dial method", colors.lightBlue)
        interface.dialAddress(address)
        state.dialing = false
        return true
    else
        log("ERROR: No crystal dial method found!", colors.red)
        state.dialing = false
        return false
    end
    
    for i, symbol in ipairs(address) do
        if i > 9 then 
            break 
        end
        
        log("Chevron " .. i .. " -> Symbol " .. symbol, colors.lightBlue)
        
        local success, err = pcall(function()
            if dialMethod == "engageSymbol" then
                interface.engageSymbol(symbol)
            elseif dialMethod == "engage" then
                interface.engage(symbol)
            end
        end)
        
        if not success then
            log("ERROR engaging symbol: " .. tostring(err), colors.red)
            state.dialing = false
            return false
        end
        
        state.chevrons[i] = true
        os.sleep(1.5)
        
        if state.incoming then
            log("INCOMING - ABORT", colors.red)
            state.dialing = false
            return false
        end
    end
    
    state.dialing = false
    log("CRYSTAL DIAL COMPLETE", colors.green)
    return true
end

-- ============================================
-- DIALING SYSTEM - BASIC INTERFACE (CORRECTED!)
-- ============================================

local function dialBasicInterface(address)
    state.dialing = true
    log("BASIC DIAL START", colors.cyan)
    
    -- Check required methods
    if not hasMethod(interface, "isCurrentSymbol") then
        log("ERROR: Missing isCurrentSymbol()", colors.red)
        state.dialing = false
        return false
    end
    
    if not hasMethod(interface, "openChevron") then
        log("ERROR: Missing openChevron()", colors.red)
        state.dialing = false
        return false
    end
    
    if not hasMethod(interface, "encodeChevron") then
        log("ERROR: Missing encodeChevron()", colors.red)
        state.dialing = false
        return false
    end
    
    -- Determine available rotation methods
    local hasRotateClockwise = hasMethod(interface, "rotateClockwise")
    local hasRotateAntiClockwise = hasMethod(interface, "rotateAntiClockwise")
    
    if not (hasRotateClockwise or hasRotateAntiClockwise) then
        log("ERROR: No rotation methods!", colors.red)
        state.dialing = false
        return false
    end
    
    -- Dial each symbol
    local direction = "clockwise"  -- Alternate direction for realism
    
    for i, targetSymbol in ipairs(address) do
        if i > 7 then 
            break 
        end
        
        log("=== CHEVRON " .. i .. " ===", colors.yellow)
        log("Rotating to symbol: " .. targetSymbol, colors.lightBlue)
        
        -- Start rotation to target symbol
        if direction == "clockwise" and hasRotateClockwise then
            log("Rotating CLOCKWISE to " .. targetSymbol, colors.gray)
            interface.rotateClockwise(targetSymbol)
        elseif hasRotateAntiClockwise then
            log("Rotating ANTICLOCKWISE to " .. targetSymbol, colors.gray)
            interface.rotateAntiClockwise(targetSymbol)
        end
        
        -- Wait for rotation to complete (with timeout)
        log("Waiting for rotation...", colors.gray)
        local waitTime = 0
        local maxWait = 10  -- 10 seconds timeout
        
        while not interface.isCurrentSymbol(targetSymbol) and waitTime < maxWait do
            sleep(0.1)
            waitTime = waitTime + 0.1
            
            -- Check for incoming
            if state.incoming then
                log("INCOMING - ABORT", colors.red)
                state.dialing = false
                return false
            end
        end
        
        if waitTime >= maxWait then
            log("ERROR: Rotation timeout!", colors.red)
            state.dialing = false
            return false
        end
        
        -- Verify we're at the correct symbol
        if interface.isCurrentSymbol(targetSymbol) then
            log("Reached symbol " .. targetSymbol, colors.lime)
            log("Opening chevron " .. i .. "...", colors.cyan)
            
            -- CORRECT SEQUENCE: openChevron() → wait → encodeChevron()
            local ok1, err1 = pcall(function()
                interface.openChevron()
            end)
            
            if not ok1 then
                log("ERROR opening chevron: " .. tostring(err1), colors.red)
                state.dialing = false
                return false
            end
            
            sleep(1)  -- Important: wait for chevron to open
            
            log("Encoding chevron " .. i .. "...", colors.cyan)
            
            local ok2, err2 = pcall(function()
                interface.encodeChevron()
            end)
            
            if not ok2 then
                log("ERROR encoding chevron: " .. tostring(err2), colors.red)
                state.dialing = false
                return false
            end
            
            sleep(0.2)
            state.chevrons[i] = true
            log("Chevron " .. i .. " LOCKED!", colors.green)
        else
            log("ERROR: Not at correct symbol!", colors.red)
            state.dialing = false
            return false
        end
        
        -- Alternate direction for next symbol (like the show!)
        direction = (direction == "clockwise") and "anticlockwise" or "clockwise"
    end
    
    state.dialing = false
    log("BASIC DIAL COMPLETE!", colors.green)
    return true
end


-- ============================================
-- MAIN DIAL FUNCTION
-- ============================================

local function dialAddress(address)
    if state.status ~= "IDLE" then
        log("Cannot dial - gate busy!", colors.red)
        return false
    end
    
    if state.dialing then
        log("Already dialing!", colors.red)
        return false
    end
    
    local testInterface = peripheral.find(state.interfaceType)
    if testInterface == nil then
        log("Interface lost! Refreshing...", colors.orange)
        refreshPeripherals()
    end
    
    log("Starting dial sequence...", colors.yellow)
    
    local success = false
    if state.interfaceType == "basic_interface" then
        success = dialBasicInterface(address)
    else
        success = dialCrystalInterface(address)
    end
    
    return success
end

-- ============================================
-- GUI RENDERING
-- ============================================

local function drawText(x, y, text, fg, bg)
    monitor.setCursorPos(x, y)
    if fg then 
        monitor.setTextColor(fg) 
    end
    if bg then 
        monitor.setBackgroundColor(bg) 
    end
    monitor.write(text)
end

local function drawButton(x, y, text, color)
    drawText(x, y, "[ " .. text .. " ]", color)
end

local function drawProgressBar(x, y, width, current, max)
    -- Add nil checks
    current = current or 0
    max = max or 1
    
    local percent = (max > 0) and (current / max) or 0
    local filled = math.floor(width * percent)
    
    monitor.setCursorPos(x, y)
    monitor.setTextColor(colors.lime)
    monitor.write(string.rep("|", filled))
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("|", width - filled))
end

local function renderMainScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    drawText(1, 1, "STARGATE COMMAND - DIALING COMPUTER", colors.white)
    drawText(1, 2, string.rep("=", 50), colors.gray)
    
    drawText(1, 4, "Gate: " .. state.gateType, colors.cyan)
    drawText(30, 4, "Interface: " .. state.interfaceType, colors.cyan)
    
    local statusColor = colors.yellow
    if state.status == "CONNECTED" then
        statusColor = colors.green
    elseif state.status == "INCOMING WORMHOLE" then
        statusColor = colors.red
    elseif state.status == "IDLE" then
        statusColor = colors.lightGray
    end
    
    drawText(1, 6, "STATUS: " .. state.status, statusColor)
    
    if state.connectedAddress then
        local addrStr = "Unknown"
        if type(state.connectedAddress) == "table" then
            addrStr = table.concat(state.connectedAddress, "-")
        else
            addrStr = tostring(state.connectedAddress)
        end
        drawText(1, 7, "Address: " .. addrStr, colors.lightBlue)
    end
    
    drawText(1, 9, "Energy:", colors.orange)
    drawProgressBar(10, 9, 30, state.energy, state.energyMax)
    local energyPct = math.floor((state.energy / state.energyMax) * 100)
    drawText(42, 9, energyPct .. "%", colors.orange)
    
    drawText(1, 11, "Chevrons:", colors.cyan)
    for i = 1, 7 do
        local symbol = state.chevrons[i] and "●" or "○"
        local color = state.chevrons[i] and colors.lime or colors.gray
        drawText(12 + (i * 3), 11, symbol, color)
    end
    
    if state.hasIris then
        local irisText = state.irisClosed and "CLOSED" or "OPEN"
        local irisColor = state.irisClosed and colors.red or colors.green
        drawText(1, 13, "Iris: " .. irisText, irisColor)
    else
        drawText(1, 13, "Iris: N/A", colors.gray)
    end
    
    drawButton(2, 15, "DIAL", colors.lime)
    drawButton(18, 15, "DISCONNECT", colors.red)
    if state.hasIris then
        drawButton(38, 15, "IRIS", colors.cyan)
    end
    drawButton(2, 17, "REFRESH HARDWARE", colors.orange)
    
    drawText(1, 19, "EVENT LOG:", colors.white)
    drawText(1, 20, string.rep("-", 50), colors.gray)
    
    for i, entry in ipairs(eventLog) do
        if i <= 6 then
            local logText = entry.time .. " " .. entry.message
            if #logText > 48 then
                logText = logText:sub(1, 45) .. "..."
            end
            drawText(2, 20 + i, logText, entry.color)
        end
    end
end

local function renderDestinationScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    drawText(1, 1, "SELECT DESTINATION", colors.yellow)
    drawText(1, 2, string.rep("=", 50), colors.gray)
    
    local y = 4
    local i = 1
    for name, address in pairs(DESTINATIONS) do
        local addrStr = table.concat(address, "-")
        drawButton(3, y, i .. ". " .. name, colors.lime)
        drawText(3, y + 1, "    " .. addrStr, colors.gray)
        y = y + 3
        i = i + 1
    end
    
    drawButton(3, y + 1, "CANCEL", colors.red)
end

local function render()
    if currentScreen == "main" then
        renderMainScreen()
    elseif currentScreen == "destinations" then
        renderDestinationScreen()
    end
end

-- ============================================
-- INPUT HANDLING
-- ============================================

local function handleMainScreenClick(x, y)
    if y == 15 and x >= 2 and x <= 15 then
        currentScreen = "destinations"
        render()
        return
    end
    
    if y == 15 and x >= 18 and x <= 35 then
        disconnectGate()
        return
    end
    
    if state.hasIris and y == 15 and x >= 38 and x <= 48 then
        toggleIris()
        return
    end
    
    if y == 17 and x >= 2 and x <= 25 then
        log("Refreshing hardware...", colors.orange)
        selfCheck()
        render()
        return
    end
end

local function handleDestinationClick(x, y)
    local destList = {}
    for name, address in pairs(DESTINATIONS) do
        table.insert(destList, {name = name, address = address})
    end
    
    for i, dest in ipairs(destList) do
        local destY = 4 + ((i - 1) * 3)
        if (y == destY or y == destY + 1) and x >= 3 then
            log("Dialing: " .. dest.name, colors.green)
            currentScreen = "main"
            render()
            dialAddress(dest.address)
            return
        end
    end
    
    local cancelY = 4 + (#destList * 3) + 1
    if y >= cancelY and x >= 3 then
        currentScreen = "main"
        render()
        return
    end
end

-- ============================================
-- MAIN LOOPS
-- ============================================

local function statusUpdateLoop()
    while true do
        updateGateStatus()
        if currentScreen == "main" then
            render()
        end
        os.sleep(0.5)
    end
end

local function inputLoop()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        
        if currentScreen == "main" then
            handleMainScreenClick(x, y)
        elseif currentScreen == "destinations" then
            handleDestinationClick(x, y)
        end
    end
end

local function apiLoop()
    if not CONFIG.API_ENABLED then
        while true do 
            os.sleep(3600) 
        end
    end
    
    while true do
        local ok, response = pcall(http.get, CONFIG.API_URL, nil, {timeout = 2})
        
        if ok and response then
            local body = response.readAll()
            response.close()
            
            local data = textutils.unserializeJSON(body)
            
            if data and data.action then
                if data.action == "dial" and data.address then
                    dialAddress(data.address)
                elseif data.action == "disconnect" then
                    disconnectGate()
                elseif data.action == "iris_open" and state.hasIris then
                    if state.irisClosed then 
                        toggleIris() 
                    end
                elseif data.action == "iris_close" and state.hasIris then
                    if not state.irisClosed then 
                        toggleIris() 
                    end
                end
            end
        end
        
        os.sleep(1)
    end
end

-- ============================================
-- MAIN ENTRY POINT
-- ============================================

local function main()
    print("===================================")
    print("  STARGATE DIALING COMPUTER v4.3")
    print("===================================")
    
    selfCheck()
    render()
    
    parallel.waitForAny(
        statusUpdateLoop,
        inputLoop,
        apiLoop
    )
end

local success, err = pcall(main)

if not success then
    if monitor then
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setTextColor(colors.red)
        monitor.write("FATAL ERROR:")
        monitor.setCursorPos(1, 3)
        monitor.write(tostring(err))
    end
    
    print("\n[FATAL ERROR]")
    print(err)
    error(err)
end