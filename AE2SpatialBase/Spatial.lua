--[[ 
==========================
    AE2 Spatial Base
    by: Jacob Croul
==========================

    Allows swapping modular AE2 spatial storage sections via a FastAPI WebSocket.

    HARDWARE LAYOUT (edit CONFIG to match your setup):
    ┌─────────────┐
    │  IO Port A  │  ← left
    │   [Computer]│  ← you are here
    │  IO Port B  │  ← right
    │  Cell Chest │  ← back
    └─────────────┘

    BEFORE FIRST RUN:
    - Confirm peripheral sides with: peripheral.getType("left") etc.
    - Confirm IO port drive slot is slot 1 with: peripheral.wrap("left").list()
    - Make sure cells are anvil-renamed with the CELL_PREFIX below
    - Ensure the API server is running and reachable
]]

-- ========================
-- CONFIG
-- Edit these values to match your setup
-- ========================
local CONFIG = {
    -- API endpoints
    API_BASE    = "http://192.168.1.41:5005/ae2/spatial",   -- Base URL for REST calls
    WS_URL      = "ws://192.168.1.41:5005/ae2/spatial/ws",  -- WebSocket endpoint

    -- Peripheral sides (change if your layout differs)
    PORT_A      = "left",    -- First Spatial IO Port side
    PORT_B      = "right",   -- Second Spatial IO Port side
    INVENTORY   = "back",    -- Cell chest side

    -- IO port drive slot number
    -- Verify with: peripheral.wrap("left").list()
    PORT_SLOT   = 1,

    -- Cell naming
    -- Cells must be anvil-renamed starting with this prefix (e.g. "SP-0001")
    CELL_PREFIX = "SP-",

    -- Timing (in seconds) — adjust if swaps feel unreliable
    TIMING = {
        PULSE       = 0.5,   -- How long the redstone pulse stays HIGH
        POST_PULSE  = 1.5,   -- Wait after pulsing before next action (IO cycle time)
        PRE_DEPLOY  = 0.5,   -- Wait after loading cell before deploying
        WS_RETRY    = 5,     -- Seconds before retrying a failed WebSocket connection
    },
}

-- ========================
-- STATE
-- Do not edit — managed at runtime
-- ========================
local state = {
    cells      = {},   -- Map of { ["SP-0001"] = { slot = 1 }, ... } built from inventory scan
    activeCell = nil,  -- Serial of the currently deployed cell, or nil if none
    ws         = nil,  -- Active WebSocket handle
}

-- ========================
-- PERIPHERALS
-- Wrapped once at startup — if sides are wrong, edit CONFIG above
-- ========================
local inv   = peripheral.wrap(CONFIG.INVENTORY)
local portA = peripheral.wrap(CONFIG.PORT_A)
local portB = peripheral.wrap(CONFIG.PORT_B)


-- ========================
-- UTILITY
-- ========================

--[[
    log(msg)
    --------
    Prints a timestamped message to the terminal.
    Prefix makes it easy to filter output if other programs are running.

    @param msg (string) — message to print
]]
local function log(msg)
    print("[Spatial Base] " .. tostring(msg))
end

--[[
    countTable(t)
    -------------
    Returns the number of entries in a table.
    Lua's # operator only works reliably on arrays, not mixed/keyed tables,
    so this is used for the cells map instead.

    @param  t     (table)  — any table
    @return count (number) — number of key-value pairs
]]
local function countTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--[[
    getPort(side)
    -------------
    Returns the peripheral handle for a given side string.
    Centralises port lookup so the rest of the code doesn't
    need to reference portA/portB directly by name.

    @param  side (string) — CONFIG.PORT_A or CONFIG.PORT_B
    @return      (table)  — peripheral handle, or nil if side is unrecognised
]]
local function getPort(side)
    if side == CONFIG.PORT_A then return portA end
    if side == CONFIG.PORT_B then return portB end
    return nil
end


-- ========================
-- REDSTONE
-- ========================

--[[
    pulsePort(side)
    ---------------
    Sends a short HIGH redstone pulse to the given side to trigger the Spatial IO Port.
    Duration is controlled by CONFIG.TIMING.PULSE.

    NOTE: The IO port must be wired to receive redstone from this side.
    Pulse too short = port may not register it. Increase TIMING.PULSE if swaps
    don't trigger reliably.

    @param side (string) — computer side to pulse ("left", "right", etc.)
]]
local function pulsePort(side)
    redstone.setOutput(side, true)
    sleep(CONFIG.TIMING.PULSE)
    redstone.setOutput(side, false)
    log("Pulsed port: " .. side)
end


-- ========================
-- INVENTORY MANAGEMENT
-- ========================

