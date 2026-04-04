#!/bin/bash

# 1. On lance Waybar en premier
pkill waybar
waybar &

# 2. On attend que Waybar soit totalement stable (3 secondes)
sleep 3
