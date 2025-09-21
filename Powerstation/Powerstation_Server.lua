-- server.lua

-- Find a modem peripheral to use for rednet communication.
local modem = peripheral.find("modem")
if not modem then
    error("No modem found. Please ensure a modem is attached to the computer.", 0)
end

-- Open the rednet channel.
rednet.open(peripheral.getName(modem))
print("Server started and rednet is open. Listening for clients...")

-- Table to store client data, using their ID as the key.
local clients = {}

-- Main loop to handle user input and rednet messages.
while true do
    -- Get a user command from the terminal.
    local command = read()

    -- Process the user command.
    local args = {}
    for arg in string.gmatch(command, "[^%s]+") do
        table.insert(args, arg)
    end
    
    local cmd = args[1]
    
    if cmd == "status" then
        -- Display a dashboard of all client statuses.
        term.clear()
        term.setCursorPos(1, 1)
        print("--- Client Status Dashboard ---")
        if next(clients) == nil then
            print("No clients connected yet.")
        else
            for id, data in pairs(clients) do
                print(string.format("Client ID: %d", id))
                print(string.format("  Accumulator Charge: %.2f%%", data.accumulator.percent))
                print(string.format("  Rotational Speed Controller Speed: %d RPM", data.rsc.targetSpeed))
                print(string.format("  Redstone Relay: %s", data.relay.powered and "ON" or "OFF"))
                print(string.format("  Kinetic Stress: %.2f / %.2f SU", data.stressometer.stress, data.stressometer.capacity))
                print("------------------------------")
            end
        end
        print("Enter a command (status, setSpeed <number>, relay <on/off>)...")
        
    elseif cmd == "setSpeed" then
        -- Send a command to all clients to change the RSC speed.
        local speed = tonumber(args[2])
        if speed and speed >= -256 and speed <= 256 then
            for id, _ in pairs(clients) do
                rednet.send(id, { command = "setSpeed", value = speed })
                print("Sent setSpeed command to client " .. id)
            end
        else
            print("Invalid speed. Please provide a number between -256 and 256.")
        end

    elseif cmd == "relay" then
        -- Send a command to all clients to toggle the Redstone Relay.
        local state = args[2]
        if state == "on" then
            for id, _ in pairs(clients) do
                rednet.send(id, { command = "setRelay", value = true })
                print("Sent relay ON command to client " .. id)
            end
        elseif state == "off" then
            for id, _ in pairs(clients) do
                rednet.send(id, { command = "setRelay", value = false })
                print("Sent relay OFF command to client " .. id)
            end
        else
            print("Invalid relay state. Use 'on' or 'off'.")
        end
    else
        print("Unknown command. Available commands: status, setSpeed <number>, relay <on/off>")
    end
    
    -- Check for incoming rednet messages from clients.
    local id, message = rednet.receive(5) -- Wait up to 5 seconds for a message.
    if id and message and message.type == "status" then
        -- Update the client's status in our table.
        clients[id] = message.data
    end
end