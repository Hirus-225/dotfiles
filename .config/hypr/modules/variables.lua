-------------------------------
---- VARIABLES D'ENVIRONNEMENT ----
-------------------------------

-- Voir https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- hl.env("XCURSOR_THEME", "Adwaita")   -- décommente pour figer le thème de curseur

-- --- Wayland natif pour les applis (évite XWayland : flou HiDPI, pas de blur) ---
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")      -- Bitwarden, Obsidian (Electron)
hl.env("MOZ_ENABLE_WAYLAND", "1")                   -- Firefox
hl.env("GDK_BACKEND", "wayland,x11")                -- apps GTK (fallback X11 si besoin)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")            -- apps Qt (fallback xcb si besoin)
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")  -- pas de barre de titre Qt en double
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")          -- scaling Qt correct en HiDPI
