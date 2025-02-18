local server_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftMail/main/mail_server.lua"
local client_url = "https://raw.githubusercontent.com/TheAgent-1/ComputerCraftMail/main/mail_client.lua"

local function downloadFile(url, filename)
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

term.clear()
term.setCursorPos(1, 1)
print("Mail System Updater")
print("1 - Install as Mail Server")
print("2 - Install as Mail Client")
write("Select an option: ")

local choice = read()
if choice == "1" then
    downloadFile(server_url, "mail_server.lua")
    print("Mail Server installed. Run 'mail_server' to start.")
elseif choice == "2" then
    downloadFile(client_url, "mail_client.lua")
    print("Mail Client installed. Run 'mail_client' to start.")
else
    print("Invalid option. Exiting.")
end