#!/usr/bin/env bash
# ============================================================
#  HaruNeko auf den neuesten Snapshot-Build von GitHub setzen
#  (schreibt pkgs/haruneko/source.json). Es gibt nur
#  Vorabversionen („canary“), daher zählt die neueste mit Snap.
#  Läuft automatisch bei `rebuild update`.
# ============================================================

set -euo pipefail

API="https://api.github.com/repos/manga-download/haruneko/releases?per_page=10"
SOURCE_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pkgs/haruneko/source.json"

# Tag, URL und SHA-256 des Linux-Snaps aus der neuesten Version
latest="$(curl -fsSL "$API" | jq -r '
  [.[] | {tag: .tag_name, asset: (.assets[] | select(.name | test("^hakuneko-electron-v[0-9.]+-linux-x64\\.snap$")))}]
  | first // empty
  | [.tag, .asset.name, .asset.browser_download_url, (.asset.digest // "" | sub("^sha256:"; ""))]
  | @tsv')"
IFS=$'\t' read -r version name url sha256 <<<"$latest"

if [ -z "${version:-}" ] || [ -z "${url:-}" ] || [ -z "${sha256:-}" ]; then
  echo "update-haruneko: GitHub-Releases nicht lesbar" >&2
  exit 1
fi

current="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$SOURCE_JSON")"
if [ "$version" = "$current" ]; then
  echo "HaruNeko $version ist aktuell."
  exit 0
fi

# Electron-Hauptversion steht im Dateinamen (…-electron-v44.1.1-…)
electron="$(sed -E 's/^hakuneko-electron-v([0-9]+)\..*/\1/' <<<"$name")"

cat >"$SOURCE_JSON" <<JSON
{
  "version": "$version",
  "electron": "$electron",
  "url": "$url",
  "sha256": "$sha256"
}
JSON
echo "HaruNeko: $current → $version (Electron $electron)"
