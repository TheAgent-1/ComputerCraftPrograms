-- Define the name of the stargate this computer is connected to
local stargateName = "<Stargate>"

-- Define API address
local API = "192.168.1.41/sg-command"
local status = "192.168.1.41/sg-status"

-- Locate the Stargate interface peripheral
local interface = peripheral.find("advanced_crystal_interface") or peripheral.find("crystal_interface") or peripheral.find("basic_interface")

-- List all Stargates and address
local Gates = {
    home = {27,25,4,25,10,28,0},
    farms = {26,6,14,31,11,29,0}
}

-- Check if the interface exists
if interface == nil then
    error("No Stargate interface found.")
end

-- Check if the interface is connected to the stargate
if interface.isStargateConnected() then
    print("Stargate is connected.")
else
    print("Stargate is not connected.")
end

-- Function to rotate the gate to a specific symbol
local function rotateToSymbol(symbol, direction)
    local current = interface.getCurrentSymbol()
    while current ~= symbol do
        if direction == "clockwise" then
            interface.rotateClockwise()
        else
            interface.rotateCounterClockwise()
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
        interface.encodeChevron()
        os.sleep(0.2)
        -- Alternate direction after each symbol
        direction = (direction == "clockwise") and "counterClockwise" or "clockwise"
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
term.write("pulling latest command from API")
local last_command = nil
while true do
    local response = http.get(API)

    -- check if the command is meant for this computer
    if response then
        local body = response.readAll()
        response.close()
        local data = textutils.unserializeJSON(body)

        if data and data.action and data.from == stargateName then
            -- the command is for this computer, now check if we havent already ran it
            if data ~= last_command then
                -- if we havent ran it, then check the the name to the address
                local gate = Gates[data.to]

                -- if the command is a dial command, then dial the stargate
                if data.action == "open" then
                    dialStargate(gate)
                end

                -- if the command is a close command, then close the stargate using the from field
                if data.action == "close" then
                    closeStargate()
                end

                -- if the command is a open iris command, then open the stargate iris using the from field
                if data.action == "iris-open" then
                    openIris()
                end

                -- if the command is a close iris command, then close the stargate iris using the from field
                if data.action == "iris-close" then
                    closeIris()
                end
            last_command = data
            end
        end
    end
    os.sleep(1)
end
