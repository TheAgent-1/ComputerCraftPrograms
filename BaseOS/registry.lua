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
        icon  = "\xA4",   -- ¤  (looks like a portal/gate — good for dialer)
        desc  = "Stargate dialer",
    },
    {
        label = "Powerstation",
        file  = "programs/powerstation.lua",
        color = colors.orange,
        icon  = "\x13",   -- ‼  (double exclaim — looks like a warning sign, good for power management)
        desc  = "Power management",
    },
    {
        label = "InfoBoard",
        file  = "programs/infoboard.lua",
        color = colors.green,
        icon  = "\x12",   -- ↕  (up-down arrow — good for info/status display)
        desc  = "Public info board",
    }
}


--[[

Symbol legend for icons:
Also see file: encodings-cc-chars.png in this repo for a visual reference.
-- Symbols (0x00–0x0F) --------------------------
\x01  ☺  smiley
\x02  ☻  filled smiley
\x03  ♥  heart
\x04  ♦  diamond
\x05  ♣  club
\x06  ♠  spade
\x07  •  bullet
\x08  ◘  inverse bullet
\x0b  ♂  male sign (circle+arrow — decent portal/gate icon!)
\x0c  ♀  female sign
\x0e  ♪  single music note
\x0f  ♫  double music note  ← confirmed

-- Arrows / navigation (0x10–0x1F) -------------
\x10  ►  right triangle    (used in BaseOS header)
\x11  ◄  left triangle     (\xab in todo is actually « from latin range)
\x12  ↕  up-down arrow
\x13  ‼  double exclaim
\x16  ▬  thick horizontal bar
\x18  ↑  up arrow
\x19  ↓  down arrow
\x1a  →  right arrow
\x1b  ←  left arrow
\x1d  ↔  left-right arrow
\x1e  ▲  solid up triangle
\x1f  ▼  solid down triangle

-- Block graphics (0x80–0x9F) ------------------
These are the 1FB00 series — partial block chars,
great for drawing custom shapes/progress bars pixel by pixel.
\x80  (em quad — blank)
\x95  ▌  left half block    ← only "standard" block in this range

-- Latin extended notable ones -----------------
\xab  «  left double angle  (used as "back" arrow in todo — looks fine)
\xbb  »  right double angle
\xb0  °  degree
\xb5  µ  micro/mu
\xd7  ×  multiply (looks like ✕, good for close/delete)
\xf7  ÷  divide
\xfb  û  (NOT a checkmark — that was wrong! it's û)
\xfc  ü

]]--