-- Powerstation Monitor and Control Script
-- NOW ON GITEA

--[[
    NOTES:
    - Numbers for motors run clockwise when set to positive values (1-256) and counterclockwise when set to negative values (-1 to -256)
      Anything set to 0 will stop the motor
    - term.clear() clears the terminal
    - term.setCursorPos(x, y) sets the cursor position to x, y
    - term.write("text") writes text to the terminal
]]


-- Powerstation Monitor & Control
-- Hybrid: Manual + API
-- With API Lock Option

-- ===== Peripherals =====
local Accumulator1 = peripheral.find("modular_accumulator_0")
local Accumulator2 = peripheral.find("modular_accumulator_1")
local DigitalAdapter = peripheral.find("digital_adapter")

-- Config
local stressSide = "bottom"
local speedSide  = "north"
local rscSide    = "top"

-- API base
local API = "http://192.168.1.41:5005/powerstation"

-- ===== Globals =====
local apiLocked = false

-- ===== Helper Functions =====
local function getTotalEnergy()
    local total = 0
    if Accumulator1 then total = total + Accumulator1.getEnergy() end
    if Accumulator2 then total = total + Accumulator2.getEnergy() end
    return total
end

local function getTotalCapacity()
    local cap = 0
    if Accumulator1 then cap = cap + Accumulator1.getCapacity() end
    if Accumulator2 then cap = cap + Accumulator2.getCapacity() end
    return cap
end

local function getTotalEnergyPercentage()
    local cap = getTotalCapacity()
    if cap > 0 then
        return (getTotalEnergy() / cap) * 100
    else
        return 0
    end
end

local function getStress()
    if DigitalAdapter then
        return DigitalAdapter.getKineticStress(stressSide), DigitalAdapter.getKineticCapacity(stressSide)
    end
    return 0, 0
end

local function getStressPercentage()
    local stress, cap = getStress()
    if cap > 0 then
        return (stress / cap) * 100
    else
        return 0
    end
end

local function getCurrentSpeed()
    if DigitalAdapter then
        return DigitalAdapter.getKineticSpeed(speedSide)
    end
    return 0
end

local function setOutputSpeed(speed)
    if DigitalAdapter and speed and speed >= -256 and speed <= 256 then
        DigitalAdapter.setTargetSpeed(rscSide, speed)
        print("Output speed set to " .. speed .. " RPM")
    end
end

-- ===== Status JSON =====
local function getStatus()
    local stress, stressCap = getStress()
    return {
        energy      = getTotalEnergy(),
        capacity    = getTotalCapacity(),
        charge_pct  = string.format("%.2f", getTotalEnergyPercentage()),
        stress      = stress,
        stress_cap  = stressCap,
        stress_pct  = string.format("%.2f", getStressPercentage()),
        speed       = getCurrentSpeed(),
        api_locked  = apiLocked
    }
end

local function pushStatus()
    local statusData = textutils.serializeJSON(getStatus())
    http.post(API .. "?status", statusData, { ["Content-Type"] = "application/json" })
end

-- ===== API Loop =====
local function apiLoop()
    local last_action, last_value = nil, nil
    while true do
        -- Only handle control if API is unlocked
        if not apiLocked then
            local response = http.get(API .. "?control")
            if response then
                local body = response.readAll()
                response.close()
                local data = textutils.unserializeJSON(body)

                if data and data.action then
                    local is_new = data.action ~= last_action or data.value ~= last_value
                    if is_new then
                        if data.action == "set-speed" and tonumber(data.value) then
                            setOutputSpeed(tonumber(data.value))
                        elseif data.action == "stop" then
                            setOutputSpeed(0)
                        end
                        last_action, last_value = data.action, data.value
                    end
                end
            end
        end

        -- Always push status, even if locked
        pushStatus()
        os.sleep(2)
    end
end

-- ===== Manual Loop =====
local function manualLoop()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("=== Powerstation Control ===")
        print("Energy: " .. getTotalEnergy() .. " / " .. getTotalCapacity() .. " FE")
        print("Charge: " .. string.format("%.2f%%", getTotalEnergyPercentage()))
        local stress, cap = getStress()
        print("Stress: " .. stress .. " / " .. cap .. " SU")
        print("Stress %: " .. string.format("%.2f%%", getStressPercentage()))
        print("Speed: " .. getCurrentSpeed() .. " RPM")
        print("API Control: " .. (apiLocked and "LOCKED" or "UNLOCKED"))

        print("\nCommands: speed <value>, stop, lock, unlock, exit")
        io.write("> ")
        local input = read()
        local cmd, arg = input:match("^(%S+)%s*(%S*)$")

        if cmd == "speed" and arg ~= "" then
            setOutputSpeed(tonumber(arg))
        elseif cmd == "stop" then
            setOutputSpeed(0)
        elseif cmd == "lock" then
            apiLocked = true
            print("API control locked out.")
        elseif cmd == "unlock" then
            apiLocked = false
            print("API control enabled.")
        elseif cmd == "exit" then
            print("Exiting manual control.")
            break
        end
        os.sleep(1)
    end
end

-- ===== Run Both =====
parallel.waitForAny(apiLoop, manualLoop)
