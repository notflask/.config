#!/usr/bin/env python3
"""Exercise the real tuning script against disposable sysfs and command doubles."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

GENTOO = Path(__file__).resolve().parents[1]


class TuningTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / "g5.json"
        self.sysfs = self.root / "sys"
        self.boost = self.sysfs / "devices/system/cpu/intel_pstate/hwp_dynamic_boost"
        self.pl1 = self.sysfs / "class/powercap/intel-rapl:0/constraint_0_power_limit_uw"
        for path in (self.boost, self.pl1):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("untouched\n")
        self.script = self.root / "tuning"
        self.script.write_text(
            (GENTOO / "files/libexec/g5-tuning").read_text()
            .replace("/etc/g5/g5.json", str(self.config))
            .replace("/sys/", str(self.sysfs) + "/")
        )
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.mock("systemctl", "exit 1")  # Control Center not running
        self.mock("sleep", "exit 0")
        self.mock("powerprofilesctl", '''
if [ "$1" = set ]; then printf '%s' "$2" >"$TEST_ROOT/profile";
else cat "$TEST_ROOT/profile"; fi
''')
        self.mock("nvidia-smi", 'echo "$*" >>"$TEST_ROOT/gpu"')
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        TEST_ROOT=str(self.root))

    def mock(self, name, code):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + code + "\n")
        path.chmod(0o755)

    def run_tuning(self, performance):
        self.config.write_text(json.dumps({"performance": performance}))
        return subprocess.run(["sh", str(self.script)], env=self.env,
                              text=True, capture_output=True)

    def test_false_boost_and_zero_gpu_clock_are_preserved(self):
        result = self.run_tuning({"cpu_dynamic_boost": False, "cpu_pl1_watts": 25,
                                  "gpu_min_clock_mhz": 0, "power_profile": "power-saver"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.boost.read_text().strip(), "0")
        self.assertEqual(self.pl1.read_text().strip(), "25000000")
        self.assertIn("--reset-gpu-clocks", (self.root / "gpu").read_text())

    def test_missing_fields_use_defaults(self):
        result = self.run_tuning({})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.boost.read_text().strip(), "1")
        self.assertEqual(self.pl1.read_text().strip(), "65000000")
        self.assertIn("--lock-gpu-clocks=1500,3105", (self.root / "gpu").read_text())

    def test_invalid_values_fail_before_hardware_writes(self):
        for config in ({"cpu_dynamic_boost": "false"}, {"cpu_pl1_watts": 999},
                       {"gpu_min_clock_mhz": 2000, "gpu_max_clock_mhz": 1000},
                       {"power_profile": "unknown"}):
            with self.subTest(config=config):
                self.assertNotEqual(self.run_tuning(config).returncode, 0)
                self.assertEqual(self.boost.read_text().strip(), "untouched")
                self.assertFalse((self.root / "gpu").exists())

    def test_gpu_failure_is_not_reported_as_success(self):
        self.mock("nvidia-smi", 'case "$1" in --lock*) exit 1;; esac')
        self.assertNotEqual(self.run_tuning({}).returncode, 0)

    def test_failed_power_profile_prevents_hardware_writes(self):
        self.mock("powerprofilesctl", 'case "$1" in get) echo balanced;; *) exit 1;; esac')
        self.assertNotEqual(self.run_tuning({}).returncode, 0)
        self.assertEqual(self.boost.read_text().strip(), "untouched")

    def test_failed_sysfs_write_is_not_reported_as_success(self):
        self.boost.unlink()
        self.boost.mkdir()
        self.assertNotEqual(self.run_tuning({}).returncode, 0)


if __name__ == "__main__":
    unittest.main()
