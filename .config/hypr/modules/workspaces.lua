--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Voir https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- et  https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

hl.window_rule({
    -- Ignore les demandes de maximisation de toutes les applis.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Corrige des soucis de drag & drop avec XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Fenêtres flottantes centrées, avec une taille imposée.
for _, rule in ipairs({
    { name = "floating-kitty",   class = "floating_kitty",              size = "1000 600", opacity = 0.95 },
    { name = "waypaper",         class = "waypaper",                    size = "400 500"  },
    { name = "gnome-calculator", class = "org.gnome.Calculator",        size = "400 600"  },
    { name = "pavucontrol",      class = "org.pulseaudio.pavucontrol",  size = "500 400"  },
    { name = "blueman-manager",  class = "blueman-manager",             size = "600 400"  },
    { name = "bitwarden",        class = "Bitwarden",                   size = "1000 500" },
    { name = "portal-gtk",       class = "xdg-desktop-portal-gtk",      size = "600 400"  },
    { name = "onlyoffice",       class = "DesktopEditors"               },
}) do
    hl.window_rule({
        name    = "float-" .. rule.name,
        match   = { class = rule.class },
        float   = true,
        center  = true,
        size    = rule.size,
        opacity = rule.opacity,
    })
end

-- Envoyer Obsidian dans le workspace spécial
hl.window_rule({
    name      = "obsidian-special",
    match     = { class = "obsidian" },
    workspace = "special",
})

-- Redimensionner les fenêtres (répétition à l'appui maintenu, delta en pixels)
local resize = { repeating = true }
hl.bind("SUPER + ALT + right", hl.dsp.window.resize({ x =  30, y =   0, relative = true }), resize)
hl.bind("SUPER + ALT + left",  hl.dsp.window.resize({ x = -30, y =   0, relative = true }), resize)
hl.bind("SUPER + ALT + up",    hl.dsp.window.resize({ x =   0, y = -30, relative = true }), resize)
hl.bind("SUPER + ALT + down",  hl.dsp.window.resize({ x =   0, y =  30, relative = true }), resize)
