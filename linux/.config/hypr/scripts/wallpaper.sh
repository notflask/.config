#!/bin/bash

CURRENT=$(awww query | grep -oP '(?<=image: ).*' | head -1)
matugen image "$CURRENT" --source-color-index 0
killall -SIGUSR2 waybar
