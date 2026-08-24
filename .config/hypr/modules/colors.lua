-- Palette Pywal, générée depuis le fond d'écran courant.
--
-- `scripts/refresh_colors.sh` écrit ~/.cache/wal/colors-hyprland.lua (table Lua)
-- en même temps que le .conf historique (encore utilisé par hyprlock, qui reste
-- en hyprlang). Ce module charge cette table et retombe sur une palette de
-- secours si Pywal n'a pas encore tourné — ainsi la config ne casse jamais.

-- Palette de secours (dernier état connu). Ne pas éditer à la main : elle sert
-- uniquement de filet si ~/.cache/wal/colors-hyprland.lua est absent.
local fallback = {
    color0     = "rgb(181b1f)",
    color1     = "rgb(D19868)",
    color2     = "rgb(CFA378)",
    color3     = "rgb(B37A91)",
    color4     = "rgb(ACB0BA)",
    color5     = "rgb(C1B3B2)",
    color6     = "rgb(B996CA)",
    color7     = "rgb(d1d4da)",
    color8     = "rgb(929498)",
    color9     = "rgb(D19868)",
    color10    = "rgb(CFA378)",
    color11    = "rgb(B37A91)",
    color12    = "rgb(ACB0BA)",
    color13    = "rgb(C1B3B2)",
    color14    = "rgb(B996CA)",
    color15    = "rgb(d1d4da)",
    foreground = "rgb(d1d4da)",
    background = "rgb(181b1f)",
}

local colors = {}

local path  = (os.getenv("HOME") or "") .. "/.cache/wal/colors-hyprland.lua"
local chunk = loadfile(path)
if chunk then
    local ok, loaded = pcall(chunk)
    if ok and type(loaded) == "table" then
        colors = loaded
    end
end

-- Toute couleur manquante est résolue depuis la palette de secours.
return setmetatable(colors, { __index = fallback })
