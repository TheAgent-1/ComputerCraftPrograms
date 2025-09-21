-- Client
device = "Accumulator"
sleep = 1  

-- Open wireless modem
local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found!")
    return
end

-- Wrap peripherals
if device == "Accumulator" then
    accumulator1 = peripheral.wrap("left")
    accumulator2 = peripheral.wrap("right")
elseif device == "Relay" then
    -- Relay uses redstone output only
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
        os.sleep(sleep)
    end
end

function Relay()
    while true do
        local event, senderId, message, protocol = os.pullEvent("rednet_message")
        if protocol == "powerstation_relay" then
            print("Relay command received: " .. message)
            if message == "RELAY_ON" then
                redstone.setOutput("back", true)
            elseif message == "RELAY_OFF" then
                redstone.setOutput("back", false)
            end
            -- Broadcast updated status back
            local status = redstone.getOutput("back") and "ON" or "OFF"
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
        local event, senderId, message, protocol = os.pullEvent("rednet_message")
        if protocol == "powerstation_rsc" then
            print("RSC command received: " .. message)
            local cmd, value = message:match("^(%S+)%s*(%S*)$")
            if cmd == "RSC_SET" and tonumber(value) then
                DigitalAdapter.setTargetSpeed("top", tonumber(value))
            end
        end
        -- Always report current target speed
        local currentSpeed = DigitalAdapter.getTargetSpeed("top")
        rednet.broadcast(currentSpeed .. " RPM", "powerstation_rsc")
        os.sleep(sleep)
    end
end

-- ===== Main =====
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
        print("Unknown device type.")
    end
end

main()
