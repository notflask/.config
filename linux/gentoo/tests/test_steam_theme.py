import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / '.config/matugen/steam-theme.py'
spec = importlib.util.spec_from_file_location('steam_theme', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SteamThemeTests(unittest.TestCase):
    def test_hashed_action_buttons_generate_balanced_rules(self):
        with tempfile.TemporaryDirectory() as tmp:
            module.steam = Path(tmp)
            ui = module.steam / 'steamui'
            ui.mkdir()
            (ui / 'library.js').write_text('PlayButtonContainer:"test-button-container"')
            css = module.library_button_contrast()
            self.assertEqual(css.count('{'), css.count('}'))
            self.assertEqual(len(list(module.blocks(css))), 3)
            self.assertIn('.test-button-container button', css)
            self.assertIn('color:var(--m-on-primary-container)', css)
            self.assertIn('background:var(--m-primary-container)', css)

    def test_missing_action_container_does_not_emit_global_rules(self):
        with tempfile.TemporaryDirectory() as tmp:
            module.steam = Path(tmp)
            self.assertEqual(module.library_button_contrast(), '')
