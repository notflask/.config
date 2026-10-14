# shellcheck shell=bash
FAILED=()
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m!!! %s\033[0m\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
list() { sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep -v '^$'; }

# fetch URL ZIEL [SHA256]
fetch() {
  local url=$1 out=$2 sha=${3:-} i
  for i in 1 2 3 4; do
    curl -fL --retry 3 --connect-timeout 20 -o "$out" "$url" && break
    [ "$i" = 4 ] && return 1
    sleep $((i * 2))
  done
  [ -z "$sha" ] || echo "$sha  $out" | sha256sum -c --quiet
}

# neueste GitHub-Release: gh_asset OWNER/REPO REGEX
gh_asset() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
    grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$2" | head -1
}

# Dateien aus SRC nach DST kopieren (Rechte bleiben), mit $SUDO
overlay() {
  local src=$1 dst=$2 f rel
  [ -d "$src" ] || return 0
  while IFS= read -r -d '' f; do
    rel=${f#"$src"/}
    ${SUDO:-} install -D -m "$(stat -c %a "$f")" "$f" "$dst/$rel"
  done < <(find "$src" -type f -print0)
}

# emerge mit Wiederholung bei Abbruch; einzelne Fehlschläge sammeln
emerge_try() {
  ${SUDO:-} emerge --ask=n --noreplace --keep-going=y "$@" && return 0
  warn "emerge fehlgeschlagen – zweiter Versuch mit --autounmask"
  ${SUDO:-} emerge --ask=n --noreplace --keep-going=y --autounmask=y --autounmask-write=y --autounmask-continue=y "$@" && return 0
  ${SUDO:-} etc-update --quiet --automode -5 >/dev/null 2>&1 || true
  ${SUDO:-} emerge --ask=n --noreplace --keep-going=y "$@" && return 0
  local p
  for p in "$@"; do
    case $p in -* | @*) continue ;; esac
    ${SUDO:-} emerge --ask=n --noreplace "$p" >/dev/null 2>&1 || FAILED+=("$p")
  done
  return 0
}

report() {
  if [ ${#FAILED[@]} -gt 0 ]; then
    warn "Nicht installiert/gebaut: ${FAILED[*]}"
  fi
}
