local speaker = peripheral.find("speaker")
if not speaker then
    print("No speaker found!")
    return
end

local song_list = {}
local song_dir = "songs/"
fs.makeDir(song_dir)

local function update_song_list()
    song_list = fs.list(song_dir)
end

local function download_song(url)
    print("Requesting song...")
    local request_url = "http://your-server-ip:5000/download?url=" .. textutils.urlEncode(url)
    local response = http.get(request_url)
    
    if not response then
        print("Failed to get response from server.")
        return false
    end
    
    print("Enter a name for the song:")
    local song_name = read() .. ".dfpwm"
    local file_path = song_dir .. song_name
    
    local file = fs.open(file_path, "wb")
    file.write(response.readAll())
    file.close()
    response.close()
    update_song_list()
    return true
end

local function play_song(file_name)
    local decoder = require("cc.audio.dfpwm").make_decoder()
    local file_path = song_dir .. file_name
    local file = fs.open(file_path, "rb")
    if not file then
        print("Song file not found!")
        return
    end
    
    while true do
        local chunk = file.read(16 * 1024)
        if not chunk then break end
        local buffer = decoder(chunk)
        speaker.playAudio(buffer)
        sleep(0)
    end
    
    file.close()
    print("Song finished playing.")
end

local function select_song()
    update_song_list()
    if #song_list == 0 then
        print("No downloaded songs available.")
        return nil
    end
    
    print("Select a song:")
    for i, song in ipairs(song_list) do
        print(i .. ". " .. song)
    end
    
    local choice = tonumber(read())
    if choice and song_list[choice] then
        return song_list[choice]
    else
        print("Invalid selection.")
        return nil
    end
end

while true do
    print("Options: (1) Download Song  (2) Play Downloaded Song (3) Exit")
    local option = read()
    
    if option == "1" then
        print("Enter YouTube URL:")
        local url = read()
        if download_song(url) then
            print("Song downloaded successfully.")
        else
            print("Failed to download song.")
        end
    elseif option == "2" then
        local song_name = select_song()
        if song_name then
            print("Playing song: " .. song_name)
            play_song(song_name)
        end
    elseif option == "3" then
        break
    else
        print("Invalid option.")
    end
end
