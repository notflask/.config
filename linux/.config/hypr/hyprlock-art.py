#!/usr/bin/env python3
# ============================================================
#  hyprlock-art.py – Bilder für den Sperrbildschirm (hyprlock.conf)
#
#    hyprlock-art.py prepare            Hintergrund mit Verlauf, Knöpfe,
#                                       leeres Bild – nach jedem Farbwechsel
#                                       (matugen/theme.sh)
#    hyprlock-art.py card OUT TITEL INTERPRET PLAYER ART-URL
#                                       Glaskarte für die laufende Musik
#                                       (hyprlock-status.sh media-card)
#
#  Alles landet in ~/.cache/hyprlock. Doppelte Auflösung, hyprlock rechnet
#  beim Anzeigen herunter (gestochen scharf auch auf dem 1440p-Monitor).
# ============================================================

import hashlib
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

home = Path.home()
config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
cache = Path(os.environ.get("XDG_CACHE_HOME", home / ".cache")) / "hyprlock"
colors_conf = config / "hypr/hyprlock-colors.conf"

S = 2  # Renderfaktor
CARD_W, CARD_H = 460, 112  # logische Größe, muss zu hyprlock.conf passen


def font(spec, size):
    """Schriftdatei über fontconfig finden (z. B. "Inter:style=SemiBold")."""
    out = subprocess.run(["fc-match", "-f", "%{file}|%{index}", spec],
                         capture_output=True, text=True).stdout
    path, _, index = out.partition("|")
    try:
        # Inter liegt als Sammlung (.ttc) vor: Schnitt über den Index
        return ImageFont.truetype(path, size, index=int(index or 0))
    except OSError:
        return ImageFont.load_default(size)


def color(name, fallback):
    """Farbe aus hyprlock-colors.conf (matugen), z. B. $lock_accent."""
    try:
        m = re.search(rf"^\${name} = rgba?\(([0-9a-fA-F]{{6}})", colors_conf.read_text(), re.M)
        if m:
            return tuple(int(m[1][i:i + 2], 16) for i in (0, 2, 4))
    except OSError:
        pass
    return fallback


