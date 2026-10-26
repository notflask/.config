#!/usr/bin/env bash
# Anzeige für hyprlock (cmd[...], reload_cmd und onclick in hyprlock.conf)
#
#   hyprlock-status.sh media-card      Pfad der Musikkarte (leeres Bild ohne Musik)
#   hyprlock-status.sh button prev|toggle|next
#                                      Bild des Knopfs (leeres Bild ohne Musik)
#   hyprlock-status.sh weather         Wetter (Open-Meteo, alle 20 min)
#   hyprlock-status.sh status          VPN, Netz (nur Symbole) und Akku oben rechts
#   hyprlock-status.sh notifications   Mitteilungen seit dem Sperren
#
# Alles muss schnell zurückkehren: hyprlock wartet auf die Ausgabe. Was
# dauert (Karte zeichnen, Wetter laden), läuft im Hintergrund, die Ausgabe
# kommt beim nächsten Aufruf.

cache=${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock
here=${XDG_CONFIG_HOME:-$HOME/.config}/hypr
mkdir -p "$cache/cards"

# Hintergrund, vom Aufrufer gelöst (hyprlock wartet sonst auf das Ende)
detach() { setsid -f "$@" </dev/null >/dev/null 2>&1; }

# Zustand des zuletzt aktiven Players (playerctld): Playing, Paused oder leer
player_status() { playerctl status 2>/dev/null; }

case ${1:-} in
  media-card)
    sep=$'\x1f'
    IFS=$sep read -r st title artist player art < <(
      playerctl metadata --format "{{status}}$sep{{title}}$sep{{artist}}$sep{{playerName}}$sep{{mpris:artUrl}}" 2>/dev/null
    )
    case $st in Playing | Paused) ;; *) title= ;; esac
    if [ -z "$title" ]; then
      echo "$cache/blank.png"
      exit
    fi
    key=$(printf '%s\x1f' "$title" "$artist" "$player" "$art" | md5sum | cut -c1-16)
    card=$cache/cards/$key.png
    if [ -f "$card" ]; then
      echo "$card" >"$cache/card-current"
      echo "$card"
      exit
    fi
    # Neu zeichnen (Albumbild evtl. erst laden); bis dahin die vorige Karte
    if mkdir "$cache/cards/$key.lock" 2>/dev/null; then
      detach sh -c '"$1" card "$2" "$3" "$4" "$5" "$6"; rmdir "$2.lock"' _ \
        "$here/hyprlock-art.py" "$card" "$title" "$artist" "$player" "$art"
    fi
    cat "$cache/card-current" 2>/dev/null || echo "$cache/blank.png"
    ;;

  button)
    st=$(player_status)
    name=${2:-}
    case $st in
      Playing) [ "$name" = toggle ] && name=pause ;;
      Paused) [ "$name" = toggle ] && name=play ;;
      *) name=blank ;;
    esac
    [ -f "$cache/buttons/$name.png" ] && echo "$cache/buttons/$name.png" || echo "$cache/blank.png"
    ;;

  weather)
    # Ort wie in matugen/theme-sun.py (Berlin) – nicht per IP, die zeigt
    # mit VPN auf den Server
    lat=52.52 lon=13.405
    file=$cache/weather
    if [ -z "$(find "$file" -mmin -20 2>/dev/null)" ] && mkdir "$file.lock" 2>/dev/null; then
      detach sh -c '
        curl -fsS --max-time 6 "https://api.open-meteo.com/v1/forecast?latitude=$1&longitude=$2&current=temperature_2m,weather_code,is_day&timezone=auto" |
          jq -r "[.current.temperature_2m, .current.weather_code, .current.is_day] | @tsv" >"$3.tmp" &&
          [ -s "$3.tmp" ] && mv -f "$3.tmp" "$3"
        rm -f "$3.tmp"; rmdir "$3.lock"' _ "$lat" "$lon" "$file"
    fi
    # Nach 3 h ohne Netz nichts mehr zeigen (veraltet)
    [ -n "$(find "$file" -mmin -180 2>/dev/null)" ] || exit 0
    IFS=$'\t' read -r temp code day <"$file" || exit 0
    # WMO-Wettercodes
    case $code in
      0) [ "$day" = 1 ] && icon="󰖙" || icon="󰖔"; text="Klar" ;;
      1) [ "$day" = 1 ] && icon="󰖕" || icon="󰼱"; text="Überwiegend klar" ;;
      2) [ "$day" = 1 ] && icon="󰖕" || icon="󰼱"; text="Teilweise bewölkt" ;;
      3) icon="󰖐"; text="Bedeckt" ;;
      45 | 48) icon="󰖑"; text="Nebel" ;;
      51 | 53 | 55 | 56 | 57) icon="󰖗"; text="Nieselregen" ;;
      61 | 63 | 66 | 80 | 81) icon="󰖗"; text="Regen" ;;
      65 | 67 | 82) icon="󰖖"; text="Starker Regen" ;;
      71 | 73 | 75 | 77 | 85 | 86) icon="󰖘"; text="Schnee" ;;
      95 | 96 | 99) icon="󰖓"; text="Gewitter" ;;
      *) icon="󰖐"; text="" ;;
    esac
    printf '%s  %s°%s\n' "$icon" "$(LC_ALL=C printf '%.0f' "$temp")" "${text:+  ·  $text}"
    ;;

  status)
    out=()
    # VPN (wie in der Taskleiste): an, verbindet, aus
    case $("$here/../quickshell/taskbar/scripts/vpn.sh" 2>/dev/null | head -n1) in
      on) out+=("󰦝") ;;
      pending) out+=("󰦞") ;;
      open) out+=("<span foreground='#ffb4ab'>󰦞</span>") ;;
    esac
    # Netz: Kabel vor WLAN
    net=$(nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null)
    if grep -q '^ethernet:connected:' <<<"$net"; then
      out+=("󰈀")
    elif grep -q '^wifi:connected:' <<<"$net"; then
      out+=("󰖩")
    else
      out+=("󰖪")
    fi
    # Akku
    for bat in /sys/class/power_supply/BAT*; do
      [ -r "$bat/capacity" ] || continue
      cap=$(<"$bat/capacity") state=$(<"$bat/status")
      icons=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
      icon=${icons[cap / 10]}
      case $state in Charging) icon="󰂄" ;; Full | "Not charging") icon="󰚥" ;; esac
      if [ "$cap" -le 15 ] && [ "$state" = Discharging ]; then
        out+=("<span foreground='#ffb4ab'>$icon  $cap %</span>")
      else
        out+=("$icon  $cap %")
      fi
      break
    done
    line=${out[0]}
    for item in "${out[@]:1}"; do line+="  $item"; done
    echo "$line"
    ;;

  notifications)
    # Erste Abfrage nach dem Sperren merkt sich die neueste ID; gezählt wird,
    # was danach kam (wie „Mitteilungen“ unter macOS). Nur App-Namen, kein
    # Inhalt – der Bildschirm ist ja gesperrt.
    command -v makoctl >/dev/null || exit 0
    lock=$(pidof -s hyprlock) || exit 0
    base_file=${XDG_RUNTIME_DIR:-/tmp}/hyprlock-notify-base
    all=$({ makoctl list -j; makoctl history -j; } 2>/dev/null | jq -s 'add // []')
    newest=$(jq '[.[].id] | max // 0' <<<"$all")
    read -r pid base 2>/dev/null <"$base_file"
    if [ "$pid" != "$lock" ]; then
      echo "$lock $newest" >"$base_file"
      exit 0
    fi
    jq -r --argjson base "$base" '
      [.[] | select(.id > $base)] | unique_by(.id) | length as $n |
      if $n == 0 then empty else
        ([.[].app_name | select(. != "" and . != "notify-send")] | unique | .[:3] | join(", ")) as $apps |
        "󰂚  \($n) \(if $n == 1 then "Mitteilung" else "Mitteilungen" end)\(if $apps != "" then "  ·  " + $apps else "" end)"
      end' <<<"$all" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
    ;;
esac
