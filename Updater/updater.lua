local GITHUB_USER = "TheAgent-1"
local REPO = "ComputerCraftPrograms"
local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. REPO .. "/main/"
local UPDATER_URL = BASE_URL .. "Updater/updater.lua"

local function downloadFile(url, filename)
    local response = http.get(url)
    if response then
        local content = response.readAll()
        response.close()
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        return true
    end
    return false
end

local function updateUpdater()
    print("Checking for updater updates...")
    local response = http.get(UPDATER_URL)
    if response then
        local newCode = response.readAll()
        response.close()
        
        -- Read current updater file
        local file = fs.open("updater.lua", "r")
        local currentCode = file.readAll()
        file.close()
        
        if newCode ~= currentCode then
            print("Updating updater script...")
            local file = fs.open("updater.lua", "w")
            file.write(newCode)
            file.close()
            print("Updater updated! Restarting...")
            shell.run("updater.lua")
            return true
        else
            print("Updater is already up to date.")
        end
    else
        print("Failed to check updater version.")
    end
    return false
end

if updateUpdater() then return end

local function getRemoteVersion(program)
    local versionURL = BASE_URL .. program .. "/version.txt"
    local response = http.get(versionURL)
    if response then
        local version = response.readAll():gsub("\n", "")
        response.close()
        return version
    end
    return nil
end

local function getLocalVersion(program)
    local versionFile = program .. "_version.txt"
    if fs.exists(versionFile) then
        local file = fs.open(versionFile, "r")
        local version = file.readAll():gsub("\n", "")
        file.close()
        return version
    end
    return "0.0.0" -- Default to old version if missing
end

local function updateProgram(program)
    local remoteVersion = getRemoteVersion(program)
    local localVersion = getLocalVersion(program)

    if remoteVersion and remoteVersion ~= localVersion then
        print("Updating " .. program .. " from " .. localVersion .. " to " .. remoteVersion)

        -- Download the new version
        local programURL = BASE_URL .. program .. "/" .. program .. ".lua"
        if downloadFile(programURL, program .. ".lua") then
            print(program .. " updated successfully!")
            
            -- Save new version number
            local file = fs.open(program .. "_version.txt", "w")
            file.write(remoteVersion)
            file.close()
        else
            print("Failed to update " .. program)
        end
    else
        print(program .. " is already up-to-date!")
    end
end

local function getProgramList()
    local listURL = BASE_URL .. "programs.txt"
    local response = http.get(listURL)
    if response then
        local programs = response.readAll()
        response.close()
        return programs:gmatch("[^\r\n]+") -- Return an iterator over program names
    end
    return {}
end

print("Checking for updates...")
for program in getProgramList() do
    if fs.exists(program .. ".lua") then -- Only update installed programs
        updateProgram(program)
    end
end
print("Update check complete.")
