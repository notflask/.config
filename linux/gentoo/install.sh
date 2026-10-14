#!/usr/bin/env bash
# install.sh – Desktop, Programme, Theme und Dotfiles auf dem installierten Gentoo.
# Als normaler Benutzer starten (nicht root). Jeder Schritt darf beliebig oft laufen.
#
#   ~/dotfiles/linux/gentoo/install.sh             alles
#   ~/dotfiles/linux/gentoo/install.sh SCHRITT ... repos packages system extras plugins services user network
set -Eeuo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
# shellcheck source=lib.sh
. "$here/lib.sh"
trap 'die "Fehler in ${BASH_SOURCE[0]##*/} Zeile $LINENO: $BASH_COMMAND"' ERR
home=$HOME
SUDO=sudo
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/bin:$PATH"
sdo() { sudo "$@"; }

check() {
  [ "$(id -u)" -ne 0 ] || die "als normaler Benutzer starten (nicht root, nicht sudo)"
  [ -e /etc/gentoo-release ] || die "das ist kein Gentoo"
  [ "$repo" = "$home/dotfiles" ] || warn "Repo liegt in $repo statt $home/dotfiles – Links zeigen dorthin"
  curl -fsS --max-time 15 -o /dev/null https://distfiles.gentoo.org/ || die "kein Internet (nmtui)"
  sudo -v
  (while kill -0 $$ 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done) &
}

