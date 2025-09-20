-- Powerstation Monitor and Control System (Client)
-- NOW ON GITEA

--[[ 
    NOTES:
    - Generic client for modular_accumulator, redstone_relay, and digital_adapter peripherals
    - Sends status updates to the server and listens for commands

]]

-- ==== CONFIG ====
local computerName = "Client_1" -- Change per machine

-- ==== Setup ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- Detect attached peripherals
local peripherals = {}
for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    if pType == "modular_accumulator"
    or pType == "redstone_relay"
    or pType == "digital_adapter" then
        peripherals[pType] = name
    end
end

if next(peripherals) == nil then
    error("No supported peripherals found!")
end

-- ==== Helper: build status ====
local function getStatus()
    local status = { computerName = computerName, type = "status", data = {} }

    -- Battery
    if peripherals["modular_accumulator"] then
        local bat = peripheral.wrap(peripherals["modular_accumulator"])
        status.data.fe = bat.getEnergy() or 0
        status.data.capacity = bat.getEnergyCapacity() or 0
    end

    -- Relay
    if peripherals["redstone_relay"] then
        local relay = peripheral.wrap(peripherals["redstone_relay"])
        status.data.state = relay.getState() and "on" or "off"
    end

    -- Adapter devices
    if peripherals["digital_adapter"] then
        local adapter = peripheral.wrap(peripherals["digital_adapter"])
        -- Stressometer
        if adapter.hasModule("stressometer") then
            status.data.stress = adapter.getStress()
        end
        -- Speedometer
        if adapter.hasModule("speedometer") then
            status.data.speed = adapter.getSpeed()
        end
    end

    return status
end

-- ==== Helper: apply command ====
local function handleCommand(msg)
    if not msg or msg.type ~= "command" then return end
    local action, value = msg.action, msg.value

    -- Relay control
    if peripherals["redstone_relay"] then
        local relay = peripheral.wrap(peripherals["redstone_relay"])
        if action == "on" then
            relay.setState(true)
        elseif action == "off" then
            relay.setState(false)
        end
    end

    -- Speed controller (via adapter)
    if peripherals["digital_adapter"] then
        local adapter = peripheral.wrap(peripherals["digital_adapter"])
        if action == "set-speed" then
            adapter.setTargetSpeed(value or 0)
        elseif action == "stop" then
            adapter.setTargetSpeed(0)
        end
    end

    -- Display link
    if peripherals["digital_adapter"] and action == "display" then
        local adapter = peripheral.wrap(peripherals["digital_adapter"])
        adapter.setText(value or "")
    end
end

-- ==== Parallel loops ====
local function statusLoop()
    while true do
        local status = getStatus()
        rednet.broadcast(status, "powerstation")
        sleep(3)
    end
end

local function commandLoop()
    while true do
        local sender, msg = rednet.receive("powerstation")
        if msg and msg.computerName == computerName and msg.type == "command" then
            handleCommand(msg)
        end
    end
end

-- Run both loops together
parallel.waitForAny(statusLoop, commandLoop)
