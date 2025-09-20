-- Powerstation Generic Client
-- Fully compliant with Create C&A peripheral docs

-- ==== CONFIG ====
local computerName = "Client_1" -- Change per machine

-- ==== Setup modem ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- ==== Detect peripherals ====
local peripherals = {}
for _, name in ipairs(peripheral.getNames()) do
    local pType = peripheral.getType(name)
    if pType == "modular_accumulator"
       or pType == "redstone_relay"
       or pType == "digital_adapter" then
        peripherals[pType] = peripheral.wrap(name)
    end
end

if next(peripherals) == nil then
    error("No supported peripherals found!")
end

-- ==== Status builder (docs-compliant) ====
local function getStatus()
    local status = { computerName = computerName, type = "status", data = {} }

    -- Accumulator
    if peripherals["modular_accumulator"] then
        local bat = peripherals["modular_accumulator"]
        status.data.fe = bat.getEnergy() or 0
        status.data.capacity = bat.getCapacity() or 0
        status.data.percent = bat.getPercent() or 0
    end

    -- Redstone Relay
    if peripherals["redstone_relay"] then
        local relay = peripherals["redstone_relay"]
        status.data.state = relay.isPowered() and "on" or "off"
        status.data.throughput = relay.getThroughput() or 0
    end

    -- Digital Adapter
    if peripherals["digital_adapter"] then
        local da = peripherals["digital_adapter"]

        -- Rotational Speed Controller (top side)
        if da.getTargetSpeed then
            status.data.targetSpeed = da.getTargetSpeed("top") or 0
        end

        -- Speedometer (north side)
        if da.getKineticSpeed then
            status.data.speed = da.getKineticSpeed("north") or 0
        end
        if da.getKineticTopSpeed then
            status.data.topSpeed = da.getKineticTopSpeed() or 0
        end

        -- Stressometer (bottom side)
        if da.getKineticStress then
            status.data.stress = da.getKineticStress("bottom") or 0
        end
        if da.getKineticCapacity then
            status.data.stressCapacity = da.getKineticCapacity("bottom") or 0
        end
    end

    return status
end

-- ==== Command handler (docs-compliant) ====
local function handleCommand(msg)
    if not msg or msg.type ~= "command" then return end
    local action, value = msg.action, msg.value

    -- Redstone Relay commands
    if peripherals["redstone_relay"] then
        local relay = peripherals["redstone_relay"]
        if action == "on" then relay.setState(true)
        elseif action == "off" then relay.setState(false) end
    end

    -- Rotational Speed Controller
    if peripherals["digital_adapter"] then
        local da = peripherals["digital_adapter"]
        if action == "set-speed" then
            da.setTargetSpeed("top", tonumber(value) or 0)
        elseif action == "stop" then
            da.setTargetSpeed("top", 0)
        elseif action == "display" then
            da.print(tostring(value) or "")
        end
    end
end

-- ==== Loops ====
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
        if msg and msg.computerName == computerName then
            handleCommand(msg)
        end
    end
end

-- Run both loops in parallel
parallel.waitForAny(statusLoop, commandLoop)
