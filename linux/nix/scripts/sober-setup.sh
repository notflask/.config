#!/usr/bin/env bash
# ============================================================
#  sober-setup – richtet Sober (Roblox, Flatpak) ein: MangoHud-Overlay,
#  Shader-Cache ohne Aufräumen, Discord-RPC-Zugriff.
#  Wird von gaming.nix als Befehl `sober-setup` installiert.
#  Alles passiert auf Benutzerebene (kein sudo) und ist wiederholbar.
# ============================================================

set -euo pipefail

app=org.vinegarhq.Sober
ext=org.freedesktop.Platform.VulkanLayer.MangoHud
branch=25.08 # = Freedesktop-Basis der GNOME-Runtime von Sober
sandbox_cfg="$HOME/.var/app/$app/config/MangoHud"

usage() {
  cat <<'HELP'
Benutzung:  sober-setup [on|off|status]

  on      (Standard) MangoHud-Erweiterung installieren, Overrides setzen,
          MangoHud.conf in die Sandbox kopieren
  off     alle Overrides von Sober zurücksetzen (nur Discord-Zugriff bleibt)
  status  zeigt Erweiterung und aktive Overrides

MangoHud in Roblox ein-/ausblenden: Shift rechts + F12
HELP
}

discord_access() {
  # Discord-RPC („Spielt Roblox“): Sober braucht den Socket von Discord
  flatpak override --user "$app" \
    --filesystem=xdg-run/app/com.discordapp.Discord:create \
    --filesystem=xdg-run/discord-ipc-0
}

sync_conf() {
  # Die Sandbox sieht ~/.config nicht (und der Symlink ins Repo wäre dort
  # ohnehin kaputt) → Kopie; theme.sh hält sie bei Themenwechsel aktuell
  local src="$HOME/.config/MangoHud/MangoHud.conf"
  [ -f "$src" ] || return 0
  mkdir -p "$sandbox_cfg"
  cp -f "$src" "$sandbox_cfg/MangoHud.conf"
}

cmd=${1:-on}
case "$cmd" in
  on)
    command -v flatpak >/dev/null || {
      echo "sober-setup: flatpak fehlt" >&2
      exit 1
    }
    flatpak info --user "$app" >/dev/null 2>&1 || {
      echo "sober-setup: Sober ist nicht installiert (siehe README)" >&2
      exit 1
    }
    if ! flatpak info --user "$ext//$branch" >/dev/null 2>&1; then
      flatpak install --user --noninteractive flathub "$ext//$branch"
    fi
    # Roblox läuft hier über OpenGL (Vulkan tippt unter Niri/NVIDIA nicht,
    # niri#2682). Die Vulkan-Ebene greift daher nicht → wie das `mangohud`-
    # Skript der Erweiterung per LD_PRELOAD einhängen ($LIB wählt der Linker).
    # shellcheck disable=SC2016
    flatpak override --user "$app" \
      --env=MANGOHUD=1 \
      --env='LD_PRELOAD=/usr/lib/extensions/vulkan/MangoHud/$LIB/libMangoHud_shim.so' \
      --env=__GL_SHADER_DISK_CACHE=1 \
      --env=__GL_SHADER_DISK_CACHE_SIZE=4294967296 \
      --env=__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
    discord_access
    sync_conf
    echo "Fertig. Sober neu starten; HUD: Shift rechts + F12."
    ;;
  off)
    flatpak override --user --reset "$app"
    discord_access
    echo "Overrides zurückgesetzt."
    ;;
  status)
    flatpak info --user "$ext//$branch" >/dev/null 2>&1 &&
      echo "Erweiterung: installiert" || echo "Erweiterung: fehlt"
    flatpak override --user --show "$app"
    ;;
  -h | --help | help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
