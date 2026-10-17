#!/usr/bin/env python3
# ============================================================
#  steam-theme.py – Steam-Theme „matugen“ für Millennium bauen
#
#  Steam hat keine Farbvariablen, sondern feste Farben in gehashten Klassen,
#  die sich mit jedem Update ändern. Darum liest das Skript Steams eigene
#  CSS (steamui/css), behält nur Regeln mit Farben und setzt die Grautöne
#  auf die Flächen von matugen um (nach Helligkeit, von surface bis
#  on_surface) und Steams Blau auf primary. Ergebnis: recolor.css.
#
#  Dazu kommen colors.css (matugen, templates/steam-colors.css) und
#  base.css/skin.json (steam/). theme.sh ruft es nach jedem Farbwechsel auf,
#  der steam-Wrapper vor jedem Start (recolor.css nur neu, wenn Steams CSS
#  sich geändert hat). Steam übernimmt die Farben beim nächsten Start.
# ============================================================

import colorsys
import hashlib
import json
import math
import os
import re
import shutil
import sys
from pathlib import Path

home = Path.home()
here = Path(__file__).resolve().parent
cache = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache"))
steam = home / ".local/share/Steam"
theme = steam / "millennium/themes/matugen"
colors = cache / "matugen/steam-colors.css"

# ── Farben ───────────────────────────────────────────────────

def srgb_to_oklab(r, g, b):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = lin(r), lin(g), lin(b)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def hex_rgb(h):
    h = h.lstrip("#")
    if len(h) in (3, 4):
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)), (int(h[6:8], 16) / 255 if len(h) == 8 else 1.0)


# Steams Grautöne (dunkel → hell) und welche Fläche von matugen sie werden.
# Dazwischen wird in OKLab gemischt.
ANCHORS = [
    ("#000000", "surface-lowest"),
    ("#0e141b", "surface-lowest"),
    ("#171d25", "surface"),
    ("#23262e", "surface-low"),
    ("#3d4450", "surface-high"),
    ("#67707b", "outline-variant"),
    ("#8b929a", "outline"),
    ("#b8bcbf", "on-surface-variant"),
    ("#dcdedf", "on-surface"),
    ("#ffffff", "on-surface"),
]
ANCHORS = [(srgb_to_oklab(*hex_rgb(h)[0])[0], v) for h, v in ANCHORS]

NEUTRAL_CHROMA = 0.06       # darunter: Grau (Steams Grautöne sind leicht bläulich)
BLUE_HUE = (215, 290)       # Steams Blau (#1a9fff, #1a44c2 …), OKLab-Farbton
TEXT_PROPS = ("color", "fill", "stroke", "caret-color", "-webkit-text-fill-color",
              "text-decoration-color", "outline-color", "column-rule-color")


def neutral(L):
    for (l1, v1), (l2, v2) in zip(ANCHORS, ANCHORS[1:]):
        if L <= l2:
            t = 0 if l2 == l1 else max(0.0, (L - l1) / (l2 - l1))
            t = round(t * 20) / 20
            if v1 == v2 or t == 0:
                return f"var(--m-{v1})"
            if t == 1:
                return f"var(--m-{v2})"
            return f"color-mix(in oklab, var(--m-{v1}) {round((1 - t) * 100)}%, var(--m-{v2}))"
    return f"var(--m-{ANCHORS[-1][1]})"


def light_theme():
    """Helle Farben von matugen (surface hell)?"""
    return "surface" in PALETTE and srgb_to_oklab(*hex_rgb(PALETTE["surface"])[0])[0] > 0.6


def recolor(rgb, alpha, prop, flat=False):
    if flat and rgb in ((255, 255, 255), (0, 0, 0)):
        # Hoher Kontrast (schwarz/weiß) sanfter: Kanten wie in Discord,
        # weiße Hervorhebungen in der Akzentfarbe
        white = rgb == (255, 255, 255)
        if prop.startswith(("border", "outline")):
            new = "var(--m-outline-variant)"
        elif prop.startswith("background"):
            new = "var(--m-primary-container)" if white else "var(--m-surface)"
        else:
            new = "var(--m-on-surface)" if white else "var(--m-on-primary-container)"
        return new if alpha >= 0.999 else f"color-mix(in srgb, {new} {round(alpha * 100, 1)}%, transparent)"
    L, a, b = srgb_to_oklab(*rgb)
    chroma = math.hypot(a, b)
    hue = math.degrees(math.atan2(b, a)) % 360
    if chroma < NEUTRAL_CHROMA:
        new = neutral(L)
    elif BLUE_HUE[0] <= hue <= BLUE_HUE[1]:
        textish = prop in TEXT_PROPS or prop.startswith("border") or prop.startswith("outline")
        new = "var(--m-primary)" if textish else "var(--m-primary-container)"
    elif prop in TEXT_PROPS and L > 0.6 and light_theme():
        # Helle Farben (Grün im Spiel, Rot …) als Schrift auf hellen Flächen
        # kaum lesbar: zur Schriftfarbe hin abdunkeln, Farbton bleibt
        new = f"color-mix(in oklab, rgb{rgb} 45%, var(--m-on-surface))"
    else:
        return None  # andere Farben (Grün, Rot …) bleiben
    if alpha >= 0.999:
        return new
    return f"color-mix(in srgb, {new} {round(alpha * 100, 1)}%, transparent)"


