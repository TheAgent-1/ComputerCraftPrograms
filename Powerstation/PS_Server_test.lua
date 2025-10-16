-- Powerstation Control Server v2.0
-- With Advanced Monitor GUI

-- ===== SETUP =====
local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
local monitor = peripheral.find("monitor")

if not modem then
    print("No wireless modem found!")
    return
end

if not monitor then
    print("No monitor found!")
    return
end

rednet.open(peripheral.getName(modem))
monitor.setTextScale(0.5)  -- Adjust as needed (0.5 to 5)

-- ===== DATA CACHE =====
local data = {
    accumulators = {},  -- {id = {energy, capacity, percent, timestamp}}
    speedometers = {},  -- {id = {speed, timestamp}}
    stressometers = {}, -- {id = {stress, capacity, percent, timestamp}}
    relay = {status = "UNKNOWN", timestamp = 0},
    rsc = {speed = 0, timestamp = 0}
}

-- ===== GUI STATE =====
local gui = {
    rscSlider = {
        x = 3,
        y = 35,
        width = 38,
        value = 0,  -- Current RSC target (-256 to 256)
        dragging = false
    }
}

-- ===== BACKGROUND LISTENER =====
function dataListener()
    while true do
        local id, message, protocol = rednet.receive()
        local timestamp = os.epoch("utc")
        
        -- Parse device ID from message if present
        local deviceID, payload = message:match("^(%S+):%s*(.+)$")
        if not deviceID then
            deviceID = "default"
            payload = message
        end
        
        if protocol == "powerstation_accumulator" then
            local stored, capacity, percent = payload:match("(%d+)/(%d+)FE,%s*(%d+)%%")
            if stored then
                data.accumulators[deviceID] = {
                    energy = tonumber(stored),
                    capacity = tonumber(capacity),
                    percent = tonumber(percent),
                    timestamp = timestamp
                }
            end
            
        elseif protocol == "powerstation_speedometer" then
            local speed = payload:match("([%d%.%-]+)%s*RPM")
            if speed then
                data.speedometers[deviceID] = {
                    speed = tonumber(speed),
                    timestamp = timestamp
                }
            end
            
        elseif protocol == "powerstation_stressometer" then
            local stress, capacity, percent = payload:match("([%d%.]+)/([%d%.]+)%s*SU,%s*(%d+)%%")
            if stress then
                data.stressometers[deviceID] = {
                    stress = tonumber(stress),
                    capacity = tonumber(capacity),
                    percent = tonumber(percent),
                    timestamp = timestamp
                }
            end
            
        elseif protocol == "powerstation_relay" then
            data.relay.status = payload
            data.relay.timestamp = timestamp
            
        elseif protocol == "powerstation_rsc" then
            local speed = payload:match("([%d%.%-]+)%s*RPM")
            if speed then
                data.rsc.speed = tonumber(speed)
                data.rsc.timestamp = timestamp
                gui.rscSlider.value = tonumber(speed)
            end
        end
    end
end

-- ===== HELPER FUNCTIONS =====
function formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

function getColor(percent)
    if percent >= 70 then return colors.lime end
    if percent >= 40 then return colors.yellow end
    return colors.red
end

function isStale(timestamp)
    return (os.epoch("utc") - timestamp) > 5000  -- 5 seconds
end

function drawProgressBar(x, y, width, percent, label)
    local fillWidth = math.floor((width - 2) * (percent / 100))
    
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(colors.gray)
    monitor.write("[" .. string.rep(" ", width - 2) .. "]")
    
    monitor.setCursorPos(x + 1, y)
    monitor.setBackgroundColor(getColor(percent))
    monitor.write(string.rep(" ", fillWidth))
    
    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(x + width + 2, y)
    monitor.write(label)
end

