# G5 performance and stability audit — 2026-10-28

## Result and scope

The machine has a working performance-oriented configuration. This session
fixed reproducible configuration and game-launch bugs; it did not establish
maximum FPS, eliminate every source of stutter, or certify game compatibility.
No CPU overclock, GPU overclock, kernel rebuild, package upgrade, filesystem
change, or speculative scheduler change was applied.

Priority workloads: ARC Raiders, Dota 2, Deadlock, Geometry Dash, later CS2,
and Roblox through Sober while using Discord webcam and screen sharing.

## Verified live baseline

| Component | Observation |
|---|---|
| CPU | i5-12500H; active intel_pstate; turbo enabled; HWP dynamic boost enabled; powersave governor with performance EPP; PL1 65 W |
| GPU | RTX 4060 laptop, NVIDIA 595.104.02; current power limit 75 W; nvidia-powerd running; 1500 MHz clock floor; about 7–8 W and 46 °C in desktop samples |
| Displays | DP-2 2560×1440 at 179.959 Hz; eDP-1 1920×1080 at 144.003 Hz |
| Kernel | 6.18.57-gentoo-dist; 1000 Hz; dynamic preemption with preempt=full; NTSYNC loaded and accessible |
| Memory | Approximately 16 GiB RAM, 8.5 GiB available in first sample; zstd zram at half RAM; negligible current memory pressure |
| Storage | Samsung 980 PRO 1 TB; about 30% used; Btrfs zstd:1, noatime, asynchronous discard; BFQ active |
| Services | No failed system/user units; Hyprland reports no configuration errors; PipeWire/WirePlumber healthy |
| Discord | Recent logs show Intel VA-API H.264 webcam and screen-share encoding. Screen share about 30–31 FPS at 720p without CPU-limit flags. This is historical evidence, not a new live call test. |
| Sober | GameMode enabled; Wayland and GPU access available; matching NVIDIA Flatpak runtime installed |

Desktop VRR being inactive is expected with the configured fullscreen-content
policy. It has not been validated in a live game during this session.

## Fixed in the repository and active through existing command links

- `g5 config set … false` now preserves JSON Boolean type instead of converting
  it to a string and failing validation.
- `gaming.hud=false` is honored by `gaming-mode`.
- Failed/invalid monitor IPC stops the launcher with an actionable error
  instead of launching gamescope with empty output dimensions.
- The gamescope helper preserves the previous `cursor.no_warps` value and
  attempts restoration on normal exit, errors, INT and TERM.
- Missing `gamescopereaper` now triggers the intended retry loop instead of
  prematurely ending cursor initialization.
- Configuration validation rejects inverted GPU minimum/maximum clock ranges.
- `g5 doctor` checks the live HWP dynamic boost value.

The earlier tablet fix remains: manual mode switching, pressure-enabled Artist
Mode for Rnote, and explicit recovery instead of changing OTD output devices
on every focus transition. The user confirmed that the earlier repair worked.

## System fixes — installation subsequently verified

The first desktop authentication attempt was not authorized. The user then
installed the staged fixes. A subsequent check confirmed that the installed
tuning executable matches the repository, the service restarted successfully,
the invalid GameMode GPU setting is absent, and every `g5 doctor` check passes.
Installed fixes:

- Power tuning preserves `cpu_dynamic_boost=false` in the battery profile.
- Tuning validates one configuration snapshot before writing hardware settings.
- CPU writes are read back; failed profile/GPU commands fail the service
  instead of unconditionally returning success.
- Generated GameMode configuration omits `apply_gpu_optimisations=0`. That
  nonempty value is invalid in GameMode 1.8.2 and causes its GPU self-test to
  fail even though GPU tuning is intentionally disabled.

The session-specific installer used was:

```sh
sudo bash /tmp/g5-performance-fixes-20261028/apply.sh
```

It backs up the original system files and user configuration cache under
`/var/backups/g5-performance-20261028`, installs the tested files, synchronizes
the effective configuration, and restarts `g5-tuning.service`. An install
failure triggers restoration. After success, rollback is:

```sh
sudo bash /var/backups/g5-performance-20261028/rollback.sh
```

The installer used `/tmp` staging; the installed files and root backup persist
independently of that staging directory.

## Dota replay baseline — 13:50 local time

A subsequent replay capture recorded 26,403 frames over approximately 180
seconds. MangoHud's local control socket triggered the recording; no screen
recording was used. GameMode and VRR on DP-2 were confirmed active. System
telemetry sampled every two seconds and was stopped after capture.