--[[
    scanCells()
    -----------
    Scans the connected chest (CONFIG.INVENTORY) and rebuilds state.cells.
    Filters items by CONFIG.CELL_PREFIX so only spatial cells are tracked.

    Cells must be anvil-renamed to match the prefix (e.g. "SP-0001").
    item.displayName is used rather than item.name (registry ID) because
    renamed items show the custom name in displayName.

    Populates: state.cells = { ["SP-0001"] = { slot = 1 }, ... }

    Called on startup and before any move operation to ensure slot data is current.
]]
local function scanCells()
    state.cells = {}
    local items = inv.list()

    for slot, item in pairs(items) do
        local detail = inv.getItemDetail(slot)
        if detail and detail.displayName then
            if detail.displayName:sub(1, #CONFIG.CELL_PREFIX) == CONFIG.CELL_PREFIX then
                state.cells[detail.displayName] = { slot = slot }
                log("Found cell: " .. detail.displayName .. " (slot " .. slot .. ")")
            end
        end
    end

    log("Scan complete — " .. countTable(state.cells) .. " cell(s) found")
end

--[[
    findCell(serial)
    ----------------
    Looks up a cell by its serial number in state.cells.
    Triggers a fresh scanCells() first to ensure slot data is accurate
    (cells may have been ejected or moved since last scan).

    @param  serial (string) — cell name to find, e.g. "SP-0001"
    @return        (table)  — { slot = N } if found, or nil if not in inventory
]]
local function findCell(serial)
    scanCells()
    return state.cells[serial]
end

--[[
    pullCell(serial, portSide)
    --------------------------
    Moves a named cell from the chest into the specified IO port's drive slot.
    Uses inv.pushItems() to push directly from chest → port by slot number.

    IMPORTANT: Assumes the IO port exposes slot CONFIG.PORT_SLOT as an inventory
    peripheral. Verify this works before relying on it — some AE2 versions may
    not expose the drive slot. If pushItems returns 0, the move failed.

    @param  serial   (string)  — cell serial to load, e.g. "SP-0001"
    @param  portSide (string)  — which port to load into (CONFIG.PORT_A or PORT_B)
    @return          (boolean) — true if cell was moved successfully, false otherwise
]]
local function pullCell(serial, portSide)
    local cell = findCell(serial)
    if not cell then
        log("Cell not found in inventory: " .. serial)
        return false
    end

    local port     = getPort(portSide)
    local portName = peripheral.getName(port)
    local moved    = inv.pushItems(portName, cell.slot, 1, CONFIG.PORT_SLOT)

    if moved == 0 then
        log("Failed to push " .. serial .. " to port " .. portSide)
        return false
    end

    log("Loaded " .. serial .. " into port " .. portSide)
    return true
end

--[[
    ejectCell(portSide)
    --------------------
    Moves the cell currently sitting in the IO port's drive slot back to the chest.
    Called after a capture cycle so the port is empty and ready for the next cell.

    Uses port.pushItems() to push from port → chest.
    The chest receives the item into any available slot (no target slot specified).

    @param portSide (string) — which port to eject from (CONFIG.PORT_A or PORT_B)
]]
local function ejectCell(portSide)
    local port    = getPort(portSide)
    local invName = peripheral.getName(inv)

    port.pushItems(invName, CONFIG.PORT_SLOT, 1)
    log("Ejected cell from port " .. portSide)
end


-- ========================
-- API COMMUNICATION
-- ========================

--[[
    postStatus()
    ------------
    POSTs the current computer state to the REST API.
    Sends a JSON body containing the list of known cell serials and the
    active cell (or null if none deployed).

    The API uses this to keep HA and the cell registry in sync.
    Called after startup scan and after every successful swap.

    Endpoint: POST CONFIG.API_BASE/status
    Body: { "cells": ["SP-0001", ...], "activeCell": "SP-0001" | null }
]]
local function postStatus()
    local cellList = {}
    for serial, _ in pairs(state.cells) do
        table.insert(cellList, serial)
    end

    local payload = textutils.serialiseJSON({
        cells      = cellList,
        activeCell = state.activeCell,
    })

    local res = http.post(
        CONFIG.API_BASE .. "/status",
        payload,
        { ["Content-Type"] = "application/json" }
    )

    if res then
        log("Status posted — " .. res.readAll())
        res.close()
    else
        log("Failed to post status to API")
    end
end

--[[
    connectWS()
    -----------
    Opens a WebSocket connection to CONFIG.WS_URL.
    Returns the WebSocket handle on success, or nil on failure.

    The handle is stored in state.ws and used by wsLoop() to receive messages.
    Reconnection is handled in wsLoop() — this function just attempts one connection.

    @return ws (table|nil) — WebSocket handle, or nil if connection failed
]]
local function connectWS()
    log("Connecting to WebSocket at " .. CONFIG.WS_URL)
    local ws, err = http.websocket(CONFIG.WS_URL)
    if not ws then
        log("WebSocket connection failed: " .. tostring(err))
        return nil
    end
    log("WebSocket connected")
    return ws
end


-- ========================
-- SWAP LOGIC
-- ========================

--[[
    doSwap(serial, portSide)
    ------------------------
    Executes a full section swap. This is the core operation of the program.

    Sequence:
      1. If a cell is currently deployed, pulse the port to capture it back,
         then wait for the IO cycle to complete, then eject the cell to the chest.
      2. Move the target cell from the chest into the port.
      3. Pulse the port to deploy the new region.
      4. Update state.activeCell and post status to the API.

    TIMING NOTE: The POST_PULSE sleep gives the IO port time to complete its
    internal cycle. If swaps are unreliable, increase CONFIG.TIMING.POST_PULSE.

    @param  serial   (string)  — serial of the cell to deploy, e.g. "SP-0001"
    @param  portSide (string)  — port to use; defaults to CONFIG.PORT_A
    @return ok       (boolean) — true if swap completed successfully
    @return message  (string)  — human-readable result message
]]
local function doSwap(serial, portSide)
    portSide = portSide or CONFIG.PORT_A
    log("Swap requested: " .. serial .. " on port " .. portSide)

    -- Step 1: Capture and eject the currently deployed cell (if any)
    if state.activeCell then
        log("Capturing active cell: " .. state.activeCell)
        pulsePort(portSide)
        sleep(CONFIG.TIMING.POST_PULSE)
        ejectCell(portSide)
    end

    -- Step 2: Load the target cell into the port
    if not pullCell(serial, portSide) then
        return false, "Cell not found in inventory: " .. serial
    end

    -- Step 3: Deploy the new region
    sleep(CONFIG.TIMING.PRE_DEPLOY)
    pulsePort(portSide)
    sleep(CONFIG.TIMING.POST_PULSE)

    -- Step 4: Update state
    state.activeCell = serial
    postStatus()

    return true, "Deployed " .. serial
end


-- ========================
-- WEBSOCKET MESSAGE HANDLER
-- ========================

--[[
    handleMessage(msg)
    ------------------
    Parses and dispatches an incoming WebSocket message.

    Expected message format: JSON object with an "action" field.

    Supported actions:
      "swap"  — { action="swap", cell="SP-0001", port="left" (optional) }
                Triggers a full section swap. Replies with swap_result.

      "scan"  — { action="scan" }
                Re-scans the inventory and posts updated status to the API.
                Useful if cells have been manually added/removed.

      "ping"  — { action="ping" }
                Replies with a pong. Used by the API to check the computer is alive.

    Unknown actions are logged and ignored — no reply is sent.

    @param msg (string) — raw JSON string received from the WebSocket
]]
local function handleMessage(msg)
    local data = textutils.unserialiseJSON(msg)
    if not data then
        log("Received invalid JSON: " .. tostring(msg))
        return
    end

    log("Action received: " .. tostring(data.action))

    if data.action == "swap" then
        local ok, result = doSwap(data.cell, data.port)
        state.ws.send(textutils.serialiseJSON({
            type    = "swap_result",
            success = ok,
            message = result,
            cell    = data.cell,
        }))

    elseif data.action == "scan" then
        scanCells()
        postStatus()

    elseif data.action == "ping" then
        state.ws.send(textutils.serialiseJSON({ type = "pong" }))

    else
        log("Unknown action: " .. tostring(data.action))
    end
end

--[[
    wsLoop()
    --------
    Blocking loop that listens for incoming WebSocket messages indefinitely.
    Passes each message to handleMessage() for dispatch.

    If the WebSocket disconnects (receive returns nil), waits CONFIG.TIMING.WS_RETRY
    seconds then attempts to reconnect. This means the program will self-recover
    from API restarts or network blips without needing a manual reboot.

    This function never returns under normal operation.
]]
local function wsLoop()
    while true do
        local msg = state.ws.receive()
        if msg == nil then
            log("WebSocket disconnected — retrying in " .. CONFIG.TIMING.WS_RETRY .. "s")
            sleep(CONFIG.TIMING.WS_RETRY)
            state.ws = connectWS()
        else
            handleMessage(msg)
        end
    end
end


-- ========================
-- STARTUP
-- ========================

--[[
    startup()
    ---------
    Entry point. Runs once when the program starts.

    Sequence:
      1. Scan inventory and build the cell table.
      2. Post initial status to the API so it knows what's available.
      3. Open WebSocket connection to the API.
      4. If connection fails, wait and retry startup recursively.
      5. Enter the WebSocket message loop.

    The recursive retry on WS failure means the program will keep attempting
    to connect on boot even if the API server isn't up yet — useful if both
    the server and the Minecraft instance start at the same time.
]]
local function startup()
    log("Starting up...")

    scanCells()
    log(countTable(state.cells) .. " cell(s) found in inventory")

    postStatus()

    state.ws = connectWS()
    if not state.ws then
        log("Could not reach API — retrying in " .. CONFIG.TIMING.WS_RETRY .. "s")
        sleep(CONFIG.TIMING.WS_RETRY)
        startup()
        return
    end

    log("Ready — waiting for instructions")
    wsLoop()
end

startup()