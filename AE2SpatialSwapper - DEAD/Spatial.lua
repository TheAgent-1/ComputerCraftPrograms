--[[
============================================================================
    AE2 Spatial Swapper - DEAD PROJECT, CANNOT DETERMINE IF CELLS ARE DEPLOYED OR NOT
    A CC:Tweaked program to swap the spatial storage cells in an Applied Energistics 2 system.
    Will connect to an external API for remote control via internet connected devices
    (e.g. smartphones, tablets, laptops, computers, etc).

    Order of operations:
    1. Connect to the ME Spatial IO Port and nearby barrel/chest
    2. Connect to the external API for remote control
    3. Start initialization process and figure out all cells via nbt data and display names
    4. Wait for user input via the external API and swap cells as needed
============================================================================
]]

-- =========================================================================
-- Configuration settings and constants
-- =========================================================================
local CONFIG = {
    -- ME Spatial IO Port settings
    ME_PORT_SIDE = "left", -- Side of the ME Spatial IO Port (e.g. "back", "left", "right", "top", "bottom")
    ME_PORT_CELL_SLOT = 1, -- Slot number in the ME Spatial IO Port where the cell is inserted (1-4)

    -- Storage container settings
    STORAGE_CONTAINER_SIDE = "right", -- Side of the storage container (e.g. chest, barrel) where cells are stored

    -- External API settings
    API_HOST = "http://192.168.1.41:8080", -- Hostname or IP address of the external API (including port)    
}

local ME_PORT = peripheral.wrap(CONFIG.ME_PORT_SIDE)
local STORAGE_CONTAINER = peripheral.wrap(CONFIG.STORAGE_CONTAINER_SIDE)


-- =========================================================================
-- Functions
-- =========================================================================

local function initialize()
    print("Initializing AE2 Spatial Swapper...")
    -- Check if ME Spatial IO Port is connected
    if not ME_PORT then
        error("Error: ME Spatial IO Port not found on side " .. CONFIG.ME_PORT_SIDE)
    end

    -- Check if storage container is connected
    if not STORAGE_CONTAINER then
        error("Error: Storage container not found on side " .. CONFIG.STORAGE_CONTAINER_SIDE)
    end


end