def oklab_to_srgb(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    def gam(c):
        c = max(0.0, min(1.0, c))
        return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return tuple(round(gam(c) * 255) for c in rgb)


def resolve(expr, palette):
    """Ausdruck aus recolor() → feste Farbe (#rrggbb[aa]) aus colors.css,
    für Stellen ohne CSS-Variablen (eingebettete SVG-Bilder)."""
    alpha = 1.0
    m = re.fullmatch(r"color-mix\(in srgb, (.*) ([\d.]+)%, transparent\)", expr)
    if m:
        expr, alpha = m.group(1), float(m.group(2)) / 100
    names = re.findall(r"var\(--m-([a-z-]+)\)", expr)
    if "rgb(" in expr or not names or any(n not in palette for n in names):
        return None
    p = re.search(r" (\d+)%,", expr)
    t = int(p.group(1)) / 100 if p and len(names) == 2 else 1.0
    labs = [srgb_to_oklab(*hex_rgb(palette[n])[0]) for n in names]
    lab = labs[0] if len(labs) == 1 else tuple(t * x + (1 - t) * y for x, y in zip(*labs))
    out = "#%02x%02x%02x" % oklab_to_srgb(*lab)
    return out if alpha >= 0.999 else out + "%02x" % round(alpha * 255)


def read_palette():
    if not colors.exists():
        return {}
    return dict(re.findall(r"--m-([a-z-]+):\s*(#[0-9a-fA-F]{6})", colors.read_text()))


PALETTE = {}

SVG_COLOR_RE = re.compile(r"(?:#|%23)[0-9a-fA-F]{6}\b|(?:#|%23)[0-9a-fA-F]{3}\b|\b(?:white|black)\b")


def recolor_svg(url, prop):
    """Farben in eingebetteten SVG-Bildern (url(data:image/svg+xml…))."""
    def sub(m):
        tok = m.group(0)
        expr = recolor(*parse_color("#" + tok[3:] if tok.startswith("%23") else tok), prop)
        new = expr and resolve(expr, PALETTE)
        if not new:
            return tok
        return "%23" + new[1:]  # „#“ beendet sonst die data:-URL
    return SVG_COLOR_RE.sub(sub, url)


COLOR_RE = re.compile(
    r"#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3,4}\b"
    r"|(?:rgb|hsl)a?\(\s*[\d.]+(?:%|deg)?\s*[, ]\s*[\d.]+%?\s*[, ]\s*[\d.]+%?\s*(?:[,/]\s*[\d.]+%?\s*)?\)"
    r"|\b(?:white|black)\b", re.I)


def parse_color(tok):
    t = tok.lower()
    if t == "white":
        return (255, 255, 255), 1.0
    if t == "black":
        return (0, 0, 0), 1.0
    if t.startswith("#"):
        return hex_rgb(t)
    nums = re.findall(r"[\d.]+%?", t)
    if t.startswith("hsl"):
        h = float(nums[0]) / 360
        sat, li = float(nums[1].rstrip("%")) / 100, float(nums[2].rstrip("%")) / 100
        rgb = tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, li, sat))
        a = nums[3] if len(nums) > 3 else "1"
        return rgb, (float(a[:-1]) / 100 if a.endswith("%") else float(a))
    def ch(n):
        return float(n[:-1]) * 2.55 if n.endswith("%") else float(n)
    def al(n):
        return float(n[:-1]) / 100 if n.endswith("%") else float(n)
    rgb = tuple(min(255, round(ch(n))) for n in nums[:3])
    return rgb, (al(nums[3]) if len(nums) > 3 else 1.0)


def recolor_value(prop, value, flat=False):
    changed = False
    def sub(m):
        nonlocal changed
        rgb, alpha = parse_color(m.group(0))
        new = recolor(rgb, alpha, prop, flat)
        if new is None:
            return m.group(0)
        changed = True
        return new
    # Bilder (url(...)) nicht anfassen – außer eingebetteten SVGs
    parts = re.split(r"(url\((?:'[^']*'|\"[^\"]*\"|[^)]*)\))", value)
    out = []
    for p in parts:
        if p.startswith("url("):
            if "data:image/svg+xml" in p and ";base64" not in p:
                new = recolor_svg(p, "fill")
                changed |= new != p
                p = new
            out.append(p)
        else:
            out.append(COLOR_RE.sub(sub, p))
    out = "".join(out)
    return out if changed else None

