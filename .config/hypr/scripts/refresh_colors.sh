#!/bin/bash

# Attendre un court instant que Pywal finisse d'écrire
sleep 0.5

# Vérifier si le fichier de couleurs de Pywal existe
if [ -f ~/.cache/wal/colors ]; then
    # Génération sécurisée du fichier pour Hyprland
    COLOR1=$(cat ~/.cache/wal/colors | sed -n '2p' | sed 's/#//')
    COLOR2=$(cat ~/.cache/wal/colors | sed -n '3p' | sed 's/#//')

    # On écrit le fichier proprement
    echo "\$color1 = rgb($COLOR1)" >~/.cache/wal/colors-hyprland.conf
    echo "\$color2 = rgb($COLOR2)" >>~/.cache/wal/colors-hyprland.conf

    # Recharger Waybar
    killall -SIGUSR2 waybar

    # Recharger SwayNC
    swaync-client -rs

    # Forcer Hyprland à relire sa config pour effacer l'erreur rouge
    hyprctl reload
else
    notify-send "Erreur" "Pywal n'a pas encore généré les couleurs."
fi
