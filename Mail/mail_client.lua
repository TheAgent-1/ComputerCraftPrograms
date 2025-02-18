local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found!")
    return
end

local function extractUsername(email)
    return email:match("^(%w+)@spectre%.local$")
end

-- User Login
local userEmail = nil
while true do
    term.clear()
    term.setCursorPos(1,1)
    print("Welcome to Spectre Mail")
    write("Enter your email (e.g., jacob@spectre.local): ")
    local inputEmail = read()
    
    if extractUsername(inputEmail) then
        userEmail = inputEmail
        break
    else
        print("Invalid email format! Press Enter to retry.")
        read()
    end
end

-- Discover Server ID
rednet.broadcast("DISCOVER_MAIL_SERVER", "mail")
local senderID, response = rednet.receive("mail_response", 5)
if senderID then
    serverID = senderID
else
    print("Failed to locate mail server.")
    return
end

-- Menu System
local function mainMenu()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("Logged in as: " .. userEmail)
        print("\n1 - Send Mail")
        print("2 - View Inbox")
        print("3 - Exit")
        write("\nSelect an option: ")
        local choice = read()

        if choice == "1" then
            sendMailScreen()
        elseif choice == "2" then
            viewInbox()
        elseif choice == "3" then
            return
        end
    end
end

-- Send Mail Screen
function sendMailScreen()
    term.clear()
    term.setCursorPos(1,1)
    print("Compose Email\n")
    write("To (e.g., alice@spectre.local): ")
    local recipient = read()
    
    if not extractUsername(recipient) then
        print("Invalid email format! Press Enter to return.")
        read()
        return
    end

    write("Message: ")
    local message = read()

    local data = {action = "send", to = recipient, from = userEmail, content = message}
    rednet.send(serverID, textutils.serialize(data), "mail")
    print("\nMail sent! Press Enter to return.")
    read()
end

-- View Inbox with Delete Option
function viewInbox()
    term.clear()
    term.setCursorPos(1,1)
    print("Fetching inbox...\n")

    local data = {action = "view", email = userEmail}
    rednet.send(serverID, textutils.serialize(data), "mail")

    local _, response = rednet.receive("mail_response", 5)
    if response then
        local success, mails = pcall(textutils.unserialize, response)
        if not success or type(mails) ~= "table" then
            print("Error: Could not retrieve emails.")
        elseif #mails == 0 then
            print("Inbox is empty.")
        else
            for i, msg in ipairs(mails) do
                print("[" .. i .. "] From: " .. msg.from)
                print("  " .. textutils.formatTime(msg.timestamp, true) .. " - " .. msg.content)
                print("")
            end
        end
    else
        print("Failed to connect to the mail server.")
    end
    print("\nPress Enter to return.")
    read()
end

-- Start Program
mainMenu()
