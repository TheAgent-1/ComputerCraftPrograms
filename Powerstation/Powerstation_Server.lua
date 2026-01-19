-- PowerStation Server Script for CC:Tweaked
-- Handles power station operations and in-game command sending
-- Communicates with external API at 192.168.1.40:5005/powerstation/api

local CONFIG = {
    API_BASE = "http://192.168.1.40:5005/powerstation/api",
    REPORT_INTERVAL = 5,  -- For dashboard auto-refresh
}

local monitor = nil
local apiOnline = false

-- ============================================
-- SETUP
-- ============================================
local function findMonitor()
    monitor = peripheral.find("monitor")
    if monitor then
        monitor.setTextScale(0.5)
        monitor.clear()
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
        print("[INFO] Monitor found and configured")
        return true
    else
        print("[WARN] No monitor found - continuing without display")
        return false
    end
end

local function testAPI()
    local response = http.get(CONFIG.API_BASE .. "/status")
    if response then
        local body = response.readAll()
        response.close()
        local data = textutils.unserializeJSON(body)
        if data and data.status == "ok" then
            print("[INFO] API Connection Successful (v" .. (data.version or "?") .. ")")
            apiOnline = true
            return true
        end
    end
    print("[ERROR] Unable to connect to API")
    apiOnline = false
    return false
end

-- ============================================
-- API UTILITIES
-- ============================================

-- Fetch full state from API
local function getFullState()
    if not apiOnline then
        return nil
    end
    
    local response = http.get(CONFIG.API_BASE .. "/status")
    if not response then
        print("[ERROR] Failed to fetch state")
        return nil
    end
    
    local body = response.readAll()
    response.close()
    
    local data = textutils.unserializeJSON(body)
    if data and data.state then
        return data.state
    end
    
    return nil
end

-- Fetch specific endpoint data
local function getEndpointData(endpoint)
    if not apiOnline then
        return nil
    end
    
    local response = http.get(CONFIG.API_BASE .. "/" .. endpoint)
    if not response then
        return nil
    end
    
    local body = response.readAll()
    response.close()
    
    return textutils.unserializeJSON(body)
end

-- Send a target value to an endpoint
local function setTarget(endpoint, value)
    if not apiOnline then
        print("[ERROR] API is offline, cannot send command")
        return false
    end
    
    local payload = textutils.serializeJSON({ target = value })
    
    local response = http.post(
        CONFIG.API_BASE .. "/" .. endpoint,
        payload,
        { ["Content-Type"] = "application/json" }
    )
    
    if response then
        local body = response.readAll()
        response.close()
        local result = textutils.unserializeJSON(body)
        
        if result and result.status then
            print("[OK] " .. result.status)
            return true
        elseif result and result.error then
            print("[ERROR] " .. result.error)
            return false
        end
    end
    
    print("[ERROR] Failed to send command")
    return false
end

-- ============================================
-- DISPLAY UTILITIES
-- ============================================

local function printHeader()
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    print("========================================")
    print("       POWERSTATION CONTROL CLI        ")
    print("========================================")
    term.setTextColor(colors.white)
end

local function printStatus(state)
    if not state then
        term.setTextColor(colors.red)
        print("  [API OFFLINE - No data available]")
        term.setTextColor(colors.white)
        return
    end
    
    print("")
    term.setTextColor(colors.cyan)
    print("  --- Current State ---")
    term.setTextColor(colors.white)
    
    -- RSC
    local targetRsc = state.target_rsc or 0
    local currentRsc = state.current_rsc or 0
    print(string.format("  RSC Target:  %d RPM", targetRsc))
    print(string.format("  RSC Actual:  %d RPM", currentRsc))
    
    -- Relay
    local targetRelay = state.target_relay and "ON" or "OFF"
    local currentRelay = state.current_relay and "ON" or "OFF"
    print(string.format("  Relay Target:  %s", targetRelay))
    print(string.format("  Relay Actual:  %s", currentRelay))
    
    -- Read-only sensors
    print("")
    term.setTextColor(colors.cyan)
    print("  --- Sensors ---")
    term.setTextColor(colors.white)
    print(string.format("  Stress:   %d SU", state.stress or 0))
    print(string.format("  Battery:  %d FE", state.battery or 0))
    
    -- Version
    print("")
    term.setTextColor(colors.gray)
    print(string.format("  Command Version: %d", state.target_version or 0))
    term.setTextColor(colors.white)
end

local function waitForKey()
    print("")
    term.setTextColor(colors.gray)
    print("Press any key to continue...")
    term.setTextColor(colors.white)
    os.pullEvent("key")
