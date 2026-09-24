#!/usr/bin/env bash
# ============================================================
#  Claude Desktop auf die neueste Version aus Anthropics
#  apt-Repository setzen (schreibt pkgs/claude-desktop/source.json).
#  Läuft automatisch bei `rebuild update`.
# ============================================================

set -euo pipefail

REPO="https://downloads.claude.ai/claude-desktop/apt/stable"
SOURCE_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/pkgs/claude-desktop/source.json"

# Neuesten Eintrag für amd64 aus dem Paketindex lesen
index="$(curl -fsSL "$REPO/dists/stable/main/binary-amd64/Packages")"
latest="$(awk -v RS= -F '\n' '{
  pkg = v = f = s = ""
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^Package: /) pkg = substr($i, 10)
    else if ($i ~ /^Version: /) v = substr($i, 10)
    else if ($i ~ /^Filename: /) f = substr($i, 11)
    else if ($i ~ /^SHA256: /) s = substr($i, 9)
  }
  if (pkg == "claude-desktop") print v, f, s
}' <<<"$index" | sort -V | tail -n 1)"
read -r version filename sha256 <<<"$latest"

if [ -z "${version:-}" ] || [ -z "${filename:-}" ] || [ -z "${sha256:-}" ]; then
  echo "update-claude-desktop: Paketindex nicht lesbar" >&2
  exit 1
fi

current="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$SOURCE_JSON")"
if [ "$version" = "$current" ]; then
  echo "Claude Desktop $version ist aktuell."
  exit 0
fi

cat >"$SOURCE_JSON" <<JSON
{
  "version": "$version",
  "url": "$REPO/$filename",
  "sha256": "$sha256"
}
JSON
echo "Claude Desktop: $current → $version"
