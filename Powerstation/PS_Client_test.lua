-- Powerstation Client v2.0
-- NOW WITH DEVICE IDs!

-- ===== CONFIGURATION =====
device = "Speedometer"  -- Accumulator, Relay, Speedometer, Stressometer, RSC
deviceID = "SER_1"      -- Unique identifier (e.g., SER_1, SER_2, ACC_Main)
statusInterval = 1      -- seconds between status broadcasts

-- ===== SETUP =====
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
    adapterSide = "east"  -- Direction of the speedometer on the adapter
elseif device == "Stressometer" then
    DigitalAdapter = peripheral.wrap("back")
    adapterSide = "west"  -- Direction of the stressometer
elseif device == "RSC" then
    DigitalAdapter = peripheral.wrap("back")
    adapterSide = "top"  -- Direction of the RSC
end

-- ===== FUNCTIONS =====
function Accumulator()
    while true do
        local feStored1 = accumulator1.getEnergy()
        local feStored2 = accumulator2.getEnergy()
        local feCapacity1 = accumulator1.getCapacity()
        local feCapacity2 = accumulator2.getCapacity()
        local totalStored = feStored1 + feStored2
        local totalCapacity = feCapacity1 + feCapacity2
        local percentage = math.floor((totalStored / totalCapacity) * 100)
        local payload = deviceID .. ": " .. totalStored .. "/" .. totalCapacity .. "FE, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_accumulator")
        os.sleep(statusInterval)
    end
end

function RelayClient()
    parallel.waitForAny(
        function()  -- Command listener
            while true do
                local id, data = rednet.receive("powerstation_relay")
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
                rednet.broadcast(deviceID .. ": " .. status, "powerstation_relay")
                os.sleep(statusInterval)
            end
        end
    )
end

function RSCClient()
    parallel.waitForAny(
        function()  -- Command listener
            while true do
                local id, data = rednet.receive("powerstation_rsc")
                if data then
                    print("RSC command received: " .. data)
                    local command, value = data:match("^(%S+)%s*(%S*)$")
                    if command == "RSC_SET" and tonumber(value) then
                        DigitalAdapter.setTargetSpeed(adapterSide, tonumber(value))
                    end
                end
            end
        end,
        function()  -- Status reporter
            while true do
                local currentSpeed = DigitalAdapter.getTargetSpeed(adapterSide)
                rednet.broadcast(deviceID .. ": " .. currentSpeed .. " RPM", "powerstation_rsc")
                os.sleep(statusInterval)
            end
        end
    )
end

function Speedometer()
    while true do
        local speed = DigitalAdapter.getKineticSpeed(adapterSide)
        rednet.broadcast(deviceID .. ": " .. speed .. " RPM", "powerstation_speedometer")
        os.sleep(statusInterval)
    end
end

function Stressometer()
    while true do
        local stress = DigitalAdapter.getKineticStress(adapterSide)
        local maxStress = DigitalAdapter.getKineticCapacity(adapterSide)
        local percentage = math.floor((stress / maxStress) * 100)
        local payload = deviceID .. ": " .. stress .. "/" .. maxStress .. " SU, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_stressometer")
        os.sleep(statusInterval)
    end
end

-- ===== MAIN =====
print("Starting " .. device .. " client (" .. deviceID .. ")")

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