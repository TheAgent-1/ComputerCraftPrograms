from flask import Flask, request, jsonify
import json
import os

app = Flask(__name__)

# File paths for user data and mail storage
USER_DATA_FILE = 'users.json'

# Function to load data from a JSON file
def load_data():
    if os.path.exists(USER_DATA_FILE):
        with open(USER_DATA_FILE, 'r') as file:
            return json.load(file)
    else:
        return {"users": {}, "mail_storage": {}}

# Function to save data to a JSON file
def save_data(data):
    with open(USER_DATA_FILE, 'w') as file:
        json.dump(data, file, indent=4)

# Load user data from the file
data = load_data()
users = data["users"]
mail_storage = data["mail_storage"]

# Endpoint to register a user
@app.route("/register", methods=["POST"])
def register_user():
    data = request.json
    username = data.get("username")
    password = data.get("password")  # Storing password in plain text (for simplicity)
    
    if username in users:
        return jsonify({"status": "error", "message": "User already exists!"}), 400
    
    # Store user credentials
    users[username] = {"password": password}
    mail_storage[username] = []  # Initialize mail storage for new user

    # Save updated data
    save_data({"users": users, "mail_storage": mail_storage})

    return jsonify({"status": "success", "message": "User registered successfully!"}), 200

# Endpoint to authenticate a user
@app.route("/login", methods=["POST"])
def login_user():
    data = request.json
    username = data.get("username")
    password = data.get("password")
    
    if username not in users or users[username]["password"] != password:
        return jsonify({"status": "error", "message": "Invalid username or password!"}), 401
    
    return jsonify({"status": "success", "message": "User authenticated successfully!"}), 200

# Endpoint to send mail (requires authentication)
@app.route("/send_mail", methods=["POST"])
def send_mail():
    data = request.json
    username = data.get("username")
    password = data.get("password")
    recipient = data.get("recipient")
    message = data.get("message")

    # Authenticate user
    if username not in users or users[username]["password"] != password:
        return jsonify({"status": "error", "message": "Invalid username or password!"}), 401

    if recipient not in mail_storage:
        return jsonify({"status": "error", "message": "Recipient does not exist!"}), 404
    
    mail_storage[recipient].append({"from": username, "message": message})

    # Save updated data
    save_data({"users": users, "mail_storage": mail_storage})

    return jsonify({"status": "success", "message": "Mail sent!"}), 200

# Endpoint to view mail (requires authentication)
@app.route("/receive_mail", methods=["GET"])
def receive_mail():
    username = request.args.get("username")
    password = request.args.get("password")
    
    # Authenticate user
    if username not in users or users[username]["password"] != password:
        return jsonify({"status": "error", "message": "Invalid username or password!"}), 401

    if username not in mail_storage:
        return jsonify({"status": "error", "message": "No mail found for this user!"}), 404
    
    return jsonify({"status": "success", "mail": mail_storage[username]}), 200

# Endpoint to delete a mail (requires authentication)
@app.route("/delete_mail", methods=["POST"])
def delete_mail():
    data = request.json
    username = data.get("username")
    password = data.get("password")
    mail_id = data.get("mail_id")

    # Authenticate user
    if username not in users or users[username]["password"] != password:
        return jsonify({"status": "error", "message": "Invalid username or password!"}), 401

    # Check if user has mail
    if username not in mail_storage:
        return jsonify({"status": "error", "message": "No mail found for this user!"}), 404

    user_mail = mail_storage[username]

    # Check if mail_id is valid (remember mail_id is 1-based from client)
    if not isinstance(mail_id, int) or mail_id < 1 or mail_id > len(user_mail):
        return jsonify({"status": "error", "message": "Invalid mail ID!"}), 400

    # Delete the mail (adjusting for 0-based index)
    user_mail.pop(mail_id - 1)

    # Save updated data
    save_data({"users": users, "mail_storage": mail_storage})

    return jsonify({"status": "success", "message": "Mail deleted successfully!"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
