-- PowerStation Server Script for CC:Tweaked
-- Handles power station operations and Ingame command sending
-- This script is to be run with a connected monitor peripheral (later used for display purposes)
-- send commands to the clients via an external API (192.168.1.41:5005/powerstation/api)

local CONFIG = {
    API_URL = "http://192.168.1.41:5005/powerstation/api",
    STATUS_URL = API_URL .. "/status"
}

local monitor = nil
local apiStatus = false


-- ============================================
-- SETUPS
-- ============================================
local function findMonitor()
    -- Find and setup the monitor peripheral
    monitor = nil
    monitor = peripheral.find("monitor")
    if not monitor then
        error("[FATAL] No monitor found!")
    end

    monitor.setTextScale(0.5)
    monitor.clear()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)

end

local function testAPI()
    -- Test connection to external API (similar to heartbeat)
    -- just ensure we can reach it
    local response = http.get(CONFIG.API_URL)
    if response then
        local body = response.readAll()
        response.close()
        print("[INFO] API Connection Successful")
        apiStatus = true
    else
        print("[ERROR] Unable to connect to API at " .. CONFIG.API_URL)
        apiStatus = false
    end
    return apiStatus
end


-- ============================================
-- UTILS
-- ============================================
local function getAPIData(dataType)
    local data = nil

    if not apiStatus then
        print("[ERROR] API is offline, cannot fetch data")
        return nil
    end

    -- Fetch data from the powerstation API
    local response = http.get(CONFIG.API_URL)
    if response then
        local body = response.readAll()
        response.close()
        data = textutils.unserializeJSON(body)
    end

    if dataType == "rsc" then
        return data.rotationSpeedController
    elseif dataType == "relay" then
        return data.relayState
    elseif dataType == "power" then
        return data.powerReserves
    elseif dataType == "stress" then
        return data.stressLevel
    else
        print("[ERROR] Unknown dataType: " .. dataType)
        return nil
    end


end

local function sendCommandToAPI(action, value)
    -- Send a command to the powerstation API
    -- Structure: (pick one)
    --      "action": "set-speed", "value": <number> (this sets the rotation speed controller value)
    --      "action": "set-relay", "value": "on"/"off" (this sets the relay state)
    --      "action": "get-power" (this fetches the current power reserves)
    --      "action": "get-stress" (this fetches the current stress level)
    if not apiStatus then
        print("[ERROR] API is offline, cannot send command")
        return nil
    end

    -- check if action is valid, and if value is required
    local postData = nil
    if action == "set-speed" then
        postData = textutils.serializeJSON({action = action, value = value})
    elseif action == "set-relay" then
        postData = textutils.serializeJSON({action = action, value = value})
    elseif action == "get-power" then
        postData = textutils.serializeJSON({action = action})
    elseif action == "get-stress" then
        postData = textutils.serializeJSON({action = action})
    else
        print("[ERROR] Invalid action: " .. action)
        return nil
    end

    -- send that fucker!
    local response = http.post(CONFIG.API_URL, postData, {["Content-Type"] = "application/json"})
    if response then
        print("[INFO] Command '" .. action .. "' sent successfully")
        response.close()
        return true
    else
        print("[ERROR] Failed to send command '" .. action .. "'")
        return false
    end
end

-- ============================================
-- MAIN CLI LOOP
-- ============================================
local function mainCLI()
    -- Print a CLI styled input to the console
    term.clear()
    term.setCursorPos(1,1)
    print("PowerStation Server CLI")
    print("Type 'help' for a list of commands.")
    write("> ")
    local input = read()
    local command = string.lower(input)

    if command == "help" then
        print("Available commands:")
        print(" help           - Show this help message")
        print(" API            - Check powerstation API status")
        print(" exit           - Exit the CLI")
        print("") --blank line for readability
        print(" rsc            - Show Rotation Speed Controller value")
        print(" rsc <value>    - Set Rotation Speed Controller (-256 to 256)")
        print(" relay          - Show Relay State")
        print(" relay <on/off> - Set Relay State")
        print(" power          - Show current energy reserves")
        print(" stress         - Show current stress level")
        print("") --blank line for readability
        print("Press any key to continue...")
        os.pullEvent("key")
        return true 
    end

    if command == "api" then
        testAPI()
        print("Press any key to continue...")
        os.pullEvent("key")
        return true
    end

    if command == "exit" then
        print("Exiting CLI...")
        return false
    end

    -- Now handle commands that control the powerstation
    -- RSC COMMAND
    if command :match("^rsc%s") then
        local _, _, valueStr = string.find(command, "^rsc%s+(%-?%d+)")
        local value = tonumber(valueStr)
        if value then
            if value < -256 or value > 256 then
                print("[ERROR] Value must be between -256 and 256")
            else
                sendCommandToAPI("set-speed", value)
            end
        else
            local rscValue = getAPIData("rsc")
            if rscValue then
                print("Rotation Speed Controller Value: " .. rscValue)
            end
        end
        print("Press any key to continue...")
        os.pullEvent("key")
        return true
    end

    -- RELAY COMMAND
    if command :match("^relay%s") then
        local _, _, state = string.find(command, "^relay%s+(%a+)")
        if state then
            state = string.lower(state)
            if state == "on" or state == "off" then
                sendCommandToAPI("set-relay", state)
            else
                print("[ERROR] Relay state must be 'on' or 'off'")
            end
        else
            local relayState = getAPIData("relay")
            if relayState then
                print("Relay State: " .. relayState)
            end
        end
        print("Press any key to continue...")
        os.pullEvent("key")
        return true
    end

    -- POWER COMMAND
    if command == "power" then
        local powerReserves = getAPIData("power")
        if powerReserves then
            print("Current Power Reserves: " .. powerReserves .. " FE")
        end
        print("Press any key to continue...")
        os.pullEvent("key")
        return true
    end

    -- STRESS COMMAND
    if command == "stress" then
        local stressLevel = getAPIData("stress")
        if stressLevel then
            print("Current Stress Level: " .. stressLevel .. " SU")
        end
        print("Press any key to continue...")
        os.pullEvent("key")
        return true
    end
end

-- Entry Point
local shouldContinue = true
--findMonitor() -- setup monitor (NOT USED YET)
if testAPI() then
    while shouldContinue do
        shouldContinue = mainCLI()
    end
else
    error("[FATAL] Cannot start CLI, API is offline.")
end