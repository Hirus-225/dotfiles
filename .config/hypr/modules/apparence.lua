-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Voir https://wiki.hypr.land/Configuring/Basics/Variables/

local colors = require("modules.colors")

-- --- APPARENCE (Look "Glass" & Moderne) ---
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 2,

        col = {
            -- 3 stops, dégradé animé (voir l'animation `borderangle`)
            active_border   = { colors = { colors.color1, colors.color2, colors.color1 }, angle = 45 },
            inactive_border = "rgba(595959aa)", -- Gris discret pour les fenêtres inactives
        },

        layout = "dwindle",

        resize_on_border        = true, -- Active le redimensionnement aux bords
        extend_border_grab_area = 20,   -- Augmente la zone de clic autour du bord (en pixels)
        hover_icon_on_border    = true, -- Change le curseur quand tu es sur le bord
    },

    decoration = {
        rounding = 12,

        -- Profondeur : focus lisible + effet "verre"
        active_opacity   = 1.0,
        inactive_opacity = 0.92,
        dim_inactive     = true,
        dim_strength     = 0.1,

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
            xray              = true,  -- le blur voit à travers les fenêtres : plus vif et moins gourmand
            ignore_opacity    = true,  -- floute même le contenu transparent
            noise             = 0.015, -- grain subtil "givre"
            popups            = true,  -- floute aussi les popups/menus
        },

        shadow = {
            enabled        = true,
            range          = 30,
            render_power   = 2,
            color          = "rgba(00000055)",
            color_inactive = "rgba(00000022)", -- ombres discrètes hors focus
            offset         = { 0, 8 },         -- ombre portée vers le bas
        },
    },
})

-- Blur sur les layers (waybar, rofi, etc.)
-- NB : en syntaxe Lua, `name` est l'identifiant de la règle et `match.namespace`
-- est le motif qui cible réellement le layer.
for _, ns in ipairs({
    "waybar",
    "swaync-notification-window",
    "swaync-control-center",
    "gtklock",
    "rofi",
}) do
    hl.layer_rule({
        name  = "blur-" .. ns,
        match = { namespace = "^" .. ns .. "$" },
        blur  = true,
    })
end
