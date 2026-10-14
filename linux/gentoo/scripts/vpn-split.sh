# vpn-split – Split-Tunneling (am VPN vorbei).
# bypass_file und bypass_edit setzt files/bin/vpn-split davor.
#
#   vpn-split apps                 Apps, die immer am VPN vorbei starten
#   vpn-split add|remove APP_ID    App hinzufügen/entfernen (Desktop-ID)
#   vpn-split sync                 Starter neu erzeugen (nach Updates)
#   vpn-split running              Programme, die gerade am VPN vorbei laufen
#   vpn-split domains              Ziele für alle Programme
#   vpn-split domain-add|domain-remove ZIEL
#
# Apps: Für jede App liegt eine Kopie ihres Starters in
# ~/.local/share/applications, deren Exec-Zeilen mit `novpn` beginnen. Der
# verdeckt den Starter des Systems – Startmenü, Rofi, Autostart und
# xdg-open starten die App so am VPN vorbei. Eine schon laufende App muss
# einmal neu gestartet werden.

config=${XDG_CONFIG_HOME:-$HOME/.config}/vpn-split
list=$config/apps
apps_dir=${XDG_DATA_HOME:-$HOME/.local/share}/applications
marker=X-Vpn-Split=true
# sudo aus dem normalen PATH
sudo=sudo

apps() {
  [ -f "$list" ] && grep -v '^$' "$list" || true
}

listed() {
  grep -qxF -- "$1" "$list" 2>/dev/null
}

# Starter des Systems (nicht unsere eigene Kopie)
source_of() {
  local dir file
  IFS=: read -ra dirs <<<"${XDG_DATA_DIRS:-/run/current-system/sw/share:/usr/local/share:/usr/share}"
  for dir in "${dirs[@]}"; do
    file=$dir/applications/$1.desktop
    [ -f "$file" ] && ! grep -qx "$marker" "$file" && echo "$file" && return
  done
  return 1
}

generate() {
  local id=$1 src out
  out=$apps_dir/$id.desktop
  if [ -f "$out" ] && ! grep -qx "$marker" "$out"; then
    echo "vpn-split: $out ist ein eigener Starter, bleibt unverändert" >&2
    return 1
  fi
  if ! src=$(source_of "$id"); then
    echo "vpn-split: kein Starter für $id gefunden" >&2
    return 1
  fi
  mkdir -p "$apps_dir"
  # D-Bus-Aktivierung umgeht Exec, deshalb raus
  sed -e '/^DBusActivatable=/d' \
    -e 's/^Exec=\(novpn \)\?/Exec=novpn /' \
    -e "0,/^\[Desktop Entry\]/s//[Desktop Entry]\n$marker/" \
    "$src" >"$out.tmp"
  mv "$out.tmp" "$out"
}

sync() {
  local file id
  for file in "$apps_dir"/*.desktop; do
    if [ -f "$file" ] && grep -qx "$marker" "$file"; then
      id=$(basename "$file" .desktop)
      listed "$id" || rm -f "$file"
    fi
  done
  apps | while read -r id; do generate "$id" || true; done
}

case ${1:-apps} in
  apps) apps ;;
  add)
    id=${2:?Desktop-ID angeben, z. B. firefox}
    id=${id%.desktop}
    generate "$id"
    mkdir -p "$config"
    listed "$id" || echo "$id" >>"$list"
    ;;
  remove)
    id=${2:?Desktop-ID angeben}
    id=${id%.desktop}
    mkdir -p "$config"
    apps | grep -vxF -- "$id" >"$list.tmp" || true
    mv "$list.tmp" "$list"
    sync
    ;;
  sync) sync ;;
  running)
    # Name des Programms zu einer PID (ohne Pfad)
    exe_of() {
      local exe
      IFS= read -r -d '' exe <"/proc/$1/cmdline" 2>/dev/null || [ -n "${exe:-}" ] || return 0
      exe=${exe##*/}
      exe=${exe#.}
      echo "${exe%-wrapped}"
    }
    slice=/sys/fs/cgroup/user.slice/user-$UID.slice/user@$UID.service/novpn.slice
    if [ -d "$slice" ]; then
      # systemd: erster Prozess jeder Scope in novpn.slice = das gestartete Programm
      for procs in "$slice"/*.scope/cgroup.procs; do
        [ -f "$procs" ] || continue
        read -r pid <"$procs" || continue
        [ -n "$pid" ] && exe_of "$pid"
      done | sort -u
    elif [ -r /sys/fs/cgroup/novpn/cgroup.procs ]; then
      # Eine gemeinsame cgroup (novpn-join) – Programme, deren
      # Elternprozess nicht selbst darin läuft, eigene zuerst
      mapfile -t pids </sys/fs/cgroup/novpn/cgroup.procs
      for pid in "${pids[@]}"; do
        [ -O "/proc/$pid" ] || continue
        read -r _ _ _ ppid _ <"/proc/$pid/stat" 2>/dev/null || continue
        case " ${pids[*]} " in *" $ppid "*) continue ;; esac
        exe_of "$pid"
      done | sort -u
    fi
    ;;
  domains) [ -f "$bypass_file" ] && grep -v '^[[:space:]]*\(#\|$\)' "$bypass_file" || true ;;
  domain-add) "$sudo" -n "$bypass_edit" add "${2:?Ziel angeben}" ;;
  domain-remove) "$sudo" -n "$bypass_edit" remove "${2:?Ziel angeben}" ;;
  *)
    echo "vpn-split apps | add ID | remove ID | sync | running | domains | domain-add ZIEL | domain-remove ZIEL" >&2
    exit 2
    ;;
esac
