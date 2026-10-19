#!/usr/bin/env python3
# ============================================================
#  theme-sun.py – hell ab Sonnenaufgang, dunkel ab Sonnenuntergang
#
#  Kein Dienst im Hintergrund: das Skript rechnet Auf- und Untergang für
#  heute aus, schaltet (theme.sh -m light|dark), falls nötig, und legt
#  einen einmaligen systemd-Timer auf den nächsten Wechsel, der es dann
#  wieder startet. Dazwischen läuft nichts. Wer per Hand umschaltet
#  (theme.sh -T), behält das bis zum nächsten Auf- oder Untergang.
#
#    theme-sun.py            schalten, falls nötig, und Timer stellen
#    theme-sun.py --no-apply nur den Modus merken und Timer stellen
#                            (beim Login: waypaper --restore färbt danach
#                            ohnehin ein und liest den Modus)
#
#  Wird nach dem Ruhezustand ein verpasster Wechsel fällig, startet
#  systemd den Timer beim Aufwachen.
# ============================================================

import math
import os
import subprocess
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path

# Ort für Auf- und Untergang (Grad Nord, Grad Ost): Berlin
LAT, LON = 52.52, 13.405

home = Path.home()
theme_sh = home / ".config/matugen/theme.sh"
mode_file = Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "theme-mode"


def sun(day):
    """Sonnenaufgang und -untergang an diesem Tag als Unix-Zeit
    (Sonnenaufgangsgleichung, auf etwa 1 min genau)."""
    noon = datetime(day.year, day.month, day.day, 12).timestamp()
    n = math.ceil(noon / 86400 + 2440587.5 - 2451545.0 + 0.0008)
    j = n - LON / 360
    m = (357.5291 + 0.98560028 * j) % 360
    mr = math.radians(m)
    c = 1.9148 * math.sin(mr) + 0.02 * math.sin(2 * mr) + 0.0003 * math.sin(3 * mr)
    lam = math.radians((m + c + 180 + 102.9372) % 360)
    transit = 2451545.0 + j + 0.0053 * math.sin(mr) - 0.0069 * math.sin(2 * lam)
    decl = math.asin(math.sin(lam) * math.sin(math.radians(23.4397)))
    lat = math.radians(LAT)
    cos_w = (math.sin(math.radians(-0.833)) - math.sin(lat) * math.sin(decl)) / (
        math.cos(lat) * math.cos(decl))
    w = math.degrees(math.acos(max(-1.0, min(1.0, cos_w))))
    unix = lambda jd: (jd - 2440587.5) * 86400
    return unix(transit - w / 360), unix(transit + w / 360)


def main():
    now = time.time()
    today = date.today()
    rise, set_ = sun(today)
    mode = "light" if rise <= now < set_ else "dark"

    current = mode_file.read_text().strip() if mode_file.exists() else ""
    if current != mode:
        if "--no-apply" in sys.argv:
            mode_file.parent.mkdir(parents=True, exist_ok=True)
            mode_file.write_text(mode + "\n")
        else:
            subprocess.run([str(theme_sh), "-m", mode], check=False)

    # Nächster Wechsel: noch heute oder morgen früh
    events = [t for t in (rise, set_, sun(today + timedelta(days=1))[0]) if t > now + 30]
    at = datetime.fromtimestamp(events[0]).strftime("%Y-%m-%d %H:%M:%S")

    # Alten Timer weg (der laufende Dienst bleibt), neuen mit eigenem Namen
    old = subprocess.run(
        ["systemctl", "--user", "list-units", "--plain", "--no-legend", "--all",
         "theme-sun-*.timer"], capture_output=True, text=True).stdout.split()
    timers = [u for u in old if u.startswith("theme-sun-") and u.endswith(".timer")]
    if timers:
        subprocess.run(["systemctl", "--user", "stop", *timers], check=False)
    subprocess.run(
        ["systemd-run", "--user", "--quiet", f"--unit=theme-sun-{int(events[0])}",
         f"--on-calendar={at}", "--timer-property=AccuracySec=1min",
         # theme.sh schickt Pywalfox im Hintergrund los; ohne das beendet
         # systemd es mit dem Dienst, und Firefox bleibt im alten Modus
         "--property=KillMode=process",
         "--description=Theme: Hell/Dunkel nach der Sonne", str(Path(__file__).resolve())],
        check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
