-- PowerStation Stress Monitor Client
-- Reports stress level from Stressometer to API (read-only)

local CONFIG = {
    API_BASE = "http://192.168.1.40:5005/powerstation/api",
    PERIPHERAL_SIDE = "back",
    REPORT_INTERVAL = 5,
}

local adapter = peripheral.wrap(CONFIG.PERIPHERAL_SIDE)
if not adapter then
    error("[FATAL] No peripheral on side: " .. CONFIG.PERIPHERAL_SIDE)
end

local lastReportedStress = nil

print("=== Stress Monitor Started ===")

while true do
    local stress = nil
    
    -- Try to read stress - method depends on your setup
    local success, result = pcall(function()
        -- For Create stressometer via digital adapter
        return adapter.getStress()
    end)
    
    if success and result then
        stress = result
    end
    
    if stress and stress ~= lastReportedStress then
        local payload = textutils.serializeJSON({ stress = stress })
        local response = http.post(
            CONFIG.API_BASE .. "/stress",
            payload,
            { ["Content-Type"] = "application/json" }
        )
        
        if response then
            response.close()
            print("[RPT] Stress: " .. stress .. " SU")
            lastReportedStress = stress
        end
    end
    
    sleep(CONFIG.REPORT_INTERVAL)
end