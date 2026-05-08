-- This program is a simple updater for various ComputerCraft programs.
-- It allows the user to download and install different programs from a self-hosted repository.
-- The programs include a mail system, a music player, a TicTacToe game, and Stargate utilities.
-- The updater provides a menu for the user to select which program to install.
-- It uses HTTP requests to download the files and saves them locally.
-- The program is designed to be run in the ComputerCraft mod for Minecraft.
-- The program is written in Lua and uses the ComputerCraft API for file handling and terminal input/output.
-- This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.

-- The full URL for the updater: http://croul1.duckdns.org:3000/Jacob/ComputerCraftPrograms/raw/branch/main/updater.lua

--=====================================
-- URL Definitions
--=====================================
--Root URL for the repositories--
local root_url = "http://croul1.duckdns.org:3000/Jacob/ComputerCraftPrograms/raw/branch/main/"

--Self Update--
local updater_url = root_url .. "updater.lua"

--Mail System--
local mailserver_url = root_url .. "Mail/mail_server.lua"
local mailclient_url = root_url .. "Mail/mail_client.lua"

--Music Player--
local musicplayer_url = root_url .. "MusicPlayer/MusicPlayer.lua"

--TicTacToe--
local tictactoeserver_url = root_url .. "TicTacToe/TicTacToe_server.lua"
local tictactoeclient_url = root_url .. "TicTacToe/TicTacToe_client.lua"

--External Mail System--
local externalmailclient_url = root_url .. "ExternalMail/mail_x_world.lua"

--Stargate--
local stargate_url = root_url .. "Stargate/Working/GateDial.lua"
local stargate_auto_url = root_url .. "Stargate/Working/GateDialAuto.lua"
local stargate_manual_url = root_url .. "Stargate/Working/GateDialManual.lua"
local stargate_full_url = root_url .. "Stargate/Working/GateDialFull.lua"
local stargate_remotedhd_url = root_url .. "Stargate/Working/RemoteDHD.lua"
local stargate_register_url = root_url .. "Stargate/Working/GateRegister.lua"
local stargate_fullWS_url = root_url .. "Stargate/Working/GateDialFull-WS.lua"
local stargate_readme_url = root_url .. "Stargate/ReadMe.txt"

--Powerstation--
local powerstationserver_url = root_url .. "Powerstation/Powerstation_Server.lua"
local powerstationclient_url = root_url .. "Powerstation/Powerstation_Client.lua"
local ps_server_url = root_url .. "Powerstation/PS_Server_test.lua"
local ps_client_url = root_url .. "Powerstation/PS_Client_test.lua"

--ToDo--
local todo_url = root_url .. "ToDo/ToDo.lua"

--BaseOS--
-- BaseOS is a set of multiple files so it needs a secondary installer to download all the necessary files
local baseos_url = root_url .. "BaseOS/BaseOS_Installer.lua"

--AE2--
local ae2_spatial_base_url = root_url .. "AE2SpatialBase/Spatial.lua"


--=====================================
-- Utility Functions
--=====================================
local function downloadFile(url, filename) --Handles downloading the selected file
    local ok, response = pcall(http.get, url)
    if not ok or not response then
        print("Failed to download " .. filename)
        return false
    end
    local status
    if response.getResponseCode then
        status = response.getResponseCode()
    end
    local content = response.readAll()
    response.close()
    if status and (status < 200 or status >= 300) then
        print("HTTP error " .. tostring(status) .. " for " .. filename)
        return false
    end
    local tmpName = filename .. ".tmp"
    local okWrite, err = pcall(function()
        local file = fs.open(tmpName, "w")
        file.write(content)
        file.close()
    end)
    if not okWrite then
        print("Failed to write file: " .. tostring(err))
        if fs.exists(tmpName) then fs.delete(tmpName) end
        return false
    end
    if fs.exists(filename) then fs.delete(filename) end
    local movedOk, moveErr = pcall(function() fs.move(tmpName, filename) end)
    if not movedOk then
        print("Failed to finalize download: " .. tostring(moveErr))
        if fs.exists(tmpName) then fs.delete(tmpName) end
        return false
    end
    print(filename .. " downloaded successfully.")
    return true
end

local function getInput()
    local s = read()
    if not s then return "" end
    s = s:match("^%s*(.-)%s*$")
    return s:upper()
end

local function SelfUpdate()
    term.clear()
    term.setCursorPos(1, 1)
    print("Running Self Update...")
    if downloadFile(updater_url, "updater.lua") then
        print("Self Update Complete. Please restart the program.")
    else
        print("Self Update Failed")
    end
end

--=====================================
-- Installation Functions
--=====================================
local function MailInstall() --Handles installing the mail system
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the installation type:")
    print("1 - Server")
    print("2 - Client")
    write("Select an option: ")

    local choice = getInput()
    if choice == "1" then
        downloadFile(mailserver_url, "MailServer.lua")
    elseif choice == "2" then
        downloadFile(mailclient_url, "MailClient.lua")
    else
        print("Invalid option. Exiting.")
    end
end

