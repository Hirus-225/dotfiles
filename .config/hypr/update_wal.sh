#!/bin/bash
# Génère les couleurs avec Pywal
wal -i "$1"

# Crée le pont pour Hyprland
cat <<EOF > ~/.cache/wal/colors-hyprland.conf
\$color1 = rgb($(cat ~/.cache/wal/colors | sed -n '2p' | sed 's/#//'))
\$color2 = rgb($(cat ~/.cache/wal/colors | sed -n '3p' | sed 's/#//'))
EOF
