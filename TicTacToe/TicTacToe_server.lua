-- Server.lua
-- Simple Tic-Tac-Toe Server

-- SETTINGS
local verbose = true -- Set to false to silence debug prints

-- UTILS
local function log(message)
    if verbose then
        print("[DEBUG] " .. message)
    end
end

-- MODEM SETUP
local modem = peripheral.find("modem", function(_, m) return m.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
    log("Wireless modem found and rednet opened.")
else
    print("No wireless modem found! Cannot continue.")
    return
end

-- GAME SETUP
local gameID = tostring(math.random(1000, 9999)) -- 4-digit random game ID
local players = {} -- will store player ids
local gameState = {
    board = {" ", " ", " ", " ", " ", " ", " ", " ", " "},
    currentTurn = nil
}

print("Hosting a new Tic-Tac-Toe game!")
print("Game ID: " .. gameID)
print("Waiting for players to join...")

-- MAIN SERVER LOOP
while true do
    local senderID, message, protocol = rednet.receive()
    log("Received message: " .. tostring(message) .. " from ID: " .. tostring(senderID))

    if type(message) == "table" and message.type == "join_request" and message.gameID == gameID then
        if #players < 2 then
            table.insert(players, senderID)
            rednet.send(senderID, {type = "join_accept", playerNum = #players, gameID = gameID})
            log("Accepted player " .. senderID .. " as Player " .. #players)
            print("Player " .. #players .. " joined! (Computer ID: " .. senderID .. ")")
        else
            rednet.send(senderID, {type = "join_full", gameID = gameID})
            log("Rejected player " .. senderID .. " (game full)")
        end
    end

    -- When two players have joined
    if #players == 2 and not gameState.currentTurn then
        gameState.currentTurn = players[1] -- Player 1 starts
        print("Both players have joined! Starting game...")
        for _, pid in ipairs(players) do
            rednet.send(pid, {type = "start_game", gameID = gameID, yourID = pid})
        end
    end

    -- TODO: Later - handle moves, win checking, etc.
end
