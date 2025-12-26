-- PowerStation Client Script for CC:Tweaked
-- Handles receiving commands from the API and executing them on the local power station
-- This script is to be run on the client machine connected to the power station peripherals
-- These peripherals need to be connected via digital adapter:
-- RSC (Rotation Speed Controller)
-- RELAY
-- STRESS

local CONFIG = {
    CLIENT_TYPE = "RSC", -- Options: "RSC", "RELAY", "BATTERY", STRESS
    PERIPHERAL_SIDE = "back", -- The side where the digital adapter is connected (for RSC, RELAY, STRESS) or the side of the battery box (for BATTERY)
    DIGITAL_ADAPTER_SIDE = "back", -- Side of the digital adapter that connects to the peripheral (only needed for RSC, RELAY, STRESS)
    BATTERY_COUNT = 1, -- Number of battery boxes connected (only needed for BATTERY type)
    API_URL = "http://192.168.1.41:5005/powerstation/api",
    STATUS_URL = "http://192.168.1.41:5005/powerstation/api/status"
}

--=============================================
-- PERIPHERAL SETUP
--=============================================
local peripheralDevice0 = nil -- Main peripheral device (RSC, RELAY, or BATTERY)
local peripheralDevice1 = nil -- Reserved for BATTERY type if needing more power storage >90MFE (total 180MFE: 180,000,000 FE)
local peripheralDevice2 = nil -- Reserved for BATTERY type if needing even more power storage >180MFE (total 270MFE: 270,000,000 FE)

if CONFIG.CLIENT_TYPE == "RSC" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE) -- RSC has to be connected via digital adapter

elseif CONFIG.CLIENT_TYPE == "RELAY" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE) -- Relay connected directly via redstone
    -- while relay can be controlled via redstone, we still wrap it for use with its functions if needed

elseif CONFIG.CLIENT_TYPE == "STRESS" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE) -- Stress Monitor connected via digital adapter

elseif CONFIG.CLIENT_TYPE == "BATTERY" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE) -- Battery Box
    if CONFIG.BATTERY_COUNT >= 2 then
        peripheralDevice1 = peripheral.wrap("right") -- Second Battery Box on the right side
    end
    if CONFIG.BATTERY_COUNT >= 3 then
        peripheralDevice2 = peripheral.wrap("left") -- Third Battery Box on the left side
    end
end

-- ============================================
-- UTILS
-- ============================================
local function getAPIData(dataType)
    -- Fetch data from the STATUS_URL endpoint
    -- this will be use to set the peripheral states
    -- this will be formatted as JSON:
    --  {
    --      "rotationSpeedController": 0,
    --      "relayState": "off",
    --      "powerReserves": 0,
    --      "stressLevel": 0
    --  }

    local response = http.get(CONFIG.STATUS_URL)
    if response then
        local responseData = response.readAll()
        response.close()
        local data = textutils.unserializeJSON(responseData)
        if data and data[dataType] ~= nil then
            return data[dataType]
        else
            print("Error: Invalid data type requested from API - " .. dataType)
            return nil
        end
    else
        print("Error: Unable to connect to API at " .. CONFIG.STATUS_URL)
        return nil
    end
end

local function setAPIData(action, value)
    -- Send data to the API endpoint to update the server state
    -- This is not used in the current client logic but can be implemented if needed
    local payload = {}
    payload[action] = value
    local jsonData = textutils.serializeJSON(payload)

    local response = http.post(CONFIG.API_URL, jsonData, {["Content-Type"] = "application/json"})
    if response then
        response.close()
    else
        print("Error: Unable to send data to API at " .. CONFIG.API_URL)
    end
end
-- ============================================
-- MAIN LOGIC
-- ============================================
local function main()
    local rotationSpeed = getAPIData("rotationSpeedController")
    local relayState = getAPIData("relayState")
    local powerReserves = getAPIData("powerReserves")
    local stressLevel = getAPIData("stressLevel")

    if CONFIG.CLIENT_TYPE == "RSC" then
        if rotationSpeed ~= nil then
            peripheralDevice0.setTargetSpeed(CONFIG.DIGITAL_ADAPTER_SIDE, rotationSpeed)
        end
    elseif CONFIG.CLIENT_TYPE == "RELAY" then
        if relayState ~= nil then
            -- Relay state can be "on","off",or "ERROR"
            if relayState == "on" then
                redstone.setOutput(CONFIG.PERIPHERAL_SIDE,true)
            elseif relayState == "off" then
                redstone.setOutput(CONFIG.PERIPHERAL_SIDE,false)
            elseif relayState == "off" and peripheralDevice0.isPowered() then
                print("Warning: Relay in ERROR state but is powered!")
                setAPIData("set-relay","ERROR")

            end
        end
    elseif CONFIG.CLIENT_TYPE == "STRESS" then
        if stressLevel ~= nil then
            print("Stress Level: " .. stressLevel)
        end
    elseif CONFIG.CLIENT_TYPE == "BATTERY" then
        if powerReserves ~= nil then
            print("Power Reserves: " .. powerReserves)
        end
    end

end

while true do
    main()
    sleep(1)
end