--[[
==========================================
  STARGATE DIALING COMPUTER v4.0
  Complete Rewrite - Bug Fixed Version
==========================================
]]

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    STARGATE_NAME = "Earth",
    API_URL = "http://192.168.1.41:5005/sg-command",
    API_ENABLED = true,
    DEBUG_MODE = true  -- Shows method names on startup
}

-- Known gate addresses (7-symbol)
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
    -- Hardware info
    gateType = "Unknown",
    interfaceType = "Unknown",
    hasIris = false,
    
    -- Current status
    irisClosed = false,
    status = "Initializing...",
    chevrons = {false, false, false, false, false, false, false, false, false},
    energy = 0,
    energyMax = 1,
    connectedAddress = nil,
    
    -- Flags
    dialing = false,
    incoming = false
}

local eventLog = {}
local currentScreen = "main"  -- "main" or "destinations"

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
    return obj ~= nil and type(obj[methodName]) == "function"
end

-- ============================================
-- HARDWARE DETECTION & SELF-CHECK
-- ============================================

local function findMonitor()
    monitor = peripheral.find("monitor")
    if not monitor then
        error("[FATAL] No monitor found!")
    end
    
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    
    log("Monitor connected", colors.green)
end

local function findInterface()
    -- Search for any stargate interface
    local types = {
        "advanced_crystal_interface",
        "crystal_interface",
        "basic_interface"
    }
    
    for _, iType in ipairs(types) do
        local found = peripheral.find(iType)
        if found then
            interface = found
            state.interfaceType = iType
            log("Interface: " .. iType, colors.green)
            return true
        end
    end
    
    error("[FATAL] No Stargate interface found!")
end

local function detectGateType()
    -- Try various methods to detect gate variant
    if hasMethod(interface, "getStargateType") then
        state.gateType = interface.getStargateType() or "Unknown"
    elseif hasMethod(interface, "getVariant") then
        state.gateType = interface.getVariant() or "Unknown"
    else
        -- Infer from interface type
        if state.interfaceType == "basic_interface" then
            state.gateType = "Milky Way"
        else
            state.gateType = "Universe/Pegasus"
        end
    end
    
    log("Gate: " .. state.gateType, colors.cyan)
end

local function detectIris()
    -- Check for iris capability
    state.hasIris = hasMethod(interface, "closeIris") or 
                    hasMethod(interface, "setIrisState") or
                    hasMethod(interface, "getIrisProgress")
    
    if state.hasIris then
        log("Iris: DETECTED", colors.green)
        
        -- Get current iris state
        if hasMethod(interface, "isIrisClosed") then
            state.irisClosed = interface.isIrisClosed()
        elseif hasMethod(interface, "getIrisProgress") then
            state.irisClosed = (interface.getIrisProgress() >= 1.0)
        end
    else
        log("Iris: NOT FOUND", colors.yellow)
    end
end

local function listAvailableMethods()
    if not CONFIG.DEBUG_MODE then return end
    
    log("Listing interface methods...", colors.gray)
    local methods = peripheral.getMethods(peripheral.getName(interface))
    
    print("\n=== AVAILABLE METHODS ===")
    for i, method in ipairs(methods) do
        print(string.format("%2d. %s", i, method))
    end
    print("=========================\n")
end

local function selfCheck()
    log("SELF-CHECK INITIATED", colors.yellow)
    
    findMonitor()
    findInterface()
    detectGateType()
    detectIris()
    listAvailableMethods()
    
    log("SELF-CHECK COMPLETE", colors.green)
    state.status = "Idle"
    os.sleep(1.5)
end

-- ============================================
-- STARGATE STATUS MONITORING
-- ============================================

local function updateEnergy()
    -- Try different energy method combinations
    if hasMethod(interface, "getEnergy") then
        state.energy = interface.getEnergy() or 0
        
        if hasMethod(interface, "getEnergyTarget") then
            state.energyMax = interface.getEnergyTarget() or 1
        elseif hasMethod(interface, "getMaxEnergy") then
            state.energyMax = interface.getMaxEnergy() or 1
        elseif hasMethod(interface, "getEnergyCapacity") then
            state.energyMax = interface.getEnergyCapacity() or 1
        else
            state.energyMax = 1000000  -- Default fallback
        end
    end
end

local function updateGateStatus()
    updateEnergy()
    
    -- Check various gate states
    local isConnected = hasMethod(interface, "isStargateConnected") and 
                        interface.isStargateConnected()
    
    local isDialing = (hasMethod(interface, "isDialingOut") and interface.isDialingOut()) or
                      (hasMethod(interface, "isStargateDialingOut") and interface.isStargateDialingOut())
    
    local isWormholeOpen = hasMethod(interface, "isWormholeOpen") and 
                           interface.isWormholeOpen()
    
    -- Determine status
    if isConnected then
        state.status = "CONNECTED"
        
        -- Get connected address
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
        
        -- Reset chevrons when idle
        if not state.dialing then
            for i = 1, 9 do
                state.chevrons[i] = false
            end
        end
    end
    
    -- Update iris state
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
end

