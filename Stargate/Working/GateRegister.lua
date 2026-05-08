--[[
-- GateRegister.lua
-- This file is part of the Stargate program.
-- It handles the registration of gates with the Stargate network.
-- The program displays a list of registered gates and allows users to add or remove gates.
-- The program is written in Lua and uses HTTP requests to communicate with the Stargate network server.
-- The API accepts JSON in the following format: {"gate": "P3X-774", "address": "15,7,22,8,31,19,0"}
-- The address is a comma-separated list of integers representing the gate's coordinates in length of 7 to 9.
-- This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.
--]]

--[[
==========================================
  GATE LIST VIEWER WITH FORM
  Interactive gate management
==========================================
]]

-- Configuration
local API_STATUS_URL = "http://192.168.1.41:5005/sg-status/api"
local API_REGISTER_URL = "http://192.168.1.41:5005/sg-status/api/register"

local monitor = nil
local gates = {}
local currentScreen = "list"  -- list, form

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function refreshPeripherals()
    monitor = peripheral.find("monitor")
    if not monitor then
        error("No monitor found!")
    end
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
end

local function drawText(x, y, text, fg, bg)
    monitor.setCursorPos(x, y)
    if fg then monitor.setTextColor(fg) end
    if bg then monitor.setBackgroundColor(bg) end
    monitor.write(text)
end

local function drawButton(x, y, text, color)
    drawText(x, y, "[ " .. text .. " ]", color)
end

-- ============================================
-- FETCH GATES
-- ============================================

local function fetchGates()
    local ok, response = pcall(http.get, API_STATUS_URL)
    
    if not ok or not response then
        return false
    end
    
    local body = response.readAll()
    response.close()
    
    local parseOk, gateList = pcall(textutils.unserializeJSON, body)
    
    if not parseOk or not gateList or type(gateList) ~= "table" then
        return false
    end
    
    gates = {}
    for _, gateData in ipairs(gateList) do
        table.insert(gates, {
            name = gateData.gate or "Unknown",
            address = gateData.address or ""
        })
    end
    
    return true
end

-- ============================================
-- MAIN LIST SCREEN
-- ============================================

local function renderListScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    drawText(1, 1, "GATE NETWORK VIEWER", colors.white)
    drawText(1, 2, string.rep("=", 50), colors.gray)
    
    if #gates == 0 then
        drawText(1, 5, "No gates found", colors.red)
        drawButton(2, 7, "REFRESH", colors.yellow)
        return
    end
    
    local y = 4
    for i, gate in ipairs(gates) do
        if i <= 15 then
            local displayText = gate.name .. " - " .. gate.address
            if #displayText > 48 then
                displayText = displayText:sub(1, 45) .. "..."
            end
            drawText(2, y, displayText, colors.lightBlue)
            y = y + 1
        end
    end
    
    drawText(1, 21, string.rep("-", 50), colors.gray)
    drawButton(2, 23, "ADD GATE", colors.green)
    drawButton(20, 23, "REFRESH", colors.yellow)
    drawButton(35, 23, "QUIT", colors.red)
end

-- ============================================
-- SUBMIT GATE TO API
-- ============================================

local function submitGateToAPI(gateName, gateAddress)
    monitor.clear()
    drawText(10, 10, "Submitting to API...", colors.yellow)
    
    local payload = {
        gate = gateName,
        address = gateAddress
    }
    
    local jsonData = textutils.serializeJSON(payload)
    
    local ok, response = pcall(function()
        return http.post(
            API_REGISTER_URL,
            jsonData,
            {["Content-Type"] = "application/json"}
        )
    end)
    
    if not ok then
        monitor.clear()
        drawText(5, 8, "ERROR: Connection failed", colors.red)
        drawText(5, 10, "Could not reach API endpoint", colors.yellow)
        sleep(3)
        return false
    end
    
    if response then
        response.close()
        monitor.clear()
        drawText(5, 8, "Gate registered successfully!", colors.lime)
        drawText(5, 9, "Gate: " .. gateName, colors.white)
        drawText(5, 10, "Address: " .. gateAddress, colors.white)
        sleep(2)
        return true
    else
        monitor.clear()
        drawText(5, 8, "ERROR: API request failed", colors.red)
        sleep(3)
        return false
    end
end

-- ============================================
-- ADD GATE FORM SCREEN
-- ============================================

local formData = {
    gateName = "",
    gateAddress = ""
}

local formFocus = 1  -- 1 = name, 2 = address

