-- Powerstation Server
-- Docs-compliant, with operator input and API command polling

-- ==== CONFIG ====
local API = "http://192.168.1.41:5005/powerstation"
local computerName = "Powerstation_Main"

-- ==== Setup modem ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

-- ==== Client status table ====
local latestStatus = {}

-- ==== Shorthand commands ====
local shorthands = {
    ["battery"] = { target = "Battery_1", action = "status-only" },
    ["relay-on"] = { target = "Relay_1", action = "on" },
    ["relay-off"] = { target = "Relay_1", action = "off" },
    ["adapter-stop"] = { target = "Adapter_1", action = "stop" },
    ["adapter-speed"] = { target = "Adapter_1", action = "set-speed" },
    ["adapter-display"] = { target = "Adapter_1", action = "display" },
    ["adapter-speedstatus"] = { target = "Adapter_1", action = "status-speed" },
    ["adapter-stressstatus"] = { target = "Adapter_1", action = "status-stress" },
    ["adapter-topSpeed"] = { target = "Adapter_1", action = "status-topSpeed" }
}

-- ==== Send status to API ====
local function sendStatusToAPI(client, data)
    local payload = { computerName = client, table.unpack(data) }
    local ok, res = pcall(http.post, API, textutils.serializeJSON(payload), { ["Content-Type"] = "application/json" })
    if ok and res then res.close() end
end

-- ==== Handle incoming client status ====
local function handleStatus(msg)
    latestStatus[msg.computerName] = msg.data

    -- Print dashboard
    term.clear()
    term.setCursorPos(1,1)
    print("=== Powerstation Status ===")
    for name, data in pairs(latestStatus) do
        print(("[%s] %s"):format(name, textutils.serialize(data)))
    end

    -- Forward to API
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

-- ==== Operator command loop ====
local function operatorLoop()
    while true do
        write("> ")
        local line = read()
        local args = {}
        for w in string.gmatch(line, "%S+") do table.insert(args, w) end

        local shorthand = shorthands[line:lower()]
        if shorthand then
            if shorthand.action == "status-only" then
                print("Latest status for", shorthand.target, ":",
                      textutils.serialize(latestStatus[shorthand.target] or {}))
            elseif shorthand.action == "status-speed" then
                print("Current speed for Adapter_1:", latestStatus["Adapter_1"] and latestStatus["Adapter_1"].speed or "N/A")
            elseif shorthand.action == "status-stress" then
                print("Current stress for Adapter_1:", latestStatus["Adapter_1"] and latestStatus["Adapter_1"].stress or "N/A")
            elseif shorthand.action == "status-topSpeed" then
                print("Top speed for Adapter_1:", latestStatus["Adapter_1"] and latestStatus["Adapter_1"].topSpeed or "N/A")
            else
                local cmd = { computerName = shorthand.target, type = "command", action = shorthand.action, value = args[2] }
                rednet.broadcast(cmd, "powerstation")
                print("Sent command:", shorthand.action, "to", shorthand.target)
            end

        elseif args[1] == "send" and #args >= 3 then
            local target = args[2]
            local action = args[3]
            local value = args[4]
            local cmd = { computerName = target, type = "command", action = action, value = value }
            rednet.broadcast(cmd, "powerstation")
            print("Sent command to", target, ":", action, value or "")

        elseif args[1] == "exit" then
            print("Shutting down server...")
            return

        else
            print("Unknown command. Available shorthands:")
            for k,_ in pairs(shorthands) do print("  ", k) end
            print("Or use full syntax: send <client> <action> [value]")
        end
    end
end

-- ==== Status loop ====
local function statusLoop()
    while true do
        local sender, msg = rednet.receive("powerstation")
        if msg and msg.type == "status" and msg.computerName then
            handleStatus(msg)
        end
    end
end

-- ==== Run all loops in parallel ====
parallel.waitForAny(statusLoop, operatorLoop, pollAPI)
