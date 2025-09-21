-- client.lua

-- Find a modem peripheral to use for rednet communication.
local modem = peripheral.find("modem")
if not modem then
    error("No modem found. Please ensure a modem is attached to the computer.", 0)
end

-- Find the other peripherals. You'll need to adjust the sides based on your setup.
-- For example, if your accumulator is on the "right" side, change "left" to "right".
local accumulator = peripheral.wrap("left")
local digitalAdapter = peripheral.wrap("right")
local redstoneRelay = peripheral.wrap("bottom")
local rsc = "top" -- Side of the Rotation Speed Controller on the Digital Adapter

-- Open the rednet channel.
rednet.open(modem)
local serverID = 0 -- We'll find the server's ID dynamically

-- Function to send status updates to the server.
local function sendStatus()
    while true do
        if serverID ~= 0 then
            -- Gather all the data from the peripherals.
            local statusData = {
                accumulator = {
                    energy = accumulator.getEnergy(),
                    capacity = accumulator.getCapacity(),
                    percent = accumulator.getPercent()
                },
                relay = {
                    powered = redstoneRelay.isPowered()
                },
                rsc = {
                    targetSpeed = digitalAdapter.getTargetSpeed(rsc)
                },
                stressometer = {
                    stress = digitalAdapter.getKineticStress("top"), -- Assumes Stressometer is on top
                    capacity = digitalAdapter.getKineticCapacity("top") -- Assumes Stressometer is on top
                }
            }

            -- Send the data to the server.
            rednet.send(serverID, { type = "status", data = statusData })
        end
        
        -- Wait for 5 seconds before sending the next update.
        sleep(5)
    end
end

-- Function to listen for commands from the server.
local function listenForCommands()
    while true do
        local id, message = rednet.receive(5) -- Wait up to 5 seconds for a message.
        if id and message then
            -- Check if the message is a command from our server.
            if id == serverID then
                if message.command == "setSpeed" then
                    -- Set the speed of the Rotational Speed Controller.
                    digitalAdapter.setTargetSpeed(rsc, message.value)
                    print("Set RSC speed to " .. message.value)
                elseif message.command == "setRelay" then
                    -- Turn the Redstone Relay on or off.
                    if message.value == true then
                        redstone.setOutput("bottom", true)
                        print("Turned Redstone Relay ON")
                    else
                        redstone.setOutput("bottom", false)
                        print("Turned Redstone Relay OFF")
                    end
                end
            end
        end
    end
end

-- Main program execution
print("Client starting up...")
print("My ID is " .. rednet.pullID())

-- Find the server ID. In this case, we'll just assume the server is the first message we receive.
print("Waiting for server to send a message...")
local id, message = rednet.receive()
serverID = id
print("Found server! ID: " .. serverID)

-- Run both functions in parallel.
parallel.waitForAll(sendStatus, listenForCommands)