local function renderFormScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    
    drawText(1, 1, "ADD NEW GATE", colors.yellow)
    drawText(1, 2, string.rep("=", 50), colors.gray)
    
    -- Gate Name Field
    drawText(2, 5, "Gate Name:", colors.white)
    local nameColor = (formFocus == 1) and colors.yellow or colors.gray
    monitor.setCursorPos(15, 5)
    monitor.setTextColor(nameColor)
    monitor.setBackgroundColor(colors.black)
    monitor.write(formData.gateName .. string.rep(" ", 30 - #formData.gateName))
    
    -- Address Field
    drawText(2, 8, "Address:", colors.white)
    drawText(15, 7, "(e.g., 1,2,3,4,5,6,0)", colors.gray)
    local addrColor = (formFocus == 2) and colors.yellow or colors.gray
    monitor.setCursorPos(15, 8)
    monitor.setTextColor(addrColor)
    monitor.setBackgroundColor(colors.black)
    monitor.write(formData.gateAddress .. string.rep(" ", 30 - #formData.gateAddress))
    
    -- Instructions
    drawText(2, 11, "TAB to switch fields", colors.gray)
    drawText(2, 12, "ENTER when done", colors.gray)
    
    -- Buttons
    drawText(1, 15, string.rep("-", 50), colors.gray)
    drawButton(2, 17, "SUBMIT", colors.green)
    drawButton(18, 17, "CANCEL", colors.red)
    
    -- Status
    if formData.gateName ~= "" and formData.gateAddress ~= "" then
        drawText(2, 20, "Fields complete - ready to submit", colors.lime)
    else
        drawText(2, 20, "Fill in all fields", colors.yellow)
    end
end

local function handleFormInput()
    while currentScreen == "form" do
        renderFormScreen()
        
        local event, param = os.pullEvent()
        
        if event == "monitor_touch" then
            local x, y = param, os.pullEvent()[2]
            
            -- Submit button (row 17)
            if y == 17 and x >= 2 and x <= 12 then
                if formData.gateName ~= "" and formData.gateAddress ~= "" then
                    local success = submitGateToAPI(formData.gateName, formData.gateAddress)
                    formData.gateName = ""
                    formData.gateAddress = ""
                    if success then
                        fetchGates()  -- Refresh the list
                    end
                    currentScreen = "list"
                    return
                end
            end
            
            -- Cancel button (row 17)
            if y == 17 and x >= 18 and x <= 28 then
                formData.gateName = ""
                formData.gateAddress = ""
                currentScreen = "list"
                return
            end
            
            -- Click on name field
            if y == 5 and x >= 15 then
                formFocus = 1
            end
            
            -- Click on address field
            if y == 8 and x >= 15 then
                formFocus = 2
            end
            
        elseif event == "key" then
            if param == keys.tab then
                formFocus = (formFocus == 1) and 2 or 1
            elseif param == keys.backspace then
                if formFocus == 1 then
                    formData.gateName = formData.gateName:sub(1, -2)
                else
                    formData.gateAddress = formData.gateAddress:sub(1, -2)
                end
            elseif param == keys.enter then
                if formData.gateName ~= "" and formData.gateAddress ~= "" then
                    local success = submitGateToAPI(formData.gateName, formData.gateAddress)
                    formData.gateName = ""
                    formData.gateAddress = ""
                    if success then
                        fetchGates()  -- Refresh the list
                    end
                    currentScreen = "list"
                    return
                end
            end
        elseif event == "char" then
            if formFocus == 1 and #formData.gateName < 30 then
                formData.gateName = formData.gateName .. param
            elseif formFocus == 2 and #formData.gateAddress < 30 then
                formData.gateAddress = formData.gateAddress .. param
            end
        end
    end
end

local function handleListInput()
    while currentScreen == "list" do
        renderListScreen()
        
        local event, side, x, y = os.pullEvent("monitor_touch")
        
        -- Add Gate button (row 23)
        if y == 23 and x >= 2 and x <= 14 then
            currentScreen = "form"
            handleFormInput()
        end
        
        -- Refresh button (row 23)
        if y == 23 and x >= 20 and x <= 32 then
            if fetchGates() then
                -- List will re-render
            end
        end
        
        -- Quit button (row 23)
        if y == 23 and x >= 35 and x <= 45 then
            monitor.clear()
            return
        end
    end
end

-- ============================================
-- MAIN
-- ============================================

local function main()
    refreshPeripherals()
    
    if not fetchGates() then
        drawText(1, 5, "Failed to fetch gates from API", colors.red)
        sleep(3)
    end
    
    handleListInput()
end

local success, err = pcall(main)

if not success then
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.red)
    monitor.write("ERROR: " .. tostring(err))
end