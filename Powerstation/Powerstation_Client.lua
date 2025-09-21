-- Powerstation Client
-- Sends live status to server, receives and executes commands
-- Docs-compliant

-- ==== CONFIG ====
local computerName = "Adapter_1"       -- change per client
local SERVER_PROTOCOL = "powerstation"
local STATUS_INTERVAL = 3              -- seconds
local FE_SIDE = "back"                  -- redstone side controlling FE flow

-- ==== Setup modem ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- ==== Peripheral Wrappers ====
local motor, accumulator, relay, adapter

-- Wrap electric motor
local ok, err = pcall(function() motor = peripheral.find("electric_motor") end)
if not ok then motor = nil end

-- Wrap accumulator
ok, err = pcall(function() accumulator = peripheral.find("modular_accumulator") end)
if not ok then accumulator = nil end

-- Wrap redstone relay
ok, err = pcall(function() relay = peripheral.find("redstone_relay") end)
if not ok then relay = nil end

-- Wrap digital adapter
ok, err = pcall(function() adapter = peripheral.find("digital_adapter") end)
if not ok then adapter = nil end

-- ==== Helper functions ====
local function getStatus()
    local status = {}

    -- Motor status
    if motor then
        status.speed = motor.getSpeed()
        status.stress = motor.getStressCapacity()
        status.energyConsumption = motor.getEnergyConsumption()
    end

    -- Accumulator status
    if accumulator then
        status.fe = accumulator.getEnergy()
        status.capacity = accumulator.getCapacity()
    end

    -- Redstone relay status
    if relay then
        status.feFlow = relay.isPowered() and "on" or "off"
        status.throughput = relay.getThroughput()
    end

    -- Digital adapter
    if adapter then
        -- For simplicity, check main sides
        local sides = {"top", "bottom", "north", "south", "east", "west"}
        status.adapter = {}
        for _, side in ipairs(sides) do
            -- Speedometers
            local ok, speed = pcall(adapter.getKineticSpeed, adapter, side)
            if ok then status.adapter[side.."_speed"] = speed end
            -- Stressometers
            ok, stress = pcall(adapter.getKineticStress, adapter, side)
            if ok then status.adapter[side.."_stress"] = stress end
        end
        status.adapter.topSpeed = adapter.getKineticTopSpeed()
    end

    return status
end

-- ==== Send status to server ====
local function sendStatus()
    local msg = {
        computerName = computerName,
        type = "status",
        data = getStatus()
    }
    rednet.broadcast(msg, SERVER_PROTOCOL)
end

-- ==== Apply commands ====
local function handleCommand(cmd)
    if cmd.computerName ~= computerName then return end
    if not cmd.action then return end

    if cmd.action == "set-speed" and motor and cmd.value then
        motor.setSpeed(tonumber(cmd.value) or 0)
    elseif cmd.action == "stop" and motor then
        motor.stop()
    elseif cmd.action == "fe" and relay and cmd.value then
        local val = tostring(cmd.value):lower()
        if val == "on" then
            redstone.setOutput(FE_SIDE, true)
        elseif val == "off" then
            redstone.setOutput(FE_SIDE, false)
        end
    elseif cmd.action == "display" and adapter and cmd.value then
        adapter.clear()
        adapter.print(tostring(cmd.value))
    end
end

-- ==== Status loop ====
local function statusLoop()
    while true do
        sendStatus()
        sleep(STATUS_INTERVAL)
    end
end

-- ==== Command listener loop ====
local function commandLoop()
    while true do
        local sender, msg = rednet.receive(SERVER_PROTOCOL)
        if msg then handleCommand(msg) end
    end
end

-- ==== Run loops in parallel ====
parallel.waitForAny(statusLoop, commandLoop)
