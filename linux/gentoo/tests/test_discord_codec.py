"""Regression coverage for the startup cleanup that deleted the native codec."""
import bz2
import hashlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "files/bin/discord-codec-fix"
LOADER = importlib.machinery.SourceFileLoader("discord_codec", str(SCRIPT))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
FIX = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(FIX)


def archive(script):
    contents = {"mainScreenPreload.js": script, "other.js": b"unrelated payload"}
    files, data = {}, b""
    for name, value in contents.items():
        digest = hashlib.sha256(value).hexdigest()
        files[name] = {"offset": str(len(data)), "size": len(value), "integrity": {
            "algorithm": "SHA256", "hash": digest, "blockSize": 4194304, "blocks": [digest],
        }}
        data += value
    header = json.dumps({"files": files}).encode()
    payload = struct.pack("<I", len(header)) + header + b"\0" * (-len(header) % 4)
    pickle = struct.pack("<I", len(payload)) + payload
    return struct.pack("<II", 4, len(pickle)) + pickle + data


def extract(raw, name):
    tree, base = FIX.unpack(raw)
    entry = tree["files"][name]
    start = base + int(entry["offset"])
    data = raw[start:start + entry["size"]]
    assert hashlib.sha256(data).hexdigest() == entry["integrity"]["hash"]
    return data


class DiscordCodecTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.core = self.root / "core.asar"
        self.cache = self.root / "cache"
        script = (
            f'exports.OPENH264_LIBRARY_FILE_NAME="{FIX.CODEC}";'.encode()
            + b'async function cleanupUnusedOpenH264Files(neededFileNames){'
            + b'const openH264Path="cache"; return ' + FIX.BEFORE + b';}'
        )
        self.original = archive(script)
        self.core.write_bytes(self.original)

    def test_restart_cleanup_keeps_native_and_downloaded_codecs(self):
        repaired = FIX.patch_archive(self.original)
        script = extract(repaired, "mainScreenPreload.js")
        result = subprocess.run(["node", "-e", (
            'const exports={}; const cleanupUnusedAssets=(names)=>names;'
            + script.decode() + '\ncleanupUnusedOpenH264Files(["new-codec.so"])'
            + '.then(names=>console.log(JSON.stringify(names)));'
        )], check=True, capture_output=True, text=True)
        self.assertEqual(json.loads(result.stdout), ["new-codec.so", FIX.CODEC])
        self.assertEqual(extract(repaired, "other.js"), b"unrelated payload")
        self.assertEqual(FIX.patch_archive(repaired), repaired)

    def test_bad_download_cannot_modify_discord(self):
        with patch.object(FIX.urllib.request, "urlopen", return_value=io.BytesIO(bz2.compress(b"bad"))):
            with self.assertRaisesRegex(RuntimeError, "checksum mismatch"):
                FIX.repair(self.core, self.cache)
        self.assertEqual(self.core.read_bytes(), self.original)
        self.assertFalse(self.cache.exists())
        self.assertFalse(self.core.with_name("core.asar.before-openh264-cleanup-fix").exists())

    def test_repair_downloads_once_and_preserves_original_backup(self):
        codec = b"verified codec fixture"
        with patch.object(FIX, "SHA256", hashlib.sha256(codec).hexdigest()), patch.object(
            FIX.urllib.request, "urlopen", return_value=io.BytesIO(bz2.compress(codec))
        ) as download:
            FIX.repair(self.core, self.cache)
            FIX.repair(self.core, self.cache)
            download.assert_called_once_with(FIX.URL, timeout=30)
        self.assertEqual((self.cache / FIX.CODEC).read_bytes(), codec)
        self.assertEqual(self.core.with_name("core.asar.before-openh264-cleanup-fix").read_bytes(), self.original)

    def test_future_native_version_needs_no_workaround(self):
        self.core.write_bytes(self.original.replace(FIX.CODEC.encode(), b"libopenh264-2.7.0-linux64.8.so"))
        with patch.object(FIX.urllib.request, "urlopen", side_effect=AssertionError("unexpected download")):
            FIX.repair(self.core, self.cache)
        self.assertFalse(self.cache.exists())

    def test_unknown_cleanup_code_is_not_modified(self):
        raw = self.original.replace(FIX.BEFORE, FIX.BEFORE.replace(b"neededFileNames", b"unknownArgNameX"))
        with self.assertRaisesRegex(RuntimeError, "Unknown Discord cleanup"):
            FIX.patch_archive(raw)


if __name__ == "__main__":
    unittest.main()
