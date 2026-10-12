//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
// Schmale Textleiste oben im minimalen Stil (Void Linux, MangoWC) – wie die
// Leiste von dwm: Tags, Layout, Fenstertitel; rechts Tray, Tastatur, VPN,
// Lautstärke, Akku, Uhr. Keine Symbole, keine Effekte. Farben aus dem
// Wallpaper (../taskbar/colors.css von matugen).
// Unter Niri/Hyprland bleibt die Taskleiste (../taskbar).
//
// Start: quickshell -p ~/.config/quickshell/minibar (`wm autostart`).
// Quickshell lädt Änderungen an den .qml-Dateien sofort neu.

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }
}
