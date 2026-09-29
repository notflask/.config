#!/usr/bin/env bash
# wlogout als zentrierte Reihe runder Buttons auf dem aktiven Monitor.
# Nochmal aufrufen (oder Esc) schließt es wieder.
#
# wlogout kennt nur Ränder in Pixeln, deshalb hier aus der Monitorgröße
# ausrechnen: n Buttons à size×size mit gap Abstand, Rest ist Rand.

pkill -x wlogout && exit 0

n=5 size=150 gap=28

# Größe des aktiven Monitors (logische Pixel) von Niri bzw. Hyprland
if [ -n "${NIRI_SOCKET:-}" ]; then
  read -r w h < <(niri msg -j focused-output 2>/dev/null |
    jq -r '.logical | "\(.width) \(.height)"' 2>/dev/null)
elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  read -r w h < <(hyprctl -j monitors 2>/dev/null |
    jq -r '.[] | select(.focused) | "\(.width / .scale | floor) \(.height / .scale | floor)"' 2>/dev/null)
fi
w=${w:-1920} h=${h:-1080}

row=$((n * size + (n - 1) * gap))
lr=$(((w - row) / 2))
tb=$(((h - size) / 2))

exec wlogout --protocol layer-shell --no-span \
  --buttons-per-row "$n" --column-spacing "$gap" --row-spacing 0 \
  -L "$lr" -R "$lr" -T "$tb" -B "$tb"
