# Avalonias Bildrate unter X11 anheben. Avalonia.X11 startet den Render-Takt
# fest mit 60 fps (AvaloniaX11Platform.Initialize), unabhängig vom Monitor:
#
#   IL_00df: ldc.i4.s 60   newobj SleepLoopRenderTimer::.ctor(int32)
#   ...    (13 Bytes weiter)
#   IL_00ec: ldc.i4.s 60   newobj UiThreadRenderTimer::.ctor(int32)
#
# Ersetzt wird nur genau dieses Paar (ldc.i4.s ist ein vorzeichenbehaftetes
# Byte → höchstens 127). Passt das Muster nicht genau einmal (andere
# Avalonia-Version), bleibt die Datei unverändert.
import re
import sys

dll, fps = sys.argv[1], int(sys.argv[2])
assert 1 <= fps <= 127

data = bytearray(open(dll, "rb").read())
timer = rb"\x1f\x3c\x73...\x0a"  # ldc.i4.s 60; newobj <MemberRef>
hits = [m.start() for m in re.finditer(timer + rb"(?=.{6}" + timer + rb")", data, re.S)]
if len(hits) != 1:
    print(f"raise-frame-rate: Muster {len(hits)}× gefunden, Bildrate bleibt 60 fps")
    sys.exit(0)

for pos in (hits[0], hits[0] + 13):
    data[pos + 1] = fps
open(dll, "wb").write(data)
print(f"raise-frame-rate: Avalonia rendert mit {fps} fps statt 60")
