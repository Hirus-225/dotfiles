#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.conf"

# Attendre que Pywal ait fini d'écrire le fichier de couleurs (max ~2s)
for _ in $(seq 1 20); do
    [ -s "$WAL_COLORS" ] && break
    sleep 0.1
done

if [ ! -s "$WAL_COLORS" ]; then
    notify-send "Erreur" "Pywal n'a pas encore généré les couleurs."
    exit 1
fi

# --- Génération pour Hyprland ---
COLOR1=$(sed -n '2p' "$WAL_COLORS" | tr -d '#')
COLOR2=$(sed -n '3p' "$WAL_COLORS" | tr -d '#')

printf '$color1 = rgb(%s)\n$color2 = rgb(%s)\n' "$COLOR1" "$COLOR2" >"$HYPR_COLORS"

# --- Rechargement des composants UI ---

# 1. Waybar
killall -SIGUSR2 waybar

# 2. SwayNC (Notification Center)
swaync-client -rs

# 3. SwayOSD : tuer puis relancer pour forcer le refresh du CSS
pkill swayosd-server
swayosd-server &

# 4. Hyprland
hyprctl reload

# Optionnel : Notification de succès
# notify-send "Système" "Couleurs mises à jour avec succès" -i "color-management"
