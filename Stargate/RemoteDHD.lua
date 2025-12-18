--[[
==========================================
  REMOTE DHD (Pocket Computer Edition)
  Portable Stargate Control v1.0
==========================================
]]

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
    API_COMMAND_URL = "http://192.168.1.41:5005/sg-command",
    API_STATUS_URL = "http://192.168.1.41:5005/sg-status/api",  -- NEW!
    LOGIN_CODE = "1234",  -- Change this!
    DEVICE_NAME = "Remote DHD",
    FORCE_RUN = false  -- Set to true to allow running off a Pocket Computer for testing
}

-- Gate network - populated from API
local GATE_NETWORK = {}
local lastNetworkUpdate = 0

-- ============================================
-- STATE
-- ============================================
local state = {
    loggedIn = false,
    currentScreen = "login",  -- login, main, selectGate, selectDest
    selectedGate = nil,
    selectedDest = nil,
    lastCommand = nil,
    message = ""
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function drawText(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(text)
end

local function drawButton(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    term.setBackgroundColor(bg or colors.gray)
    term.setTextColor(fg or colors.white)
    term.write(" " .. text .. " ")
end

local function drawBox(x, y, width, height, color)
    term.setBackgroundColor(color)
    for i = 0, height - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", width))
    end
end

local function showMessage(msg, color, duration)
    state.message = msg
    if color then
        term.setTextColor(color)
    end
    sleep(duration or 1.5)
    state.message = ""
end

-- ============================================
-- GATE NETWORK FETCHING
-- ============================================

local function fetchGateNetwork()
    clearScreen()
    drawText(1, 8, "Scanning gate network...", colors.yellow)
    
    local ok, response = pcall(http.get, CONFIG.API_STATUS_URL)
    
    if ok and response then
        local body = response.readAll()
        response.close()
        
        local parseOk, gateList = pcall(textutils.unserializeJSON, body)
        
        if parseOk and gateList and type(gateList) == "table" then
            -- Clear old network
            GATE_NETWORK = {}
            
            -- Extract gate names
            for _, gateData in ipairs(gateList) do
                if gateData.gate then
                    table.insert(GATE_NETWORK, gateData.gate)
                end
            end
            
            -- Sort alphabetically
            table.sort(GATE_NETWORK)
            
            lastNetworkUpdate = os.clock()
            
            drawText(1, 9, "Found " .. #GATE_NETWORK .. " gates", colors.lime)
            sleep(1)
            return true
        else
            drawText(1, 9, "Failed to parse network", colors.red)
            sleep(2)
            return false
        end
    else
        drawText(1, 9, "Cannot reach API", colors.red)
        drawText(1, 10, "Using offline mode", colors.yellow)
        sleep(2)
        return false
    end
end

-- ============================================
-- API COMMUNICATION
-- ============================================

local function sendCommand(action, from, to)
    local payload = {
        action = action,
        from = from
    }
    
    if to then
        payload.to = to
    end
    
    local jsonData = textutils.serializeJSON(payload)
    
    local success, response = pcall(function()
        return http.post(
            CONFIG.API_COMMAND_URL,  -- CHANGED!
            jsonData,
            {["Content-Type"] = "application/json"}
        )
    end)
    
    if success and response then
        response.close()
        return true, "Command sent!"
    else
        return false, "Connection failed"
    end
end

-- ============================================
-- LOGIN SCREEN
-- ============================================

local function renderLogin()
    clearScreen()
    
    drawText(1, 1, "=======================", colors.cyan)
    drawText(1, 2, " REMOTE DHD - LOGIN", colors.cyan)
    drawText(1, 3, "=======================", colors.cyan)
    
    drawText(1, 5, "Enter Access Code:", colors.white)
    drawText(1, 7, "> ", colors.yellow)
    
    drawText(1, 10, "Authorized Personnel", colors.gray)
    drawText(1, 11, "Only", colors.gray)
end

local function handleLogin()
    renderLogin()
    
    term.setCursorPos(3, 7)
    term.setTextColor(colors.white)
    
    local input = read("*")  -- Masked input
    
    if input == CONFIG.LOGIN_CODE then
        state.loggedIn = true
        showMessage("Access Granted", colors.lime, 1)
        
        -- Fetch gate network after successful login
        fetchGateNetwork()
        
        state.currentScreen = "selectGate"
        return true
    else
        showMessage("Access Denied!", colors.red, 2)
        return false
    end
end

-- ============================================
-- GATE SELECTOR SCREEN
-- ============================================

local function renderGateSelector()
    clearScreen()
    
    drawText(1, 1, "=======================", colors.cyan)
    drawText(1, 2, " SELECT CONTROL GATE", colors.cyan)
    drawText(1, 3, "=======================", colors.cyan)
    
    drawText(1, 5, "Which gate to control?", colors.white)
    
     -- Check if network is empty
    if #GATE_NETWORK == 0 then
        drawText(1, 7, "No gates detected", colors.red)
        drawText(1, 8, "Press R to refresh", colors.yellow)
        drawText(1, 20, "[`] Logout", colors.gray)
        return
    end

    local y = 7
    local displayCount = 0
    
    for i, gate in ipairs(GATE_NETWORK) do
        if displayCount < 10 then
            local color = colors.lightGray
            if state.selectedGate == gate then
                color = colors.lime
                drawText(1, y, ">", colors.yellow)
            end
            drawButton(3, y, i .. ". " .. gate, colors.white, color)
            y = y + 1
            displayCount = displayCount + 1
        end
    end
    
    drawText(1, 18, "[ENTER] Continue", colors.gray)
    drawText(1, 19, "[R] Refresh Network", colors.gray)
    drawText(1, 20, "[`] Logout", colors.gray)
end

local function handleGateSelector()
    while state.currentScreen == "selectGate" do
        -- Auto-refresh every 60 seconds
        if os.clock() - lastNetworkUpdate > 60 then
            fetchGateNetwork()
        end
        
        renderGateSelector()
        
        local event, param = os.pullEvent()
        
        if event == "char" then
            if param == "`" then  -- BACKTICK to logout
                state.currentScreen = "login"
                state.loggedIn = false
                state.selectedGate = nil
                return
            elseif param == "r" or param == "R" then  -- Refresh network
                fetchGateNetwork()
            end
            
            local num = tonumber(param)
            if num and num >= 1 and num <= #GATE_NETWORK then
                state.selectedGate = GATE_NETWORK[num]
                renderGateSelector()
            end
        elseif event == "key" then
            if param == keys.enter and state.selectedGate then
                state.currentScreen = "main"
                return
            end
        end
    end
end

-- ============================================
-- MAIN CONTROL SCREEN
-- ============================================

local function renderMain()
    clearScreen()
    
    -- Header
    drawText(1, 1, "=======================", colors.cyan)
    drawText(1, 2, " REMOTE DHD CONTROL", colors.cyan)
    drawText(1, 3, "=======================", colors.cyan)
    
    -- Current gate
    drawText(1, 5, "Controlling:", colors.white)
    drawText(14, 5, state.selectedGate or "None", colors.lime)
    
    -- Buttons
    drawButton(2, 7, "1. DIAL GATE", colors.white, colors.green)
    drawButton(2, 9, "2. DISCONNECT", colors.white, colors.red)
    drawButton(2, 11, "3. IRIS OPEN", colors.white, colors.blue)
    drawButton(2, 13, "4. IRIS CLOSE", colors.white, colors.orange)
    
    -- Footer
    drawText(1, 16, "5. Change Gate", colors.gray)
    drawText(1, 17, "0. Logout", colors.gray)
    
    -- Message area
    if state.message ~= "" then
        drawText(1, 19, state.message, colors.yellow)
    end
end

local function handleMain()
    while state.currentScreen == "main" do
        renderMain()
        
        local event, param = os.pullEvent("char")
        
        if param == "1" then
            state.currentScreen = "selectDest"
            return
        elseif param == "2" then
            -- Disconnect
            local ok, msg = sendCommand("close", state.selectedGate)
            showMessage(msg, ok and colors.lime or colors.red)
        elseif param == "3" then
            -- Iris Open
            local ok, msg = sendCommand("iris-open", state.selectedGate)
            showMessage(msg, ok and colors.lime or colors.red)
        elseif param == "4" then
            -- Iris Close
            local ok, msg = sendCommand("iris-close", state.selectedGate)
            showMessage(msg, ok and colors.lime or colors.red)
        elseif param == "5" then
            state.currentScreen = "selectGate"
            return
        elseif param == "0" then
            state.currentScreen = "login"
            state.loggedIn = false
            state.selectedGate = nil
            return
        end
    end
end

-- ============================================
-- DESTINATION SELECTOR SCREEN
-- ============================================

local function renderDestSelector()
    clearScreen()
    
    drawText(1, 1, "=======================", colors.cyan)
    drawText(1, 2, " SELECT DESTINATION", colors.cyan)
    drawText(1, 3, "=======================", colors.cyan)
    
    drawText(1, 5, "Dial to:", colors.white)
    
    -- Build list of valid destinations (all gates EXCEPT the one we're controlling)
    local availableDests = {}
    for _, gate in ipairs(GATE_NETWORK) do
        if gate ~= state.selectedGate then
            table.insert(availableDests, gate)
        end
    end
    
    local y = 7
    for i, dest in ipairs(availableDests) do
        if i <= 10 then  -- Fit on screen
            local color = colors.lightGray
            if state.selectedDest == dest then
                color = colors.lime
                drawText(1, y, ">", colors.yellow)
            end
            drawButton(3, y, i .. ". " .. dest, colors.white, color)
            y = y + 1
        end
    end
    
    drawText(1, 19, "[ENTER] Dial", colors.lime)
    drawText(1, 20, "[ESC] Cancel", colors.gray)
    
    -- Store for input handling
    state.availableDests = availableDests
end

local function handleDestSelector()
    while state.currentScreen == "selectDest" do
        renderDestSelector()
        
        local event, param = os.pullEvent()
        
        if event == "char" then
            local num = tonumber(param)
            if num and num >= 1 and num <= #state.availableDests then
                state.selectedDest = state.availableDests[num]
                renderDestSelector()
            end
        elseif event == "key" then
            if param == keys.enter and state.selectedDest then
                -- Send dial command
                clearScreen()
                drawText(1, 10, "Sending dial command...", colors.yellow)
                
                local ok, msg = sendCommand("open", state.selectedGate, state.selectedDest)
                
                clearScreen()
                if ok then
                    drawText(1, 9, "Command Sent!", colors.lime)
                    drawText(1, 11, "FROM: " .. state.selectedGate, colors.white)
                    drawText(1, 12, "TO:   " .. state.selectedDest, colors.white)
                else
                    drawText(1, 10, "Error: " .. msg, colors.red)
                end
                
                sleep(2)
                state.selectedDest = nil
                state.availableDests = nil
                state.currentScreen = "main"
                local ok, msg = sendCommand("null", "", "")  -- Dummy to reset state
                return
            elseif param == keys.backspace or param == keys.delete then
                state.selectedDest = nil
                state.availableDests = nil
                state.currentScreen = "main"
                local ok, msg = sendCommand("null", "", "")  -- Dummy to reset state
                return
            end
        end
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================

local function main()
    -- Check if running on pocket computer (or forced via CONFIG)
    if not (pocket or CONFIG.FORCE_RUN) then
        print("ERROR: This program requires")
        print("a Pocket Computer!")
        print("")
        print("Craft a Pocket Computer and")
        print("run this program on it.")
        return
    end
    
    -- Main loop
    while true do
        if state.currentScreen == "login" then
            handleLogin()
        elseif state.currentScreen == "selectGate" then
            handleGateSelector()
        elseif state.currentScreen == "main" then
            handleMain()
        elseif state.currentScreen == "selectDest" then
            handleDestSelector()
        end
    end
end

-- ============================================
-- ERROR HANDLING & START
-- ============================================

local function startup()
    clearScreen()
    
    drawText(1, 8, "STARGATE REMOTE DHD", colors.cyan)
    drawText(1, 9, "Initializing...", colors.gray)
    
    sleep(1)
    
    -- Check for wireless modem
    if not peripheral.find("modem") then
        clearScreen()
        drawText(1, 8, "WARNING:", colors.red)
        drawText(1, 9, "No wireless modem!", colors.yellow)
        drawText(1, 11, "Commands may fail", colors.gray)
        sleep(3)
    end
    
    main()
end

local success, err = pcall(startup)

if not success then
    clearScreen()
    term.setTextColor(colors.red)
    print("FATAL ERROR:")
    print(err)
end