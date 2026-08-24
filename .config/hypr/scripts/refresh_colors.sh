#!/bin/bash

WAL_COLORS="$HOME/.cache/wal/colors"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.conf"
HYPR_COLORS_LUA="$HOME/.cache/wal/colors-hyprland.lua"

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
# On exporte toute la palette ($color0..$colorN) sous DEUX formes :
#   - colors-hyprland.conf : hyprlang, sourcé par hyprlock.conf (hyprlock n'a
#     pas migré vers Lua, il utilise toujours hyprlang).
#   - colors-hyprland.lua  : table Lua, chargée par modules/colors.lua depuis
#     la config Hyprland (Lua depuis Hyprland 0.55).
#
# Écriture ATOMIQUE : on remplit d'abord un fichier temporaire, puis on le
# renomme d'un coup (mv). Ainsi ni Hyprland ni hyprlock ne lisent un fichier
# vide ou partiel — sinon $color1 est indéfini et le rechargement échoue avec
# "failed to parse $color1 as a color" (voir apparence.lua / hyprlock.conf).
TMP=$(mktemp "${HYPR_COLORS}.XXXXXX")
TMP_LUA=$(mktemp "${HYPR_COLORS_LUA}.XXXXXX")

printf '%s\n' \
    '-- Palette Pywal générée par scripts/refresh_colors.sh.' \
    '-- Ne pas éditer à la main : réécrit à chaque changement de fond d'"'"'écran.' \
    'return {' >>"$TMP_LUA"

i=0
while IFS= read -r line; do
    hex=$(printf '%s' "$line" | tr -d '#')
    if [ -n "$hex" ]; then
        printf '$color%d = rgb(%s)\n' "$i" "$hex" >>"$TMP"
        printf '    color%d = "rgb(%s)",\n' "$i" "$hex" >>"$TMP_LUA"
    fi
    i=$((i + 1))
done <"$WAL_COLORS"

# foreground / background (utilisés par hyprlock) depuis colors.sh
WAL_SH="$HOME/.cache/wal/colors.sh"
if [ -s "$WAL_SH" ]; then
    FG=$(sed -n "s/^foreground='#\(.*\)'.*/\1/p" "$WAL_SH")
    BG=$(sed -n "s/^background='#\(.*\)'.*/\1/p" "$WAL_SH")
    if [ -n "$FG" ]; then
        printf '$foreground = rgb(%s)\n' "$FG" >>"$TMP"
        printf '    foreground = "rgb(%s)",\n' "$FG" >>"$TMP_LUA"
    fi
    if [ -n "$BG" ]; then
        printf '$background = rgb(%s)\n' "$BG" >>"$TMP"
        printf '    background = "rgb(%s)",\n' "$BG" >>"$TMP_LUA"
    fi
fi

printf '}\n' >>"$TMP_LUA"

# Renommage atomique (même système de fichiers → instantané et sûr).
mv -f "$TMP" "$HYPR_COLORS"
mv -f "$TMP_LUA" "$HYPR_COLORS_LUA"

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
