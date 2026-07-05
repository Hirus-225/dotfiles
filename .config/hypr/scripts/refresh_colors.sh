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
# On exporte toute la palette ($color0..$colorN) pour que hyprland.conf ET
# hyprlock.conf puissent référencer n'importe quelle couleur (ex. $color4).
: >"$HYPR_COLORS"
i=0
while IFS= read -r line; do
    hex=$(printf '%s' "$line" | tr -d '#')
    [ -n "$hex" ] && printf '$color%d = rgb(%s)\n' "$i" "$hex" >>"$HYPR_COLORS"
    i=$((i + 1))
done <"$WAL_COLORS"

# foreground / background (utilisés par hyprlock) depuis colors.sh
WAL_SH="$HOME/.cache/wal/colors.sh"
if [ -s "$WAL_SH" ]; then
    FG=$(sed -n "s/^foreground='#\(.*\)'.*/\1/p" "$WAL_SH")
    BG=$(sed -n "s/^background='#\(.*\)'.*/\1/p" "$WAL_SH")
    [ -n "$FG" ] && printf '$foreground = rgb(%s)\n' "$FG" >>"$HYPR_COLORS"
    [ -n "$BG" ] && printf '$background = rgb(%s)\n' "$BG" >>"$HYPR_COLORS"
fi

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
