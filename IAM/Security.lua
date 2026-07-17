-- ============================================================
--  HOLD IAM Client
--  Requires: Advanced Peripherals (Player Detector)
--  Place detector adjacent to this computer.
--  Run on a regular Computer or Advanced Computer.
-- ============================================================

local BASE_URL      = "http://192.168.1.41:8000"  -- your server IP
local DOOR_SIDE     = "front"   -- redstone side wired to door/gate
local DOOR_OPEN_SEC = 5         -- how long the door stays open

local detector = peripheral.find("playerDetector")
if not detector then
    error("[IAM] No playerDetector found. Check connections.", 0)
end

-- ============================================================
--  Helpers
-- ============================================================

local function setDoor(open)
    redstone.setOutput(DOOR_SIDE, open)
end

local function verify(username)
    local url = BASE_URL .. "/verify?user=" .. textutils.urlEncode(username)
    local ok, response = pcall(http.get, url)

    if not ok or not response then
        print("[IAM] Server unreachable.")
        return false
    end

    local body = textutils.unserialiseJSON(response.readAll())
    response.close()
    return body and body.verified == true
end

local function grantAccess(username)
    print("[GRANTED] " .. username)
    setDoor(true)
    sleep(DOOR_OPEN_SEC)
    setDoor(false)
end

local function denyAccess(username)
    print("[DENIED]  " .. username)
    -- Optional: flash a monitor, play a note block, etc.
end

-- ============================================================
--  Startup check
-- ============================================================

print("[IAM] Checking server...")
local ok, resp = pcall(http.get, BASE_URL .. "/ping")
if ok and resp then
    resp.close()
    print("[IAM] Server OK. Watching for players...")
else
    print("[IAM] WARNING: Server not reachable. Will keep retrying on events.")
end

setDoor(false) -- ensure door starts closed

-- ============================================================
--  Main event loop
-- ============================================================

while true do
    -- playerClick fires when a player right-clicks the detector block
    local event, username, device = os.pullEvent("playerClick")

    print("[IAM] Click from: " .. username)

    -- Optional proximity check: only process if within 5 blocks
    -- Remove this if you want global click access
    if detector.isPlayerInRange(5, username) then
        if verify(username) then
            grantAccess(username)
        else
            denyAccess(username)
        end
    else
        print("[IAM] " .. username .. " is out of range, ignoring.")
    end
end