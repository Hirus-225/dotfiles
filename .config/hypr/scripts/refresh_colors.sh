#!/bin/bash

# Attendre un court instant que Pywal finisse d'écrire
sleep 0.5

# Vérifier si le fichier de couleurs de Pywal existe
if [ -f ~/.cache/wal/colors ]; then
    # --- Génération pour Hyprland ---
    COLOR1=$(cat ~/.cache/wal/colors | sed -n '2p' | sed 's/#//')
    COLOR2=$(cat ~/.cache/wal/colors | sed -n '3p' | sed 's/#//')

    echo "\$color1 = rgb($COLOR1)" >~/.cache/wal/colors-hyprland.conf
    echo "\$color2 = rgb($COLOR2)" >>~/.cache/wal/colors-hyprland.conf

    # --- Rechargement des composants UI ---

    # 1. Waybar
    killall -SIGUSR2 waybar

    # 2. SwayNC (Notification Center)
    swaync-client -rs

    # 3. SwayOSD (Le widget de volume/luminosité)
    # On tue le serveur actuel et on le relance pour forcer le refresh du CSS
    pkill swayosd-server
    swayosd-server &

    sleep 3

    # 4. Hyprland
    hyprctl reload

    # Optionnel : Notification de succès
    # notify-send "Système" "Couleurs mises à jour avec succès" -i "color-management"
else
    notify-send "Erreur" "Pywal n'a pas encore généré les couleurs."
fi