| Measurement | Result |
|---|---|
| Average FPS, calculated from total frame time | 147.1 |
| Slowest 1% frame-time mean, expressed as FPS | 73.3 |
| 99th-percentile frame time | 11.41 ms |
| Frames exceeding 16.7 / 33.3 / 50 ms | 32 / 2 / 1 |
| CPU package temperature, mean / maximum | 97.4 / 100 °C |
| GPU utilization, mean | 37.8% |
| GPU temperature, mean / maximum | 73.3 / 78 °C |
| NVMe busy time | Approximately 1.1% |

MangoHud labels its 99th-percentile-derived result `1% Min FPS` (87.6 FPS).
That differs from averaging the slowest 1% of frame times (73.3 FPS); retain
the definition when comparing runs.

P-core thermal counters increased substantially during this run, and the CPU
fan reached 100%. Sustained CPU thermal throttling is now demonstrated in
actual gameplay, rather than inferred from historical counters. The low GPU
utilization is consistent with a CPU-side limit, but this run alone cannot
quantify how many FPS throttling costs. A controlled power-limit comparison
on the same replay segment is the next useful optimization test.

Raw logs, system telemetry and `dota-baseline-summary.json` are saved locally
under `~/.local/state/g5/benchmarks/`. The data is not uploaded. Replay segment,
camera and graphics settings were user-controlled rather than automated, so
future comparisons must reproduce them before claiming an improvement.

## Temporary 45 W replay trial — 14:01 local time

The first readiness check found 65 W and no restore timer, so no comparison
was recorded then. After the user reran the temporary helper, PL1 was verified
at 45 W with an active 12-minute restoration timer. All 91 system samples
during the subsequent three-minute run reported 45 W. Dota used a new process
ID; the collector and MangoHud control connection were updated accordingly.

| Measurement | 65 W baseline | 45 W trial |
|---|---:|---:|
| Average FPS from total frame time | 147.1 | 136.5 |
| Slowest 1% frame-time mean, expressed as FPS | 73.3 | 69.9 |
| 99th-percentile frame time | 11.41 ms | 11.66 ms |
| Mean CPU package temperature | 97.4 °C | 97.5 °C |
| Peak CPU package temperature | 100 °C | 100 °C |

Thermal counters continued increasing. This trial did not demonstrate a
temperature or frame-pacing improvement, so 45 W is not selected as a new
default. The average FPS was about 7.2% lower in this run; one user-controlled
replay comparison does not establish the exact causal effect of the limit.
PL1 readback proves the configured value, not actual package power draw:
unprivileged RAPL energy reads were unavailable. The package's short-term
limit remained 120 W with a long-term averaging window of about 56 seconds;
the MMIO interface separately reported 90 W long-term. These observations
warrant measuring actual package power and checking thermal behavior before
trying further limits. No persistent power configuration was changed.

Trial data was stored in `dota-45w-summary.json` beside the baseline logs.

## Benchmark cleanup

At the user's request, the raw benchmark directory, temporary capture/analysis
scripts, compiled temporary bytecode and used installer staging were deleted.
The MangoHud configuration and matugen template were restored exactly to their
pre-benchmark versions. No user benchmark units remain, and PL1 was verified
back at 65 W. The normal gaming services and installed bug fixes are retained.

The system-owned transient restore timer/service were subsequently removed
using `sudo`. Final verification at 14:10 local time found zero benchmark
system units, unit files or user units, no remaining capture scripts or data,
and PL1 at 65 W. The cleanup helper also deleted itself. The installed tuning
executable matches the tested repository version; every `g5 doctor` check
passes, Hyprland reports no configuration errors, and OTD runs in Artist Mode.
Desktop `pkexec` authentication had failed because polkit requested the root
identity (confirmed by PAM logs showing `user=root`), not the flask user's
password. This audit summary keeps the measured results after raw-data deletion.

## Verification performed

