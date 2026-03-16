#!/bin/bash
HOUR=$(date +%H)

if [ $HOUR -lt 12 ]; then
    echo "󰖚  Bonjour, Charles !"
elif [ $HOUR -lt 18 ]; then
    echo "󰖙  Bon après-midi, Charles !"
else
    echo "󰖔  Bonsoir, Charles !"
fi
