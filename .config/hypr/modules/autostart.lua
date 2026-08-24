-------------------
---- AUTOSTART ----
-------------------

-- Voir https://wiki.hypr.land/Configuring/Basics/Autostart/
-- Équivalent Lua des anciens `exec-once` : on s'abonne à l'événement
-- "hyprland.start", qui ne se déclenche qu'au démarrage (pas sur `hyprctl reload`).

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/waybar/scripts/launch.sh")
    hl.exec_cmd("nm-applet --indicator")   -- Wi-Fi
    hl.exec_cmd("blueman-applet")          -- Bluetooth
    hl.exec_cmd("awww-daemon 2>/dev/null &")
    hl.exec_cmd("wal -i /home/zogoue_charles/Images/Wallpapers/od_outrun_wave.png && ~/.config/hypr/scripts/refresh_colors.sh")
    hl.exec_cmd("sleep 1 && awww restore --transition-type wave --transition-angle 45 --transition-duration 2")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Agent polkit (élévations GUI : blueman, gnome-disks, montages…)
    -- Nécessite le paquet : yay -S hyprpolkitagent
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("swayosd-libinput-backend")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("rclone mount gdrive: /home/zogoue_charles/google-drive --vfs-cache-mode writes --vfs-cache-max-age 24h --vfs-cache-max-size 5G &")
end)
