"""Exercise Vencord setup without root or a real Discord installation."""
from pathlib import Path
import subprocess
import tempfile
import unittest


GENTOO = Path(__file__).resolve().parents[1]


class VencordTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.discord = self.root / "discord"
        self.resources = self.discord / "resources"
        self.resources.mkdir(parents=True)
        self.app = self.resources / "app.asar"
        self.app.write_text("current Discord")
        self.cache = self.root / "cache"
        self.cache.mkdir()
        self.cli = self.cache / "VencordInstallerCli-v1.4.2"
        self.cli.write_text('''#!/bin/sh
test "$1" = -install && test "$2" = -location || exit 1
mv "$3/resources/app.asar" "$3/resources/_app.asar"
printf '%s' 'require("/home/test/.config/Vencord/dist/patcher.js")' > "$3/resources/app.asar"
''')
        self.cli.chmod(0o755)

    def run_setup(self):
        source = (GENTOO / "files/bin/g5").read_text()
        function = source.split("setup_vencord() {", 1)[1].split("\n}\n", 1)[0]
        function = "setup_vencord() {" + function + "\n}\n"
        function = function.replace("/opt/discord", str(self.discord)).replace("/var/cache", str(self.cache))
        return subprocess.run(["bash", "-c", 'set -euo pipefail\nid() { echo 0; }\n'
                               + function + '\nsetup_vencord'], text=True, capture_output=True)

    def test_stale_backup_does_not_skip_install_or_restore_old_discord(self):
        (self.resources / "_app.asar").write_text("old Discord")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("/Vencord/dist/patcher.js", self.app.read_text())
        self.assertEqual((self.resources / "_app.asar").read_text(), "current Discord")
        backups = list(self.resources.glob("app.asar.before-vencord-repair.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "old Discord")

    def test_installed_loader_is_idempotent(self):
        self.assertEqual(self.run_setup().returncode, 0)
        before = self.app.read_bytes()
        self.cli.write_text("#!/bin/sh\nexit 1\n")
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.app.read_bytes(), before)

    def test_installer_failure_is_reported(self):
        self.cli.write_text("#!/bin/sh\nexit 1\n")
        self.assertNotEqual(self.run_setup().returncode, 0)

    def test_installer_success_without_loader_is_failure(self):
        self.cli.write_text("#!/bin/sh\nexit 0\n")
        self.assertNotEqual(self.run_setup().returncode, 0)


if __name__ == "__main__":
    unittest.main()
