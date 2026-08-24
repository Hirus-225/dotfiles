--------------------
---- ANIMATIONS ----
--------------------

-- Voir https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.config({
    animations = {
        enabled = true,
    },
})

-- Courbes de Bézier personnalisées
hl.curve("fluent_decel", { type = "bezier", points = { { 0,    1   }, { 0,    1    } } })
hl.curve("easeOutExpo",  { type = "bezier", points = { { 0.16, 1   }, { 0.3,  1    } } })
hl.curve("softReturn",   { type = "bezier", points = { { 0.1,  1   }, { 0,    1    } } })
hl.curve("overshot",     { type = "bezier", points = { { 0.05, 0.9 }, { 0.1,  1.05 } } }) -- léger rebond "spring"
hl.curve("smoothOut",    { type = "bezier", points = { { 0.36, 0   }, { 0.66, -0.56 } } })
hl.curve("borderRotate", { type = "bezier", points = { { 0.5,  0   }, { 0.5,  1    } } }) -- rotation du dégradé de bordure

hl.animation({ leaf = "windows",          enabled = true, speed = 5,   bezier = "overshot",     style = "popin 85%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4,   bezier = "smoothOut",    style = "popin 85%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "borderangle",      enabled = true, speed = 100, bezier = "borderRotate", style = "loop" }) -- dégradé de bordure qui tourne
hl.animation({ leaf = "fade",             enabled = true, speed = 6,   bezier = "default" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,   bezier = "overshot",     style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5,   bezier = "easeOutExpo",  style = "slidevert" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- décommente l'ensemble si tu veux ce comportement.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- Voir https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
hl.config({
    dwindle = {
        -- pseudotile = true, -- Interrupteur principal du pseudotiling (lié à mainMod + P plus bas)
        preserve_split = true, -- You probably want this
    },
})

-- Voir https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
hl.config({
    master = {
        new_status = "master",
    },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#misc
hl.config({
    misc = {
        force_default_wallpaper = -1,   -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- Désactivé : on utilise awww pour le fond d'écran
    },
})
