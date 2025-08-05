-- Define the name of the stargate this computer is connected to
local stargateName = "<Stargate>"

-- Define API address
local API = "192.168.1.41/sg-command"

-- Locate the Stargate interface peripheral
local interface = peripheral.find("advanced_crystal_interface") or peripheral.find("crystal_interface") or peripheral.find("basic_interface")

-- List all Stargates and address
local Gates = {
    "home" = {},
    "farms" = {}
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
function dialStargate(address)
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
        
        -- Alternate direction after each symbol
        direction = (direction == "clockwise") and "counterClockwise" or "clockwise"
    end
end

-- Function to close wormhole
function closeStargate()
    if interface.isStargateConnected() then
        print("Closing Stargate")
        interface.disconnectStargate()
    end

    if interface.isStargateConnected() == false then
        print("Stargate Closed")
        
-- main loop
print("pulling latest command from API")
while true do
    local last_command = {}
    local newest_command = http.get(API)

    -- check if the command is meant for this computer
    if 
