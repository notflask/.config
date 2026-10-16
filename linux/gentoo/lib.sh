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

# media-sound/spotify lädt ein fest eingestelltes Spotify-Paket von Spotifys
# Mirror. Spotify nimmt alte Builds irgendwann vom Server (HTTP 404); dann
# scheitert emerge schon beim Download und meldet nur "Failed to emerge", ohne
# Build-Log – genau der Fall, in dem Spotify still fehlt. Diese Funktion legt
# ein kleines lokales Overlay an, das den aktuellen Build nimmt. Sie tut
# nichts, wenn das offizielle ebuild seinen Build noch laden kann.
spotify_overlay() {
  local base=https://repository-origin.spotify.com/pool/non-free/s/spotify-client/
  local main=/var/db/repos/gentoo/media-sound/spotify overlay=/var/db/repos/local/media-sound/spotify
  local ever=/var/lib/g5-spotify.ver src deb file pv build up_pv up_build
  have curl || return 0

  src=$(ls "$main"/spotify-*.ebuild 2>/dev/null | sort -V | tail -1) || true
  if [ -z "$src" ]; then warn "Spotify: kein ebuild in $main"; return 0; fi

  # Lädt das offizielle ebuild seinen Build noch? Dann ist kein Overlay nötig.
  up_pv=${src##*/}; up_pv=${up_pv#spotify-}; up_pv=${up_pv%.ebuild}
  up_build=$(sed -n 's/^BUILD_ID_AMD64="\(.*\)"$/\1/p' "$src")
  if [ -n "$up_build" ] && curl -fsS --max-time 20 -o /dev/null -r 0-0 \
      "$base/spotify-client_${up_pv}.${up_build}_amd64.deb" 2>/dev/null; then
    info "Spotify: offizielles ebuild lädt (${up_pv})"
    return 0
  fi

  # Neuesten amd64-Build von Spotifys Mirror nehmen.
  deb=$(curl -fsSL --max-time 30 "$base" 2>/dev/null |
    grep -oE 'spotify-client_[^"<> ]+_amd64\.deb' | sort -V | tail -1) || true
  file=${deb#spotify-client_}; file=${file%_amd64.deb}
  case $file in *".g"*) : ;; *) warn "Spotify: Build-Liste nicht ladbar"; return 0 ;; esac
  pv=${file%.g*}; build=g${file##*.g}
  if [ -z "$pv" ] || [ "$build" = g ]; then warn "Spotify: Version unlesbar ($file)"; return 0; fi

  if [ "$(cat "$ever" 2>/dev/null)" = "$file" ] && [ -e "$overlay/spotify-$pv.ebuild" ]; then
    info "Spotify: lokales Overlay passt schon ($pv)"; return 0
  fi

  step "Spotify: lokales Overlay für $pv"
  ${SUDO:-} install -d /var/db/repos/local/metadata /var/db/repos/local/profiles "$overlay"
  printf 'local\n' | ${SUDO:-} tee /var/db/repos/local/profiles/repo_name >/dev/null
  printf 'masters = gentoo\n' | ${SUDO:-} tee /var/db/repos/local/metadata/layout.conf >/dev/null
  printf '[local]\nlocation = /var/db/repos/local\nmasters = gentoo\nauto-sync = no\npriority = 100\n' |
    ${SUDO:-} tee /etc/portage/repos.conf/local.conf >/dev/null

  ${SUDO:-} rm -f "$overlay"/spotify-*.ebuild
  ${SUDO:-} install -m644 "$src" "$overlay/spotify-$pv.ebuild"
  ${SUDO:-} cp -rf "$main/files" "$overlay/"
  if [ -f "$main/metadata.xml" ]; then
    ${SUDO:-} install -m644 "$main/metadata.xml" "$overlay/metadata.xml"
  fi
  ${SUDO:-} sed -i "s/^BUILD_ID_AMD64=.*/BUILD_ID_AMD64=\"$build\"/" "$overlay/spotify-$pv.ebuild"
  if ! grep -q "^BUILD_ID_AMD64=\"$build\"$" "$overlay/spotify-$pv.ebuild"; then
    warn "Spotify: ebuild ließ sich nicht anpassen"; return 0
  fi

  if ${SUDO:-} ebuild "$overlay/spotify-$pv.ebuild" manifest >/dev/null 2>&1; then
    printf '%s\n' "$file" | ${SUDO:-} tee "$ever" >/dev/null
    info "Spotify: $pv bereit (Overlay ::local)"
  else
    warn "Spotify: Manifest fehlgeschlagen – von Hand: sudo ebuild $overlay/spotify-$pv.ebuild manifest"
  fi
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
