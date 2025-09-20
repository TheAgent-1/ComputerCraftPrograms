-- Powerstation Monitor and Control System (Server)
-- NOW ON GITEA

--[[ 
    NOTES:
    - This program is designed to run on a computer connected to many computer peripherals
    - Recives status updates from computer peripherals and can send control commands to them
    - Uses rednet for communication (requires wireless modem)
    - Collects client status, forwards to Flask API, and sends commands back
    - Includes shorthand commands for easier operator use

]]

-- ==== CONFIG ====
local API = "http://192.168.1.41:5005/powerstation"
local computerName = "Powerstation_Main"

-- ==== Setup ====
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

local latestStatus = {}

-- ==== Shorthand commands ====
local shorthands = {
    ["battery"] = { target = "Battery_1", action = "status-only" },  -- just info
    ["relay-on"] = { target = "Relay_1", action = "on" },
    ["relay-off"] = { target = "Relay_1", action = "off" },
    ["adapter-stop"] = { target = "Adapter_1", action = "stop" },
    ["adapter-speed"] = { target = "Adapter_1", action = "set-speed" },
    ["adapter-display"] = { target = "Adapter_1", action = "display" }
}

-- ==== Networking helpers ====
local function sendToAPI(data)
    local ok, err = http.post(API, textutils.serializeJSON(data), { ["Content-Type"] = "application/json" })
    if not ok then
        print("API POST failed:", err or "unknown error")
    else
        ok.close()
    end
end

local function handleStatus(msg)
    latestStatus[msg.computerName] = msg.data
    -- Print update
    term.clear()
    term.setCursorPos(1, 1)
    print("=== Powerstation Status ===")
    for name, data in pairs(latestStatus) do
        print(("[%s] %s"):format(name, textutils.serialize(data)))
    end
    -- Forward to API
    sendToAPI({ computerName = msg.computerName, table.unpack(msg.data) })
end

local function statusLoop()
    while true do
        local sender, msg = rednet.receive("powerstation")
        if msg and msg.type == "status" and msg.computerName then
            handleStatus(msg)
        end
    end
end

-- ==== Operator command loop ====
local function operatorLoop()
    while true do
        write("> ")
        local line = read()
        local args = {}
        for w in string.gmatch(line, "%S+") do table.insert(args, w) end

        -- Try shorthand first
        local shorthand = shorthands[line:lower()]
        if shorthand then
            local cmd = {
                computerName = shorthand.target,
                type = "command",
                action = shorthand.action,
                value = args[2] -- optional: speed value or display text
            }
            if shorthand.action ~= "status-only" then
                rednet.broadcast(cmd, "powerstation")
                print("Sent command:", shorthand.action, "to", shorthand.target)
            else
                print("Status-only command. Latest data for", shorthand.target, ":",
                      textutils.serialize(latestStatus[shorthand.target] or {}))
            end

        -- fallback to full send syntax
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

-- ==== Run both loops ====
parallel.waitForAny(statusLoop, operatorLoop)

