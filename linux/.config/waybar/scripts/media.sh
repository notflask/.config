#!/usr/bin/env bash
# Waybar-Medienwidget (group/media in config-base): Cover, Titel, Steuerung.
#   media.sh                  custom/media: Titel · Interpret, Tooltip mit Details,
#                             lädt nebenbei das Cover und weckt image#cover
#   media.sh cover            image#cover: Pfad zum aktuellen Cover
#   media.sh button prev|play|next
#                             Steuerknöpfe (nur sichtbar, wenn ein Player läuft)
#
# Alle Modi laufen dauerhaft mit `playerctl --follow` und geben nur bei
# Änderungen etwas aus. Welcher Player gemeint ist, entscheidet playerctld
# (zuletzt aktiver Player, wird von niri gestartet).

signal=9 # "signal" von image#cover
dir=${XDG_RUNTIME_DIR:-/tmp}/waybar-media
cover=$dir/cover.png
mkdir -p "$dir"

dim='#9399b2'

wake_cover() { pkill -RTMIN+$signal -x 'waybar|\.waybar-wrapped'; }

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  printf '%s' "$s"
}

# $1 Text, $2 Klasse, $3 Tooltip. Schreiben fehlgeschlagen = Waybar weg → beenden
out() {
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
    "$(json_escape "$1")" "$2" "$(json_escape "$3")" || exit
}

# `playerctl --follow ARGS` als Eingabe auf $feed öffnen. Die Schleife liest
# dann im Skript selbst (keine Pipe-Subshell), und playerctl endet mit dem
# Skript: Waybar beendet beim Neustart nur dieses Skript, und SIGPIPE erbt es
# von Waybar als ignoriert – ohne das liefen alte Instanzen ewig weiter und
# überschrieben das Cover mit ihrer eigenen Version.
follow() {
  exec {feed}< <(exec playerctl --follow "$@" 2>/dev/null)
  feed_pid=$!
  trap 'kill "$feed_pid" 2>/dev/null' EXIT
  trap exit TERM INT HUP
}

nf() { printf "<span font_family='Symbols Nerd Font' size='13pt' rise='-1pt'>%s</span>" "$1"; }

# Cover holen, abrunden (wenn ImageMagick da ist) und als cover.png verlinken.
# Läuft im Hintergrund; bei schnellem Titelwechsel gewinnt nur der aktuelle.
fetch_cover() {
  local url=$1 key file tmp
  key=$(printf '%s' "$url" | md5sum | cut -c1-16)
  # eigener Name je Form, damit nach dem Installieren von ImageMagick kein
  # eckiges Cover aus dem Cache kommt
  if command -v magick >/dev/null; then file=$dir/$key-kreis.png
  else file=$dir/$key-eckig.png; fi
  if [ ! -s "$file" ]; then
    tmp=$(mktemp "$dir/dl.XXXXXX")
    case $url in
      file://*) local path=${url#file://}  # %20 usw. dekodieren
                cp -- "$(printf '%b' "${path//%/\\x}")" "$tmp" 2>/dev/null ;;
      http*)    curl -sfL --max-time 10 -o "$tmp" -- "$url" ;;
    esac
    if [ -s "$tmp" ]; then
      if [[ $file = *-kreis.png ]]; then
        # rund ausschneiden, dazu ein feiner heller Rand wie bei den Glas-Pillen
        magick "$tmp" -alpha set -resize 128x128^ -gravity center -extent 128x128 \
          \( -size 128x128 xc:none -fill white -draw 'circle 63.5,63.5 63.5,0' \) \
          -compose DstIn -composite -compose Over \
          -fill none -stroke 'rgba(255,255,255,0.45)' -strokewidth 5 \
          -draw 'circle 63.5,63.5 63.5,2.5' "PNG32:$file" 2>/dev/null
      else
        cp "$tmp" "$file"
      fi
    fi
    rm -f "$tmp"
  fi
  # inzwischen ein anderer Titel? Dann nichts überschreiben
  [ "$(cat "$dir/url" 2>/dev/null)" = "$url" ] || return
  if [ -s "$file" ]; then ln -sfn "$file" "$cover"; else rm -f "$cover"; fi
  wake_cover
  # alte Cover aufräumen, die letzten 20 behalten
  ls -t "$dir"/*.png 2>/dev/null | grep -v '/cover.png$' | tail -n +21 | xargs -r rm -f
}

case ${1:-} in
  cover)
    # Ohne Ausgabe behält Waybar den alten Pfad und zeigt das letzte Cover
    # weiter (die Datei liegt ja noch im Cache) – daher bewusst ein Pfad,
    # den es nicht gibt, dann blendet Waybar das Modul aus.
    if [ -e "$cover" ]; then readlink -f "$cover"; else echo "$dir/kein-cover"; fi
    exit ;;

  button)
    case $2 in
      prev) icon=󰒮 tip='Vorheriger Titel' ;;
      next) icon=󰒭 tip='Nächster Titel' ;;
    esac
    follow status
    while read -r -u "$feed" status; do
      case $2:$status in
        *:)            out '' '' '' ;;
        play:Playing)  out "$(nf 󰏤)" playing 'Pause' ;;
        play:*)        out "$(nf 󰐊)" paused 'Abspielen' ;;
        *)             out "$(nf "$icon")" "${status,,}" "$tip" ;;
      esac
    done
    exit ;;
esac

rm -f "$cover" "$dir/url"
wake_cover

s=$'\x1f'
fmt="{{status}}$s{{markup_escape(title)}}$s{{markup_escape(artist)}}$s{{markup_escape(album)}}$s{{playerName}}$s{{duration(mpris:length)}}$s{{mpris:artUrl}}"

follow metadata --format "$fmt"
while IFS=$s read -r -u "$feed" status title artist album player length art; do
  # Cover nur bei Änderung neu holen
  if [ "$art" != "$(cat "$dir/url" 2>/dev/null)" ]; then
    printf '%s' "$art" > "$dir/url"
    if [ -n "$art" ]; then
      fetch_cover "$art" &
    else
      rm -f "$cover"
      wake_cover
    fi
  fi

  if [ -z "$status" ] || [ -z "$title$artist" ]; then
    out '' '' ''
    continue
  fi

  text="<b>${title:-Unbekannt}</b>"
  [ -n "$artist" ] && text+="<span alpha='60%'>  ·  $artist</span>"

  case $status in
    Playing) state=Wiedergabe ;;
    Paused)  state=Pausiert ;;
    *)       state=Gestoppt ;;
  esac
  name=${player%%.*}
  name=${name^}

  tip="<span size='large' weight='bold'>${title:-Unbekannt}</span>"
  [ -n "$artist" ] && tip+=$'\n'"$artist"
  [ -n "$album" ] && tip+=$'\n'"<span foreground='$dim'>$album</span>"
  tip+=$'\n\n'"<span foreground='$dim' size='small'>$name · $state${length:+ · $length}</span>"
  tip+=$'\n'"<span foreground='$dim' size='small'>Klick: Play/Pause · Scrollen: Titel wechseln</span>"

  out "$text" "${status,,}" "$tip"
done
