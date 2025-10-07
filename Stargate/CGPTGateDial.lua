--[[
==========================================
  STARGATE DIALING COMPUTER (SGC CONSOLE)
  Author: Jacob Croul
  This program controls a Stargate via the
  Stargate Journey mod using a connected
  ComputerCraft terminal and monitor.
  It simulates the SGC's Dialing Computer.
  Version: 1.1 (Hybrid Input, Iris Fix, UI polish)
==========================================
]]

-- ======= CONFIG =======
local STARGATE_NAME = "<Stargate>"
local API_URL = "http://192.168.1.41:5005/sg-command"

-- Quick-dial addresses (add your own here)
local knownAddresses = {
    ["Abydos"] = "-26-6-14-31-11-29-",
    ["Atlantis"] = "-5-8-9-16-3-20-",
    ["Earth"] = "-1-2-3-4-5-6-"
}

-- ======= INIT =======
local monitor = peripheral.find("monitor")
if not monitor then error("[SGC ERROR] No monitor connected.") end

local interface = peripheral.find("advanced_crystal_interface")
    or peripheral.find("crystal_interface")
    or peripheral.find("basic_interface")
if not interface then error("[SGC ERROR] No Stargate interface found!") end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

-- ======= STATE =======
local irisClosed = true
local status = "Idle"
local log = {}
local chevrons = {false, false, false, false, false, false, false}
local energyPercent = 0
local connectedAddr = "None"
local lastAction = nil

-- ======= UTILITY =======
local function addLog(entry)
    table.insert(log, 1, textutils.formatTime(os.time(), true) .. " | " .. entry)
    if #log > 6 then table.remove(log) end
end

local function drawText(x, y, text, color)
    monitor.setCursorPos(x, y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function progressBar(x, y, width, percent)
    local filled = math.floor(width * percent / 100)
    local bar = string.rep("#", filled) .. string.rep("-", width - filled)
    monitor.setCursorPos(x, y)
    monitor.write("[" .. bar .. "]")
end

-- ======= GUI RENDER =======
local function render()
    monitor.clear()

    -- Header
    drawText(1, 1, "SGC DIALING COMPUTER", colors.white)
    drawText(30, 1, "[ Iris: " .. (irisClosed and "CLOSED " or "OPEN   ") .. "]", irisClosed and colors.red or colors.green)
    drawText(1, 2, string.rep("-", 45), colors.gray)

    -- Status
    drawText(1, 3, "Gate Status: " .. status, colors.yellow)
    drawText(1, 4, "Connected Address: " .. connectedAddr, colors.lightBlue)
    drawText(1, 5, "Energy: ", colors.orange)
    progressBar(10, 5, 20, energyPercent)
    drawText(31, 5, energyPercent .. "%", colors.orange)

    -- Chevrons
    drawText(1, 7, "Chevron Lock Progress:", colors.cyan)
    for i = 1, 7 do
        drawText(3, 7 + i, "Chevron " .. i .. ": " .. (chevrons[i] and "Locked ✓" or "Awaiting..."), chevrons[i] and colors.green or colors.gray)
    end

    -- Buttons
    drawText(1, 16, "[ Dial ]", colors.lime)
    drawText(10, 16, "[ Disconnect ]", colors.red)
    drawText(26, 16, "[ Iris Toggle ]", colors.cyan)

    -- Known destinations (optional)
    drawText(1, 17, "Quick Dial:", colors.white)
    local x = 3
    for name, addr in pairs(knownAddresses) do
        drawText(x, 18, "[" .. name .. "]", colors.lightBlue)
        x = x + #name + 4
    end

    -- Logs
    drawText(1, 20, "Event Log:", colors.white)
    for i, entry in ipairs(log) do
        drawText(3, 20 + i, entry, colors.gray)
    end
end

-- ======= STARGATE CONTROL =======
local function updateStatus()
    if interface.isStargateConnected() then
        status = "Active Wormhole"
        connectedAddr = interface.getConnectedAddress() or "Unknown"
    elseif interface.isStargateDialingOut() then
        status = "Dialing Out"
    elseif interface.isWormholeOpen() then
        status = "Incoming Wormhole"
    else
        status = "Idle"
        connectedAddr = "None"
    end

    local ok, e, cap = pcall(interface.getEnergy), pcall(interface.getEnergyCapacity)
    if ok and type(e) == "number" and type(cap) == "number" then
        energyPercent = math.floor(e / cap * 100)
    else
        energyPercent = 0
    end
end

local function toggleIris()
    local ok, state = pcall(interface.getIris)
    if not ok then addLog("Iris control unavailable.") return end
    if irisClosed then
        interface.openIris()
        addLog("Opening iris...")
    else
        interface.closeIris()
        addLog("Closing iris...")
    end
    irisClosed = not irisClosed
end

local function closeGate()
    if interface.isStargateConnected() then
        addLog("Closing Stargate...")
        interface.disconnectStargate()
        for i = 1, 7 do chevrons[i] = false end
    else
        addLog("No active wormhole.")
    end
end

local function simulateChevronLock()
    for i = 1, 7 do
        chevrons[i] = true
        render()
        os.sleep(0.4)
    end
    addLog("Chevron 7 locked! Wormhole established.")
end

local function dialGate(address)
    addLog("Dialing " .. address .. "...")
    status = "Dialing Out"
    render()
    simulateChevronLock()
    status = "Active Wormhole"
    render()
end

-- ======= API POLL LOOP =======
local function apiLoop()
    while true do
        local response = http.get(API_URL)
        if response then
            local body = response.readAll()
            response.close()
            local data = textutils.unserializeJSON(body)
            if data and data.action and data.from == STARGATE_NAME then
                if data.action ~= lastAction then
                    if data.action == "open" then dialGate(data.to or "UNKNOWN") end
                    if data.action == "close" then closeGate() end
                    if data.action == "iris-open" and irisClosed then toggleIris() end
                    if data.action == "iris-close" and not irisClosed then toggleIris() end
                    lastAction = data.action
                end
            end
        end
        os.sleep(1)
    end
end

-- ======= INPUT LOOP =======
local function inputLoop()
    while true do
        local _, _, x, y = os.pullEvent("monitor_touch")

        -- Top buttons
        if y == 16 then
            if x >= 1 and x <= 7 then
                term.setCursorPos(1, 1)
                term.clear()
                write("Enter destination address or name: ")
                local input = read()
                local addr = knownAddresses[input] or input
                addLog("Manual dial to " .. input)
                dialGate(addr)
            elseif x >= 10 and x <= 23 then
                closeGate()
            elseif x >= 26 and x <= 38 then
                toggleIris()
            end
        end

        -- Quick dial buttons
        if y == 18 then
            local pos = 3
            for name, addr in pairs(knownAddresses) do
                local len = #name + 2
                if x >= pos and x <= pos + len then
                    dialGate(addr)
                    break
                end
                pos = pos + len + 2
            end
        end
    end
end

-- ======= MAIN LOOP =======
local function guiLoop()
    while true do
        updateStatus()
        render()
        os.sleep(0.5)
    end
end

parallel.waitForAny(apiLoop, inputLoop, guiLoop)