# ── repos ──
do_repos() {
  step "Portage-Konfiguration aus dem Repo, Overlays synchronisieren"
  sdo cp "$here"/portage/package.use/* /etc/portage/package.use/
  sdo cp "$here"/portage/package.accept_keywords/* /etc/portage/package.accept_keywords/
  sdo cp "$here"/portage/package.license/* /etc/portage/package.license/
  sdo cp "$here"/portage/package.mask/* /etc/portage/package.mask/
  sdo install -d /etc/portage/sets /etc/portage/repos.conf
  sdo cp "$here"/portage/sets/* /etc/portage/sets/
  sdo cp "$here/portage/repos.conf" /etc/portage/repos.conf/g5.conf
  sdo emaint sync -a || warn "Sync nicht vollständig"
}

# ── packages ──
do_packages() {
  local set pkgs
  for set in g5-base g5-desktop g5-apps; do
    step "Pakete: @$set"
    mapfile -t pkgs < <(list "$here/portage/sets/$set")
    emerge_try "${pkgs[@]}"
  done
  step "System auf Stand"
  sdo emerge --ask=n -uDN --keep-going=y @world || warn "@world nicht vollständig"
  sdo emerge --ask=n @preserved-rebuild || true
}

# ── system ──
blackhole_url=https://codeberg.org/fairyglade/ly-community/raw/commit/fd85d8584545433520f34fb25584b17280f4c0b9/animations/dur/blackhole-smooth-240x67.dur
blackhole_sha256=c28dc5ccfb67802b20fdb4520d360742a2a7329e2f63e06d9b5e2f6a42444415
gbcc_commit=d0dc074726ba410bf70b06c77ec5acf16843c1ed

do_system() {
  step "Systemdateien"
  local etc_tmp
  etc_tmp=$(mktemp -d)
  cp -a "$here/files/etc/." "$etc_tmp/"
  rm -f "$etc_tmp/kernel/cmdline.tpl"
  overlay "$etc_tmp" /etc
  rm -rf "$etc_tmp"
  overlay "$here/files/opt" /opt
  sdo chmod 440 /etc/sudoers.d/g5
  sdo visudo -cq -f /etc/sudoers.d/g5 || { sdo rm -f /etc/sudoers.d/g5; warn "sudoers.d/g5 fehlerhaft – entfernt"; }
  sdo install -d /usr/local/sbin /usr/local/libexec /usr/local/bin /var/lib/vpn-bypass /etc/wireguard /usr/lib/systemd/system-sleep
  sdo install -m 755 "$here"/files/sbin/* /usr/local/sbin/
  sdo install -m 755 "$here"/files/libexec/* /usr/local/libexec/
  sdo install -m 755 "$here/files/sleep/g5-tuning" /usr/lib/systemd/system-sleep/g5-tuning
  sdo touch /var/lib/vpn-bypass/domains

  local c
  for c in "$here"/files/bin/*; do sdo ln -sfn "$c" "/usr/local/bin/$(basename "$c")"; done
  sdo ln -sfn "$here/scripts/wm.sh" /usr/local/bin/wm
  sdo ln -sfn "$here/scripts/gaming-mode.sh" /usr/local/bin/gaming-mode
  sdo ln -sfn "$here/scripts/flatpak-nvidia-sync.sh" /usr/local/bin/flatpak-nvidia-sync
  sdo ln -sfn "$repo/linux/.config/matugen/theme.sh" /usr/local/bin/theme
  sdo ln -sfn "$here/scripts/gpu-info.sh" /usr/local/bin/gpu-info
  printf '#!/bin/sh\nexec bash %s "$@"\n' "$here/scripts/sober-setup.sh" | sdo tee /usr/local/bin/sober-setup >/dev/null
  sdo chmod 755 /usr/local/bin/sober-setup

  step "Login: ly"
  if [ -f /etc/ly/config.ini ]; then
    local dur=/etc/ly/blackhole.dur tmp
    if ! echo "$blackhole_sha256  $dur" | sha256sum -c --quiet 2>/dev/null; then
      tmp=$(mktemp)
      fetch "$blackhole_url" "$tmp" "$blackhole_sha256" && sdo install -m 644 "$tmp" "$dur" || warn "ly: Animation nicht geladen"
      rm -f "$tmp"
    fi
    set_ly() {
      sdo sed -i -E "s|^#?[[:space:]]*$1[[:space:]]*=.*|$1 = $2|" /etc/ly/config.ini
      grep -qE "^$1 = " /etc/ly/config.ini || echo "$1 = $2" | sdo tee -a /etc/ly/config.ini >/dev/null
    }
    set_ly lang de
    set_ly animation dur_file
    set_ly dur_file_path "$dur"
    set_ly dur_offset_alignment center
    set_ly full_color true
    set_ly bigclock en
    set_ly clock "%a %d.%m.%Y %H:%M"
    set_ly waylandsessions /etc/ly/sessions
    set_ly xsessions /etc/ly/xsessions
    sdo install -d /etc/ly/xsessions
  else
    warn "ly fehlt (Schritt packages)"
  fi

  step "Schriften ohne Paket, macOS-Cursor"
  local fdir=/usr/local/share/fonts/g5 tmp u
  sdo install -d "$fdir"
  tmp=$(mktemp -d)
  [ -e "$fdir/AppleColorEmoji-Linux.ttf" ] || {
    fetch "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260722-484daf4e/AppleColorEmoji-Linux.ttf" \
      "$tmp/emoji.ttf" e37c7af6265ac4a0af6d57bc65e86109a776d9966e8343334557f63da482516f &&
      sdo install -m 644 "$tmp/emoji.ttf" "$fdir/AppleColorEmoji-Linux.ttf" || warn "Apple-Emoji nicht geladen"; }
  [ -e "$fdir/Monocraft.ttf" ] || {
    fetch "https://github.com/IdreesInc/Monocraft/releases/download/v4.2.1/Monocraft-ttf.zip" "$tmp/mono.zip" \
      897faffbef8cc27fadd0d5aa51872ab5f908e22a89bb8fa5b191366025d503e0 &&
      unzip -qjo "$tmp/mono.zip" '*.ttf' -d "$tmp/mono" && sdo install -m 644 "$tmp"/mono/*.ttf "$fdir/" || warn "Monocraft nicht geladen"; }
  [ -e "$fdir/minecraftia.ttf" ] || {
    fetch "https://fontlibrary.org/assets/downloads/minecraftia/71962a7e3d4a70435c030466a12f1d63/minecraftia.zip" "$tmp/mc.zip" &&
      unzip -qjo "$tmp/mc.zip" '*.ttf' -d "$tmp/mc" && sdo install -m 644 "$tmp"/mc/*.ttf "$fdir/" || warn "Minecraftia nicht geladen"; }
  [ -e "$fdir/calibri.ttf" ] || {
    fetch "https://archive.org/download/PowerPointViewer_201801/PowerPointViewer.exe" "$tmp/ppv.exe" \
      249473568eba7a1e4f95498acba594e0f42e6581add4dead70c1dfb908a09423 &&
      cabextract -q -L -d "$tmp/ppv" "$tmp/ppv.exe" && cabextract -q -L -F '*.tt[fc]' -d "$tmp/ppv" "$tmp/ppv/ppviewer.cab" &&
      sdo install -m 644 "$tmp"/ppv/*.tt[fc] "$fdir/" || warn "Vista-Schriften nicht geladen"; }
  [ -n "$(ls "$fdir"/Vazirmatn* 2>/dev/null)" ] || {
    u=$(gh_asset rastikerdar/vazirmatn '\.zip$') && fetch "$u" "$tmp/vz.zip" &&
      unzip -qjo "$tmp/vz.zip" 'fonts/ttf/*.ttf' -d "$tmp/vz" && sdo install -m 644 "$tmp"/vz/*.ttf "$fdir/" || warn "Vazirmatn nicht geladen"; }
  [ -n "$(ls "$fdir"/Amiri* 2>/dev/null)" ] || {
    u=$(gh_asset aliftype/amiri '\.zip$') && fetch "$u" "$tmp/am.zip" &&
      unzip -qjo "$tmp/am.zip" '*.ttf' -d "$tmp/am" && sdo install -m 644 "$tmp"/am/*.ttf "$fdir/" || warn "Amiri nicht geladen"; }
  if [ ! -d /usr/share/icons/macOS ]; then
    fetch "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz" "$tmp/cur.tar.xz" \
      9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762 &&
      sdo tar -xJf "$tmp/cur.tar.xz" -C /usr/share/icons || warn "macOS-Cursor nicht geladen"
  fi
  rm -rf "$tmp"
  sdo fc-cache -f >/dev/null
  have dconf && sdo dconf update

  step "Gigabyte Control Center"
  if [ "$(cat /var/lib/g5-gbcc.rev 2>/dev/null)" != "$gbcc_commit" ]; then
    tmp=$(mktemp -d)
    if (cd "$tmp" && git init -q && git fetch -q --depth 1 https://github.com/notflask/gigabyte-control-center.git "$gbcc_commit" &&
      git checkout -q FETCH_HEAD && python -m build --wheel --no-isolation >/dev/null &&
      sdo python -m installer --prefix /usr dist/*.whl &&
      sdo install -Dm644 gigabyte-control-center.desktop /usr/share/applications/gigabyte-control-center.desktop &&
      sed 's/#000000/#8e939e/' gbcc/data/gbcc.svg | sdo install -Dm644 /dev/stdin /usr/share/icons/hicolor/scalable/apps/gigabyte-control-center.svg &&
      sed 's/#000000/#2e3436/' gbcc/data/gbcc.svg | sdo install -Dm644 /dev/stdin /usr/share/icons/hicolor/symbolic/apps/gigabyte-control-center-symbolic.svg); then
      echo "$gbcc_commit" | sdo tee /var/lib/g5-gbcc.rev >/dev/null
    else
      warn "Gigabyte Control Center nicht gebaut"; FAILED+=(gigabyte-control-center)
    fi
    rm -rf "$tmp"
  fi

  step "Kernel-Einstellungen sofort anwenden"
  sdo sysctl --quiet --system || true
  sdo udevadm control --reload && sdo udevadm trigger --subsystem-match=drm || true
  sdo /usr/local/sbin/vencord-patch || true
  [ -d /opt/spotify/spotify-client ] && { sdo chmod a+wr /opt/spotify/spotify-client; sdo chmod -R a+wr /opt/spotify/spotify-client/Apps; } || true
}

# ── extras: Programme ohne Gentoo-Paket ──
do_extras() {
  local tmp u v
  tmp=$(mktemp -d)

  step "Claude Desktop (.deb von Anthropic)"
  local apt=https://downloads.claude.ai/claude-desktop/apt/stable line
  line=$(curl -fsSL "$apt/dists/stable/main/binary-amd64/Packages" | awk -v RS= -F '\n' '{
      p = v = f = s = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^Package: /) p = substr($i, 10)
        else if ($i ~ /^Version: /) v = substr($i, 10)
        else if ($i ~ /^Filename: /) f = substr($i, 11)
        else if ($i ~ /^SHA256: /) s = substr($i, 9)
      }
      if (p == "claude-desktop") print v, f, s }' | sort -V | tail -1) || true
  read -r v u s <<<"$line" || true
  if [ -n "${v:-}" ] && [ "$(cat /var/lib/g5-claude-desktop.ver 2>/dev/null)" != "$v" ]; then
    if fetch "$apt/$u" "$tmp/cd.deb" "$s" && (cd "$tmp" && ar x cd.deb && mkdir -p cd && tar -xf data.tar.* -C cd); then
      sdo rm -rf /usr/lib/claude-desktop
      sdo cp -a "$tmp/cd/usr/lib/claude-desktop" /usr/lib/
      sdo cp -a "$tmp/cd/usr/share/." /usr/local/share/
      sdo chmod 4755 /usr/lib/claude-desktop/chrome-sandbox
      sdo tee /usr/local/bin/claude-desktop >/dev/null <<'EOF'
#!/bin/sh
[ -n "$WAYLAND_DISPLAY" ] && set -- --ozone-platform=wayland "$@"
exec /usr/lib/claude-desktop/claude-desktop "$@"
EOF
      sdo chmod 755 /usr/local/bin/claude-desktop
      echo "$v" | sdo tee /var/lib/g5-claude-desktop.ver >/dev/null
    else
      warn "Claude Desktop nicht installiert"; FAILED+=(claude-desktop)
    fi
  fi

  step "TradingView (Snap-Paket entpackt)"
  u=$(curl -fsSL -H 'Snap-Device-Series: 16' 'https://api.snapcraft.io/v2/snaps/info/tradingview?fields=download,version' |
    jq -r '[."channel-map"[] | select(.channel.name=="stable" and .channel.architecture=="amd64")][0] | "\(.version) \(.download.url)"' 2>/dev/null) || u=""
  v=${u%% *}; u=${u#* }
  if [ -n "$v" ] && [ "$(cat /var/lib/g5-tradingview.ver 2>/dev/null)" != "$v" ]; then
    if fetch "$u" "$tmp/tv.snap" && unsquashfs -q -n -d "$tmp/tv" "$tmp/tv.snap" >/dev/null; then
      sdo rm -rf /opt/tradingview
      sdo cp -a "$tmp/tv" /opt/tradingview
      printf '#!/bin/sh\nexec /opt/tradingview/tradingview "$@"\n' | sdo install -m755 /dev/stdin /usr/local/bin/tradingview
      sed -e 's|^Exec=.*|Exec=/usr/local/bin/tradingview %U|' -e 's|^Icon=.*|Icon=/opt/tradingview/meta/gui/icon.png|' \
        "$tmp"/tv/meta/gui/tradingview.desktop 2>/dev/null | sdo install -Dm644 /dev/stdin /usr/local/share/applications/tradingview.desktop || true
      echo "$v" | sdo tee /var/lib/g5-tradingview.ver >/dev/null
    else
      warn "TradingView nicht installiert"; FAILED+=(tradingview)
    fi
  fi

  step "GE-Proton"
  local ct=$home/.steam/root/compatibilitytools.d
  u=$(gh_asset GloriousEggroll/proton-ge-custom 'x86_64\.tar\.gz$|[0-9]\.tar\.gz$') || u=""
  if [ -n "$u" ]; then
    v=$(basename "$u" .tar.gz); v=${v%-x86_64}
    if [ ! -d "$ct/$v" ]; then
      mkdir -p "$ct" && fetch "$u" "$tmp/ge.tgz" && tar -xzf "$tmp/ge.tgz" -C "$ct" || warn "GE-Proton nicht geladen"
    fi
  fi

  step "Spicetify"
  u=$(gh_asset spicetify/cli 'linux-amd64\.tar\.gz$') || u=""
  if [ -n "$u" ]; then
    mkdir -p "$home/.spicetify" && fetch "$u" "$tmp/sp.tgz" && tar -xzf "$tmp/sp.tgz" -C "$home/.spicetify" &&
      ln -sfn "$home/.spicetify/spicetify" "$home/.local/bin/spicetify" || warn "Spicetify nicht geladen"
  fi

  step "GPU Screen Recorder UI (Overlay Alt+Z)"
  local r
  for r in gpu-screen-recorder-notification:gsr-notify gpu-screen-recorder-ui:gsr-ui; do
    local bin=${r#*:}; r=${r%%:*}
    if ! have "$bin" || [ "${G5_UPDATE:-0}" = 1 ]; then
      rm -rf "${tmp:?}/$r"
      if git clone -q --depth 1 "https://repo.dec05eba.com/$r" "$tmp/$r" &&
        (cd "$tmp/$r" && meson setup build --prefix=/usr/local --buildtype=release -Dstrip=true >/dev/null && meson compile -C build >/dev/null) &&
        sdo meson install -C "$tmp/$r/build" >/dev/null; then :; else warn "$r nicht gebaut"; FAILED+=("$r"); fi
    fi
  done

  step "xdg-terminal-exec, CachyOS-Ananicy-Regeln"
  fetch https://gitlab.freedesktop.org/Vladimir-csp/xdg-terminal-exec/-/raw/master/xdg-terminal-exec "$tmp/xte" &&
    sdo install -m755 "$tmp/xte" /usr/local/bin/xdg-terminal-exec || warn "xdg-terminal-exec nicht geladen"
  if git clone -q --depth 1 https://github.com/CachyOS/ananicy-rules.git "$tmp/ar"; then
    sdo install -d /etc/ananicy.d && sdo cp -rf "$tmp"/ar/00-* "$tmp"/ar/ananicy.conf /etc/ananicy.d/ 2>/dev/null || sdo cp -rf "$tmp"/ar/. /etc/ananicy.d/
    sdo rm -rf /etc/ananicy.d/.git
  fi
  rm -rf "$tmp"
}

# ── plugins ──
do_plugins() {
  step "Hyprland-Übersicht (hyprtasking) für die installierte Hyprland-Version"
  local hv tmp commit
  hv=$(portageq best_version / gui-wm/hyprland 2>/dev/null | sed 's|.*/hyprland-||; s/-r[0-9]*$//') || true
  [ -n "$hv" ] || { warn "Hyprland nicht installiert"; return 0; }
  if [ "$(cat /var/lib/g5-hyprtasking.ver 2>/dev/null)" = "$hv" ] && [ -e /etc/hyprland/plugins/libhyprtasking.so ]; then
    info "passt schon zu Hyprland $hv"; return 0
  fi
  tmp=$(mktemp -d)
  if git clone -q https://github.com/raybbian/hyprtasking.git "$tmp/ht"; then
    commit=$(awk -v v="#v$hv" '{ sub(/[ \t]+$/, "") } substr($0, length($0) - length(v) + 1) == v {print; exit}' "$tmp/ht/hyprpm.toml" |
      grep -oE '"[0-9a-f]{40}"' | tail -1 | tr -d '"') || true
    [ -n "$commit" ] && git -C "$tmp/ht" checkout -q "$commit" || info "kein fester Stand für Hyprland $hv – nehme den neuesten"
    if (cd "$tmp/ht" && meson setup build --buildtype=release >/dev/null && meson compile -C build >/dev/null); then
      sdo install -Dm755 "$tmp/ht/build/libhyprtasking.so" /etc/hyprland/plugins/libhyprtasking.so
      echo "$hv" | sdo tee /var/lib/g5-hyprtasking.ver >/dev/null
    else
      warn "hyprtasking nicht gebaut – Super+O geht im Glas-Stil nicht"; FAILED+=(hyprtasking)
    fi
  fi
  rm -rf "$tmp"
}