# ── CSS lesen ────────────────────────────────────────────────

def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def blocks(css, i=0):
    """(Kopf, Inhalt) für jeden Block auf dieser Ebene."""
    n = len(css)
    while i < n:
        start = i
        quote = None
        while i < n:
            c = css[i]
            if c == "\\":  # Escape (auch in Selektoren: .KeyTheme_\\")
                i += 2
                continue
            if quote:
                if c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c == "{":
                break
            elif c == ";":  # @import, @charset …
                start = i + 1
            i += 1
        if i >= n:
            return
        head = css[start:i].strip()
        depth, j, quote = 1, i + 1, None
        while j < n and depth:
            c = css[j]
            if c == "\\":
                j += 2
                continue
            if quote:
                if c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            j += 1
        yield head, css[i + 1:j - 1]
        i = j


def split_decls(body):
    out, cur, depth, quote, escaped = [], [], 0, None, False
    for c in body:
        if escaped:
            escaped = False
        elif c == "\\":
            escaped = True
        elif quote:
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif c == ";" and depth == 0:
            out.append("".join(cur))
            cur = []
            continue
        cur.append(c)
    out.append("".join(cur))
    return out


# Monocraft ist eine Pixelschrift: ein Pixel = 1/9 em. Nur bei 9, 18, 27 …
# px liegen die Pixel auf ganzen Bildschirmpixeln, sonst werden Striche
# ungleich dick (13px: mal 1, mal 2 Pixel). Darum Steams Größen einrasten.
PX_RE = re.compile(r"([\d.]+)px")


def snap_size(value):
    m = PX_RE.fullmatch(re.sub(r"\s*!important\s*$", "", value.strip()))
    if not m:
        return None
    px = float(m.group(1))
    if px <= 10.5:
        return 9
    if px <= 22.5:
        return 18
    return round(px / 9) * 9


SKIP_AT = ("@keyframes", "@-webkit-keyframes", "@font-face", "@page", "@property")
# Farbthemen der Bildschirmtastatur (Big Picture): Tausende Regeln, nicht nötig
SKIP_SELECTOR = re.compile(r"KeyTheme_|\.Spectrum\b")


# Steams eigener flacher Stil (Einstellung „hoher Kontrast“): ohne Unschärfe,
# ohne verschwommene Kopien der Spielbilder, Flächen deckend. Diese Regeln
# gelten hier immer, mit sanfteren Farben (recolor(flat=True)).
FLAT_MEDIA = re.compile(r"^@media\s*\(\s*prefers-contrast\s*:\s*more\s*\)$", re.I)


def convert(css, flat=False):
    out = []
    for head, body in blocks(css):
        if head.startswith("@"):
            if head.lower().startswith(SKIP_AT):
                continue
            if FLAT_MEDIA.match(head):
                continue  # kommt in flatten() ohne @media
            inner = convert(body, flat)
            if inner:
                out.append(f"{head}{{{inner}}}")
            continue
        if SKIP_SELECTOR.search(head):
            continue
        decls = []
        size = None
        for d in split_decls(body):
            if ":" in d and d.split(":", 1)[0].strip().lower() == "font-size":
                size = snap_size(d.split(":", 1)[1])
        for d in split_decls(body):
            if ":" not in d:
                continue
            prop, value = d.split(":", 1)
            prop = prop.strip().lower()
            if prop.startswith(("transition", "animation", "will-change")):
                continue
            value = re.sub(r"\s*!important\s*$", "", value.strip())
            if prop == "font-size" and size:
                decls.append(f"font-size:{size}px!important")
                continue
            if prop == "line-height" and size:
                m = PX_RE.fullmatch(value)
                if m and float(m.group(1)) < size + 2:
                    decls.append(f"line-height:{size + 2}px!important")
                    continue
            new = recolor_value(prop, value, flat)
            if new and prop == "background" and COLOR_RE.fullmatch(value):
                # nur eine Farbe: als background-color, sonst setzt die
                # Kurzform mit !important Bild, Wiederholung und Lage zurück
                prop = "background-color"
            if new:
                decls.append(f"{prop}:{new}!important")
            elif flat and value:
                decls.append(f"{prop}:{value}!important")  # auch Ränder, Deckkraft …
        if decls:
            out.append(f"{head}{{{';'.join(decls)}}}")
    return "".join(out)

