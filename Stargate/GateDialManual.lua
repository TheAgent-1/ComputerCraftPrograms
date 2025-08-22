-- Locate the Stargate interface peripheral
local interface = peripheral.find("advanced_crystal_interface") or peripheral.find("crystal_interface") or peripheral.find("basic_interface")

-- List all Stargates and address
local Gates = { --Placeholders, addresses should follow the format of 8 numbers, followed by a 0
    -- Example addresses, replace with actual Stargate addresses
    example = {32,12,1,16,7,10,2,0},
    home = {},
    farms = {}
}

-- Function to rotate the gate to a specific symbol
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

-- Function to dial a Stargate by address (table of 8–9 numbers)
local function dialStargate(address)
    if #address < 8 or #address > 9 then
        error("Invalid address length. Must be 8 or 9 symbols.")
        
    end

    print("Beginning dialing sequence...")

    -- Start with clockwise rotation
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
        -- Alternate direction after each symbol
        direction = (direction == "clockwise") and "antiClockwise" or "clockwise"
    end
end

-- Function to close wormhole
local function closeStargate()
    if interface.isStargateConnected() then
        print("Closing Stargate")
        interface.disconnectStargate()
    end

    if interface.isStargateConnected() == false then
        print("Stargate Closed")
    end
end

local function openIris()
    if interface.getIris() then
        interface.openIris()
        -- Wait until iris is fully open
        while interface.getIrisProgressPercentage() ~= 0 do
            os.sleep(0.1)
        end
        print("Iris is fully open.")
        return true
    else
        print("No iris installed.")
        return false
    end
end

local function closeIris()
    if interface.getIris() then
        interface.closeIris()
        -- Wait until iris is fully closed
        while interface.getIrisProgressPercentage() ~= 100 do
            os.sleep(0.1)
        end
        print("Iris is fully closed.")
        return true
    else
        print("No iris installed.")
        return false
    end
end
        
-- main loop
while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("Stargate Dialer")
    -- list all gates
    print("Available Stargates:")
    for name, address in pairs(Gates) do
        print(name .. ": " .. table.concat(address, ", "))
    end

    -- Read user input
    command = input("Enter command (dial <gate_name>, close, iris-open, iris-close): ")
    if command then
        local cmd, arg = command:match("^(%S+)%s*(%S*)$")
        if cmd == "dial" and arg ~= "" then
            local gate = Gates[arg]
            if gate and #gate > 0 then
                dialStargate(gate)
            else
                print("Unknown gate or address not set.")
            end
        end
        if data.action == "close" then
            closeStargate()
        end
        if data.action == "iris-open" then
            openIris()
        end
        if data.action == "iris-close" then
            closeIris()
        end
        if cmd == "exit" then
            print("Exiting Stargate Dialer.")
            break
        end
    end
    os.sleep(1)
end
-- Locate the Stargate interface peripheral
local interface = peripheral.find("advanced_crystal_interface") or peripheral.find("crystal_interface") or peripheral.find("basic_interface")

-- List all Stargates and address
local Gates = { --Placeholders, addresses should follow the format of 8 numbers, followed by a 0
    -- Example addresses, replace with actual Stargate addresses
    example = {32,12,1,16,7,10,2,0},
    home = {},
    farms = {}
}

-- Function to rotate the gate to a specific symbol
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

-- Function to dial a Stargate by address (table of 8–9 numbers)
local function dialStargate(address)
    if #address < 8 or #address > 9 then
        error("Invalid address length. Must be 8 or 9 symbols.")
        
    end

    print("Beginning dialing sequence...")

    -- Start with clockwise rotation
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
        -- Alternate direction after each symbol
        direction = (direction == "clockwise") and "antiClockwise" or "clockwise"
    end
end

-- Function to close wormhole
local function closeStargate()
    if interface.isStargateConnected() then
        print("Closing Stargate")
        interface.disconnectStargate()
    end

    if interface.isStargateConnected() == false then
        print("Stargate Closed")
    end
end

local function openIris()
    if interface.getIris() then
        interface.openIris()
        -- Wait until iris is fully open
        while interface.getIrisProgressPercentage() ~= 0 do
            os.sleep(0.1)
        end
        print("Iris is fully open.")
        return true
    else
        print("No iris installed.")
        return false
    end
end

local function closeIris()
    if interface.getIris() then
        interface.closeIris()
        -- Wait until iris is fully closed
        while interface.getIrisProgressPercentage() ~= 100 do
            os.sleep(0.1)
        end
        print("Iris is fully closed.")
        return true
    else
        print("No iris installed.")
        return false
    end
end
        
-- main loop
while true do
    term.clear()
    term.setCursorPos(1, 1)
    print("Stargate Dialer")
    -- list all gates
    print("Available Stargates:")
    for name, address in pairs(Gates) do
        print(name .. ": " .. table.concat(address, ", "))
    end

    -- Read user input
    command = input("Enter command (dial <gate_name>, close, iris-open, iris-close): ")
    if command then
        local cmd, arg = command:match("^(%S+)%s*(%S*)$")
        if cmd == "dial" and arg ~= "" then
            local gate = Gates[arg]
            if gate and #gate > 0 then
                dialStargate(gate)
            else
                print("Unknown gate or address not set.")
            end
        end
        if data.action == "close" then
            closeStargate()
        end
        if data.action == "iris-open" then
            openIris()
        end
        if data.action == "iris-close" then
            closeIris()
        end
        if cmd == "exit" then
            print("Exiting Stargate Dialer.")
            break
        end
    end
    os.sleep(1)
end
