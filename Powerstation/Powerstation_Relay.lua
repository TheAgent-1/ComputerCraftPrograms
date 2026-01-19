-- PowerStation Relay Client
-- Controls redstone output based on API target state

local CONFIG = {
    API_BASE = "http://192.168.1.40:5005/powerstation/api",
    RELAY_SIDE = "back",         -- Side for redstone output
    POLL_INTERVAL = 1,
    REPORT_INTERVAL = 5,
}

-- ============================================
-- STATE TRACKING
-- ============================================
local lastTargetVersion = -1
local lastReportedState = nil
local lastReportTime = 0

-- ============================================
-- API FUNCTIONS
-- ============================================
local function fetchTarget()
    local response = http.get(CONFIG.API_BASE .. "/target")
    if not response then
        return nil
    end
    
    local body = response.readAll()
    response.close()
    
    return textutils.unserializeJSON(body)
end

local function reportRelayState(isOn)
    local payload = textutils.serializeJSON({ current = isOn })
    local response = http.post(
        CONFIG.API_BASE .. "/relay",
        payload,
        { ["Content-Type"] = "application/json" }
    )
    
    if response then
        response.close()
        return true
    end
    return false
end

-- ============================================
-- MAIN LOOP
-- ============================================
print("=== Relay Client Started ===")
print("Relay side: " .. CONFIG.RELAY_SIDE)
print("")

while true do
    local now = os.clock()
    
    -- 1. Fetch target
    local target = fetchTarget()
    
    if target and target.version ~= lastTargetVersion then
        local relayTarget = target.target_relay
        
        if relayTarget ~= nil then
            local newState = (relayTarget == true)
            redstone.setOutput(CONFIG.RELAY_SIDE, newState)
            print("[CMD] Relay " .. (newState and "ON" or "OFF") .. " (v" .. target.version .. ")")
            lastTargetVersion = target.version
        end
    end
    
    -- 2. Report current state
    local currentState = redstone.getOutput(CONFIG.RELAY_SIDE)
    
    if currentState ~= lastReportedState or (now - lastReportTime) >= CONFIG.REPORT_INTERVAL then
        if reportRelayState(currentState) then
            lastReportedState = currentState
            lastReportTime = now
            print("[RPT] Relay state: " .. (currentState and "ON" or "OFF"))
        end
    end
    
    sleep(CONFIG.POLL_INTERVAL)
end