-- Powerstation Client
device = "Accumulator"  -- Change this per client
statusInterval = 1      -- seconds between status broadcasts

local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if not modem then
    print("No wireless modem found!")
    return
end
rednet.open(peripheral.getName(modem))

-- Peripheral setup
if device == "Accumulator" then
    accumulator1 = peripheral.wrap("left")
    accumulator2 = peripheral.wrap("right")
elseif device == "Relay" then
    relaySide = "back"
elseif device == "Speedometer" then
    DigitalAdapter = peripheral.wrap("back")
elseif device == "Stressometer" then
    DigitalAdapter = peripheral.wrap("back")
elseif device == "RSC" then
    DigitalAdapter = peripheral.wrap("back")
end

-- ===== Functions =====
function Accumulator()
    while true do
        local feStored1 = accumulator1.getEnergy()
        local feStored2 = accumulator2.getEnergy()
        local feCapacity1 = accumulator1.getCapacity()
        local feCapacity2 = accumulator2.getCapacity()
        local totalStored = feStored1 + feStored2
        local totalCapacity = feCapacity1 + feCapacity2
        local percentage = math.floor((totalStored / totalCapacity) * 100)
        local payload = totalStored .. "/" .. totalCapacity .. "FE, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_accumulator")
        os.sleep(statusInterval)
    end
end

-- Relay: handles commands and periodically broadcasts status
function RelayClient()
    -- Parallel tasks: command listener & status reporter
    parallel.waitForAny(
        function()  -- Command listener
            while true do
                local id, data = rednet.receive("powerstation_relay")  -- block until command
                if data then
                    print("Relay command received: " .. data)
                    if data == "RELAY_ON" then
                        redstone.setOutput(relaySide, true)
                    elseif data == "RELAY_OFF" then
                        redstone.setOutput(relaySide, false)
                    end
                end
            end
        end,
        function()  -- Status reporter
            while true do
                local status = redstone.getOutput(relaySide) and "ON" or "OFF"
                rednet.broadcast(status, "powerstation_relay")
                os.sleep(statusInterval)
            end
        end
    )
end

-- RSC: handles commands and periodically broadcasts target speed
function RSCClient()
    parallel.waitForAny(
        function()  -- Command listener
            while true do
                local id, data = rednet.receive("powerstation_rsc")  -- block until command
                if data then
                    print("RSC command received: " .. data)
                    local command, value = data:match("^(%S+)%s*(%S*)$")
                    if command == "RSC_SET" and tonumber(value) then
                        DigitalAdapter.setTargetSpeed("top", tonumber(value))  -- adjust as needed
                    end
                end
            end
        end,
        function()  -- Status reporter
            while true do
                local currentSpeed = DigitalAdapter.getTargetSpeed("top")  -- adjust as needed
                rednet.broadcast(currentSpeed .. " RPM", "powerstation_rsc")
                os.sleep(statusInterval)
            end
        end
    )
end

function Speedometer()
    while true do
        local speed = DigitalAdapter.getKineticSpeed("east")  -- adjust direction
        rednet.broadcast(speed .. " RPM", "powerstation_speedometer")
        os.sleep(statusInterval)
    end
end

function Stressometer()
    while true do
        local stress = DigitalAdapter.getKineticStress("west")  -- adjust direction
        local maxStress = DigitalAdapter.getKineticCapacity("west")
        local percentage = math.floor((stress / maxStress) * 100)
        local payload = stress .. "/" .. maxStress .. " SU, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_stressometer")
        os.sleep(statusInterval)
    end
end

-- ===== Main =====
if device == "Accumulator" then
    Accumulator()
elseif device == "Relay" then
    RelayClient()
elseif device == "Speedometer" then
    Speedometer()
elseif device == "Stressometer" then
    Stressometer()
elseif device == "RSC" then
    RSCClient()
else
    print("Unknown device type specified.")
end
