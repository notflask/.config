# G5 configuration (`g5.json`)

One file describes the whole system: `linux/gentoo/config/g5.json`. It lives in
the repo, so every reinstall comes out the same. Edit it, then run `g5 apply`.

```sh
g5 config edit                       # open in $EDITOR, validated on save
g5 config set gaming.stretch 1920x1440
g5 config get performance.cpu_pl1_watts
g5 apply                             # apply everything (or: g5 apply gaming)
g5 doctor                            # check that the whole system is healthy
```

Editors that understand JSON Schema (Neovim with `jsonls`, VS Code) offer
autocompletion and inline docs through `g5.schema.json`.

**Cost at runtime: none.** `g5 apply` merges the file once and writes the
result to `~/.cache/g5/config.json` (user) and `/etc/g5/g5.json` (system
services). Scripts read that finished file with a single `jq` call when they
start. Nothing polls or runs in the background.

## Profiles

A profile is a small JSON file in `config/profiles/` that only lists what it
changes. It is merged over `g5.json`: objects are merged, lists are replaced.

| Command | Effect |
|---|---|
| `g5 profile list` | show profiles, `*` = active |
| `g5 profile use quiet` | activate a profile and apply it |
| `g5 profile reset` | back to plain `g5.json` |
| `g5 profile show [NAME]` | print a profile |
| `g5 profile export FILE` | save the effective config (base + profile) |
| `g5 profile import FILE [NAME]` | validate a file and add it as a profile |

Included profiles:

- **max**: PL1 80 W and a more aggressive fan curve. Louder and hotter, with the highest sustained clocks.
- **quiet**: balanced power, PL1 45 W, GPU clock not locked, fans left on auto. Good for studying.
- **battery**: power-saver, PL1 25 W, no dynamic boost, GPU idles freely.

The active profile is stored per machine in `~/.config/g5/profile`, not in the repo.

## Options

### `system` (used once by `configure.sh`)

| Key | Default | Meaning |
|---|---|---|
| `user` | `flask` | login name |
| `hostname` | `g5` | host name |
| `timezone` | `Europe/Berlin` | zone from `/usr/share/zoneinfo` |
| `locale` | `de_DE.UTF-8` | system language |
| `kernel` | `sys-kernel/gentoo-kernel` | built locally with `/etc/kernel/config.d/g5.config` (1000 Hz, `-march=native`). `gentoo-kernel-bin` is the prebuilt 300 Hz kernel, with no compile time. |

Environment variables (`USERNAME`, `HOSTNAME_G5`, `TZ_G5`, `LOCALE_G5`, `KERNEL_PKG`) still override these.

### `desktop`

| Key | Default | Meaning |
|---|---|---|
| `style` | `minimal` | `minimal`: flat, thin text bar, no blur or animations (lightest on the GPU). `glass`: Liquid Glass taskbar, blur, rounded corners. |
| `terminal` | `ghostty` | Super+T |
| `shell` | `fish` | login shell, changed with `chsh` on apply |
| `launcher` | `rofi` | Super+D / Super+Space |
| `screenshot` | `opal` | `opal`: select a region and annotate it. `grim`: plain region capture. Bound to Print and Super+Shift+S. |
| `cursor.theme`, `cursor.size` | `macOS`, `24` | applied to Hyprland, GTK and new apps |
| `keyboard_layouts` | `us ru ua de` | Alt+Shift cycles through them |

### `monitors`

A list with one entry per output. `hyprctl monitors` shows the names.

| Key | Example | Meaning |
|---|---|---|
| `name` | `DP-2` | output |
| `mode` | `2560x1440@179.959` | `WxH@Hz`, `preferred`, `highrr` |
| `position` | `1920x0` | position in the layout, or `auto` |
| `scale` | `1` | |
| `vrr` | `3` | 0 off, 1 always, 2 fullscreen, 3 only fullscreen games (recommended: no desktop flicker) |

### `performance` (applied at boot and after resume by `g5-tuning.service`)

