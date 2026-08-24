#!/bin/bash
# Rétroéclairage du clavier (MacBook, LED smc::kbd_backlight) + retour visuel SwayOSD.
# SwayOSD ne sait pas piloter la classe "leds", on passe donc par brightnessctl
# et on affiche l'OSD nous-mêmes via --custom-progress.
#
# Usage : kbd_backlight.sh up | down

DEV="smc::kbd_backlight"
STEP=15   # pas en pourcentage

case "$1" in
    up)   brightnessctl -q -d "$DEV" set "+${STEP}%" ;;
    down) brightnessctl -q -d "$DEV" set "${STEP}%-" ;;
    *)    echo "Usage: $0 up|down" >&2; exit 1 ;;
esac

cur=$(brightnessctl -d "$DEV" get)
max=$(brightnessctl -d "$DEV" max)
progress=$(awk "BEGIN{printf \"%.2f\", $cur/$max}")

swayosd-client --custom-icon keyboard-brightness-symbolic --custom-progress "$progress"
