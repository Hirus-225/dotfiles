#!/bin/bash

# 1. On lance Waybar en premier
pkill waybar
waybar &

# 2. On attend que Waybar soit totalement stable (3 secondes)
sleep 3

# 3. On lance 1Password en mode "silencieux" (dans le tray)
# L'option --silent permet de ne pas ouvrir la fenêtre principale
1password --silent &