| Key | Default | Meaning |
|---|---|---|
| `power_profile` | `performance` | power-profiles-daemon profile |
| `cpu_pl1_watts` | `65` | sustained CPU power limit. The firmware allows 90 W, at which the i5-12500H throttles thermally under game + stream. 65 keeps clocks stable. |
| `cpu_dynamic_boost` | `true` | clock up instantly after I/O waits |
| `gpu_min_clock_mhz` | `1500` | lowest RTX 4060 clock. Animations are always instant, at the cost of +10–15 W at idle. `0` = driver default. |
| `gpu_max_clock_mhz` | `3105` | upper clock limit |

### `gaming` (defaults for `gaming-mode`)

Every key can be overridden per game with a launch option (`gaming-mode --help`).

| Key | Default | Meaning |
|---|---|---|
| `monitor` | `DP-2` | the game opens here |
| `stretch` | `""` | e.g. `1920x1440`: every game started with `gaming-mode` is stretched. Empty means native; use `--stretch WxH` per game instead. |
| `refresh` | `0` | refresh rate for stretched games. 0 = monitor rate − 3 Hz, so VRR follows every frame. |
| `hud` | `true` | MangoHud (Shift_R+F12 toggles it) |
| `cursor` | `grab` | `grab`: gamescope locks the mouse (camera), and Hyprland also keeps the cursor inside the window, because Unreal games like ARC Raiders release the lock in menus (recommended). `confine`: Hyprland keeps the cursor in the window, but in shooters the camera stops at the window edge. `free`: no restriction. |
| `grab_keyboard` | `false` | the game gets every key, including Super. Super+G inside gamescope toggles it. |
| `fan_curve` | `50:25,…` | `gbcc` fan curve (TEMP:PERCENT) while a game runs; empty = auto |
| `renice` | `5` | GameMode priority boost. Higher values starve Discord's stream encoder. |
| `governor` | `powersave` | CPU governor while a game runs. `powersave`: idle cores clock down, busy cores still boost to full turbo (intel_pstate), so the package stays cooler. `performance` (GameMode's default) keeps every core clocked up, which on this laptop ran the CPU at 100 °C in Geometry Dash. |
| `watchdog` | `false` | end the whole game once its main window closes and only leftovers stay open (e.g. Geode's console in Geometry Dash), so Steam sees it as stopped. Not with `stretch`. `--watchdog` / `--no-watchdog` per game. |

### `vpn`

| Key | Default | Meaning |
|---|---|---|
| `interface` | `wg0` | |
| `autostart` | `false` | connect at boot |
| `lock_without_tunnel` | `false` | block all internet (except LAN) whenever the tunnel is down |
| `bypass_apps` | `[]` | desktop IDs that always start outside the VPN. Edited by `vpn app add ID` or the VPN panel. |
| `bypass_domains` | `[]` | domains or IPv4 networks reached outside the VPN. Edited by `vpn domain add X`. |

The kill-switch is always on while the tunnel is up. It is never active when you
are disconnected, unless `lock_without_tunnel` is `true`.

### `apps` (used by `install.sh` and `update`)

| Key | Default | Meaning |
|---|---|---|
| `flatpaks` | `["org.vinegarhq.Sober"]` | installed by `g5 apply apps` |
| `spicetify` | `true` | Spotify theme follows the wallpaper colors |
| `vencord` | `true` | patched into Discord after every Discord update |
| `claude_desktop` | `true` | |
| `tradingview` | `true` | |
| `ge_proton` | `true` | latest GE-Proton (x86_64) in Steam's compatibility tools |

## One-time setups (`g5 setup`)

| Command | What it does | Runs automatically |
|---|---|---|
| `g5 setup nvidia-flatpak` | Flatpak GL extension matching the NVIDIA driver (Sober needs it) | after every `nvidia-drivers` build (portage hook) and in `update` |
| `g5 setup sober` | MangoHud, shader cache and Discord RPC for Sober | `install.sh user` |
| `g5 setup spicetify` | Spotify theme | after every Spotify update (portage hook) and in `update` |
| `g5 setup vencord` | Vencord in Discord | after every Discord update (portage hook) |