18 regression tests passed:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s linux/gentoo/tests -v
```

Coverage includes false/zero settings, failed hardware commands, invalid input
before hardware writes, normal and stretched game commands, failed monitor
IPC, cursor restoration, and delayed reaper discovery. Shell syntax checks,
configuration validation, and `git diff --check` passed.

GameMode's live built-in tests passed registration, multiple clients, reaper,
supervisor, governor switching/restoration, fan start/end hooks, and I/O
priority. Its priority test passed after starting the diagnostic at nice 0
instead of inheriting the terminal's adjusted niceness. At that point the
full self-test failed on the GPU configuration line; the subsequently installed
fix removed that line. The full self-test was not rerun during gameplay. Fans were
verified back in automatic mode afterward; CPU settings remained at the
original governor/EPP/PL1 values.

## I/O pressure investigation — resolved

A subsequent six-second host-side sample localized the pressure to Ghostty's
own service cgroup (about 45.9% stall time). Its renderer and I/O threads spent
approximately 93–100% of polling observations sleeping in `io_cqring_wait`.
NVMe busy time over the same interval was 0.72%, with approximately 0.125 MB/s
read and 1.136 MB/s written. No Ghostty I/O bandwidth/IOPS limits were configured.

This matches the behavior documented by Ghostty's maintainer: Linux accounts
idle io_uring completion waits as I/O wait even without actual disk or network
activity. The large pressure reading is therefore explained by idle-wait
accounting; it does not demonstrate an SSD bottleneck. The earlier inference
that the pressure might indicate a responsiveness problem was too broad.

Ghostty's installed configuration documentation recommends the default
`async-backend=auto`; forcing epoll is available but requires restarting the
application and is not established as a performance improvement. No terminal,
kernel or scheduler settings were changed. No persistent collector or service
was created for this investigation.

## Measurements and remaining acceptance checks

1. **Thermals:** The later Dota baseline confirmed sustained thermal throttling
   at the current settings. It does not establish the best power limit.
   The 45 W trial did not improve temperature or measured frame pacing, so
   the original 65 W setting was restored; no further limit changes selected.
   The 80 W `max` profile is not guaranteed to be faster.
2. **I/O pressure — resolved:** the dominant high reading came from Ghostty's
   idle io_uring waits, as detailed above. No disk-performance change justified.
3. **Frame pacing:** measure the same repeatable section of a game for several
   minutes, first alone and then with Discord screen share + webcam. Record
   average FPS, 1% lows, frame-time spikes, CPU/GPU clocks and temperatures,
   and throttle-counter deltas. Compare identical scenes and game settings.
4. **Compatibility:** validate fullscreen/Alt+Tab, stretched gamescope pointer
   capture, per-game VRR behavior, Sober GameMode activation, camera, screen
   sharing, and suspend/resume. These require actual workload interaction.
5. **Clock floor:** compare 1500 MHz against automatic clocks using the same
   workload. The idle power sample alone establishes neither a frame-time
   benefit nor a reason to change the floor.

Direct scanout stays disabled because the existing setup documents black
screens with gamescope. Discord's Intel encoder path stays in place because
its logs demonstrate hardware encoding and the NVIDIA path has a recorded
crash history. No new live benchmark justifies reversing either workaround.

## Primary references

- [Intel P-state behavior](https://docs.kernel.org/admin-guide/pm/intel_pstate.html)
- [Pressure stall information](https://docs.kernel.org/accounting/psi.html)
- [BFQ tradeoffs](https://docs.kernel.org/block/bfq-iosched.html)
- [Hyprland rendering options](https://wiki.hypr.land/Configuring/Basics/Variables/)
- [GameMode 1.8.2 GPU configuration handling](https://raw.githubusercontent.com/FeralInteractive/gamemode/1.8.2/daemon/gamemode-gpu.c)
- [Ghostty maintainer's explanation of idle io_uring pressure](https://github.com/ghostty-org/ghostty/discussions/9474)
- [Ghostty async-backend configuration](https://ghostty.org/docs/config/reference#async-backend)

## Desktop integration verification (2026-10-28)

- Regression suite: 24 passed; one optional offline Codex package installation
  test skipped because G5_CODEX_TEST_DEB was not supplied.
- Shell/Lua syntax and whitespace checks passed; live Hyprland config errors
  empty, Quickshell mono reloaded, and g5 doctor passed every check.
- Same-workspace focus reproduced Geometry Dash resizing to 1261x1382. After
  separating the browser from the game workspace, six focus transitions kept
  the game at 2560x1440 with both fullscreen states set. The window-open hook
  now also separates newcomers from occupied game workspaces.
- Steam action CSS regression coverage checks balanced rules and hashed class
  resolution. Bundled HUD font is readable inside Steam's container runtime.
- These checks do not establish universal runtime stability. Sustained CPU
  thermal throttling remains; camera-on/off frame-time comparisons, other
  games and suspend/resume remain manual acceptance work.
