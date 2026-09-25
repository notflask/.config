#!/usr/bin/env bash
# wlogout als zentrierte Reihe runder Buttons auf dem aktiven Monitor.
# Nochmal aufrufen (oder Esc) schließt es wieder.
#
# wlogout kennt nur Ränder in Pixeln, deshalb hier aus der Monitorgröße
# ausrechnen: n Buttons à size×size mit gap Abstand, Rest ist Rand.

pkill -x wlogout && exit 0

n=5 size=150 gap=28

read -r w h < <(niri msg -j focused-output 2>/dev/null |
  python3 -c 'import json,sys; l=json.load(sys.stdin)["logical"]; print(l["width"], l["height"])' 2>/dev/null)
w=${w:-1920} h=${h:-1080}

row=$((n * size + (n - 1) * gap))
lr=$(((w - row) / 2))
tb=$(((h - size) / 2))

exec wlogout --protocol layer-shell --no-span \
  --buttons-per-row "$n" --column-spacing "$gap" --row-spacing 0 \
  -L "$lr" -R "$lr" -T "$tb" -B "$tb"