-- ============================================
-- DIALING SYSTEM
-- ============================================

local function dialCrystalInterface(address)
    state.dialing = true
    log("CRYSTAL DIAL SEQUENCE START", colors.cyan)
    
    for i, symbol in ipairs(address) do
        if i > 9 then break end  -- Max 9 chevrons
        
        log("Chevron " .. i .. " - Symbol " .. symbol, colors.lightBlue)
        
        -- Engage symbol
        if hasMethod(interface, "engageSymbol") then
            interface.engageSymbol(symbol)
        elseif hasMethod(interface, "engage") then
            interface.engage(symbol)
        else
            log("ERROR: No engage method!", colors.red)
            state.dialing = false
            return false
        end
        
        state.chevrons[i] = true
        os.sleep(1.2)  -- Wait for chevron animation
        
        -- Check for incoming wormhole interrupt
        if state.incoming then
            log("INCOMING DETECTED - ABORT", colors.red)
            state.dialing = false
            return false
        end
    end
    
    state.dialing = false
    log("DIAL SEQUENCE COMPLETE", colors.green)
    return true
end

local function dialBasicInterface(address)
    state.dialing = true
    log("BASIC DIAL SEQUENCE START", colors.cyan)
    
    -- Verify required methods exist
    if not hasMethod(interface, "getCurrentSymbol") then
        log("ERROR: Missing getCurrentSymbol", colors.red)
        state.dialing = false
        return false
    end
    
    for i, targetSymbol in ipairs(address) do
        if i > 7 then break end  -- Basic gates are 7-chevron max
        
        log("Rotating to symbol " .. targetSymbol, colors.lightBlue)
        
        -- Get current position
        local currentSymbol = interface.getCurrentSymbol()
        local rotations = 0
        
        -- Rotate to target symbol
        while currentSymbol ~= targetSymbol and rotations < 40 do
            -- Calculate shortest path
            local clockwiseDist = (targetSymbol - currentSymbol + 39) % 39
            local counterDist = (currentSymbol - targetSymbol + 39) % 39
            
            if clockwiseDist <= counterDist then
                -- Rotate clockwise
                if hasMethod(interface, "rotateClockwise") then
                    interface.rotateClockwise(1)  -- Rotate 1 step
                elseif hasMethod(interface, "rotate") then
                    interface.rotate(1)
                end
            else
                -- Rotate counter-clockwise
                if hasMethod(interface, "rotateAntiClockwise") then
                    interface.rotateAntiClockwise(1)
                elseif hasMethod(interface, "rotateCounterClockwise") then
                    interface.rotateCounterClockwise(1)
                elseif hasMethod(interface, "rotate") then
                    interface.rotate(-1)
                end
            end
            
            os.sleep(0.05)
            currentSymbol = interface.getCurrentSymbol()
            rotations = rotations + 1
        end
        
        if rotations >= 40 then
            log("ERROR: Rotation timeout!", colors.red)
            state.dialing = false
            return false
        end
        
        -- Encode chevron
        log("Encoding chevron " .. i, colors.cyan)
        
        if hasMethod(interface, "raiseChevron") then
            -- Milky Way style: raise then lower
            interface.raiseChevron()
            os.sleep(0.4)
            
            if hasMethod(interface, "lowerChevron") then
                interface.lowerChevron()
                os.sleep(0.4)
            end
            
        elseif hasMethod(interface, "encodeChevron") then
            -- Simple encode
            interface.encodeChevron()
            os.sleep(0.5)
            
        elseif hasMethod(interface, "closeChevron") then
            -- Alternative method
            interface.closeChevron()
            os.sleep(0.5)
        end
        
        state.chevrons[i] = true
        
        -- Check for abort
        if state.incoming then
            log("INCOMING DETECTED - ABORT", colors.red)
            state.dialing = false
            return false
        end
    end
    
    state.dialing = false
    log("DIAL SEQUENCE COMPLETE", colors.green)
    return true
end

local function dialAddress(address)
    -- Safety checks
    if state.status ~= "IDLE" then
        log("Cannot dial - gate busy!", colors.red)
        return false
    end
    
    if state.dialing then
        log("Already dialing!", colors.red)
        return false
    end
    
    -- Start dial based on interface type
    if state.interfaceType == "basic_interface" then
        return dialBasicInterface(address)
    else
        return dialCrystalInterface(address)
    end
end

-- ============================================
-- GUI RENDERING
-- ============================================

local function drawText(x, y, text, fg, bg)
    monitor.setCursorPos(x, y)
    if fg then monitor.setTextColor(fg) end
    if bg then monitor.setBackgroundColor(bg) end
    monitor.write(text)
