-- TTT Server
-- A Tic-Tac-Toe server using rednet for multiplayer
-- Project: TTT (Tic-Tac-Toe Transmission)
-- Author: Jacob + ChatGPT

-- Auto-open wireless modem
local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found! Please attach a wireless modem.")
    return
end

print("[TTT Server] Tic-Tac-Toe Server started.")
local games = {} -- { game_id = { players = {id1, id2}, board = {}, turn = 1 or 2, status = "waiting/playing/win/draw", winner = nil } }
local gameCounter = 0

-- Helper: Create an empty 3x3 board
local function createBoard()
    return {
        {" ", " ", " "},
        {" ", " ", " "},
        {" ", " ", " "}
    }
end

-- Helper: Check if a symbol wins
local function checkWin(board, symbol)
    for i = 1, 3 do
        -- Check rows
        if board[i][1] == symbol and board[i][2] == symbol and board[i][3] == symbol then
            return true
        end
        -- Check columns
        if board[1][i] == symbol and board[2][i] == symbol and board[3][i] == symbol then
            return true
        end
    end
    -- Check diagonals
    if board[1][1] == symbol and board[2][2] == symbol and board[3][3] == symbol then
        return true
    end
    if board[1][3] == symbol and board[2][2] == symbol and board[3][1] == symbol then
        return true
    end
    return false
end

-- Helper: Check if the board is full
local function checkDraw(board)
    for i = 1, 3 do
        for j = 1, 3 do
            if board[i][j] == " " then
                return false
            end
        end
    end
    return true
end

-- Helper: Send board updates to both players
local function broadcast(game)
    for _, playerID in ipairs(game.players) do
        rednet.send(playerID, {
            type = "game_update",
            board = game.board,
            turn = game.turn,
            status = game.status,
            winner = game.winner
        }, "ttt")
    end
end

-- Main server loop
while true do
    local senderID, message, protocol = rednet.receive("ttt")

    if type(message) == "table" then
        if message.type == "start_game" then
            -- New game request
            gameCounter = gameCounter + 1
            local gameID = tostring(gameCounter)

            games[gameID] = {
                players = {senderID},
                board = createBoard(),
                turn = 1,
                status = "waiting",
                winner = nil
            }

            rednet.send(senderID, { type = "waiting_for_player", game_id = gameID }, "ttt")
            print("[TTT Server] Player " .. senderID .. " started game " .. gameID)

        elseif message.type == "join_game" then
            -- Join an existing game
            local game = games[message.game_id]
            if game and #game.players == 1 then
                table.insert(game.players, senderID)
                game.status = "playing"

                broadcast(game)
                print("[TTT Server] Player " .. senderID .. " joined game " .. message.game_id)
            else
                rednet.send(senderID, { type = "error", message = "Cannot join this game." }, "ttt")
                print("[TTT Server] Player " .. senderID .. " failed to join game " .. (message.game_id or "nil"))
            end

        elseif message.type == "make_move" then
            -- Player made a move
            local game = games[message.game_id]
            if not game then
                rednet.send(senderID, { type = "error", message = "Game not found." }, "ttt")
            elseif game.status ~= "playing" then
                rednet.send(senderID, { type = "error", message = "Game not active." }, "ttt")
            elseif game.players[game.turn] ~= senderID then
                rednet.send(senderID, { type = "error", message = "Not your turn." }, "ttt")
            else
                local move = message.move
                if move and move.row >= 1 and move.row <= 3 and move.col >= 1 and move.col <= 3 then
                    if game.board[move.row][move.col] == " " then
                        local symbol = (game.turn == 1) and "X" or "O"
                        game.board[move.row][move.col] = symbol

                        if checkWin(game.board, symbol) then
                            game.status = "win"
                            game.winner = senderID
                        elseif checkDraw(game.board) then
                            game.status = "draw"
                        else
                            -- Switch turns
                            game.turn = (game.turn == 1) and 2 or 1
                        end

                        broadcast(game)
                        print("[TTT Server] Player " .. senderID .. " moved to (" .. move.row .. "," .. move.col .. ")")
                    else
                        rednet.send(senderID, { type = "error", message = "Cell already occupied." }, "ttt")
                    end
                else
                    rednet.send(senderID, { type = "error", message = "Invalid move coordinates." }, "ttt")
                end
            end
        end
    end
end
