#!/usr/bin/env python3
"""Verify the real configuration CLI without changing the user's settings."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

GENTOO = Path(__file__).resolve().parents[1]


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ("files/bin/g5", "config/g5.json", "config/g5.schema.json"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(GENTOO / name, path)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / "user-config"))

    def command(self, *args):
        return subprocess.run([str(self.root / "files/bin/g5"), "config", *args],
                              env=self.env, text=True, capture_output=True)

    def config(self):
        return json.loads((self.root / "config/g5.json").read_text())

    def test_set_false_preserves_boolean_type(self):
        for key in ("gaming.hud", "performance.cpu_dynamic_boost"):
            result = self.command("set", key, "false")
            self.assertEqual(result.returncode, 0, result.stderr)
            section, field = key.split(".")
            self.assertIs(self.config()[section][field], False)

    def test_plain_string_still_works(self):
        result = self.command("set", "performance.power_profile", "balanced")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.config()["performance"]["power_profile"], "balanced")

    def test_invalid_clock_range_does_not_change_config(self):
        before = self.config()
        result = self.command("set", "performance.gpu_max_clock_mhz", "1000")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.config(), before)


if __name__ == "__main__":
    unittest.main()
