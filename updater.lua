--Mail System--
local mailserver_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/Mail/mail_server.lua"
local mailclient_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/Mail/mail_client.lua"

--Music Player--
local musicplayer_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftPrograms/refs/heads/main/MusicPlayer/MusicPlayer.lua"

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

local function main() --Handles main screen
    term.clear()
    term.setCursorPos(1, 1)
    print("Updater")
    print("0 - Exit")
    print("1 - Install Mail System")
    print("2 - Install Music Player (Broken)")
    write("Select an option: ")

    local choice = read()

    if choice == "1" then
        MailInstall()
   
    elseif choice == "2" then
        MusicInstall()
    else
        print("Invalid option. Exiting.")
    end
end


main()
