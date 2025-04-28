-- Constants
local SERVER_URL = "http://localhost:5000"  -- URL of the Python mail server (adjust as needed)

-- Function to handle HTTP requests
function http_request(endpoint, method, data)
    local response = http.post(SERVER_URL..endpoint, textutils.serializeJSON(data))
    if response then
        return textutils.unserializeJSON(response.readAll())
    else
        print("Error: Unable to contact server.")
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
    
    local response = http_request("/register", "POST", data)
    if response and response.status == "success" then
        print("Registration successful!")
    else
        print("Error: " .. (response.message or "Unknown error"))
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
    
    local response = http_request("/login", "POST", data)
    if response and response.status == "success" then
        print("Login successful!")
        return username  -- Return the logged-in username
    else
        print("Error: " .. (response.message or "Unknown error"))
        return nil
    end
end

-- Function to send mail
function send_mail(username)
    term.clear()
    term.setCursorPos(1,1)
    print("Enter recipient username: ")
    local recipient = read()
    print("Enter your message: ")
    local message = read()
    
    local data = {
        username = username,
        password = password,  -- Remember: For simplicity, assuming password is stored locally
        recipient = recipient,
        message = message
    }
    
    local response = http_request("/send_mail", "POST", data)
    if response and response.status == "success" then
        print("Mail sent to " .. recipient)
    else
        print("Error: " .. (response.message or "Unknown error"))
    end
end

-- Function to view mail
function view_mail(username)
    term.clear()
    term.setCursorPos(1,1)
    print("Fetching your mail...")

    local data = {
        username = username,
        password = password
    }

    local response = http_request("/receive_mail", "GET", data)
    if response and response.status == "success" then
        print("Your mail:")
        for i, mail in ipairs(response.mail) do
            print(i .. ". From: " .. mail.from)
            print("   Message: " .. mail.message)
        end
    else
        print("Error: " .. (response.message or "No mail found"))
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
    username = login_user()
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
        send_mail(username)
    elseif action == "2" then
        view_mail(username)
    elseif action == "3" then
        break
    else
        print("Invalid choice.")
    end
end

