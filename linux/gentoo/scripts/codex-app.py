#!/usr/bin/env python3
"""Install the verified OpenAI desktop build and its minimal Linux window layout.

Run without sudo. An optional .deb argument supports an offline installation.
Keep the version, checksums, and patch together when updating this build.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import tarfile
import tempfile
import urllib.request


VERSION = "26.1023.51421"
PACKAGE_SHA256 = "4484dc2b54fc0978beb23b8d8d717494e4e0b4fbeab0a876739105e50b44de5a"
ASAR_SHA256 = "5e5e186b50fe970b45744fd7bdf288980862af2d01c588d12dd509fb3c794c8a"
LEGACY_MINIMAL_SHA256 = "97af7e2fca2df4ace87071326034b52e86fb9e7f4d21ae078975a44e3e08b0f3"
MINIMAL_SHA256 = "eb43951c135ffee23f22b1673b8446aadcfc0a954b9f63f7d26bc7a4d4d701dc"
PACKAGE_NAME = f"chatgpt_{VERSION}_amd64.deb"
PACKAGE_URL = (
    "https://persistent.oaistatic.com/codex-app-prod/linux/deb/"
    f"pool/main/c/chatgpt/{PACKAGE_NAME}"
)
WINDOW_PATCHES = (
    (
        b"z=new k.BrowserWindow(R);r&&",
        b"z=new k.BrowserWindow(process.platform===`linux`&&(d===`primary`||d===`detached`)?"
        b"{...R,frame:!1,titleBarOverlay:!1}:R);process.platform===`linux`&&"
        b"(d===`primary`||d===`detached`)&&z.setMenuBarVisibility(!1);"
        b"process.platform===`linux`&&require(require(`node:path`).join("
        b"process.resourcesPath,`g5-matugen.cjs`))(this.options.settingsStore,k);r&&",
    ),
    (
        b"n.setTitleBarOverlay(B9(t))",
        b"(process.platform!==`linux`&&n.setTitleBarOverlay(B9(t)))",
    ),
    (
        b"e.setTitleBarOverlay(B9(this.windowZooms.get(e.id)))",
        b"(process.platform!==`linux`&&e.setTitleBarOverlay(B9(this.windowZooms.get(e.id))))",
    ),
)
MENU_CSS = (
    b"\n/* Local Linux minimal-window customization. */\n"
    b":root[data-codex-os=linux] ._ApplicationMenuTopBar_azz1c_2{display:none!important}\n"
)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require_digest(path, expected):
    if digest(path) != expected:
        raise RuntimeError(f"Checksum mismatch: {path}; installation left unchanged")


def patch_archive(source, destination):
    """Append two replacement entries; leave all other ASAR data untouched."""
    require_digest(source, ASAR_SHA256)
    with source.open("rb") as original:
        first = original.read(16)
        base = 8 + struct.unpack("<I", first[4:8])[0]
        header = json.loads(original.read(struct.unpack("<I", first[12:16])[0]))
        build = header["files"][".vite"]["files"]["build"]["files"]
        assets = header["files"]["webview"]["files"]["assets"]["files"]
        replacements = []
        offset = source.stat().st_size - base
        for entry, is_script in (
            (build["main-UOTY8NmV.js"], True),
            (assets["app-primary-4ccde6131b6d.css"], False),
        ):
            original.seek(base + int(entry["offset"]))
            data = original.read(entry["size"])
            if is_script:
                for before, after in WINDOW_PATCHES:
                    if data.count(before) != 1:
                        raise RuntimeError("Unsupported window code; refusing patch")
                    data = data.replace(before, after, 1)
                with tempfile.TemporaryDirectory(prefix="codex-syntax-") as tmp:
                    script = Path(tmp) / "main.js"
                    script.write_bytes(data)
                    subprocess.run(["node", "--check", str(script)], check=True)
            else:
                if b"._ApplicationMenuTopBar_azz1c_2{" not in data:
                    raise RuntimeError("Unsupported menu CSS; refusing patch")
                data += MENU_CSS
            entry["offset"], entry["size"] = str(offset), len(data)
            integrity = entry["integrity"]
            if integrity["algorithm"] != "SHA256":
                raise RuntimeError("Unsupported ASAR integrity algorithm")
            integrity["hash"] = hashlib.sha256(data).hexdigest()
            block_size = integrity["blockSize"]
            integrity["blocks"] = [
                hashlib.sha256(data[i:i + block_size]).hexdigest()
                for i in range(0, len(data), block_size)
            ]
            replacements.append(data)
            offset += len(data)

        encoded = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
        payload = struct.pack("<I", len(encoded)) + encoded + b"\0" * (-len(encoded) % 4)
        header_pickle = struct.pack("<I", len(payload)) + payload
        with destination.open("wb") as output:
            output.write(struct.pack("<II", 4, len(header_pickle)))
            output.write(header_pickle)
            original.seek(base)
            shutil.copyfileobj(original, output, 1024 * 1024)
            for data in replacements:
                output.write(data)
    # Exact match to the build already exercised in the desktop app, including
    # all untouched entries and both modified entries' integrity metadata.
    require_digest(destination, MINIMAL_SHA256)


def download_package():
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "codex-app"
    cache.mkdir(parents=True, exist_ok=True)
    package = cache / PACKAGE_NAME
    if not package.exists():
        partial = package.with_suffix(".deb.partial")
        try:
            with urllib.request.urlopen(PACKAGE_URL, timeout=30) as response, partial.open("wb") as output:
                shutil.copyfileobj(response, output, 1024 * 1024)
            require_digest(partial, PACKAGE_SHA256)
            partial.replace(package)
        finally:
            partial.unlink(missing_ok=True)
    require_digest(package, PACKAGE_SHA256)
    return package


def extract_package(package, staging):
    process = subprocess.Popen(["ar", "p", str(package), "data.tar.xz"], stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode="r|xz") as archive:
            archive.extractall(staging, filter="data")
        # Drain archive padding before waiting for ar, including on small pipes.
        while process.stdout.read(1024 * 1024):
            pass
    except BaseException:
        process.kill()
        raise
    finally:
        process.stdout.close()
        returncode = process.wait()
    if returncode:
        raise RuntimeError(f"Could not extract {package}")


def check_link(path, target):
    if path.exists() or path.is_symlink():
        if not path.is_symlink() or os.readlink(path) != str(target):
            raise RuntimeError(f"Refusing to replace an existing launcher: {path}")


def link(path, target):
    check_link(path, target)
    if not path.is_symlink():
        path.symlink_to(target)


def app_is_running(destination):
    executable = destination / "ChatGPT"
    for process in Path("/proc").iterdir():
        if not process.name.isdigit():
            continue
        try:
            if (process / "exe").resolve() == executable:
                return True
        except OSError:
            continue
    return False


def install(package, data_dir, bin_dir):
    appbase = data_dir / "chatgpt"
    destination = appbase / VERSION
    links = (
        (appbase / "current", VERSION),
        (bin_dir / "chatgpt", appbase / "current" / "codex-launcher"),
        (bin_dir / "codex-app", "chatgpt"),
    )
    for path, target in links:
        check_link(path, target)
    if destination.exists():
        # Also adopts the identical, manually installed build from this session.
        original = destination / "resources/app.asar"
        backup = destination / "resources/app.asar.before-minimal"
        require_digest(backup, ASAR_SHA256)
        if digest(original) == LEGACY_MINIMAL_SHA256:
            if app_is_running(destination):
                raise RuntimeError("Quit ChatGPT before adding the Matugen theme loader")
            patched = destination / "resources/app.asar.minimal"
            patch_archive(backup, patched)
            shutil.copy2(Path(__file__).with_name("codex-matugen.cjs"), destination / "resources/g5-matugen.cjs")
            patched.replace(original)
        require_digest(original, MINIMAL_SHA256)
        require_digest(destination / "resources/g5-matugen.cjs", digest(Path(__file__).with_name("codex-matugen.cjs")))
    else:
        package = Path(package) if package else download_package()
        require_digest(package, PACKAGE_SHA256)
        appbase.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".install-", dir=appbase) as tmp:
            staging = Path(tmp)
            extract_package(package, staging)
            app = staging / "usr/lib/chatgpt"
            original = app / "resources/app.asar"
            patched = app / "resources/app.asar.minimal"
            patch_archive(original, patched)
            original.rename(app / "resources/app.asar.before-minimal")
            patched.rename(original)
            shutil.copy2(Path(__file__).with_name("codex-matugen.cjs"), app / "resources/g5-matugen.cjs")
            shutil.copy2(staging / "usr/share/pixmaps/chatgpt.png", app / "chatgpt.png")
            (app / "MINIMAL-WINDOW.txt").write_text(
                f"ChatGPT (Codex) {VERSION}, minimal Linux layout.\n"
                f"Source: {PACKAGE_URL}\nPackage SHA256: {PACKAGE_SHA256}\n"
                "Menu strip and window buttons hidden; keyboard shortcuts retained.\n"
                "Matugen colors: ~/.cache/matugen/chatgpt-theme.json, reloaded automatically.\n"
                "To undo: quit the app, copy resources/app.asar.before-minimal over\n"
                "resources/app.asar, then reopen it.\n"
                "Version-specific patch: update the installer and reverify before upgrading.\n"
            )
            app.rename(destination)
    bin_dir.mkdir(parents=True, exist_ok=True)
    for path, target in links:
        link(path, target)
    applications = data_dir / "applications"
    applications.mkdir(parents=True, exist_ok=True)
    executable = str(bin_dir / "chatgpt")
    for character in ("\\", '"', "`", "$"):
        executable = executable.replace(character, "\\" + character)
    desktop = (
        "[Desktop Entry]\nName=ChatGPT (Codex)\nComment=ChatGPT by OpenAI\n"
        f'Exec="{executable}" %U\nIcon={appbase}/current/chatgpt.png\n'
        "Type=Application\nTerminal=false\nStartupNotify=true\nCategories=Development;\n"
        "Keywords=Codex;OpenAI;ChatGPT;\nMimeType=x-scheme-handler/codex;\n"
    )
    entry = applications / "chatgpt.desktop"
    if not entry.exists() or entry.read_text() != desktop:
        entry.write_text(desktop)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", nargs="?", type=Path, help="verified .deb for offline installation")
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error("run as the desktop user, without sudo")
    if platform.machine() != "x86_64":
        parser.error("this verified build is for x86_64")
    data_dir = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    destination = install(args.package, data_dir, Path.home() / ".local/bin")
    subprocess.run(["update-desktop-database", str(data_dir / "applications")], check=True)
    handler = subprocess.check_output(["xdg-mime", "query", "default", "x-scheme-handler/codex"], text=True).strip()
    if not handler:
        subprocess.run(["xdg-mime", "default", "chatgpt.desktop", "x-scheme-handler/codex"], check=True)
    print(f"ChatGPT (Codex) {VERSION}: {destination}; minimal window layout installed")


if __name__ == "__main__":
    main()
