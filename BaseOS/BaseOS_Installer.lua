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