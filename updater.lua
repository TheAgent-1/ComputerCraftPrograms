-- This program is a simple updater for various ComputerCraft programs.
-- It allows the user to download and install different programs from a self-hosted repository.
-- The programs include a mail system, a music player, a TicTacToe game, and Stargate utilities.
-- The updater provides a menu for the user to select which program to install.
-- It uses HTTP requests to download the files and saves them locally.
-- The program is designed to be run in the ComputerCraft mod for Minecraft.
-- The program is written in Lua and uses the ComputerCraft API for file handling and terminal input/output.
-- This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.

--Self Update--
local updater_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/updater.lua"

--Mail System--
local mailserver_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Mail/mail_server.lua"
local mailclient_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Mail/mail_client.lua"

--Music Player--
local musicplayer_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/MusicPlayer/MusicPlayer.lua"

--TicTacToe--
local tictactoeserver_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/TicTacToe/TicTacToe_server.lua"
local tictactoeclient_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/TicTacToe/TicTacToe_client.lua"

--External Mail System--
local externalmailclient_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/ExternalMail/mail_x_world.lua"

--Stargate--
local stargate_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/GateDial.lua"
local stargate_auto_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/GateDialAuto.lua"
local stargate_manual_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/GateDialManual.lua"
local stargate_full_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/GateDialFull.lua"
local stargate_remotedhd_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/RemoteDHD.lua"
local stargate_readme_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Stargate/ReadMe.txt"

--Powerstation--
local powerstationserver_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Powerstation/Powerstation_Server.lua"
local powerstationclient_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Powerstation/Powerstation_Client.lua"
local ps_server_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Powerstation/PS_Server_test.lua"
local ps_client_url = "http://192.168.1.41:3002/Jacob/ComputerCraftPrograms/raw/branch/main/Powerstation/PS_Client_test.lua"

local function downloadFile(url, filename) --Handles downloading the selected file
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        print(filename .. " downloaded successfully.")
        return true
    else
        print("Failed to download " .. filename)
    end
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

local function MailInstall() --Handles installing the mail system
    term.clear()
    term.setCursorPos(1, 1)
    print("Please select the installation type:")
    print("1 - Server")
    print("2 - Client")
    write("Select an option: ")

    local choice = read()
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
    local choice = read()
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

    local choice = read()
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

    local choice = read()
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
    print("4 - GateDialFull")
    print("5 - RemoteDHD")
    write("Select an option: ")

    local choice = read()
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
        downloadFile(stargate_remotedhd_url, "RemoteDHD.lua")
        --downloadFile(stargate_readme_url, "Stargate_Readme.txt")
        --print("Run 'edit Stargate_Readme.txt' to view the Readme")
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

    local choice = read()
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

local function main() --Handles main screen
    term.clear()
    term.setCursorPos(1, 1)
    print("Updater")
    print("Use -1 to run Self Update")
    print("0 - Exit")
    print("1 - Install Mail System")
    print("2 - Install Music Player (Broken)")
    print("3 - Install TicTacToe (Broken)")
    print("4 - Install External Mail System")
    print("5 - Stargate")
    print("6 - Powerstation")
    write("Select an option: ")

    local choice = read()
    if choice == "0" then
        term.clear()
        term.setCursorPos(1, 1)
        return
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
    else
        print("Invalid option. Exiting.")
    end
end

main()