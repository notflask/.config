#!/usr/bin/env python3
"""Exercise the launcher with isolated configuration and mocked desktop tools."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/gaming-mode.sh"
MONITORS = [
    {"name": "DP-2", "width": 2560, "height": 1440,
     "refreshRate": 179.959, "focused": True}
]
MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, sys, time
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ["MOCK_ROOT"])
with (root / "events").open("a") as log:
    log.write(json.dumps([name, args]) + "\n")
if name == "sleep":
    time.sleep(0.01)
elif name == "gamescope":
    (root / "game-pid").write_text(str(os.getpid()))
    time.sleep(float(os.environ.get("MOCK_GAME_SECONDS", "0.5")))
elif name == "pgrep":
    sys.exit(1)
elif name == "hyprctl":
    command = args[0]
    if command == "monitors":
        if os.environ.get("MOCK_MONITOR_FAILURE") == "1":
            sys.exit(1)
        print(os.environ["MOCK_MONITORS"])
    elif command == "getoption":
        print(json.dumps({"bool": os.environ.get("MOCK_NO_WARPS", "true") == "true"}))
    elif command == "clients":
        pid = root / "game-pid"
        print(json.dumps([{"pid": int(pid.read_text()), "mapped": True,
                           "address": "0xabc", "at": [0, 0],
                           "size": [2560, 1440]}] if pid.exists() else []))
    elif command == "activewindow":
        print(json.dumps({"pid": int((root / "game-pid").read_text())}))
    elif command == "cursorpos":
        print("1280, 720")
    elif command == "dispatch" and "window =" in args[1]:
        if os.environ.get("MOCK_FOCUS_FAILURE") == "1":
            sys.exit(1)
'''


class GamingModeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="g5-gaming-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "g5").mkdir()
        (self.root / "bin").mkdir()
        for name in ("hyprctl", "gamescope", "ionice", "sleep", "pgrep"):
            executable = self.root / "bin" / name
            executable.write_text(MOCK)
            executable.chmod(0o755)
        self.env = os.environ | {
            "HOME": str(self.root),
            "XDG_CACHE_HOME": str(self.root),
            "XDG_STATE_HOME": str(self.root),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "HYPRLAND_INSTANCE_SIGNATURE": "mock",
            "PATH": str(self.root / "bin") + ":" + os.environ["PATH"],
            "MOCK_ROOT": str(self.root),
            "MOCK_MONITORS": json.dumps(MONITORS),
        }
        self.config()

    def config(self, **gaming):
        (self.root / "g5/config.json").write_text(json.dumps({"gaming": gaming}))

    def run_launcher(self, *args, dry=True):
        return subprocess.run(
            ["bash", str(SCRIPT), *(["--dry-run"] if dry else []),
             *args, "/usr/bin/true"],
            env=self.env, capture_output=True, text=True, timeout=8,
        )

    def events(self, tool):
        return [args for name, args in
                map(json.loads, (self.root / "events").read_text().splitlines())
                if name == tool]

    def test_hud_false_is_preserved(self):
        self.config(hud=False)
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "gamemoderun /usr/bin/true")

    def test_default_native_command(self):
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "gamemoderun mangohud /usr/bin/true")

    def test_stretch_uses_valid_monitor_dimensions(self):
        result = self.run_launcher("--stretch", "1920x1440")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-W 2560 -H 1440 -r 177", result.stdout)

    def test_non_hyprland_retains_fallback_dimensions(self):
        self.env["HYPRLAND_INSTANCE_SIGNATURE"] = ""
        result = self.run_launcher("--stretch", "1920x1440")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-W 2560 -H 1440 -r 177", result.stdout)

    def test_failed_monitor_query_prevents_launch(self):
        self.env["MOCK_MONITOR_FAILURE"] = "1"
        result = self.run_launcher("--stretch", "1920x1440", dry=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hyprctl monitors -j", result.stderr)
        self.assertEqual(self.events("gamescope"), [])

    def test_invalid_geometry_prevents_launch(self):
        for field, value in (("width", 0), ("height", 12.5),
                             ("refreshRate", 0), ("refreshRate", 1001)):
            with self.subTest(field=field, value=value):
                monitor = MONITORS[0] | {field: value}
                self.env["MOCK_MONITORS"] = json.dumps([monitor])
                result = self.run_launcher("--stretch", "1920x1440", dry=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.events("gamescope"), [])

    def test_cursor_setting_restored_after_focus_ipc_failure(self):
        self.env["MOCK_FOCUS_FAILURE"] = "1"
        result = self.run_launcher("--stretch", "1920x1440", dry=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        evaluations = [args[1] for args in self.events("hyprctl") if args[0] == "eval"]
        self.assertEqual(evaluations, [
            "hl.config({ cursor = { no_warps = false } })",
            "hl.config({ cursor = { no_warps = true } })",
        ])

    def test_original_false_cursor_setting_is_preserved(self):
        self.env.update(MOCK_FOCUS_FAILURE="1", MOCK_NO_WARPS="false")
        result = self.run_launcher("--stretch", "1920x1440", dry=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(args[0] == "eval" for args in self.events("hyprctl")))

    def test_missing_reaper_is_retried(self):
        self.env["MOCK_GAME_SECONDS"] = "3"
        result = self.run_launcher("--stretch", "1920x1440", dry=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.events("pgrep")), 30)


if __name__ == "__main__":
    unittest.main()
