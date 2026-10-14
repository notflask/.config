# shellcheck shell=bash
FAILED=()
WARNINGS=()
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { WARNINGS+=("$*"); printf '\033[1;33m    %s\033[0m\n' "$*" >&2; }
die() {
  WARNINGS+=("ABBRUCH: $*")
  printf '\033[1;31m!!! %s\033[0m\n' "$*" >&2
  report
  exit 1
}

# Alles zusätzlich in eine Logdatei schreiben: start_log DATEI
start_log() {
  LOGFILE=$1
  mkdir -p "$(dirname "$LOGFILE")"
  exec > >(tee -a "$LOGFILE") 2>&1
  printf '\n===== %s %s =====\n' "$(date '+%F %T')" "$0 $*"
}
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
  local w f
  [ ${#WARNINGS[@]} -gt 0 ] || [ ${#FAILED[@]} -gt 0 ] || { printf '\n\033[1;32m==> Keine Fehler.\033[0m\n'; return 0; }
  printf '\n\033[1;31m==================== Zusammenfassung ====================\033[0m\n'
  for w in "${WARNINGS[@]}"; do printf '\033[1;33m  ! %s\033[0m\n' "$w"; done
  if [ ${#FAILED[@]} -gt 0 ]; then
    printf '\033[1;31m  Nicht installiert/gebaut: %s\033[0m\n' "${FAILED[*]}"
    for f in /var/tmp/portage/*/*/temp/build.log; do
      [ -f "$f" ] && [ "$f" -nt "${LOGFILE:-/}" ] && printf '  Build-Log: %s\n' "$f"
    done
  fi
  [ -n "${LOGFILE:-}" ] && printf '  Komplettes Log: %s\n' "$LOGFILE"
  return 0
}
