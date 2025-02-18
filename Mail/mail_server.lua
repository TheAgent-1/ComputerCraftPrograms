local mailDir = "mailbox"

if not fs.exists(mailDir) then
    fs.makeDir(mailDir)
end

local function extractUsername(email)
    return email:match("^(%w+)@spectre%.local$")
end

local function saveMail(to, from, message)
    local username = extractUsername(to)
    if not username then return end

    local filepath = fs.combine(mailDir, username .. ".txt")
    local mail = {}

    if fs.exists(filepath) then
        local file = fs.open(filepath, "r")
        mail = textutils.unserialize(file.readAll()) or {}
        file.close()
    end

    table.insert(mail, {timestamp = os.time(), from = from, content = message})

    local file = fs.open(filepath, "w")
    file.write(textutils.serialize(mail))
    file.close()
end

local function getMail(username)
    local filepath = fs.combine(mailDir, username .. ".txt")
    if not fs.exists(filepath) then return {} end

    local file = fs.open(filepath, "r")
    local mail = textutils.unserialize(file.readAll()) or {}
    file.close()
    
    return mail
end

local function deleteMail(username, index)
    local filepath = fs.combine(mailDir, username .. ".txt")
    if not fs.exists(filepath) then return false end

    local file = fs.open(filepath, "r")
    local mail = textutils.unserialize(file.readAll()) or {}
    file.close()

    if mail[index] then
        table.remove(mail, index)
        local file = fs.open(filepath, "w")
        file.write(textutils.serialize(mail))
        file.close()
        return true
    end
    return false
end

local modem = peripheral.find("modem", function(_, modem) return modem.isWireless() end)
if modem then
    rednet.open(peripheral.getName(modem))
else
    print("No wireless modem found!")
    return
end

local serverID = os.getComputerID()
print("Mail Server Online. Server ID: " .. serverID)

while true do
    local senderID, message = rednet.receive("mail")
    
    -- Check if message is valid
    if message then
        local success, data = pcall(textutils.unserialize, message)
        if not success or type(data) ~= "table" then
            rednet.send(senderID, "Error: Invalid data format!", "mail_response")
        else
            if data.action == "send" then
                saveMail(data.to, data.from, data.content)
                rednet.send(senderID, "Mail sent!", "mail_response")
            elseif data.action == "view" then
                local username = extractUsername(data.email)
                if username then
                    local mail = getMail(username)
                    rednet.send(senderID, textutils.serialize(mail), "mail_response")
                else
                    rednet.send(senderID, "Invalid email!", "mail_response")
                end
            elseif data.action == "delete" then
                local username = extractUsername(data.email)
                if username and deleteMail(username, data.index) then
                    rednet.send(senderID, "Mail deleted!", "mail_response")
                else
                    rednet.send(senderID, "Invalid request!", "mail_response")
                end
            end
        end
    end
end
