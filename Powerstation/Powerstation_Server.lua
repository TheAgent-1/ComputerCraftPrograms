-- Powerstation Control Server
-- NOW ON GITEA

-- Curently supported devices:
-- Accumulator (status) - powerstation_accumulator
-- Relay (on/off/status) - powerstation_relay
-- Speedometer (status) - powerstation_speedometer
-- Stressometer (status) - powerstation_stressometer
-- RSC (set <target_speed>/status) - powerstation_rsc

-- Server
local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found!")
    return
end


-- ===== Functions =====
function Accumulator()  -- Get accumulator status
    local id, data = rednet.receive("powerstation_accumulator", 3) -- returns energy level over capacity and percentage (e.g., "5000/10000FE, 50%")
    if data then 
        -- split data into two parts
        local energy, percentage = data:match("^(%d+/%d+FE),%s*(%d+%%)$")
        return energy
    else return "No data"
    end
end

function Relay(action)  -- Control the relay: "on", "off", or nil to just get status
    if action == "on" then
        rednet.broadcast("RELAY_ON", "powerstation_relay")
    elseif action == "off" then
        rednet.broadcast("RELAY_OFF", "powerstation_relay")
    else
        local id, data = rednet.receive("powerstation_relay", 3)
        if data then return data
        else return "No data"
        end
    end
end

function speedometer() -- Get current speed
    local id, data = rednet.receive("powerstation_speedometer", 3)
    if data then return data
    else return "No data"
    end
end

function stressometer() -- Get current stress
    local id, data = rednet.receive("powerstation_stressometer", 3)
    if data then return data
    else return "No data"
    end
end

function RSC(action)  -- Control the RSC: <target_speed>, or nil to get status
    if action then
        rednet.broadcast("RSC_SET " .. tostring(action), "powerstation_rsc")
    else
        local id, data = rednet.receive("powerstation_rsc", 3)
        if data then return data
        else return "No data"
        end
    end
end

function mainLoop()
    while true do
        -- Listen for commands
        term.clear()
        term.setCursorPos(1,1)
        print("=== Powerstation Control ===")
        write("User >")

        local input = read() -- Read user input
        local command, arg = input:match("^(%S+)%s*(.-)%s*$") -- Split command and argument
        if command == "status" then
            term.clear()
            term.setCursorPos(1,1)
            print("=== Powerstation Status ===")
            print("Energy Level: " .. Accumulator())
            print("Relay status: " .. Relay())
            print("Current Speed: " .. speedometer())
            print("Current Stress: " .. stressometer())
            print("RSC Speed: " .. RSC())

            print("Press Enter to continue...")
            read()
        elseif command == "relay" and (arg == "on" or arg == "off") then
            print("Relay: " .. Relay(arg))
            print("Press Enter to continue...")
            read()
        elseif command == "rsc" and tonumber(arg) then
            RSC(tonumber(arg))
            print("RSC Speed set to " .. RSC())
            print("Press Enter to continue...")
            read()
        elseif command == "lock" then
            print("Lockout API... (not implemented)")
            print("Press Enter to continue...")
            read()
        elseif command == "unlock" then
            print("Unlock API... (not implemented)")
            print("Press Enter to continue...")
            read()
        elseif command == "exit" then
            print("Exiting Powerstation Control.")
            break
        else
            print("Unknown command. Available commands: status, relay <on/off>, rsc <speed>, lock, unlock, exit")
            print("Press Enter to continue...")
            read()
        end
    end
end

        
mainLoop()