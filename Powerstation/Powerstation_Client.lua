-- Client
device = "Accumulator"
sleep = 1  

local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found!")
    return
end

if device == "Accumulator" then
    accumulator1 = peripheral.wrap("left")
    accumulator2 = peripheral.wrap("right")
elseif device == "Relay" then
    -- No peripherals needed for relay control
elseif device == "Speedometer" then
    DigitalAdapter = peripheral.wrap("back")
elseif device == "Stressometer" then
    DigitalAdapter = peripheral.wrap("back")
elseif device == "RSC" then
    DigitalAdapter = peripheral.wrap("back")
end

-- ===== Functions =====
function Accumulator()  -- Get accumulator status
    while true do
        local feStored1 = accumulator1.getEnergy()
        local feStored2 = accumulator2.getEnergy()
        local feCapacity1 = accumulator1.getCapacity()
        local feCapacity2 = accumulator2.getCapacity()
        local totalStored = feStored1 + feStored2
        local totalCapacity = feCapacity1 + feCapacity2
        local percentage = math.floor((totalStored / totalCapacity) * 100)

        -- Output Example: "5000/10000FE, 50%"
        local payload = totalStored .. "/" .. totalCapacity .. "FE, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_accumulator")
        os.sleep(sleep)
    end
end

function Relay()  -- Control the relay: "on", "off", or nil to just get status
    while true do
        local id, data = rednet.receive("powerstation_relay", 0.1)
        if data then
            print("Relay command received: " .. data)
            if data == "RELAY_ON" then
                redstone.setOutput("back", true)
            elseif data == "RELAY_OFF" then
                redstone.setOutput("back", false)
            end
        else
            local status = redstone.getOutput("back")
            if status then status = "ON" else status = "OFF" end
            rednet.broadcast(status, "powerstation_relay")
        end
        os.sleep(sleep)
    end
end

function speedometer() -- Get current speed
    while true do
        local speed = DigitalAdapter.getKineticSpeed("east")  -- Adjust direction as needed
        rednet.broadcast(speed .. " RPM", "powerstation_speedometer")
        os.sleep(sleep)
    end
end

function stressometer() -- Get current stress
    while true do
        local stress = DigitalAdapter.getKineticStress("west")  -- Adjust direction as needed
        local maxStress = DigitalAdapter.getKineticCapacity("west")
        local percentage = math.floor((stress / maxStress) * 100)
        local payload = stress .. "/" .. maxStress .. " SU, " .. percentage .. "%"
        rednet.broadcast(payload, "powerstation_stressometer")
        os.sleep(sleep)
    end
end

function RSC()
    while true do
        local id, data = rednet.receive("powerstation_rsc", 0.1)
        if data then
            print("RSC command received: " .. data)
            local command, value = data:match("^(%S+)%s*(%S*)$")
            if command == "RSC_SET" and tonumber(value) then
                DigitalAdapter.setTargetSpeed("top", tonumber(value))  -- Adjust direction as needed
            end
        else
            local currentSpeed = DigitalAdapter.getTargetSpeed("top")  -- Adjust direction as needed
            rednet.broadcast(currentSpeed .. " RPM", "powerstation_rsc")
        end
        os.sleep(sleep)
    end
end

function main()
    if device == "Accumulator" then
        Accumulator()
    elseif device == "Relay" then
        Relay()
    elseif device == "Speedometer" then
        speedometer()
    elseif device == "Stressometer" then
        stressometer()
    elseif device == "RSC" then
        RSC()
    else
        print("Unknown device type specified.")
    end
end

        

main()