end

local function drawButton(x, y, text, color)
    drawText(x, y, "[ " .. text .. " ]", color)
end

local function drawProgressBar(x, y, width, current, max)
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
    
    -- Header
    drawText(1, 1, "STARGATE COMMAND - DIALING COMPUTER", colors.white)
    drawText(1, 2, string.rep("=", 50), colors.gray)
    
    -- System Info
    drawText(1, 4, "Gate Type: " .. state.gateType, colors.cyan)
    drawText(1, 5, "Interface: " .. state.interfaceType, colors.cyan)
    
    -- Status
    local statusColor = colors.yellow
    if state.status == "CONNECTED" then
        statusColor = colors.green
    elseif state.status == "INCOMING WORMHOLE" then
        statusColor = colors.red
    elseif state.status == "IDLE" then
        statusColor = colors.lightGray
    end
    
    drawText(1, 7, "STATUS: " .. state.status, statusColor)
    
    -- Connected Address
    if state.connectedAddress then
        local addrStr = "Unknown"
        if type(state.connectedAddress) == "table" then
            addrStr = table.concat(state.connectedAddress, "-")
        else
            addrStr = tostring(state.connectedAddress)
        end
        drawText(1, 8, "Address: " .. addrStr, colors.lightBlue)
    end
    
    -- Energy Bar
    drawText(1, 10, "Energy:", colors.orange)
    drawProgressBar(10, 10, 30, state.energy, state.energyMax)
    local energyPct = math.floor((state.energy / state.energyMax) * 100)
    drawText(42, 10, energyPct .. "%", colors.orange)
    
    -- Chevron Indicators
    drawText(1, 12, "Chevrons:", colors.cyan)
    for i = 1, 7 do
        local symbol = state.chevrons[i] and "●" or "○"
        local color = state.chevrons[i] and colors.lime or colors.gray
        drawText(12 + (i * 3), 12, symbol, color)
    end
    
    -- Iris Status
    if state.hasIris then
        local irisText = state.irisClosed and "CLOSED" or "OPEN"
        local irisColor = state.irisClosed and colors.red or colors.green
        drawText(1, 14, "Iris: " .. irisText, irisColor)
    else
        drawText(1, 14, "Iris: N/A", colors.gray)
    end
    
    -- Control Buttons
    drawButton(2, 16, "DIAL", colors.lime)
    drawButton(18, 16, "DISCONNECT", colors.red)
    if state.hasIris then
        drawButton(38, 16, "IRIS", colors.cyan)
    end
    
    -- Event Log
    drawText(1, 18, "EVENT LOG:", colors.white)
    drawText(1, 19, string.rep("-", 50), colors.gray)
    
    for i, entry in ipairs(eventLog) do
        if i <= 7 then
            local logText = entry.time .. " " .. entry.message
            if #logText > 48 then
                logText = logText:sub(1, 45) .. "..."
            end
            drawText(2, 19 + i, logText, entry.color)
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
        drawButton(3, y, i .. ". " .. name, colors.lime)
        y = y + 2
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
    -- Dial button (row 16, cols 2-15)
    if y == 16 and x >= 2 and x <= 15 then
        currentScreen = "destinations"
        render()
        return
    end
    
    -- Disconnect button (row 16, cols 18-35)
    if y == 16 and x >= 18 and x <= 35 then
        disconnectGate()
        return
    end
    
    -- Iris button (row 16, cols 38-48)
    if state.hasIris and y == 16 and x >= 38 and x <= 48 then
        toggleIris()
        return
    end
end

local function handleDestinationClick(x, y)
    -- Map destinations to rows
    local destList = {}
    for name, address in pairs(DESTINATIONS) do
        table.insert(destList, {name = name, address = address})
    end
    
    -- Check each destination row (starting at y=4, every 2 rows)
    for i, dest in ipairs(destList) do
        local destY = 4 + ((i - 1) * 2)
        if y == destY and x >= 3 then
            log("Dialing: " .. dest.name, colors.green)
            dialAddress(dest.address)
            currentScreen = "main"
            render()
            return
        end
    end
    
    -- Cancel button (approximate position)
    local cancelY = 4 + (#destList * 2) + 1
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
        -- Sleep forever if API disabled
        while true do os.sleep(3600) end
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
                    if state.irisClosed then toggleIris() end
                    
                elseif data.action == "iris_close" and state.hasIris then
                    if not state.irisClosed then toggleIris() end
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
    print("  STARGATE DIALING COMPUTER v4.0")
    print("===================================")
    print("")
    
    -- Run self-diagnostic
    selfCheck()
    
    -- Initial render
    render()
    
    -- Start parallel loops
    parallel.waitForAny(
        statusUpdateLoop,
        inputLoop,
        apiLoop
    )
end

-- Execute with error handling
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