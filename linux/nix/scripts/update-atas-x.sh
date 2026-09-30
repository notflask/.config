#!/usr/bin/env bash
# ============================================================
#  ATAS X auf den neuesten Linux-Build aus ATAS' Alpha-Kanal
#  setzen (schreibt pkgs/atas-x/source.json).
#  Läuft automatisch bei `rebuild update`.
# ============================================================

set -euo pipefail

CHANNEL="https://updates.orderflowtrading.net/v2/platformx_linux_alpha"
SOURCE_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pkgs/atas-x/source.json"

# Neueste Version aus dem Verzeichnis-Listing lesen
version="$(curl -fsSL "$CHANNEL/" |
  grep -oE 'atasx_linux_[0-9.]+[0-9]\.tar\.gz' |
  sed -E 's/^atasx_linux_(.*)\.tar\.gz$/\1/' |
  sort -uV | tail -n 1)"

if [ -z "$version" ]; then
  echo "update-atas-x: Verzeichnis-Listing nicht lesbar" >&2
  exit 1
fi

current="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$SOURCE_JSON")"
if [ "$version" = "$current" ]; then
  echo "ATAS X $version ist aktuell."
  exit 0
fi

# Keine Prüfsummen auf dem Server – Datei laden (landet gleich im Store,
# der Build nutzt sie danach mit)
url="$CHANNEL/atasx_linux_$version.tar.gz"
sha256="$(nix hash convert --hash-algo sha256 --to base16 "$(nix-prefetch-url --type sha256 "$url")")"

cat >"$SOURCE_JSON" <<JSON
{
  "version": "$version",
  "url": "$url",
  "sha256": "$sha256"
}
JSON
echo "ATAS X: $current → $version"
