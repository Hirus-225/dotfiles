#!/bin/bash
# 1. Change le fond d'écran et génère les couleurs
wal -i "$1"

# 2. Régénère le fichier pour Hyprland (la commande qu'on a vu avant)
cat <<EOF > ~/.cache/wal/colors-hyprland.conf
\$color1 = rgb($(cat ~/.cache/wal/colors | sed -n '2p' | sed 's/#//'))
\$color2 = rgb($(cat ~/.cache/wal/colors | sed -n '3p' | sed 's/#//'))
EOF

# 3. Force Waybar à recharger ses couleurs
killall -SIGUSR2 waybar
