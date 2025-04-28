-- This program is a simple updater for various ComputerCraft programs.
-- It allows the user to download and install different programs from a GitHub repository.
-- The programs include a mail system, a music player, and a TicTacToe game.
-- The updater provides a menu for the user to select which program to install.
-- It uses HTTP requests to download the files and saves them locally.
-- The program is designed to be run in the ComputerCraft mod for Minecraft.
-- The program is written in Lua and uses the ComputerCraft API for file handling and terminal input/output.
-- This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.

--Mail System--
local mailserver_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/Mail/mail_server.lua"
local mailclient_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/Mail/mail_client.lua"

--Music Player--
local musicplayer_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/MusicPlayer/MusicPlayer.lua"

--TicTacToe--
local tictactoeserver_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/TicTacToe/TicTacToe_server.lua"
local tictactoeclient_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/TicTacToe/TicTacToe_client.lua"

local function downloadFile(url, filename) --Handles downloading the selected file
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        print(filename .. " downloaded successfully.")
    else
        print("Failed to download " .. filename)
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

local function main() --Handles main screen
    term.clear()
    term.setCursorPos(1, 1)
    print("Updater")
    print("0 - Exit")
    print("1 - Install Mail System")
    print("2 - Install Music Player (Broken)")
    print("3 - Install TicTacToe (Broken)")
    write("Select an option: ")

    local choice = read()
    if choice == "0" then
        term.clear()
        term.setCursorPos(1, 1)
        return
    elseif choice == "1" then
        MailInstall()
   
    elseif choice == "2" then
        MusicInstall()

    elseif choice == "3" then
        TicTacToeInstall()

    else
        print("Invalid option. Exiting.")
    end
end


main()
