#!/usr/bin/env python3
"""Check safe failures; optionally exercise the real official package offline.

G5_CODEX_TEST_DEB=/path/to/chatgpt_26.1023.51421_amd64.deb \
    python3 -m unittest discover -s linux/gentoo/tests -p test_codex_app.py
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/codex-app.py"
SPEC = importlib.util.spec_from_file_location("codex_app", SCRIPT)
CODEX = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CODEX)


class CodexAppTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="codex repo test ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = self.root / "data"
        self.bin = self.root / "bin"

    def test_wrong_package_leaves_installation_unchanged(self):
        package = self.root / "wrong.deb"
        package.write_bytes(b"not the verified OpenAI package")
        with self.assertRaisesRegex(RuntimeError, "Checksum mismatch"):
            CODEX.install(package, self.data, self.bin)
        self.assertFalse(self.data.exists())
        self.assertFalse(self.bin.exists())

    def test_existing_launcher_is_not_overwritten_or_downloaded_over(self):
        self.bin.mkdir()
        launcher = self.bin / "codex-app"
        launcher.write_text("existing user launcher\n")
        with patch.object(CODEX, "download_package", side_effect=AssertionError("unexpected download")):
            with self.assertRaisesRegex(RuntimeError, "existing launcher"):
                CODEX.install(None, self.data, self.bin)
        self.assertEqual(launcher.read_text(), "existing user launcher\n")
        self.assertFalse(self.data.exists())

    def test_matugen_bridge_reloads_both_modes_and_preserves_fonts(self):
        result = subprocess.run([
            "node", "-e", r"""
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const { EventEmitter } = require('node:events');
const install = require(process.argv[1]);
const file = process.argv[2];
const values = new Map([
  ['appearanceDarkChromeTheme', { fonts: { ui: 'Inter', code: 'Monocraft' }, contrast: 73, opaqueWindows: true }],
  ['appearanceLightChromeTheme', { fonts: { ui: 'Noto Sans', code: 'Monocraft' }, contrast: 51, opaqueWindows: false }],
]);
let writes = 0;
const store = {
  getEffective: key => values.get(key),
  set: (key, value) => { values.set(key, value); writes++; },
  flush: async () => {},
};
const electron = { app: new EventEmitter(), nativeTheme: { themeSource: 'system' } };
const dark = { mode: 'dark', accent: '#aabbcc', surface: '#112233', ink: '#eeeeee',
  semanticColors: { diffAdded: '#88cc88', diffRemoved: '#ff8888', skill: '#ccaaff' } };
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(condition) {
  for (let i = 0; i < 200; i++) { if (condition()) return; await delay(25); }
  throw Error('Matugen live update timed out');
}
(async () => {
  await fs.writeFile(file, JSON.stringify(dark));
  install(store, electron, file);
  await until(() => electron.nativeTheme.themeSource === 'dark');
  let theme = values.get('appearanceDarkChromeTheme');
  assert.equal(theme.surface, dark.surface);
  assert.deepEqual(theme.fonts, { ui: 'Inter', code: 'Monocraft' });
  assert.equal(theme.contrast, 73);
  assert.equal(theme.opaqueWindows, true);
  assert.equal(values.get('appearanceTheme'), 'dark');
  const beforeInvalid = writes;
  await fs.writeFile(file, JSON.stringify({ ...dark, accent: 'invalid' }));
  await delay(1200);
  assert.equal(writes, beforeInvalid);
  const light = { ...dark, mode: 'light', surface: '#eeeeee', ink: '#112233' };
  await fs.writeFile(file, JSON.stringify(light));
  await until(() => electron.nativeTheme.themeSource === 'light');
  theme = values.get('appearanceLightChromeTheme');
  assert.equal(theme.surface, light.surface);
  assert.deepEqual(theme.fonts, { ui: 'Noto Sans', code: 'Monocraft' });
  assert.equal(theme.contrast, 51);
  const beforeStop = writes;
  electron.app.emit('will-quit');
  await fs.writeFile(file, JSON.stringify(dark));
  await delay(1200);
  assert.equal(writes, beforeStop);
})().catch(error => { console.error(error); process.exitCode = 1; });
""", str(SCRIPT.with_name("codex-matugen.cjs")), str(self.root / "palette.json")
        ], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(shutil.which("matugen"), "matugen is not installed")
    def test_matugen_template_renders_valid_light_and_dark_palettes(self):
        template = SCRIPT.parents[2] / ".config/matugen/templates/chatgpt-theme.json"
        output = self.root / "palette.json"
        config = self.root / "matugen.toml"
        config.write_text(
            f"[config]\n[templates.chatgpt]\ninput_path = {json.dumps(str(template))}\n"
            f"output_path = {json.dumps(str(output))}\n"
        )
        for mode in ("light", "dark"):
            subprocess.run([
                "matugen", "image", str(SCRIPT.parents[1] / "wallpapers/nebel-dunkel.jpg"),
                "--config", str(config), "--mode", mode, "--source-color-index", "0", "--quiet"
            ], check=True, capture_output=True)
            palette = json.loads(output.read_text())
            self.assertEqual(palette["mode"], mode)
            for color in (palette["accent"], palette["surface"], palette["ink"], *palette["semanticColors"].values()):
                self.assertRegex(color, r"^#[0-9a-fA-F]{6}$")

    @unittest.skipUnless(os.environ.get("G5_CODEX_TEST_DEB"), "set G5_CODEX_TEST_DEB for offline integration test")
    def test_real_package_fresh_install_and_repeat_match_working_build(self):
        self.bin.mkdir()
        cli = self.bin / "codex"
        cli.write_text("existing Codex CLI\n")
        destination = CODEX.install(Path(os.environ["G5_CODEX_TEST_DEB"]), self.data, self.bin)
        archive = destination / "resources/app.asar"
        self.assertEqual(CODEX.digest(archive), CODEX.MINIMAL_SHA256)
        self.assertEqual(CODEX.digest(destination / "resources/app.asar.before-minimal"), CODEX.ASAR_SHA256)
        before = archive.stat().st_mtime_ns
        with patch.object(CODEX, "download_package", side_effect=AssertionError("unexpected download")):
            self.assertEqual(CODEX.install(None, self.data, self.bin), destination)
        self.assertEqual(archive.stat().st_mtime_ns, before)
        self.assertEqual(cli.read_text(), "existing Codex CLI\n")
        self.assertEqual((self.bin / "codex-app").resolve(), destination / "codex-launcher")
        self.assertTrue((destination / "ChatGPT").is_file())
        self.assertEqual(
            (destination / "resources/g5-matugen.cjs").read_bytes(),
            SCRIPT.with_name("codex-matugen.cjs").read_bytes(),
        )
        desktop = self.data / "applications/chatgpt.desktop"
        self.assertIn(f'Exec="{self.bin}/chatgpt" %U', desktop.read_text())
        if shutil.which("desktop-file-validate"):
            subprocess.run(["desktop-file-validate", str(desktop)], check=True)


if __name__ == "__main__":
    unittest.main()
