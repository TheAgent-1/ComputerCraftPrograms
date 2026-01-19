-- PowerStation RSC Client
-- Polls target state from API, applies to peripheral, reports actual state back

local CONFIG = {
    API_BASE = "http://192.168.1.40:5005/powerstation/api",
    PERIPHERAL_SIDE = "back",
    ADAPTER_DIRECTION = "back",  -- Direction RSC is connected to adapter
    POLL_INTERVAL = 1,           -- Seconds between polls
    REPORT_INTERVAL = 5,         -- Seconds between state reports
}

-- ============================================
-- PERIPHERAL SETUP
-- ============================================
local adapter = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)
if not adapter then
    error("[FATAL] No peripheral found on side: " .. CONFIG.PERIPHERAL_SIDE)
end

-- Verify it's a valid adapter with RSC methods
if not adapter.setTargetSpeed then
    error("[FATAL] Peripheral does not have setTargetSpeed method. Is this a Digital Adapter with RSC?")
end

-- ============================================
-- STATE TRACKING
-- ============================================
local lastTargetVersion = -1
local lastReportedSpeed = nil
local lastReportTime = 0

-- ============================================
-- API FUNCTIONS
-- ============================================
local function fetchTarget()
    local response = http.get(CONFIG.API_BASE .. "/target")
    if not response then
        print("[WARN] Cannot reach API")
        return nil
    end
    
    local body = response.readAll()
    response.close()
    
    local data = textutils.unserializeJSON(body)
    if not data then
        print("[ERROR] Failed to parse target response")
        return nil
    end
    
    return data
end

local function reportCurrentSpeed(speed)
    local payload = textutils.serializeJSON({ current = speed })
    local response = http.post(
        CONFIG.API_BASE .. "/rsc",
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
-- PERIPHERAL FUNCTIONS
-- ============================================
local function setRSCSpeed(speed)
    local success, err = pcall(function()
        adapter.setTargetSpeed(CONFIG.ADAPTER_DIRECTION, speed)
    end)
    
    if not success then
        print("[ERROR] Failed to set RSC speed: " .. tostring(err))
        return false
    end
    return true
end

local function getCurrentSpeed()
    local success, result = pcall(function()
        return adapter.getTargetSpeed(CONFIG.ADAPTER_DIRECTION)
    end)
    
    if success then
        return result
    end
    return nil
end

-- ============================================
-- MAIN LOOP
-- ============================================
print("=== RSC Client Started ===")
print("Polling: " .. CONFIG.API_BASE)
print("")

while true do
    local now = os.clock()
    
    -- 1. Fetch target state from API
    local target = fetchTarget()
    
    if target then
        -- 2. Check if target has changed (using version number)
        if target.version and target.version ~= lastTargetVersion then
            local newSpeed = target.target_rsc
            
            if newSpeed then
                print("[CMD] Setting RSC to " .. newSpeed .. " (v" .. target.version .. ")")
                
                if setRSCSpeed(newSpeed) then
                    lastTargetVersion = target.version
                end
            end
        end
    end
    
    -- 3. Report current speed periodically (or when changed)
    local currentSpeed = getCurrentSpeed()
    
    if currentSpeed then
        local shouldReport = false
        
        -- Report if value changed
        if currentSpeed ~= lastReportedSpeed then
            shouldReport = true
        end
        
        -- Or if enough time has passed (heartbeat)
        if (now - lastReportTime) >= CONFIG.REPORT_INTERVAL then
            shouldReport = true
        end
        
        if shouldReport then
            if reportCurrentSpeed(currentSpeed) then
                lastReportedSpeed = currentSpeed
                lastReportTime = now
                print("[RPT] Reported speed: " .. currentSpeed)
            end
        end
    end
    
    -- 4. CRITICAL: Yield to prevent "too long without yielding"
    sleep(CONFIG.POLL_INTERVAL)
end