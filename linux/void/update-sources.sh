#!/usr/bin/env bash
# shellcheck disable=SC2329 # die Paket-Funktionen ruft die Schleife unten über ihren Namen auf
# ============================================================
#  update-sources.sh – neueste Versionen der eigenen Pakete eintragen
#  (version= und checksum= in srcpkgs/*/template). Wie die
#  update-*.sh-Skripte unter NixOS; läuft bei `update` automatisch.
#  Danach baut setup.sh (Schritt custom) die geänderten Pakete neu.
#
#    update-sources.sh            alle
#    update-sources.sh atas-x …   nur diese
# ============================================================

set -euo pipefail

here=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

get() { sed -n "s/^$2=\"\{0,1\}\([^\" ]*\)\"\{0,1\}$/\1/p" "$here/srcpkgs/$1/template" | head -n1; }
# Variable im Template setzen (nur einzeilige Werte)
put() { sed -i "s|^$2=.*|$2=$3|" "$here/srcpkgs/$1/template"; }
sha_of() { curl -fsSL "$1" -o "$tmp/f" && sha256sum "$tmp/f" | cut -d' ' -f1; }
changed() { echo "$1: $2 → $3"; }

claude_desktop() {
  local repo=https://downloads.claude.ai/claude-desktop/apt/stable latest version sha
  latest=$(curl -fsSL "$repo/dists/stable/main/binary-amd64/Packages" | awk -v RS= -F '\n' '{
    pkg = v = s = ""
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^Package: /) pkg = substr($i, 10)
      else if ($i ~ /^Version: /) v = substr($i, 10)
      else if ($i ~ /^SHA256: /) s = substr($i, 9)
    }
    if (pkg == "claude-desktop") print v, s
  }' | sort -V | tail -n1)
  read -r version sha <<<"$latest"
  [ -n "${sha:-}" ] || { echo "claude-desktop: Paketindex nicht lesbar" >&2; return 1; }
  [ "$version" = "$(get claude-desktop version)" ] && return 0
  changed claude-desktop "$(get claude-desktop version)" "$version"
  put claude-desktop version "$version"
  put claude-desktop revision 1
  put claude-desktop checksum "$sha"
}

atas_x() {
  local channel=https://updates.orderflowtrading.net/v2/platformx_linux_alpha version
  version=$(curl -fsSL "$channel/" | grep -oE 'atasx_linux_[0-9.]+[0-9]\.tar\.gz' |
    sed -E 's/^atasx_linux_(.*)\.tar\.gz$/\1/' | sort -uV | tail -n1)
  [ -n "$version" ] || { echo "atas-x: Verzeichnis-Listing nicht lesbar" >&2; return 1; }
  # .NET-Laufzeit: neueste 10.0.x
  local dotnet dsha asha
  dotnet=$(curl -fsSL https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json |
    jq -r '."latest-runtime"')
  [ "$version" = "$(get atas-x version)" ] && [ "$dotnet" = "$(get atas-x _dotnet)" ] && return 0
  asha=$(sha_of "$channel/atasx_linux_$version.tar.gz")
  dsha=$(sha_of "https://builds.dotnet.microsoft.com/dotnet/Runtime/$dotnet/dotnet-runtime-$dotnet-linux-x64.tar.gz")
  changed atas-x "$(get atas-x version) (.NET $(get atas-x _dotnet))" "$version (.NET $dotnet)"
  put atas-x version "$version"
  put atas-x revision 1
  put atas-x _dotnet "$dotnet"
  # zweizeilige checksum: erste Zeile ATAS, zweite .NET
  sed -i "/^checksum=/{N;s|.*|checksum=\"$asha\n $dsha\"|}" "$here/srcpkgs/atas-x/template"
}

haruneko() {
  local latest version name sha electron
  latest=$(curl -fsSL "https://api.github.com/repos/manga-download/haruneko/releases?per_page=10" | jq -r '
    [.[] | {tag: .tag_name, asset: (.assets[] | select(.name | test("^hakuneko-electron-v[0-9.]+-linux-x64\\.snap$")))}]
    | first // empty | [.tag, .asset.name, (.asset.digest // "" | sub("^sha256:"; ""))] | @tsv')
  IFS=$'\t' read -r version name sha <<<"$latest"
  [ -n "${sha:-}" ] || { echo "haruneko: GitHub-Releases nicht lesbar" >&2; return 1; }
  [ "$version" = "$(get haruneko version)" ] && return 0
  electron=$(sed -E 's/^hakuneko-electron-v([0-9.]+)-linux-x64\.snap$/\1/' <<<"$name")
  changed haruneko "$(get haruneko version)" "$version (Electron $electron)"
  put haruneko version "$version"
  put haruneko revision 1
  put haruneko _electron "$electron"
  sed -i "/^checksum=/s|\"[0-9a-f]*|\"$sha|" "$here/srcpkgs/haruneko/template"
}

tradingview() {
  local info version rev url sha
  info=$(curl -fsSL -H 'Snap-Device-Series: 16' \
    'https://api.snapcraft.io/v2/snaps/info/tradingview?fields=version,download,revision' |
    jq -r '.["channel-map"][] | select(.channel.name == "stable" and .channel.architecture == "amd64")
      | [.version, .revision, .download.url] | @tsv' | head -n1)
  IFS=$'\t' read -r version rev url <<<"$info"
  [ -n "${url:-}" ] || { echo "tradingview: Snap-Store nicht lesbar" >&2; return 1; }
  [ "$version" = "$(get tradingview version)" ] && [ "$rev" = "$(get tradingview _snaprev)" ] && return 0
  sha=$(sha_of "$url")
  changed tradingview "$(get tradingview version)" "$version"
  put tradingview version "$version"
  put tradingview revision 1
  put tradingview _snaprev "$rev"
  put tradingview checksum "$sha"
}

warp_terminal() {
  local url ver build sha
  url=$(curl -fsS -o /dev/null -w '%{redirect_url}' 'https://app.warp.dev/download?package=pacman')
  # …/stable/v0.2026.10.07.08.29.stable_00/warp-terminal-v…-1-x86_64.pkg.tar.zst
  ver=$(sed -E 's|.*/stable/v([0-9.]+)\.(stable_[0-9]+)/.*|\1|' <<<"$url")
  build=$(sed -E 's|.*/stable/v([0-9.]+)\.(stable_[0-9]+)/.*|\2|' <<<"$url")
  [[ $ver =~ ^[0-9.]+$ ]] || { echo "warp-terminal: Download-Link nicht lesbar" >&2; return 1; }
  [ "$ver" = "$(get warp-terminal version)" ] && [ "$build" = "$(get warp-terminal _build)" ] && return 0
  sha=$(sha_of "$url")
  changed warp-terminal "$(get warp-terminal version)" "$ver"
  put warp-terminal version "$ver"
  put warp-terminal revision 1
  put warp-terminal _build "$build"
  put warp-terminal checksum "$sha"
}

all=(claude-desktop atas-x haruneko tradingview warp-terminal)
[ $# -gt 0 ] || set -- "${all[@]}"
rc=0
for p in "$@"; do
  "${p//-/_}" || rc=1
done
exit $rc
