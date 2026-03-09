-- This Program is used to install BaseOS on a ComputerCraft Computer.
-- It will download all the necessary files and place them in the correct directories.

--=====================================
-- URL Definitions
--=====================================
--Root URL for the files--
local root_url = "http://croul1.duckdns.org:3000/Jacob/ComputerCraftPrograms/raw/branch/main/BaseOS/"

-- Core
local kernel_url = root_url .. "kernel.lua"
local registry_url = root_url .. "registry.lua"

-- Programs
local gatedialer_url = root_url .. "programs/gatedialer.lua"
local powerstation_url = root_url .. "programs/powerstation.lua"
local todo_url = root_url .. "programs/todo.lua"


--=====================================
-- Functions
--=====================================
local function downloadFile(url, filename) --Handles downloading the selected file
    local ok, response = pcall(http.get, url)
    if not ok or not response then
        print("Failed to download " .. filename)
        return false
    end
    local status
    if response.getResponseCode then
        status = response.getResponseCode()
    end
    local content = response.readAll()
    response.close()
    if status and (status < 200 or status >= 300) then
        print("HTTP error " .. tostring(status) .. " for " .. filename)
        return false
    end
    local tmpName = filename .. ".tmp"
    local okWrite, err = pcall(function()
        local file = fs.open(tmpName, "w")
        file.write(content)
        file.close()
    end)
    if not okWrite then
        print("Failed to write file: " .. tostring(err))
        if fs.exists(tmpName) then fs.delete(tmpName) end
        return false
    end
    if fs.exists(filename) then fs.delete(filename) end
    local movedOk, moveErr = pcall(function() fs.move(tmpName, filename) end)
    if not movedOk then
        print("Failed to finalize download: " .. tostring(moveErr))
        if fs.exists(tmpName) then fs.delete(tmpName) end
        return false
    end
    print(filename .. " downloaded successfully.")
    return true
end

local function KernelInstall() --Handles installing the kernel
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing BaseOS Kernel...")
    downloadFile(kernel_url, "kernel.lua")
end

local function RegistryInstall() --Handles installing the registry
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing BaseOS Registry...")
    downloadFile(registry_url, "registry.lua")
end

local function CreateProgramDir() --Creates the programs directory if it doesn't exist
    if not fs.exists("programs") then
        fs.makeDir("programs")
    end
end

-- ++++++++++++++++++++++++++++++++++++
-- Program Installers
-- Each program has its own installer function that handles downloading the necessary file(s) for that program
-- ++++++++++++++++++++++++++++++++++++
local function GateDialerInstall() --Handles installing the GateDialer program
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing GateDialer...")
    downloadFile(gatedialer_url, "programs/gatedialer.lua")
end

local function PowerstationInstall() --Handles installing the Powerstation program
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing Powerstation...")
    downloadFile(powerstation_url, "programs/powerstation.lua")
end

local function ToDoInstall() --Handles installing the ToDo program
    term.clear()
    term.setCursorPos(1, 1)
    print("Installing ToDo...")
    downloadFile(todo_url, "programs/todo.lua")
end

-- ++++++++++++++++++++++++++++++++++++
-- BaseOS Installer
-- This function handles installing all of BaseOS by calling the individual installer functions for the kernel, registry, and programs.
-- ++++++++++++++++++++++++++++++++++++
local function BaseOSInstall() --Handles installing all of BaseOS
    CreateProgramDir()
    KernelInstall()
    RegistryInstall()
    GateDialerInstall()
    PowerstationInstall()
    ToDoInstall()
end


BaseOSInstall() --Run the installer