# ── services ──
do_services() {
  step "systemd-Dienste"
  local s
  for s in NetworkManager bluetooth power-profiles-daemon upower fstrim.timer systemd-timesyncd systemd-boot-update \
    nvidia-persistenced nvidia-powerd g5-firewall vpn-bypass vpn-bypass-dst.timer vpn-lock vpn-peer-info \
    gigabyte-control-center g5-tuning ananicy-cpp snapper-cleanup.timer; do
    sdo systemctl enable "$s" >/dev/null 2>&1 && info "an: $s" || info "übersprungen: $s"
  done
  if [ -e /usr/lib/systemd/system/ly@.service ] || [ -e /lib/systemd/system/ly@.service ]; then
    sdo systemctl disable getty@tty2.service >/dev/null 2>&1 || true
    sdo systemctl enable ly@tty2.service
  else
    warn "ly-Dienst nicht gefunden"
  fi
  sdo install -d /etc/systemd/user/graphical-session.target.wants
  for s in polkit-agent swayidle cameractrlsd flatpak-nvidia-sync matugen-first-run; do
    sdo ln -sfn "/etc/systemd/user/$s.service" "/etc/systemd/user/graphical-session.target.wants/$s.service"
  done
  sdo systemctl disable systemd-networkd.service systemd-networkd.socket >/dev/null 2>&1 || true
  sdo systemctl enable systemd-resolved.service >/dev/null 2>&1 || true
}

