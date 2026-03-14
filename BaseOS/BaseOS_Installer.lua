-- ============================================================================
-- BaseOS Installer
-- Downloads and installs all BaseOS files from Gitea.
-- To add a new program: add one entry to the PROGRAMS table. That's it.
-- ============================================================================

local ROOT = "http://croul1.duckdns.org:3000/Jacob/ComputerCraftPrograms/raw/branch/main/BaseOS/"

-- --- Core files (always installed) -------------------------------------------
local CORE = {
    { url = ROOT .. "kernel.lua",   dest = "kernel.lua"   },
    { url = ROOT .. "registry.lua", dest = "registry.lua" },
}

-- --- Programs (installed into /programs/) ------------------------------------
-- To add a new program, just add a line here.
local PROGRAMS = {
    "gatedialer",
    "powerstation",
    "todo",
    "infoboard",
}

-- --- Download helper ----------------------------------------------------------
local function downloadFile(url, dest)
    io.write("  " .. dest .. "... ")

    local ok, resp = pcall(http.get, url)
    if not ok or not resp then
        print("FAILED (no response)")
        return false
    end

    local status = resp.getResponseCode and resp.getResponseCode()
    local content = resp.readAll()
    resp.close()

    if status and (status < 200 or status >= 300) then
        print("FAILED (HTTP " .. tostring(status) .. ")")
        return false
    end

    local tmp = dest .. ".tmp"
    local writeOk = pcall(function()
        local f = fs.open(tmp, "w")
        f.write(content)
        f.close()
    end)

    if not writeOk then
        print("FAILED (write error)")
        if fs.exists(tmp) then fs.delete(tmp) end
        return false
    end

    if fs.exists(dest) then fs.delete(dest) end
    local moveOk = pcall(fs.move, tmp, dest)
    if not moveOk then
        print("FAILED (move error)")
        if fs.exists(tmp) then fs.delete(tmp) end
        return false
    end

    print("OK")
    return true
end

-- --- Installer ---------------------------------------------------------------
local function install()
    term.clear()
    term.setCursorPos(1, 1)
    print("BaseOS Installer")
    print(string.rep("=", 24))

    local failed = 0

    -- Core files
    print("\nCore:")
    for _, f in ipairs(CORE) do
        if not downloadFile(f.url, f.dest) then
            failed = failed + 1
        end
    end

    -- Programs
    print("\nPrograms:")
    if not fs.exists("programs") then fs.makeDir("programs") end
    for _, name in ipairs(PROGRAMS) do
        local url  = ROOT .. "programs/" .. name .. ".lua"
        local dest = "programs/" .. name .. ".lua"
        if not downloadFile(url, dest) then
            failed = failed + 1
        end
    end

    -- Summary
    print(string.rep("=", 24))
    if failed == 0 then
        print("All files installed!")
        print("Run kernel.lua to start BaseOS.")
    else
        print(failed .. " file(s) failed.")
        print("Check your connection and retry.")
    end
end

install()