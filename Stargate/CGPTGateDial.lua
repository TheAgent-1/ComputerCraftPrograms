--[[
==========================================
  STARGATE DIALING COMPUTER (SGC CONSOLE)
  Author: Jacob Croul
  Version: 2.0
==========================================
This program controls a Stargate via the
Stargate Journey mod using a connected
ComputerCraft terminal and monitor.
It simulates the SGC's Dialing Computer.
==========================================
]]

-- ======= CONFIG =======
local STARGATE_NAME = "<Stargate>"
local API_URL = "http://192.168.1.41:5005/sg-command"

-- Define known gates here
local DESTINATIONS = {
    Abydos = {26,6,14,31,11,29,0},
    Chulak = {12,8,19,24,5,9,0}
}

-- ======= INIT =======
local monitor = peripheral.find("monitor")
if not monitor then error("[SGC ERROR] No monitor connected.") end

-- Locate the Stargate interface peripheral and set type
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

if not interface then
    error("[STOP CODE: SG-NOINTERFACE] No Stargate interface found. Check your connections.")
end

monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.clear()

-- ======= STATE =======
local irisClosed = true
local status = "Idle"
local log = {}
local chevrons = {false,false,false,false,false,false,false}
local energyPercent = 0
local connectedAddr = "None"
local lastAction = nil
local dialing = false
local overlayActive = false

-- ======= UTILITY =======
local function addLog(entry)
    table.insert(log, 1, textutils.formatTime(os.time(), true) .. " | " .. entry)
    if #log > 6 then table.remove(log) end
end