# ── user ──
linked=(nvim tmux ghostty quickshell rofi mako matugen waypaper hypr MangoHud sioyek gtklock swayidle)
mizu_rev=426e89a4d05c038feaab4a2855351da8b6a4f5fa
opal_rev=abd7ace2de249e5539e5c49c712ae1a82e158595

do_user() {
  step "Dotfiles verlinken"
  local name dst
  mkdir -p "$home/.config" "$home/.local/share/applications" "$home/.local/bin" "$home/.cache"
  for name in "${linked[@]}"; do
    dst=$home/.config/$name
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
      mv "$dst" "$dst.bak-$(date +%s)"; warn "$dst gesichert als .bak"
    fi
    ln -sfn "$repo/linux/.config/$name" "$dst"
  done
  mkdir -p "$home/.config/Vencord/themes"
  xdg-user-dirs-update || true
  mkdir -p "$home/Wallpapers"
  cp -n "$here"/wallpapers/* "$home/Wallpapers/" 2>/dev/null || true

  step "Sitzung: UWSM-Umgebung"
  mkdir -p "$home/.config/uwsm"
  cat >"$home/.config/uwsm/env" <<'EOF'
export PATH="$HOME/.local/bin:$HOME/.spicetify:/opt/bin:$PATH"
export LIBVA_DRIVER_NAME=nvidia
export NVD_BACKEND=direct
export MOZ_DISABLE_RDD_SANDBOX=1
export ELECTRON_OZONE_PLATFORM_HINT=auto
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME=kde
export XCURSOR_THEME=macOS
export XCURSOR_SIZE=24
EOF
  cat >"$home/.config/uwsm/env-hyprland" <<'EOF'
export AQ_DRM_DEVICES=/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu
EOF

  step "Starter: Discord"
  local d
  for d in /usr/share/applications/discord.desktop /usr/share/applications/discord-*.desktop; do
    [ -f "$d" ] && sed 's|^Exec=.*|Exec=/usr/local/bin/discord|' "$d" >"$home/.local/share/applications/discord.desktop" && break
  done

  step "Stil"
  [ -e "$home/.config/g5/style" ] || /usr/local/bin/style minimal
  /usr/local/bin/style | sed 's/^/    Stil: /'

  step "Pywalfox, mizu, opal"
  [ -x "$home/.local/bin/pywalfox" ] || uv tool install pywalfox || warn "pywalfox nicht installiert"
  printf '#!/bin/sh\nexec %s/.local/bin/pywalfox start\n' "$home" | sdo tee /usr/local/libexec/pywalfox-host >/dev/null
  sdo chmod 755 /usr/local/libexec/pywalfox-host
  local nm
  for nm in /usr/lib/mozilla/native-messaging-hosts /usr/lib64/mozilla/native-messaging-hosts; do
    sdo install -d "$nm"
    printf '{"name":"pywalfox","description":"pywalfox","path":"/usr/local/libexec/pywalfox-host","type":"stdio","allowed_extensions":["pywalfox@frewacom.org"]}\n' |
      sdo tee "$nm/pywalfox.json" >/dev/null
  done
  if [ "$(cat "$home/.cache/mizu.rev" 2>/dev/null)" != "$mizu_rev" ]; then
    if cargo install --locked --root "$home/.local" --git https://github.com/notflask/mizu --rev "$mizu_rev" mizu; then
      echo "$mizu_rev" >"$home/.cache/mizu.rev"
      printf '[Desktop Entry]\nType=Application\nName=mizu\nExec=mizu %%f\nIcon=application-pdf\nMimeType=application/pdf;application/epub+zip;\nCategories=Office;Viewer;\n' \
        >"$home/.local/share/applications/io.github.notflask.Mizu.desktop"
    else
      warn "mizu nicht gebaut"; FAILED+=(mizu)
    fi
  fi
  if [ "$(cat "$home/.cache/opal.rev" 2>/dev/null)" != "$opal_rev" ]; then
    cargo install --locked --root "$home/.local" --git https://github.com/notflask/opal --rev "$opal_rev" opal &&
      echo "$opal_rev" >"$home/.cache/opal.rev" || { warn "opal nicht gebaut"; FAILED+=(opal); }
  fi

  step "Flatpak (Sober), Split-Tunneling, Spicetify"
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
  flatpak list --user --app 2>/dev/null | grep -q Sober || flatpak install --user -y flathub org.vinegarhq.Sober || warn "Sober nicht installiert"
  vpn-split sync || true
  have spotify && have spicetify && { spicetify-setup || warn "Spotify einmal starten und anmelden, dann spicetify-setup"; }
}

# ── network ──
do_network() {
  step "NetworkManager + systemd-resolved"
  sdo systemctl enable --now systemd-resolved.service || true
  sdo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  sdo systemctl restart NetworkManager.service || true
  sleep 5
  curl -fsS --max-time 10 -o /dev/null https://distfiles.gentoo.org/ && info "Netz ok" || warn "kein Netz – nmtui bzw. Neustart"
}

all=(repos packages system extras plugins services user network)
start_log "$HOME/.local/state/g5-install.log"
check
[ $# -gt 0 ] || set -- "${all[@]}"
for s in "$@"; do
  case $s in
    repos | packages | system | extras | plugins | services | user | network) "do_$s" ;;
    *) die "unbekannter Schritt: $s (${all[*]})" ;;
  esac
done
report
step "Fertig. Neu starten, im Login (ly) Hyprland wählen. Details: linux/gentoo/README.md"
