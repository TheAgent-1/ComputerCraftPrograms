-- Powerstation Server
-- Displays live dashboard, forwards API & operator commands to clients

-- ==== CONFIG ====
local API = "http://192.168.1.41:5005/powerstation"
local SERVER_PROTOCOL = "powerstation"
local DASH_UPDATE_INTERVAL = 2 -- seconds

-- ==== Setup modem ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- ==== Status storage ====
local latestStatus = {} -- keyed by computerName
local apiLocked = false

-- ==== Send status to API ====
local function sendStatusToAPI(client, data)
    local payload = { computerName = client, data = data }
    local ok, res = pcall(http.post, API, textutils.serializeJSON(payload), { ["Content-Type"] = "application/json" })
    if ok and res then res.close() end
end

-- ==== Handle incoming client status ====
local function handleStatus(msg)
    if msg.computerName and msg.type == "status" then
        latestStatus[msg.computerName] = msg.data
        sendStatusToAPI(msg.computerName, msg.data)
    end
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
                rednet.broadcast(cmd, SERVER_PROTOCOL)
                print("Sent API command:", cmd.action, "to", cmd.computerName)
            end
        end
        sleep(2)
    end
end

-- ==== Draw dashboard ====
local function drawDashboard()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Powerstation Control (Manual) ===")

    if next(latestStatus) == nil then
        print("No client data yet...")
        return
    end

    for client, data in pairs(latestStatus) do
        print("\n-- Client: " .. client .. " --")
        -- Motor info
        if data.speed then
            print("Motor Speed: " .. data.speed .. " RPM")
            print("Motor Stress: " .. (data.stress or 0) .. " SU")
            print("Energy Consumed: " .. (data.energyConsumption or 0) .. " FE/t")
        end
        -- Accumulator info
        if data.fe then
            print("Energy: " .. data.fe .. " / " .. (data.capacity or 0) .. " FE")
            local percent = (data.fe / (data.capacity or 1)) * 100
            print(string.format("Charge: %.2f%%", percent))
        end
        -- Redstone relay
        if data.feFlow then
            print("FE Flow: " .. data.feFlow)
            print("Throughput: " .. (data.throughput or 0) .. " FE/t")
        end
        -- Digital adapter
        if data.adapter then
            for k, v in pairs(data.adapter) do
                print(k .. ": " .. v)
            end
            if data.adapter.topSpeed then
                print("Adapter Top Speed: " .. data.adapter.topSpeed)
            end
        end
    end

    print("\nAPI Control: " .. (apiLocked and "LOCKED" or "UNLOCKED"))
    print("Commands: speed <value> <target>, stop <target>, fe <on|off> <target>, lock, unlock, status, exit")
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
            if cmdType == "speed" and args[2] and args[3] then
                local val = tonumber(args[2]) or 0
                local target = args[3]
                rednet.broadcast({ computerName = target, type="command", action="set-speed", value=val }, SERVER_PROTOCOL)

            elseif cmdType == "stop" and args[2] then
                local target = args[2]
                rednet.broadcast({ computerName = target, type="command", action="stop" }, SERVER_PROTOCOL)

            elseif cmdType == "fe" and args[2] and args[3] then
                local val = args[2]:lower()
                local target = args[3]
                if val == "on" or val == "off" then
                    rednet.broadcast({ computerName = target, type="command", action="fe", value=val }, SERVER_PROTOCOL)
                end

            elseif cmdType == "lock" then
                apiLocked = true

            elseif cmdType == "unlock" then
                apiLocked = false

            elseif cmdType == "status" then
                -- redraw occurs automatically

            elseif cmdType == "exit" then
                print("Shutting down server...")
                return

            else
                print("Unknown command or missing target")
            end
        end

        sleep(0.1)
    end
end

-- ==== Status listener loop ====
local function statusLoop()
    while true do
        local sender, msg = rednet.receive(SERVER_PROTOCOL)
        if msg then
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