def flatten(css):
    """Inhalt aller @media (prefers-contrast: more)-Blöcke, ohne die Abfrage."""
    out = []
    for head, body in blocks(css):
        if FLAT_MEDIA.match(head):
            out.append(convert(body, flat=True))
        elif head.startswith("@") and not head.lower().startswith(SKIP_AT):
            inner = flatten(body)
            if inner:
                out.append(f"{head}{{{inner}}}")
    return "".join(out)

def library_list():
    """Bibliothek-Liste: nicht installierte Spiele deutlich blasser.
    Steam nimmt dafür ein helles Grau (#cbced8 statt #fff) – nach der
    Umsetzung liegt das bei hellen Farben fast auf on_surface, beide Arten
    sähen gleich aus. Die gehashten Klassen stehen nur in Steams JS
    (Modul mit Container, Uninstalled, Installed …)."""
    m = None
    for js in sorted((steam / "steamui").glob("*.js")):
        m = re.search(r'\{Container:"([\w-]+)",HoverOverlay:"([\w-]+)",Uninstalled:"([\w-]+)",'
                      r'Selected:"([\w-]+)"', js.read_text(errors="replace"))
        if m:
            break
    if not m:
        return ""
    item, hover, uninstalled, selected = (f".{c}" for c in m.groups())
    u = f"{item}{uninstalled}"
    return (f"{u}{{color:var(--m-outline)!important}}\n"
            f"{u}:hover,{u}{hover},{u}{selected},{selected} {u}"
            f"{{color:var(--m-on-surface-variant)!important}}\n")


# ── Theme schreiben ──────────────────────────────────────────

def install_fonts():
    """Monocraft nach ~/.local/share/fonts. Steams Browser läuft in
    pressure-vessel; der bindet /usr/local/share/fonts zwar ein, seine
    fontconfig kennt aber nur /usr/share/fonts und ~/.local/share/fonts –
    sonst zeigt Steam statt Monocraft die Ersatzschrift (DejaVu Sans Mono)."""
    target = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share")) / "fonts/Monocraft"
    # Ohne Light/ExtraLight: Steams dünne Schrift (100–300) nimmt sonst
    # Monocrafts Haarlinien-Schnitte, die bei kleinen Größen zerfallen
    for old in target.glob("Monocraft-*Light*.ttf"):
        old.unlink()
    for src in sorted(Path("/usr/local/share/fonts").rglob("Monocraft*.ttf")):
        if "Light" in src.name:
            continue
        dst = target / src.name
        if not dst.exists() or dst.stat().st_size != src.stat().st_size:
            target.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)


def main():
    if not steam.is_dir():
        return 0
    sources = sorted((steam / "steamui/css").glob("*.css"))
    if not sources:
        print("steam-theme: keine CSS in steamui/css gefunden", file=sys.stderr)
        return 1
    theme.mkdir(parents=True, exist_ok=True)
    first_time = not (theme / "skin.json").exists()

    install_fonts()
    for name in ("skin.json", "base.css"):
        shutil.copyfile(here / "steam" / name, theme / name)
    if colors.exists():
        shutil.copyfile(colors, theme / "colors.css")

    # recolor.css nur neu, wenn sich Steams CSS, die Farben (für SVG-Bilder)
    # oder dieses Skript geändert haben
    PALETTE.update(read_palette())
    h = hashlib.sha256(Path(__file__).read_bytes())
    h.update(json.dumps(PALETTE, sort_keys=True).encode())
    for src in sources:
        h.update(src.name.encode())
        h.update(src.read_bytes())
    stamp = theme / ".source-hash"
    if not (theme / "recolor.css").exists() or not stamp.exists() or stamp.read_text() != h.hexdigest():
        out = [f"/* Erzeugt von steam-theme.py aus Steams CSS – hier nichts ändern. */\n"]
        texts = [(src.name, strip_comments(src.read_text(errors="replace"))) for src in sources]
        for name, css in texts:
            out.append(f"/* {name} */\n{convert(css)}\n")
        # danach, damit sie gewinnen
        for name, css in texts:
            out.append(f"/* {name}: flach */\n{flatten(css)}\n")
        out.append(f"/* Bibliothek */\n{library_list()}")
        tmp = theme / "recolor.css.tmp"
        tmp.write_text("".join(out))
        tmp.replace(theme / "recolor.css")
        stamp.write_text(h.hexdigest())

    # Beim ersten Mal in Millennium aktivieren (später gilt die eigene Wahl)
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "millennium/config.json"
    if first_time and config.exists():
        try:
            data = json.loads(config.read_text())
            data.setdefault("themes", {})["activeTheme"] = "matugen"
            config.write_text(json.dumps(data, indent=4))
        except (OSError, ValueError) as e:
            print(f"steam-theme: Millennium-Config nicht geändert: {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