def save(img, out):
    """Erst fertig schreiben, dann umbenennen (hyprlock liest nie halbe Dateien)."""
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    img.save(tmp, "PNG" if out.suffix == ".png" else "JPEG", quality=92)
    os.replace(tmp, out)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def rim(size, radius, top=150, bottom=30, width=S):
    """Lichtkante wie Liquid Glass: oben hell, nach unten fast weg."""
    w, h = size
    edge = Image.new("L", size, 0)
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, w - 1, h - 1), radius, outline=255, width=width)
    fade = Image.linear_gradient("L").resize(size)  # 0 oben … 255 unten
    fade = fade.point(lambda v: top + (bottom - top) * v // 255)
    alpha = Image.composite(fade, Image.new("L", size, 0), edge)
    layer = Image.new("RGBA", size, (255, 255, 255, 0))
    layer.putalpha(alpha)
    return layer


def fit(text, fnt, width):
    """Text auf Breite kürzen, mit „…“."""
    if fnt.getlength(text) <= width:
        return text
    while text and fnt.getlength(text + "…") > width:
        text = text[:-1]
    return text.rstrip() + "…"


# ── prepare ──────────────────────────────────────────────────

def background():
    """Verkleinertes Hintergrundbild (theme.sh) oben und unten sanft
    abdunkeln, damit Uhr, Karte und Passwortfeld auf jedem Bild lesbar
    sind. Die Mitte bleibt unberührt."""
    src = cache / "wallpaper.jpg"
    if not src.exists():
        return
    img = Image.open(src).convert("RGB")
    w, h = img.size
    # Deckkraft des Schwarz je Zeile: oben 50 %, Mitte 0, unten 58 %
    stops = [(0.0, 0.50), (0.30, 0.10), (0.45, 0.0), (0.62, 0.0), (0.80, 0.22), (1.0, 0.58)]
    col = Image.new("L", (1, 256))
    for y in range(256):
        t = y / 255
        for (t0, a0), (t1, a1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                f = (t - t0) / (t1 - t0)
                f = f * f * (3 - 2 * f)  # weich (smoothstep)
                col.putpixel((0, y), round(255 * (a0 + (a1 - a0) * f)))
                break
    shade = col.resize((w, h), Image.BILINEAR)
    img = Image.composite(Image.new("RGB", (w, h)), img, shade)
    save(img, cache / "lock.jpg")


def glyph(name, char, size, glyph_size, glass=False):
    """Knopf als Bild (hyprlock: image mit onclick): Nerd-Font-Symbol,
    bei glass=True auf einer runden Glasscheibe. Bilder statt Labels, weil
    ihre Größe genau feststeht – die Knöpfe sitzen pixelgenau."""
    px = size * S
    img = Image.new("RGBA", (px, px), (255, 255, 255, 0))
    if glass:
        disc = Image.new("RGBA", (px, px), (255, 255, 255, 34))
        disc.alpha_composite(rim((px, px), px // 2, top=140, bottom=25))
        disc.putalpha(Image.composite(disc.getchannel("A"), Image.new("L", (px, px), 0),
                                      rounded_mask((px, px), px // 2)))
        img.alpha_composite(disc)
    draw = ImageDraw.Draw(img)
    fnt = font("Symbols Nerd Font Mono", glyph_size * S)
    draw.text((px / 2, px / 2), char, font=fnt, anchor="mm", fill=(255, 255, 255, 240))
    save(img, cache / "buttons" / f"{name}.png")


def buttons():
    # Musik (in der Karte): nur das Symbol
    for name, char in (("prev", "󰒮"), ("next", "󰒭"), ("play", "󰐊"), ("pause", "󰏤")):
        glyph(name, char, 40, 22)
    # Ein/Aus unten rechts: Glasscheiben
    for name, char in (("suspend", "󰤄"), ("reboot", "󰜉"), ("poweroff", "󰐥")):
        glyph(name, char, 44, 20, glass=True)


def prepare():
    cache.mkdir(parents=True, exist_ok=True)
    save(Image.new("RGBA", (1, 1), (0, 0, 0, 0)), cache / "blank.png")
    buttons()
    background()


# ── card ─────────────────────────────────────────────────────

def cover(url):
    """Albumbild als PIL-Bild: file:// direkt, http(s) einmal laden und
    zwischenspeichern (Spotify, Browser)."""
    if not url:
        return None
    try:
        if url.startswith("file://"):
            return Image.open(urllib.request.url2pathname(url[7:])).convert("RGB")
        if url.startswith(("http://", "https://")):
            dst = cache / "art" / hashlib.md5(url.encode()).hexdigest()
            if not dst.exists():
                dst.parent.mkdir(parents=True, exist_ok=True)
                with urllib.request.urlopen(url, timeout=4) as r:
                    dst.write_bytes(r.read())
            return Image.open(dst).convert("RGB")
    except Exception:
        return None
    return None


def card(out, title, artist, player, art_url):
    """Musikkarte im Glas-Stil: das Albumbild stark verwischt als getönte
    Glasfläche, links das Bild klein, daneben Titel, Interpret und Player.
    Rechts bleibt Platz für die Knöpfe (Labels in hyprlock.conf)."""
    W, H = CARD_W * S, CARD_H * S
    radius = 28 * S
    art = cover(art_url)
    if art is None:
        accent = color("lock_accent", (120, 130, 160))
        art = Image.new("RGB", (64, 64), accent)

    glass = ImageOps.fit(art, (W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(36 * S))
    glass = ImageEnhance.Color(glass).enhance(1.5)
    glass = ImageEnhance.Brightness(glass).enhance(0.5)
    glass = glass.convert("RGBA")
    glass.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, 18)))
    glass.alpha_composite(rim((W, H), radius))
    glass.putalpha(rounded_mask((W, H), radius))

    pad = 16 * S
    thumb_size = H - 2 * pad
    thumb = ImageOps.fit(art, (thumb_size, thumb_size), Image.LANCZOS).convert("RGBA")
    thumb.putalpha(rounded_mask(thumb.size, 14 * S))
    thumb.alpha_composite(rim(thumb.size, 14 * S, top=90, bottom=40))
    glass.alpha_composite(thumb, (pad, pad))

    x = pad + thumb_size + 14 * S
    width = W - x - 150 * S  # rechts drei Knöpfe (hyprlock.conf)
    draw = ImageDraw.Draw(glass)
    f_title = font("Inter:style=SemiBold", 17 * S)
    f_artist = font("Inter:style=Medium", 14 * S)
    f_player = font("Inter:style=Medium", 11 * S)
    lines = [(fit(title, f_title, width), f_title, 245)]
    if artist:
        lines.append((fit(artist, f_artist, width), f_artist, 185))
    if player:
        lines.append((fit(player.split(".")[0].capitalize(), f_player, width), f_player, 120))
    heights = [f.getbbox("Hg")[3] for _, f, _ in lines]
    gap = 5 * S
    y = (H - sum(heights) - gap * (len(lines) - 1)) / 2
    for (text, fnt, alpha), h in zip(lines, heights):
        draw.text((x, y), text, font=fnt, fill=(255, 255, 255, alpha))
        y += h + gap

    save(glass, out)
    # Alte Karten aufräumen (mehr als 30)
    cards = sorted(Path(out).parent.glob("*.png"), key=lambda p: p.stat().st_mtime)
    for old in cards[:-30]:
        old.unlink(missing_ok=True)


if __name__ == "__main__":
    match sys.argv[1:]:
        case ["prepare"]:
            prepare()
        case ["card", out, title, artist, player, art_url]:
            card(out, title, artist, player, art_url)
        case _:
            sys.exit(__doc__ or "hyprlock-art.py prepare | card OUT TITEL INTERPRET PLAYER ART-URL")