function drawButton(x, y, width, text, bgColor, textColor)
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(bgColor)
    monitor.setTextColor(textColor)
    local padding = math.floor((width - #text) / 2)
    monitor.write(string.rep(" ", padding) .. text .. string.rep(" ", width - padding - #text))
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

function drawSlider(sliderData)
    local x, y, width = sliderData.x, sliderData.y, sliderData.width
    local value = sliderData.value
    
    -- Slider track
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(colors.gray)
    monitor.write(string.rep(" ", width))
    
    -- Calculate handle position (value -256 to 256 mapped to slider width)
    local normalizedValue = (value + 256) / 512  -- 0 to 1
    local handlePos = math.floor(x + (normalizedValue * (width - 1)))
    
    -- Draw handle
    monitor.setCursorPos(handlePos, y)
    monitor.setBackgroundColor(colors.lightBlue)
    monitor.write(" ")
    
    -- Draw value
    monitor.setBackgroundColor(colors.black)
    monitor.setCursorPos(x, y - 1)
    monitor.write("RSC Speed: " .. value .. " RPM")
    
    -- Draw scale markers
    monitor.setCursorPos(x, y + 1)
    monitor.write("-256")
    monitor.setCursorPos(x + width - 3, y + 1)
    monitor.write("256")
    monitor.setCursorPos(x + width/2 - 1, y + 1)
    monitor.write("0")
end

-- ===== GUI RENDERING =====
function drawGUI()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    
    local w, h = monitor.getSize()
    
    -- ===== HEADER =====
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.gray)
    monitor.clearLine()
    monitor.setCursorPos(math.floor(w/2 - 10), 1)
    monitor.write("POWERSTATION CONTROL")
    monitor.setBackgroundColor(colors.black)
    
    -- ===== ENERGY STATUS =====
    local yPos = 3
    monitor.setCursorPos(2, yPos)
    monitor.setTextColor(colors.lightBlue)
    monitor.write("=== ENERGY STORAGE ===")
    monitor.setTextColor(colors.white)
    yPos = yPos + 1
    
    local totalEnergy = 0
    local totalCapacity = 0
    local accCount = 0
    
    for id, acc in pairs(data.accumulators) do
        totalEnergy = totalEnergy + acc.energy
        totalCapacity = totalCapacity + acc.capacity
        accCount = accCount + 1
        
        if not isStale(acc.timestamp) then
            monitor.setCursorPos(2, yPos)
            monitor.write(id .. ":")
            drawProgressBar(2, yPos + 1, 25, acc.percent, acc.percent .. "%  " .. formatNumber(acc.energy) .. "/" .. formatNumber(acc.capacity) .. " FE")
            yPos = yPos + 2
        end
    end
    
    if accCount > 0 then
        local totalPercent = math.floor((totalEnergy / totalCapacity) * 100)
        monitor.setCursorPos(2, yPos)
        monitor.setTextColor(colors.yellow)
        monitor.write("TOTAL:")
        monitor.setTextColor(colors.white)
        drawProgressBar(2, yPos + 1, 25, totalPercent, totalPercent .. "%  " .. formatNumber(totalEnergy) .. "/" .. formatNumber(totalCapacity) .. " FE")
        yPos = yPos + 3
    else
        monitor.setCursorPos(2, yPos)
        monitor.setTextColor(colors.red)
        monitor.write("No accumulators connected")
        monitor.setTextColor(colors.white)
        yPos = yPos + 2
    end
    
    -- ===== STEAM ENGINE ROOMS =====
    monitor.setCursorPos(2, yPos)
    monitor.setTextColor(colors.lightBlue)
    monitor.write("=== STEAM ENGINE ROOMS ===")
    monitor.setTextColor(colors.white)
    yPos = yPos + 1
    
    -- Combine speed and stress data by ID
    local engines = {}
    for id, speed in pairs(data.speedometers) do
        if not engines[id] then engines[id] = {} end
        engines[id].speed = speed
    end
    for id, stress in pairs(data.stressometers) do
        if not engines[id] then engines[id] = {} end
        engines[id].stress = stress
    end
    
    for id, engine in pairs(engines) do
        monitor.setCursorPos(2, yPos)
        monitor.write(id .. ":")
        yPos = yPos + 1
        
        if engine.speed and not isStale(engine.speed.timestamp) then
            monitor.setCursorPos(4, yPos)
            local speedColor = engine.speed.speed > 0 and colors.lime or colors.red
            monitor.setTextColor(speedColor)
            monitor.write("Speed: " .. engine.speed.speed .. " RPM")
            monitor.setTextColor(colors.white)
            yPos = yPos + 1
        end
        
        if engine.stress and not isStale(engine.stress.timestamp) then
            monitor.setCursorPos(4, yPos)
            monitor.write("Stress: ")
            drawProgressBar(12, yPos, 15, engine.stress.percent, engine.stress.percent .. "%  " .. formatNumber(engine.stress.stress) .. "/" .. formatNumber(engine.stress.capacity) .. " SU")
            yPos = yPos + 1
        end
        
        yPos = yPos + 1
    end
    
    if next(engines) == nil then
        monitor.setCursorPos(2, yPos)
        monitor.setTextColor(colors.red)
        monitor.write("No engine rooms connected")
        monitor.setTextColor(colors.white)
        yPos = yPos + 2
    end
    
    -- ===== CONTROLS =====
    local controlY = h - 8
    monitor.setCursorPos(2, controlY)
    monitor.setTextColor(colors.lightBlue)
    monitor.write("=== CONTROLS ===")
    monitor.setTextColor(colors.white)
    controlY = controlY + 1
    
    -- Relay button
    local relayColor = data.relay.status == "ON" and colors.green or colors.red
    local relayText = "RELAY: " .. data.relay.status
    drawButton(2, controlY, 15, relayText, relayColor, colors.white)
    controlY = controlY + 2
    
    -- RSC Slider
    drawSlider(gui.rscSlider)
    
    -- Footer
    monitor.setCursorPos(2, h)
    monitor.setTextColor(colors.gray)
    monitor.write("Last update: " .. os.date("%H:%M:%S"))
    monitor.setTextColor(colors.white)
end

-- ===== TOUCH HANDLING =====
function handleTouch(x, y)
    -- Relay button (adjust coordinates as needed)
    if x >= 2 and x <= 17 and y == (monitor.getSize() - 7) then
        if data.relay.status == "ON" then
            rednet.broadcast("RELAY_OFF", "powerstation_relay")
        else
            rednet.broadcast("RELAY_ON", "powerstation_relay")
        end
    end
    
    -- RSC Slider
    local slider = gui.rscSlider
    if y == slider.y and x >= slider.x and x <= slider.x + slider.width then
        -- Calculate new value
        local normalizedPos = (x - slider.x) / slider.width
        local newValue = math.floor((normalizedPos * 512) - 256)
        newValue = math.max(-256, math.min(256, newValue))  -- Clamp
        
        slider.value = newValue
        rednet.broadcast("RSC_SET " .. newValue, "powerstation_rsc")
        drawGUI()  -- Immediate visual feedback
    end
end

-- ===== MAIN LOOP =====
function guiLoop()
    while true do
        drawGUI()
        os.sleep(1)  -- Update every second
    end
end

function touchLoop()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        handleTouch(x, y)
    end
end

-- ===== START =====
print("Powerstation Control Server started!")
print("Monitor: " .. peripheral.getName(monitor))
print("Listening for devices...")

parallel.waitForAny(
    dataListener,
    guiLoop,
    touchLoop
)