-- Server Code (TicTacToe Server)

local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
    print("Wireless modem connected and Rednet communication opened.")
else
    print("No wireless modem found. Exiting server.")
    return
end

local games = {}  -- Table to store game data

-- Example game data structure:
-- games[gameID] = { players = {player1, player2}, board = {}, turn = 1 }

local function printBoard(board)
    for i = 1, 3 do
        print(board[i][1] .. " | " .. board[i][2] .. " | " .. board[i][3])
        if i < 3 then
            print("--------")
        end
    end
end

local function handleGameRequests()
    while true do
        local senderID, message = rednet.receive("ttt")
        print("Server received message: ", message.type)  -- Debugging print

        if message.type == "join_game" then
            local gameID = message.game_id
            local game = games[gameID]

            if game then
                -- Add the player to the game
                table.insert(game.players, senderID)
                print("Player " .. senderID .. " joined game " .. gameID)

                -- Send success response
                rednet.send(senderID, { type = "game_joined", game_id = gameID })
            else
                -- If the game doesn't exist
                rednet.send(senderID, { type = "error", message = "Game ID not found." })
                print("Game ID not found: " .. gameID)
            end
        elseif message.type == "start_game" then
            local gameID = message.game_id
            local game = { players = { senderID }, board = {{ " ", " ", " " }, { " ", " ", " " }, { " ", " ", " " }}, turn = 1 }
            games[gameID] = game
            print("New game started with ID: " .. gameID)
            
            rednet.send(senderID, { type = "waiting_for_player" })
            print("Waiting for second player...")

        elseif message.type == "make_move" then
            local gameID = message.game_id
            local move = message.move
            local game = games[gameID]

            if game then
                local row, col = unpack(move)
                -- Update the board with the move
                if game.board[row][col] == " " then
                    local player = (game.turn % 2 == 1) and "X" or "O"
                    game.board[row][col] = player
                    game.turn = game.turn + 1

                    -- Check if the game is won or still ongoing
                    local winner = checkWinner(game.board)
                    if winner then
                        rednet.send(game.players[1], { type = "game_over", winner = winner })
                        rednet.send(game.players[2], { type = "game_over", winner = winner })
                        print("Game over! Winner: " .. winner)
                    else
                        -- Send updated board to both players
                        rednet.send(game.players[1], { type = "game_update", board = game.board, turn = game.turn })
                        rednet.send(game.players[2], { type = "game_update", board = game.board, turn = game.turn })
                    end
                else
                    print("Invalid move!")
                end
            end
        end
    end
end

-- Function to check if a player has won the game
local function checkWinner(board)
    -- Check rows
    for i = 1, 3 do
        if board[i][1] == board[i][2] and board[i][2] == board[i][3] and board[i][1] ~= " " then
            return board[i][1]
        end
    end

    -- Check columns
    for i = 1, 3 do
        if board[1][i] == board[2][i] and board[2][i] == board[3][i] and board[1][i] ~= " " then
            return board[1][i]
        end
    end

    -- Check diagonals
    if board[1][1] == board[2][2] and board[2][2] == board[3][3] and board[1][1] ~= " " then
        return board[1][1]
    end
    if board[1][3] == board[2][2] and board[2][2] == board[3][1] and board[1][3] ~= " " then
        return board[1][3]
    end

    return nil  -- No winner yet
end

-- Start the server
handleGameRequests()
