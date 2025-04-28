-- Constants
local SERVER_URL = "http://192.168.1.40:5000"  -- Replace with your server URL

-- Function to handle HTTP POST requests
function http_post(endpoint, data)
    local jsonData = textutils.serializeJSON(data)
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local response, err = http.post(SERVER_URL .. endpoint, jsonData, headers)
    if response then
        local responseBody = response.readAll()
        response.close()
        local responseData = textutils.unserializeJSON(responseBody)
        return responseData
    else
        print("HTTP POST request failed: " .. (err or "Unknown error"))
        return nil
    end
end

-- Function to handle HTTP GET requests
function http_get(endpoint, params)
    local url = SERVER_URL .. endpoint
    if params then
        local query = {}
        for k, v in pairs(params) do
            table.insert(query, textutils.urlEncode(k) .. "=" .. textutils.urlEncode(v))
        end
        url = url .. "?" .. table.concat(query, "&")
    end

    local response = http.get(url)
    if response then
        local responseBody = response.readAll()
        response.close()
        local responseData = textutils.unserializeJSON(responseBody)
        return responseData
    else
        print("HTTP GET request failed.")
        return nil
    end
end

-- Function to handle user registration
function register_user()
    term.clear()
    term.setCursorPos(1,1)
    print("Enter your username: ")
    local username = read()
    print("Enter your password: ")
    local password = read("*")

    local data = {
        username = username,
        password = password
    }

    local response = http_post("/register", data)
    if response and response.status == "success" then
        print("Registration successful!")
    else
        print("Error: " .. (response and response.message or "Unknown error"))
    end
end

-- Function to handle user login
function login_user()
    term.clear()
    term.setCursorPos(1,1)
    print("Enter your username: ")
    local username = read()
    print("Enter your password: ")
    local password = read("*")

    local data = {
        username = username,
        password = password
    }

    local response = http_post("/login", data)
    if response and response.status == "success" then
        print("Login successful!")
        return username, password  -- Return username and password
    else
        print("Error: " .. (response and response.message or "Unknown error"))
        return nil, nil
    end
end

-- Function to send mail
function send_mail(username, password)
    term.clear()
    term.setCursorPos(1,1)
    print("Enter recipient username: ")
    local recipient = read()
    print("Enter your message: ")
    local message = read()

    local data = {
        username = username,
        password = password,
        recipient = recipient,
        message = message
    }

    local response = http_post("/send_mail", data)
    if response and response.status == "success" then
        print("Mail sent to " .. recipient)
    else
        print("Error: " .. (response and response.message or "Unknown error"))
    end
end

-- Function to view mail
function view_mail(username, password)
    term.clear()
    term.setCursorPos(1,1)
    print("Fetching your mail...")

    local params = {
        username = username,
        password = password
    }

    local response = http_get("/receive_mail", params)
    if response and response.status == "success" then
        print("Your mail:")
        for i, mail in ipairs(response.mail) do
            print(i .. ". From: " .. mail.from)
            print("   Message: " .. mail.message)
        end
    else
        print("Error: " .. (response and response.message or "No mail found"))
    end
end

-- Main program
term.clear()
term.setCursorPos(1,1)
print("Welcome to the Mail Client!")
print("1. Register")
print("2. Login")
local choice = read()

local username, password
if choice == "1" then
    register_user()
elseif choice == "2" then
    username, password = login_user()
    if username then
        print("Welcome, " .. username .. "!")
    else
        return
    end
else
    print("Invalid choice.")
    return
end

while true do
    print("\nWhat would you like to do?")
    print("1. Send Mail")
    print("2. View Mail")
    print("3. Exit")
    local action = read()

    if action == "1" then
        send_mail(username, password)
    elseif action == "2" then
        view_mail(username, password)
    elseif action == "3" then
        break
    else
        print("Invalid choice.")
    end
end