end

-- ============================================
-- COMMAND HANDLERS
-- ============================================

local function cmdHelp()
    printHeader()
    print("")
    term.setTextColor(colors.green)
    print("Available Commands:")
    term.setTextColor(colors.white)
    print("  help              Show this help message")
    print("  status / s        Show current powerstation state")
    print("  dashboard / d     Live updating dashboard")
    print("  api               Test API connection")
    print("  exit / quit       Exit the CLI")
    
    term.setTextColor(colors.green)
    print("Control Commands:")
    term.setTextColor(colors.white)
    print("  rsc               Show RSC values")
    print("  rsc <-256 to 256> Set RSC target speed")
    print("")
    print("  relay             Show relay state")
    print("  relay on          Turn relay ON")
    print("  relay off         Turn relay OFF")
    print("")
    print("  power             Show battery level")
    print("  stress            Show stress level")
    
    waitForKey()
    return true
end

local function cmdStatus()
    printHeader()
    local state = getFullState()
    printStatus(state)
    waitForKey()
    return true
end

local function cmdDashboard()
    -- Live updating dashboard - press Q to exit
    while true do
        printHeader()
        local state = getFullState()
        printStatus(state)
        
        print("")
        term.setTextColor(colors.yellow)
        print("  [Auto-refresh every " .. CONFIG.POLL_INTERVAL .. "s - Press Q to exit]")
        term.setTextColor(colors.white)
        
        -- Wait for either timeout or Q key
        local timer = os.startTimer(CONFIG.POLL_INTERVAL)
        
        while true do
            local event, param = os.pullEvent()
            
            if event == "timer" and param == timer then
                break  -- Refresh
            elseif event == "key" and param == keys.q then
                return true  -- Exit dashboard
            elseif event == "key" then
                break  -- Any other key also refreshes
            end
        end
    end
end

local function cmdAPI()
    printHeader()
    print("")
    print("Testing API connection...")
    print("")
    testAPI()
    waitForKey()
    return true
end

local function cmdRSC(args)
    printHeader()
    print("")
    
    if args and #args > 0 then
        -- Setting RSC value
        local value = tonumber(args[1])
        
        if not value then
            term.setTextColor(colors.red)
            print("[ERROR] Invalid number: " .. args[1])
            term.setTextColor(colors.white)
        elseif value < -256 or value > 256 then
            term.setTextColor(colors.red)
            print("[ERROR] Value must be between -256 and 256")
            term.setTextColor(colors.white)
        else
            print("Setting RSC target to " .. value .. " RPM...")
            print("")
            setTarget("rsc", value)
        end
    else
        -- Showing RSC values
        local data = getEndpointData("rsc")
        
        if data then
            print("RSC Status:")
            print("")
            print(string.format("  Target Speed:  %d RPM", data.target_rsc or 0))
            print(string.format("  Current Speed: %d RPM", data.current_rsc or 0))
            
            local diff = (data.target_rsc or 0) - (data.current_rsc or 0)
            if math.abs(diff) > 5 then
                print("")
                term.setTextColor(colors.yellow)
                print("  [Ramping - difference: " .. diff .. " RPM]")
                term.setTextColor(colors.white)
            end
        else
            term.setTextColor(colors.red)
            print("[ERROR] Could not fetch RSC data")
            term.setTextColor(colors.white)
        end
    end
    
    waitForKey()
    return true
end

local function cmdRelay(args)
    printHeader()
    print("")
    
    if args and #args > 0 then
        -- Setting relay state
        local state = string.lower(args[1])
        
        if state == "on" then
            print("Turning relay ON...")
            print("")
            setTarget("relay", true)
        elseif state == "off" then
            print("Turning relay OFF...")
            print("")
            setTarget("relay", false)
        else
            term.setTextColor(colors.red)
            print("[ERROR] Relay state must be 'on' or 'off'")
            term.setTextColor(colors.white)
        end
    else
        -- Showing relay state
        local data = getEndpointData("relay")
        
        if data then
            local targetStr = data.target_relay and "ON" or "OFF"
            local currentStr = data.current_relay and "ON" or "OFF"
            
            print("Relay Status:")
            print("")
            print("  Target State:  " .. targetStr)
            print("  Current State: " .. currentStr)
            
            if data.target_relay ~= data.current_relay then
                print("")
                term.setTextColor(colors.yellow)
                print("  [State mismatch - command pending]")
                term.setTextColor(colors.white)
            end
        else
            term.setTextColor(colors.red)
            print("[ERROR] Could not fetch relay data")
            term.setTextColor(colors.white)
        end
    end
    
    waitForKey()
    return true
