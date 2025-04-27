-- TTT Client
-- A Tic-Tac-Toe client for connecting to the TTT server

-- Auto-open wireless modem
local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found! Please attach a wireless modem.")
    return
end

print("[TTT Client] Welcome to Tic-Tac-Toe!")

-- Function to print the game board with row/column labels
local function printBoard(board)
    print("      1    2    3")
    for row = 1, 3 do
        local line = row .. "   "
        for col = 1, 3 do
            line = line .. board[row][col] .. "  |"
        end
        print(line:sub(1, -2)) -- Remove last extra " |"
        
        if row < 3 then
            print("  -----------------")
        end
    end
end

-- Function to handle user input for their move
local function getMove()
    local valid = false
    local move = {}
    
    while not valid do
        print("Enter your move (row, column): ")
        local input = read()
        local row, col = input:match("^(%d),(%d)$")
        
        row, col = tonumber(row), tonumber(col)
        
        if row and col and row >= 1 and row <= 3 and col >= 1 and col <= 3 then
            move = { row = row, col = col }
            valid = true
        else
            print("Invalid move. Please enter a valid row and column (1-3).")
        end
    end
    
    return move
end

-- Function to handle receiving updates from the server
local function handleGameUpdate(message)
    if message.status == "waiting" then
        print("Waiting for another player to join...")
    elseif message.status == "playing" then
        printBoard(message.board)
        
        if message.turn == 1 then
            print("Your turn! (You are 'X')")
        else
            print("Waiting for opponent's move...")
        end
    elseif message.status == "win" then
        printBoard(message.board)
        print("You win!")
    elseif message.status == "draw" then
        printBoard(message.board)
        print("It's a draw!")
    end
end

-- Main loop for the client
local function startGame()
    -- Ask the user to either start or join a game
    print("Would you like to start a new game (type 'start') or join an existing one (type 'join')?")
    local action = read()

    if action == "start" then
        -- Start a new game
        rednet.send(0, { type = "start_game" }, "ttt")
        print("Starting a new game...")

        local senderID, message = rednet.receive("ttt")

        if message.type == "waiting_for_player" then
            print("Waiting for opponent...")
        end

        -- Game loop
        local gameID = message.game_id
        while true do
            local senderID, message = rednet.receive("ttt")
            if message.game_id == gameID then
                handleGameUpdate(message)
                if message.status == "playing" and message.turn == 1 then
                    local move = getMove()
                    rednet.send(0, { type = "make_move", game_id = gameID, move = move }, "ttt")
                end
            end
        end

    elseif action == "join" then
        print("Enter the game ID to join: ")
        local gameID = read()
        rednet.send(0, { type = "join_game", game_id = gameID }, "ttt")

        local senderID, message = rednet.receive("ttt")
        if message.type == "error" then
            print(message.message)
            return
        end

        -- Game loop after joining
        while true do
            local senderID, message = rednet.receive("ttt")
            if message.game_id == gameID then
                handleGameUpdate(message)
                if message.status == "playing" and message.turn == 2 then
                    local move = getMove()
                    rednet.send(0, { type = "make_move", game_id = gameID, move = move }, "ttt")
                end
            end
        end
    else
        print("Invalid option! Please type 'start' or 'join'.")
    end
end

-- Start the game loop
startGame()
