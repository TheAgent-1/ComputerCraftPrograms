-- PowerStation Battery Worker for CC:Tweaked
-- Read-only sensor worker
--
-- This worker:
--  - Reads energy stored in up to 3 battery boxes
--  - Aggregates their total FE locally
--  - Reports the value to the Powerstation API
--  - Identifies itself via a sensor ID
--
-- This worker does NOT receive commands.
-- It is a pure telemetry source.

local CONFIG = {
    SENSOR_ID = "1", -- Unique sensor ID (string or number, e.g. "1", "2", "3")
    API_URL = "http://192.168.1.40:5005/powerstation/api/battery",

    -- Battery box sides (set to nil if unused)
    BATTERY_0 = "back",
    BATTERY_1 = "right",
    BATTERY_2 = "left",

    REPORT_INTERVAL = 5 -- seconds between reports
}

-- ============================================
-- PERIPHERAL SETUP
-- ============================================

local batteries = {}

local function tryWrap(side)
    if side then
        local p = peripheral.wrap(side)
        if p and p.getEnergyStored then
            return p
        end
    end
    return nil
end

batteries[1] = tryWrap(CONFIG.BATTERY_0)
batteries[2] = tryWrap(CONFIG.BATTERY_1)
batteries[3] = tryWrap(CONFIG.BATTERY_2)

-- Validate at least one battery exists
if not batteries[1] and not batteries[2] and not batteries[3] then
    error("[FATAL] No valid battery peripherals found")
end

-- ============================================
-- UTILS
-- ============================================

-- Aggregate total energy across all connected batteries
local function getTotalEnergy()
    local total = 0

    for _, battery in pairs(batteries) do
        if battery then
            local ok, value = pcall(battery.getEnergyStored)
            if ok and type(value) == "number" then
                total = total + value
            end
        end
    end

    return total
end

-- Send battery reading to the API
local function reportBattery(totalEnergy)
    local payload = textutils.serializeJSON({
        sensor = CONFIG.SENSOR_ID,
        battery = totalEnergy
    })

    local response = http.post(
        CONFIG.API_URL,
        payload,
        { ["Content-Type"] = "application/json" }
    )

    if response then
        response.close()
        return true
    end

    print("[WARN] Failed to report battery data to API")
    return false
end

-- ============================================
-- MAIN LOOP
-- ============================================

print("[INFO] Battery worker started")
print("[INFO] Sensor ID:", CONFIG.SENSOR_ID)

while true do
    local totalEnergy = getTotalEnergy()
    reportBattery(totalEnergy)
    sleep(CONFIG.POLL_INTERVAL)
end
