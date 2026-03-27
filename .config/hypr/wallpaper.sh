#!/bin/bash
# Dossier contenant tes images
DIR="/home/zogoue_charles/Images/Wallpaper"
# Sélectionne une image au hasard
PICS=($DIR/*)
RANDOM_PIC=${PICS[$RANDOM%${#PICS[@]}]}

# Applique l'image avec une transition aléatoire
swww img "$RANDOM_PIC" --transition-type random --transition-step 90

