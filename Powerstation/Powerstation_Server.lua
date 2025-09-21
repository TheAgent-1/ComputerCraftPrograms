-- Powerstation Server (Fixed, Dashboard + API + Operator + Docs-Compliant)

-- ==== CONFIG ====
local API = "http://192.168.1.41:5005/powerstation"
local computerName = "Powerstation_Main"
local DASH_UPDATE_INTERVAL = 2 -- seconds

-- ==== Setup modem ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- ==== Client status table ====
local latestStatus = {}
local apiLocked = false
local feFlow = "on"

-- ==== Send status to API ====
local function sendStatusToAPI(client, data)
    local payload = { computerName = client, table.unpack(data) }
    local ok, res = pcall(http.post, API, textutils.serializeJSON(payload), { ["Content-Type"] = "application/json" })
    if ok and res then res.close() end
end

-- ==== Handle incoming client status ====
local function handleStatus(msg)
    latestStatus[msg.computerName] = msg.data
    sendStatusToAPI(msg.computerName, msg.data)
end

-- ==== Poll API for commands ====
local function pollAPI()
    while true do
        local ok, res = pcall(http.get, API .. "?type=newest_command")
        if ok and res then
            local text = res.readAll()
            res.close()
            local cmd = textutils.unserializeJSON(text)
            if cmd and cmd.computerName and cmd.action then
                rednet.broadcast(cmd, "powerstation")
                print("Sent API command:", cmd.action, "to", cmd.computerName)
            end
        end
        sleep(2)
    end
end

-- ==== Dashboard interface ====
local function drawDashboard()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Powerstation Control (Manual) ===")

    -- Energy
    local totalEnergy, totalCapacity = 0, 0
    for _, data in pairs(latestStatus) do
        if data.fe then totalEnergy = totalEnergy + data.fe end
        if data.capacity then totalCapacity = totalCapacity + data.capacity end
    end
    local chargePercent = totalCapacity > 0 and (totalEnergy / totalCapacity * 100) or 0

    -- Stress / Speed (adapter example)
    local adapter = latestStatus["Adapter_1"] or {}
    local stress, stressCap = adapter.stress or 0, adapter.stressCapacity or 0
    local stressPercent = stressCap > 0 and (stress / stressCap * 100) or 0
    local speed = adapter.speed or 0

    print(string.format("Energy: %d / %d FE", totalEnergy, totalCapacity))
    print(string.format("Charge: %.2f%%", chargePercent))
    print(string.format("Stress: %d / %d SU", stress, stressCap))
    print(string.format("Stress %%: %.2f%%", stressPercent))
    print(string.format("Speed: %d RPM", speed))
    print("FE Flow: " .. feFlow)
    print("API Control: " .. (apiLocked and "LOCKED" or "UNLOCKED"))
    print("\nCommands: speed <value>, stop, fe <on|off>, lock, unlock, status, exit")
end

-- ==== Operator input handler ====
local function operatorLoop()
    while true do
        drawDashboard()
        write("> ")
        local line = read()
        local args = {}
        for w in string.gmatch(line, "%S+") do table.insert(args, w) end

        if #args > 0 then
            local cmdType = args[1]:lower()
            if cmdType == "speed" and args[2] then
                local val = tonumber(args[2]) or 0
                rednet.broadcast({ computerName = "Adapter_1", type="command", action="set-speed", value=val }, "powerstation")

            elseif cmdType == "stop" then
                rednet.broadcast({ computerName = "Adapter_1", type="command", action="stop" }, "powerstation")

            elseif cmdType == "fe" and args[2] then
                local val = args[2]:lower()
                if val == "on" or val == "off" then feFlow = val end

            elseif cmdType == "lock" then
                apiLocked = true

            elseif cmdType == "unlock" then
                apiLocked = false

            elseif cmdType == "status" then
                -- dashboard redraw automatically shows latest status

            elseif cmdType == "exit" then
                print("Shutting down server...")
                return

            else
                print("Unknown command")
            end
        end

        sleep(0.1)
    end
end

-- ==== Status listener loop ====
local function statusLoop()
    while true do
        local sender, msg = rednet.receive("powerstation")
        if msg and msg.type == "status" and msg.computerName then
            handleStatus(msg)
        end
    end
end

-- ==== Dashboard updater loop ====
local function dashboardLoop()
    while true do
        drawDashboard()
        sleep(DASH_UPDATE_INTERVAL)
    end
end

-- ==== Run loops in parallel ====
parallel.waitForAny(statusLoop, operatorLoop, pollAPI, dashboardLoop)