local function MusicInstall() --Handles installing the music player
    term.clear()
    term.setCursorPos(1, 1)
    print("Music Player is currently broken.")
    print("Would you like to download it anyway? (Y/N)")
    local choice = getInput()
    if choice == "Y" then
        downloadFile(musicplayer_url, "MusicPlayer.lua")
    elseif choice == "N" then
        print("Installation cancelled.")
    else
        print("Invalid option. Exiting.")
    end
end

local function TicTacToeInstall() --Handles installing the TicTacToe game
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the installation type:")
    print("1 - Server")
    print("2 - Client")
    write("Select an option: ")

    local choice = getInput()
    if choice == "1" then
        downloadFile(tictactoeserver_url, "TicTacToeServer.lua")
    elseif choice == "2" then
        downloadFile(tictactoeclient_url, "TicTacToeClient.lua")
    else
        print("Invalid option. Exiting.")
    end
end

local function ExternalMailInstall() --Handles installing the external mail system
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the installation type:")
    print("1 - Client")
    write("Select an option: ")

    local choice = getInput()
    if choice == "1" then
        downloadFile(externalmailclient_url, "MailXWorld.lua")
    else
        print("Invalid option. Exiting.")
    end
end

local function StargateInstall() --Handles installing the Stargate program
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the Stargate program to install:")
    print("1 - GateDial")
    print("2 - GateDialAuto")
    print("3 - GateDialManual")
    print("4 - GateDialFull (Recommended)")
    print("5 - GateDialFull-WS (WebSocket version)")
    print("6 - RemoteDHD (Only for Portable Devices)")
    print("7 - GateRegister")
    write("Select an option: ")

    local choice = getInput()
    if choice == "1" then
        downloadFile(stargate_url, "GateDial.lua")
        downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "2" then
        downloadFile(stargate_auto_url, "GateDialAuto.lua")
        downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "3" then
        downloadFile(stargate_manual_url, "GateDialManual.lua")
        downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "4" then
        downloadFile(stargate_full_url, "GateDialFull.lua")
        downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "5" then
        downloadFile(stargate_fullWS_url, "GateDialFull-WS.lua")
        downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "6" then
        downloadFile(stargate_remotedhd_url, "RemoteDHD.lua")
        --downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        --print("Run 'edit Stargate_Readme.txt' to view the Readme")
    elseif choice == "7" then
        downloadFile(stargate_register_url, "GateRegister.lua")
    else
        print("Invalid option. Exiting.")
    end
end

local function PowerstationInstall() --Handles installing the Powerstation program
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the Powerstation program to install:")
    print("1 - Powerstation Server")
    print("2 - Powerstation Client")
    print("3 - Powerstation Server - Test Branch")
    print("4 - Powerstation Client - Test Branch")
    write("Select an option: ")

    local choice = getInput()
    if choice == "1" then
        downloadFile(powerstationserver_url, "Powerstation_Server.lua")
    elseif choice == "2" then
        downloadFile(powerstationclient_url, "Powerstation_Client.lua")
    elseif choice == "3" then
        downloadFile(ps_server_url, "PS_Server_test.lua")
    elseif choice == "4" then
        downloadFile(ps_client_url, "PS_Client_test.lua")
    else
        print("Invalid option. Exiting.")
    end
end

local function ToDoInstall() --Handles installing the ToDo program
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing ToDo...")
    downloadFile(root_url .. "ToDo/ToDo.lua", "ToDo.lua")
end

local function BaseOSInstall() --Handles installing BaseOS
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing BaseOS...")
    downloadFile(baseos_url, "BaseOS_Installer.lua")
end

local function AE2SpatialBaseInstall() --Handles installing AE2 Spatial Base
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing AE2 Spatial Base...")
    downloadFile(ae2_spatial_base_url, "Spatial.lia")
end

--=====================================
-- Main Loop
--=====================================
local function main() --Handles main screen
    term.clear()
    term.setCursorPos(1, 1)
    print("Updater")
    --DEBUG--
    print("updater url: " .. updater_url)
    print("Use -1 to run Self Update")
    print("0 - Exit")
    print("1 - Install Mail System")
    print("2 - Install Music Player (Broken)")
    print("3 - Install TicTacToe (Broken)")
    print("4 - Install External Mail System")
    print("5 - Install Stargate")
    print("6 - Install Powerstation")
    print("7 - Install ToDo")
    print("8 - Install BaseOS")
    print("9 - Install AE2 Spatial Base")
    write("Select an option: ")
    local choice = getInput()
    if choice == "0" then
        term.clear()
        term.setCursorPos(1, 1)
        return false
    elseif choice == "-1" then
        SelfUpdate()
    elseif choice == "1" then
        MailInstall()
    elseif choice == "2" then
        MusicInstall()
    elseif choice == "3" then
        TicTacToeInstall()
    elseif choice == "4" then
        ExternalMailInstall()
    elseif choice == "5" then
        StargateInstall()
    elseif choice == "6" then
        PowerstationInstall()
    elseif choice == "7" then
        ToDoInstall()
    elseif choice == "8" then
        BaseOSInstall()
    elseif choice == "9" then
        AE2SpatialBaseInstall()
    else
        print("Invalid option. Exiting.")
    end
    return true
end

local shouldContinue = true
while shouldContinue do
    shouldContinue = main()
end