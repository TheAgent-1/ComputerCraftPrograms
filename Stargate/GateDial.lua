-- Stargate Dialer (API + Manual Control)

-- Define the name of the stargate this computer is connected to
local stargateName = "<Stargate>" -- Change this to match your gate

-- API endpoints
local API = "http://192.168.1.41:5005/sg-command"
local status = "http://192.168.1.41:5005/sg-status"

-- Locate the Stargate interface peripheral
local interface = peripheral.find("advanced_crystal_interface") or peripheral.find("crystal_interface") or peripheral.find("basic_interface")

-- List Stargates and addresses
local Gates = {
    home = {27,25,4,25,10,28,3,0},
    farms = {26,6,14,31,33,11,29,0},
    example = {32,12,1,16,7,10,2,0}
}

-- ===== Functions =====
local function rotateToSymbol(symbol, direction)
    local current = interface.getCurrentSymbol()
    while current ~= symbol do
        if direction == "clockwise" then
            interface.rotateClockwise(symbol)
        else
            interface.rotateAntiClockwise(symbol)
        end
        os.sleep(0.1)
        current = interface.getCurrentSymbol()
    end
end

local function dialStargate(address)
    if #address < 8 or #address > 9 then
        error("Invalid address length. Must be 8 or 9 symbols.")
    end

    print("Beginning dialing sequence...")

    local direction = "clockwise"
    for i, symbol in ipairs(address) do
        print("Dialing symbol " .. i .. ": " .. symbol)
        rotateToSymbol(symbol, direction)
        if interface.getCurrentSymbol() == symbol then
            interface.openChevron()
            os.sleep(1)
            interface.encodeChevron()
        end
        os.sleep(0.2)
        direction = (direction == "clockwise") and "antiClockwise" or "clockwise"
    end
end

local function closeStargate()
    if interface.isStargateConnected() then
        print("Closing Stargate")
        interface.disconnectStargate()
    end
    if not interface.isStargateConnected() then
        print("Stargate Closed")
    end
end

local function openIris()
    if interface.getIris() then
        interface.openIris()
        while interface.getIrisProgressPercentage() ~= 0 do
            os.sleep(0.1)
        end
        print("Iris is fully open.")
    else
        print("No iris installed.")
    end
end

local function closeIris()
    if interface.getIris() then
        interface.closeIris()
        while interface.getIrisProgressPercentage() ~= 100 do
            os.sleep(0.1)
        end
        print("Iris is fully closed.")
    else
        print("No iris installed.")
    end
end

-- ===== API Loop =====
local function apiLoop()
    local last_action, last_from, last_to = nil, nil, nil
    while true do
        local response = http.get(API)
        if response then
            local body = response.readAll()
            response.close()
            local data = textutils.unserializeJSON(body)

            if data and data.action and data.from == stargateName then
                local is_new = data.action ~= last_action or data.from ~= last_from or data.to ~= last_to
                if is_new then
                    local gate = data.to and Gates[data.to] or nil
                    if data.action == "open" and gate then dialStargate(gate) end
                    if data.action == "close" then closeStargate() end
                    if data.action == "iris-open" then openIris() end
                    if data.action == "iris-close" then closeIris() end
                    last_action, last_from, last_to = data.action, data.from, data.to
                end
            end
        end
        os.sleep(1)
    end
end

-- ===== Manual Loop =====
local function manualLoop()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("Stargate Dialer")
        print("Available Stargates:")
        for name, address in pairs(Gates) do
            print(name .. ": " .. table.concat(address, ", "))
        end

        io.write("Enter command (dial <gate>, close, iris-open, iris-close, exit): ")
        local command = read()
        local cmd, arg = command:match("^(%S+)%s*(%S*)$")

        if cmd == "dial" and arg ~= "" then
            local gate = Gates[arg]
            if gate and #gate > 0 then dialStargate(gate)
            else print("Unknown gate or address not set.") end
        elseif cmd == "close" then closeStargate()
        elseif cmd == "iris-open" then openIris()
        elseif cmd == "iris-close" then closeIris()
        elseif cmd == "exit" then print("Exiting manual control.") break end

        os.sleep(1)
    end
end

-- Run both loops in parallel
parallel.waitForAny(apiLoop, manualLoop)
