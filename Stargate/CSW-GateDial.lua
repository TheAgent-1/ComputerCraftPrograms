
-- Locate the Stargate interface peripheral and set '<type>'
local interface = nil
local interfaceType = nil

if peripheral.find("advanced_crystal_interface") then
    interface = peripheral.find("advanced_crystal_interface")
    interfaceType = "advanced_crystal_interface"

elseif peripheral.find("crystal_interface") then
    interface = peripheral.find("crystal_interface")
    interfaceType = "crystal_interface"

elseif peripheral.find("basic_interface") then
    interface = peripheral.find("basic_interface")
    interfaceType = "basic_interface"
end

-- kill if not interface
if not interface then
    error("[STOP CODE: SG-NOINTERFACE] No Stargate interface found. Check your connections.")
end

-- Get the list of gates from the Server Computer
local modem = peripheral.find("modem")
if not modem then
    error("[STOP CODE: SG-NOMODEM] No modem found. Required for communication with Server Computer.")
end

modem.open(9731)
local Gates = {}
print("Waiting for gate list from Server Computer...")
while true do
    local event, side, sender, port, distance, message = os.pullEvent("modem_message")
    if message and message.type == "gateList" then
        Gates = message.data
        print("Received gate list from Server Computer.")
        break
    end
end

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
    -- Crystal or Advanced interface
    if interfaceType == "advanced_crystal_interface" or interfaceType == "crystal_interface" then
        for i, symbol in ipairs(address) do
            print("Dialing symbol " .. i .. ": " .. symbol)
            interface.engageSymbol(symbol)
        end
        return
    end

    -- Basic Interface
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


--main
print("Stargate Dialer Initialized.")
print("Available gates:")
for i, gate in ipairs(Gates) do
    -- need a "press enter for more" if there are more than 5 gates
    if i > 5 then
        print("Press Enter to see more gates...")
        local key = os.pullEvent("key")
        -- check if key is enter else backspace
        if key == keys.enter then
            -
        elseif key == keys.backspace then
            print("Exiting gate list.")