end

local function cmdPower()
    printHeader()
    print("")
    
    local state = getFullState()
    
    if state then
        local battery = state.battery or 0
        print("Battery Status:")
        print("")
        print(string.format("  Stored Energy: %d FE", battery))

        -- Visual bar (assuming max 270,000,000 FE - adjust as needed)
        local maxEnergy = 270000000
        local percentage = math.min(100, math.floor((battery / maxEnergy) * 100))
        local barWidth = 30
        local filledWidth = math.floor((percentage / 100) * barWidth)
        
        print("")
        local bar = "  [" .. string.rep("=", filledWidth) .. string.rep("-", barWidth - filledWidth) .. "]"
        print(bar .. " " .. percentage .. "%")
    else
        term.setTextColor(colors.red)
        print("[ERROR] Could not fetch battery data")
        term.setTextColor(colors.white)
    end
    
    waitForKey()
    return true
end

local function cmdStress()
    printHeader()
    print("")
    
    local state = getFullState()
    
    if state then
        local stress = state.stress or 0
        print("Stress Level:")
        print("")
        print(string.format("  Current Stress: %d SU", stress))
        
        -- Warning thresholds (adjust based on your setup)
        if stress > 900 then
            term.setTextColor(colors.red)
            print("")
            print("  [CRITICAL - Network near capacity!]")
        elseif stress > 700 then
            term.setTextColor(colors.yellow)
            print("")
            print("  [WARNING - High stress level]")
        else
            term.setTextColor(colors.green)
            print("")
            print("  [OK - Stress level normal]")
        end
        term.setTextColor(colors.white)
    else
        term.setTextColor(colors.red)
        print("[ERROR] Could not fetch stress data")
        term.setTextColor(colors.white)
    end
    
    waitForKey()
    return true
end

-- ============================================
-- COMMAND PARSER
-- ============================================

local function parseInput(input)
    local parts = {}
    for word in input:gmatch("%S+") do
        table.insert(parts, word)
    end
    
    local command = string.lower(parts[1] or "")
    local args = {}
    
    for i = 2, #parts do
        table.insert(args, parts[i])
    end
    
    return command, args
end

-- ============================================
-- MAIN CLI LOOP
-- ============================================

local function mainCLI()
    printHeader()
    
    -- Show quick status line
    if apiOnline then
        term.setTextColor(colors.green)
        print("  API: Online")
    else
        term.setTextColor(colors.red)
        print("  API: Offline")
    end
    term.setTextColor(colors.white)
    
    print("")
    print("Type 'help' for commands, 'status' for state")
    print("")
    write("> ")
    
    local input = read()
    local command, args = parseInput(input)
    
    -- Empty input
    if command == "" then
        return true
    end
    
    -- Command dispatch
    if command == "help" or command == "?" then
        return cmdHelp()
        
    elseif command == "status" or command == "s" then
        return cmdStatus()
        
    elseif command == "dashboard" or command == "d" then
        return cmdDashboard()
        
    elseif command == "api" then
        return cmdAPI()
        
    elseif command == "exit" or command == "quit" or command == "q" then
        print("Exiting...")
        return false
        
    elseif command == "rsc" then
        return cmdRSC(args)
        
    elseif command == "relay" then
        return cmdRelay(args)
        
    elseif command == "power" or command == "battery" then
        return cmdPower()
        
    elseif command == "stress" then
        return cmdStress()
        
    else
        printHeader()
        print("")
        term.setTextColor(colors.red)
        print("[ERROR] Unknown command: " .. command)
        term.setTextColor(colors.white)
        print("")
        print("Type 'help' for available commands.")
        waitForKey()
        return true
    end
end

-- ============================================
-- ENTRY POINT
-- ============================================

print("Initializing PowerStation Server...")
print("")

-- Optional monitor setup
findMonitor()

-- Test API connection
if testAPI() then
    print("")
    print("Starting CLI...")
    sleep(1)
    
    local running = true
    while running do
        local success, result = pcall(mainCLI)
        
        if success then
            running = result
        else
            -- Handle errors gracefully
            term.setTextColor(colors.red)
            print("[ERROR] " .. tostring(result))
            term.setTextColor(colors.white)
            print("Restarting CLI in 3 seconds...")
            sleep(3)
            testAPI()  -- Re-check API status
        end
    end
else
    print("")
    term.setTextColor(colors.red)
    print("[FATAL] Cannot start - API is offline")
    print("Check your network connection and API server")
    term.setTextColor(colors.white)
end