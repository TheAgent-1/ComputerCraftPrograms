-- PowerStation Client Script for CC:Tweaked
-- Handles receiving commands from the API and executing them on the local power station
-- This script is to be run on the client machine connected to the power station peripherals
-- These peripherals need to be connected via digital adapter:
-- RSC (Rotation Speed Controller)
-- RELAY
-- STRESS
--
-- This client is a "worker node":
--  - It polls desired state from the API
--  - Applies changes ONLY when commands change
--  - Does NOT make decisions itself

local CONFIG = {
    CLIENT_TYPE = "RSC", -- Options: "RSC", "RELAY", "BATTERY", "STRESS"
    PERIPHERAL_SIDE = "back", -- Side where the peripheral or digital adapter is connected
    DIGITAL_ADAPTER_SIDE = "back", -- Adapter-side connection (RSC / STRESS only)
    BATTERY_COUNT = 1, -- Only needed for BATTERY type
    API_URL = "http://192.168.1.40:5005/powerstation/api",
    STATUS_URL = "http://192.168.1.40:5005/powerstation/api/status"
}

-- ============================================
-- PERIPHERAL SETUP
-- ============================================
local peripheralDevice0 = nil
local peripheralDevice1 = nil
local peripheralDevice2 = nil

if CONFIG.CLIENT_TYPE == "RSC" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)

elseif CONFIG.CLIENT_TYPE == "RELAY" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)

elseif CONFIG.CLIENT_TYPE == "STRESS" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)

elseif CONFIG.CLIENT_TYPE == "BATTERY" then
    peripheralDevice0 = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)
    if CONFIG.BATTERY_COUNT >= 2 then
        peripheralDevice1 = peripheral.wrap("right")
    end
    if CONFIG.BATTERY_COUNT >= 3 then
        peripheralDevice2 = peripheral.wrap("left")
    end
end

-- ============================================
-- API UTILS
-- ============================================

-- Fetch full powerstation state from the API
local function fetchState()
    local response = http.get(CONFIG.STATUS_URL)
    if not response then
        print("[ERROR] Cannot reach Powerstation API")
        return nil
    end

    local body = response.readAll()
    response.close()

    return textutils.unserializeJSON(body)
end

-- Send a command back to the API (same protocol as server CLI / web UI)
local function sendCommand(action, value)
    local payload = textutils.serializeJSON({
        action = action,
        value = value
    })

    local response = http.post(
        CONFIG.API_URL,
        payload,
        { ["Content-Type"] = "application/json" }
    )

    if response then response.close() end
end

-- ============================================
-- COMMAND TRACKING
-- ============================================

-- Prevents re-applying the same command every poll
local lastCommandId = -1

-- ============================================
-- MAIN LOGIC
-- ============================================

local function applyState(state)
    -- RSC WORKER
    if CONFIG.CLIENT_TYPE == "RSC" then
        if state.rotationSpeedController ~= nil then
            peripheralDevice0.setTargetSpeed(
                CONFIG.DIGITAL_ADAPTER_SIDE,
                state.rotationSpeedController
            )
            print("RSC set to", state.rotationSpeedController)
        end

    -- RELAY WORKER
    elseif CONFIG.CLIENT_TYPE == "RELAY" then
        if state.relayState == "on" then
            redstone.setOutput(CONFIG.PERIPHERAL_SIDE, true)
            print("Relay set to ON")

        elseif state.relayState == "off" then
            redstone.setOutput(CONFIG.PERIPHERAL_SIDE, false)
            print("Relay set to OFF")

            -- Detect relay desync / fault condition
            if peripheralDevice0.isPowered() then
                print("[WARN] Relay reports OFF but is powered")
                sendCommand("set-relay", "ERROR")
            end
        end

    -- STRESS WORKER (read-only)
    elseif CONFIG.CLIENT_TYPE == "STRESS" then
        if state.stressLevel ~= nil then
            print("Stress Level:", state.stressLevel)
        end

    -- BATTERY WORKER (read-only)
    elseif CONFIG.CLIENT_TYPE == "BATTERY" then
        if state.powerReserves ~= nil then
            print("Power Reserves:", state.powerReserves, "FE")
        end
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================

while true do
    local state = fetchState()

    if state and state.command_id ~= nil then
        -- Only act when a new command is issued
        if state.command_id ~= lastCommandId then
            applyState(state)
            lastCommandId = state.command_id
        end
    end

    sleep(1)
end
