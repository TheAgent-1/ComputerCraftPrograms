-- Client Code (TicTacToe Client)

local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
    print("Wireless modem connected and Rednet communication opened.")
else
    print("No wireless modem found. Exiting client.")
    return
end

local function printBoard(board)
    for i = 1, 3 do
        print(board[i][1] .. " | " .. board[i][2] .. " | " .. board[i][3])
        if i < 3 then
            print("--------")
        end
    end
end

local function getMove()
    print("Enter your move (row col): ")
    local move = read()
    local row, col = move:match("^(%d+)%s*(%d+)$")
    return tonumber(row), tonumber(col)
end

local function gameLoop(gameID)
    while true do
        local senderID, message = rednet.receive("ttt")
        if message.game_id == gameID then
            if message.type == "game_update" then
                -- Display the board
                printBoard(message.board)
                print("It's Player " .. (message.turn % 2 == 1 and "X's" or "O's") .. " turn.")

                -- If it's the player's turn, get their move
                if message.turn % 2 == 1 then
                    local row, col = getMove()
                    rednet.send(0, { type = "make_move", game_id = gameID, move = {row, col} }, "ttt")
                end
            elseif message.type == "game_over" then
                print("Game over! Winner: " .. message.winner)
                break
            end
        end
    end
end

local function startGame()
    -- Ask the user whether they want to start or join a game
    print("Would you like to start a new game (type 'start') or join an existing one (type 'join')?")
    local action = read()

    if action == "start" then
        -- Starting a new game
        local gameID = math.random(1000, 9999)  -- Generate a unique game ID
        rednet.send(0, { type = "start_game", game_id = gameID }, "ttt")
        print("Started a new game! Game ID: " .. gameID)

        -- Wait for the second player to join
        local senderID, message = rednet.receive("ttt")
        if message.type == "waiting_for_player" then
            print("Waiting for second player...")
        end

        -- Once both players are in the game, start the game loop
        gameLoop(gameID)
        
    elseif action == "join" then
        -- Joining an existing game
        print("Enter the Game ID to join: ")
        local gameID = tonumber(read())

        -- Send join request to the server
        rednet.send(0, { type = "join_game", game_id = gameID }, "ttt")

        -- Wait for the server response (confirmation or error)
        local senderID, message = rednet.receive("ttt", 10)  -- Timeout after 10 seconds
        if senderID then
            if message.type == "error" then
                print("Error: " .. message.message)
                return
            elseif message.type == "game_joined" then
                print("Successfully joined game ID: " .. message.game_id)
                -- Proceed with the game loop
                gameLoop(message.game_id)
            end
        else
            print("No response from server. The game may not exist or is unavailable.")
        end
    else
        print("Invalid option! Please type 'start' or 'join'.")
    end
end

-- Main function to start the client
startGame()
