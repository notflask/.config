# App-Symbol aus den eingebetteten Avalonia-Ressourcen holen
# (/Assets/Icons/PlatformX.ico in OFT.Platform.Avalonia.dll) und die
# PNG-Bilder daraus als hicolor-Icons ablegen.
#
# Aufbau der Ressource „!AvaloniaResources“:
#   int32 Indexlänge, int32 Version, int32 Anzahl,
#   je Eintrag: Pfad (.NET-String), int32 Offset, int32 Größe; danach Daten
import os
import struct
import sys

dll, outdir = sys.argv[1], sys.argv[2]
data = open(dll, "rb").read()
wanted = b"/Assets/Icons/PlatformX.ico"


def read_index(pos):
    index_len, _version, count = struct.unpack_from("<iii", data, pos)
    if not (0 < count < 100000 and 0 < index_len < len(data)):
        return None
    base = pos + 4 + index_len
    p, entries = pos + 12, {}
    for _ in range(count):
        n = data[p]
        if n >= 0x80 or data[p + 1] != ord("/"):
            return None
        name = data[p + 1 : p + 1 + n]
        off, size = struct.unpack_from("<ii", data, p + 1 + n)
        entries[name] = (base + off, size)
        p += 1 + n + 8
    return entries if p == base else None


ico = None
for i in range(len(data) - 16):
    if data[i + 13] == ord("/") and data[i + 12] < 0x80:
        entries = read_index(i)
        if entries and wanted in entries:
            off, size = entries[wanted]
            ico = data[off : off + size]
            break
if ico is None or ico[:4] != b"\0\0\1\0":
    sys.exit("PlatformX.ico nicht gefunden")

(count,) = struct.unpack_from("<H", ico, 4)
for k in range(count):
    w, h, *_rest, size, off = struct.unpack_from("<BBBBHHII", ico, 6 + 16 * k)
    w = w or 256
    png = ico[off : off + size]
    if w not in (16, 24, 32, 48, 64, 128) or w != (h or 256) or png[:4] != b"\x89PNG":
        continue
    d = os.path.join(outdir, f"{w}x{w}", "apps")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "atas-x.png"), "wb").write(png)
