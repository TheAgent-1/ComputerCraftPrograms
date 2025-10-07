--[[
==========================================
  STARGATE DIALING COMPUTER v4.1
  FIX: Peripheral detection & rotation
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
    if obj == nil then return false end
    return type(obj[methodName]) == "function"
end

-- ============================================
-- HARDWARE DETECTION (FRESH EVERY TIME)
-- ============================================

local function refreshPeripherals()
    -- Clear old references
    interface = nil
    monitor = nil
    
    -- Find monitor
    monitor = peripheral.find("monitor")
    if not monitor then
        error("[FATAL] No monitor found!")
    end
    
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    
    -- Find interface (check in priority order)
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
        -- Guess based on interface
        if state.interfaceType == "basic_interface" then
            state.gateType = "Milky Way"
        else
            state.gateType = "Universe/Pegasus"
        end
    end
    
    log("Gate Type: " .. state.gateType, colors.cyan)
end

local function detectIris()
    state.hasIris = hasMethod(interface, "closeIris") or 
                    hasMethod(interface, "openIris")
    
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
    if not CONFIG.DEBUG_MODE then return end
    
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
            state.energyMax = interface.getEnergyTarget()
        elseif hasMethod(interface, "getMaxEnergy") then
            state.energyMax = interface.getMaxEnergy()
        elseif hasMethod(interface, "getEnergyCapacity") then
            state.energyMax = interface.getEnergyCapacity()
        else
            state.energyMax = 1000000
        end
    end
end

local function updateGateStatus()
    -- Refresh interface reference in case it changed
    local testInterface = peripheral.find(state.interfaceType)
    if testInterface ~= nil then
        interface = testInterface
    end
    
    updateEnergy()
    
    local isConnected = hasMethod(interface, "isStargateConnected") and 
                        interface.isStargateConnected()
    
    local isDialing = (hasMethod(interface, "isDialingOut") and interface.isDialingOut()) or
                      (hasMethod(interface, "isStargateDialingOut") and interface.isStargateDialingOut())
    
    local isWormholeOpen = hasMethod(interface, "isWormholeOpen") and 
                           interface.isWormholeOpen()
    
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
    
    -- Reset chevrons
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
    
    -- Check if we need to dial or can just engage symbols
    local dialMethod = nil
    
    if hasMethod(interface, "engageSymbol") then
        dialMethod = "engageSymbol"
    elseif hasMethod(interface, "engage") then
        dialMethod = "engage"
    elseif hasMethod(interface, "dialAddress") then
        -- Some crystal interfaces have a direct dial method
        log("Using direct dial method", colors.lightBlue)
        interface.dialAddress(address)
        state.dialing = false
        return true
    else
        log("ERROR: No crystal dial method found!", colors.red)
        state.dialing = false
        return false
    end
    
    -- Engage each symbol
    for i, symbol in ipairs(address) do
        if i > 9 then break end
        
        log("Chevron " .. i .. " -> Symbol " .. symbol, colors.lightBlue)
        
        -- Try to engage
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
        os.sleep(1.5)  -- Wait for chevron animation
        
        -- Check for abort conditions
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
-- DIALING SYSTEM - BASIC INTERFACE
-- ============================================

local function dialBasicInterface(address)
    state.dialing = true
    log("BASIC DIAL START", colors.cyan)
    
    -- Verify we have required methods
    if not hasMethod(interface, "getCurrentSymbol") then
        log("ERROR: Missing getCurrentSymbol()", colors.red)
        state.dialing = false
        return false
    end
    
    -- Check what rotation methods exist
    local rotateClockwise = nil
    local rotateCounter = nil
    
    if hasMethod(interface, "rotateClockwise") then
        rotateClockwise = function() interface.rotateClockwise(1) end
    elseif hasMethod(interface, "rotate") then
        rotateClockwise = function() interface.rotate(1) end
    end
    
    if hasMethod(interface, "rotateAntiClockwise") then
        rotateCounter = function() interface.rotateAntiClockwise(1) end
    elseif hasMethod(interface, "rotateCounterClockwise") then
        rotateCounter = function() interface.rotateCounterClockwise(1) end
    elseif hasMethod(interface, "rotate") then
        rotateCounter = function() interface.rotate(-1) end
    end
    
    if not rotateClockwise or not rotateCounter then
        log("ERROR: Missing rotation methods", colors.red)
        state.dialing = false
        return false
    end
    
    -- Check chevron encoding methods
    local encodeChevron = nil
    
    if hasMethod(interface, "raiseChevron") and hasMethod(interface, "lowerChevron") then
        encodeChevron = function()
            interface.raiseChevron()
            os.sleep(0.5)
            interface.lowerChevron()
            os.sleep(0.5)
        end
    elseif hasMethod(interface, "encodeChevron") then
        encodeChevron = function()
            interface.encodeChevron()
            os.sleep(0.5)
        end
    elseif hasMethod(interface, "closeChevron") then
        encodeChevron = function()
            interface.closeChevron()
            os.sleep(0.5)
        end
    else
        log("ERROR: No chevron encode method", colors.red)
        state.dialing = false
        return false
    end
    
    -- Now actually dial
    for i, targetSymbol in ipairs(address) do
        if i > 7 then break end
        
        log("Dialing symbol " .. targetSymbol, colors.lightBlue)
        
        -- Get current position
        local currentSymbol = interface.getCurrentSymbol()
        
        if currentSymbol == nil then
            log("ERROR: getCurrentSymbol() returned nil!", colors.red)
            state.dialing = false
            return false
        end
        
        log("Current: " .. currentSymbol .. " Target: " .. targetSymbol, colors.gray)
        
        -- Rotate to target
        local attempts = 0
        local maxAttempts = 50
        
        while currentSymbol ~= targetSymbol and attempts < maxAttempts do
            -- Calculate shortest path (assuming 39 symbols, 0-38)
            local diff = (targetSymbol - currentSymbol + 39) % 39
            
            if diff == 0 then
                break  -- Already at target
            elseif diff <= 19 then
                -- Go clockwise
                rotateClockwise()
            else
                -- Go counter-clockwise  
                rotateCounter()
            end
            
            os.sleep(0.1)
            currentSymbol = interface.getCurrentSymbol()
            attempts = attempts + 1
            
            if attempts % 10 == 0 then
                log("Rotation attempt " .. attempts .. "/50", colors.gray)
            end
        end
        
        if attempts >= maxAttempts then
            log("ERROR: Rotation timeout on chevron " .. i, colors.red)
            state.dialing = false
            return false
        end
        
        log("Reached symbol " .. targetSymbol .. " - encoding chevron " .. i, colors.cyan)
        
        -- Encode the chevron
        local success, err = pcall(encodeChevron)
        if not success then
            log("ERROR encoding: " .. tostring(err), colors.red)
            state.dialing = false
            return false
        end
        
        state.chevrons[i] 