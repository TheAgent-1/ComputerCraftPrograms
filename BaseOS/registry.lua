-- ============================================================================
-- BaseOS  |  registry.lua
-- List of programs the OS can launch.
-- Each entry must have: label, file
-- Optional:  color (tile bg), icon (single char), desc (subtitle)
-- ============================================================================

return {
    {
        label = "ToDo",
        file  = "programs/todo.lua",
        color = colors.blue,
        icon  = "\x06",    -- spade (task icon)
        desc  = "Task manager",
    },
    {
        label = "GateDial",
        file  = "programs/gatedialer.lua",
        color = colors.cyan,
        icon  = "\x0f",   -- circle
        desc  = "Stargate dialer",
    },
    {
        label = "Powerstation",
        file  = "programs/powerstation.lua",
        color = colors.orange,
        icon  = "\x0e",   -- musical note (stands in for lightning)
        desc  = "Power management",
    },
}
