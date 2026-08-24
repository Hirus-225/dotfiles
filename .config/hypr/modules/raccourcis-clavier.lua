---------------------
---- KEYBINDINGS ----
---------------------

-- Voir https://wiki.hypr.land/Configuring/Basics/Binds/

local prog = require("modules.my_programs")

local mainMod = "SUPER" -- Touche "Windows"/"Cmd" comme modificateur principal

hl.bind(mainMod .. " + N",           hl.dsp.exec_cmd(prog.fileManager))
hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd(prog.menu))
hl.bind(mainMod .. " + P",           hl.dsp.window.pseudo())          -- dwindle
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))    -- dwindle
hl.bind(mainMod .. " + T",           hl.dsp.exec_cmd(prog.terminal))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q",   hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + M",           hl.dsp.exit())
hl.bind(mainMod .. " + V",           hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("kitty --class floating_kitty"))

hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("proton-pass"))
hl.bind(mainMod .. " + L",           hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + B",   hl.dsp.exec_cmd("killall waybar && waybar &")) -- Bouton d'urgence barre
hl.bind(mainMod .. " + W",           hl.dsp.exec_cmd("waypaper"))
hl.bind(mainMod .. " + R",           hl.dsp.exec_cmd("~/.config/waybar/scripts/launch.sh"))

-- Utilise le style de ton launcher actuel pour le presse-papier
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(
    [[cliphist list | rofi -dmenu -theme ~/.config/rofi/launchers/type-2/style-1.rasi -p "History" | cliphist decode | wl-copy]]
))

-- hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("/home/zogoue_charles/.local/bin/powermenu.sh"))

-- Toggle Fullscreen (Mode Focus)
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(0))

-- --- SECTION SCRATCHPAD (SUPER + S) ---
-- Envoie la fenêtre active dans le tiroir caché
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
-- Affiche/Cache le tiroir (toggle)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())

-- Navigation (Focus)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Navigation (Workspaces) + déplacement de fenêtre vers un workspace
for i = 1, 10 do
    local key = i % 10 -- 10 est mappé sur la touche 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- Switch de workspace avec la molette (ou défilement trackpad + Cmd)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Plugins
-- Les dispatchers de plugins passent désormais par le namespace `hl.plugin`
-- (ex. hl.plugin.hyprexpo...). Voir la doc du plugin ; l'ancien binding
-- `bind = $mainMod, E, hyprexpo:expo, toggle` était déjà désactivé.

--------------------------------
---   SCREENSHOTS (SECURE)   ---
--------------------------------

-- Sélectionner une zone -> Presse-papier (Rapide & intuitif)
hl.bind("SUPER + C", hl.dsp.exec_cmd(
    [[grim -g "$(slurp)" - | wl-copy && notify-send -t 2000 "Capture d'écran" "Zone copiée dans le presse-papier"]]
))

-- Tout l'écran -> Presse-papier
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(
    [[grim - | wl-copy && notify-send -t 2000 "Capture d'écran" "Écran copié dans le presse-papier"]]
))

-- Sélectionner une zone -> Enregistrer dans ~/Images (Archive)
hl.bind("SUPER + CONTROL + C", hl.dsp.exec_cmd(
    [[f="$HOME/Images/$(date +'%Y-%m-%d_%Hh%Mm%Ss').png"; grim -g "$(slurp)" "$f" && notify-send -t 2500 "Capture d'écran" "Enregistrée : $f"]]
))

-- Verrouiller quand on ferme le capot
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprlock"), { locked = true })