local function drawText(x,y,text,color)
    monitor.setCursorPos(x,y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function progressBar(x,y,width,percent)
    local filled = math.floor(width * percent / 100)
    local bar = string.rep("#", filled) .. string.rep("-", width - filled)
    monitor.setCursorPos(x,y)
    monitor.write("[" .. bar .. "]")
end

-- ======= GUI RENDER =======
local function render()
    monitor.clear()
    
    -- Header
    drawText(1,1,"SGC DIALING COMPUTER",colors.white)
    drawText(30,1,"[ Iris: " .. (irisClosed and "CLOSED " or "OPEN   ") .. "]", irisClosed and colors.red or colors.green)
    drawText(1,2,string.rep("-",45),colors.gray)
    
    -- Status
    drawText(1,3,"Gate Status: "..status,colors.yellow)
    
    -- Connected Address (handle table or string)
    local addrStr = "None"
    if connectedAddr then
        if type(connectedAddr) == "table" then
            if interface.addressToString then
                addrStr = interface.addressToString(connectedAddr)
            else
                addrStr = table.concat(connectedAddr,"-")
            end
        else
            addrStr = tostring(connectedAddr)
        end
    end
    drawText(1,4,"Connected Address: "..addrStr,colors.lightBlue)
    
    -- Energy
    drawText(1,5,"Energy: ",colors.orange)
    progressBar(10,5,20,energyPercent)
    drawText(31,5,energyPercent.."%",colors.orange)
    
    -- Chevrons
    drawText(1,7,"Chevron Lock Progress:",colors.cyan)
    for i=1,7 do
        drawText(3,7+i,"Chevron "..i..": "..(chevrons[i] and "Locked ✓" or "Awaiting..."), chevrons[i] and colors.green or colors.gray)
    end
    
    -- Buttons
    drawText(1,16,"[ Dial ]",colors.lime)
    drawText(10,16,"[ Disconnect ]",colors.red)
    drawText(26,16,"[ Iris Toggle ]",colors.cyan)
    
    -- Logs
    drawText(1,18,"Event Log:",colors.white)
    for i,entry in ipairs(log) do
        drawText(3,18+i,entry,colors.gray)
    end
end


local function showDestinationOverlay()
    overlayActive = true
    monitor.clear()
    drawText(1,1,"Select Destination:",colors.yellow)
    local y=3
    local keys={}
    for name,address in pairs(DESTINATIONS) do
        drawText(3,y,name,colors.lime)
        keys[y]=name
        y=y+1
    end
    drawText(3,y,"Cancel",colors.red)
    local cancelY=y
    while true do
        local _,_,x,yTouch = os.pullEvent("monitor_touch")
        if yTouch==cancelY then break end
        if keys[yTouch] then
            dialGate(DESTINATIONS[keys[yTouch]])
            break
        end
    end
    overlayActive = false
end

-- ======= STARGATE CONTROL =======
local function updateStatus()
    if interface.isStargateConnected() then
        status = "Active Wormhole"
        connectedAddr = interface.getConnectedAddress() or "Unknown"
        if not dialing then
            for i=1,7 do chevrons[i]=true end
        end
    elseif interface.isStargateDialingOut() then
        status = "Dialing Out"
    elseif interface.isWormholeOpen() then
        status = "Incoming Wormhole"
    else
        status = "Idle"
        connectedAddr = "None"
        for i=1,7 do chevrons[i]=false end
    end
    if interface.getEnergy and interface.getEnergyCapacity then
        energyPercent = math.floor(interface.getEnergy()/interface.getEnergyCapacity()*100)
    else
        energyPercent = 0
    end
end

local function toggleIris()
    if not interface.getIris then
        addLog("No iris installed.")
        return
    end
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
        for i=1,7 do chevrons[i]=false end
    else
        addLog("No active wormhole.")
    end
end

-- ======= CHEVRON SEQUENCE =======
local function simulateChevronLock(address)
    dialing = true
    for i,symbol in ipairs(address) do
        if interfaceType=="advanced_crystal_interface" or interfaceType=="crystal_interface" then
            interface.engageSymbol(symbol)
        else
            -- Basic Interface
            local direction="clockwise"
            local current = interface.getCurrentSymbol()
            while current~=symbol do
                if direction=="clockwise" then
                    interface.rotateClockwise(symbol)
                else
                    interface.rotateAntiClockwise(symbol)
                end
                os.sleep(0.1)
                current = interface.getCurrentSymbol()
            end
            interface.openChevron()
            os.sleep(1)
            interface.encodeChevron()
        end
        if i<=7 then
            chevrons[i]=true
            addLog("Chevron "..i.." locked!")
        end
        render()
        os.sleep(0.5)
        -- Abort if gate suddenly connects
        if interface.isStargateConnected() and i<#address then
            addLog("Incoming wormhole detected — aborting outgoing sequence.")
            interface.disconnectStargate()
            for i=1,7 do chevrons[i]=false end
            dialing=false
            return
        end
    end
    addLog("Chevron 7 locked — wormhole established!")
    dialing=false
end

local function dialGate(address)
    if interface.isStargateConnected() then
        addLog("Cannot dial — gate already connected!")
        return
    end
    local addrStr = interface.addressToString and interface.addressToString(address) or "UNKNOWN"
    addLog("Dialing "..addrStr.."...")
    simulateChevronLock(address)
end

-- ======= DESTINATION OVERLAY =======
local function showDestinationOverlay()
    overlayActive = true
    monitor.clear()
    drawText(1,1,"Select Destination:",colors.yellow)
    local y=3
    local keys={}
    for name,address in pairs(DESTINATIONS) do
        drawText(3,y,name,colors.lime)
        keys[y]=name
        y=y+1
    end
    drawText(3,y,"Cancel",colors.red)
    local cancelY=y

    while true do
        local _,_,xTouch,yTouch = os.pullEvent("monitor_touch")
        if yTouch==cancelY then break end
        if keys[yTouch] then
            dialGate(DESTINATIONS[keys[yTouch]])
            break
        end
    end

    overlayActive = false
end


-- ======= API LOOP =======
local function apiLoop()
    while true do
        if http then
            local response = http.get(API_URL)
            if response then
                local body = response.readAll()
                response.close()
                local data = textutils.unserializeJSON(body)
                if data and data.action and data.from==STARGATE_NAME then
                    if data.action~=lastAction then
                        if data.action=="open" then dialGate(DESTINATIONS[data.to] or {0}) end
                        if data.action=="close" then closeGate() end
                        if data.action=="iris-open" and irisClosed then toggleIris() end
                        if data.action=="iris-close" and not irisClosed then toggleIris() end
                        lastAction=data.action
                    end
                end
            end
        end
        os.sleep(1)
    end
end

-- ======= INPUT LOOP =======
local function inputLoop()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if not overlayActive then
            if y == 16 then
                if x >= 1 and x <= 7 then
                    showDestinationOverlay()
                elseif x >= 10 and x <= 23 then
                    closeGate()
                elseif x >= 26 and x <= 38 then
                    toggleIris()
                end
            end
        end
        -- ignore input while overlayActive=true
    end
end


-- ======= MAIN GUI LOOP =======
local function guiLoop()
    while true do
        if not overlayActive then
            updateStatus()
            render()
        end
        os.sleep(0.5)
    end
end


-- ======= RUN ALL =======
parallel.waitForAny(apiLoop,inputLoop,guiLoop)
