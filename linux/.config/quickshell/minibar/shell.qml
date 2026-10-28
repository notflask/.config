//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
// Schmale Textleiste oben im minimalen Stil (Hyprland) – wie die
// Leiste von dwm: Tags, Layout, Fenstertitel; rechts Tray, Tastatur, VPN,
// Lautstärke, Akku, Uhr. Keine Symbole, keine Effekte. Farben aus dem
// Wallpaper (../taskbar/colors.css von matugen).
// Im Glas-Stil gilt die Taskleiste (../taskbar).
//
// Start: quickshell -p ~/.config/quickshell/minibar (`wm autostart`).
// Quickshell lädt Änderungen an den .qml-Dateien sofort neu.

import QtQuick
import Quickshell

ShellRoot {
    Osd {
        background: Theme.bg
        foreground: Theme.fg
        accent: Theme.accent
        rim: Qt.alpha(Theme.fg, 0.25)
        fontFamily: Theme.font
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    AltTab {}

    // Emoji-Auswahl (Super+., ../shared/EmojiPicker.qml), flach wie die Leiste
    EmojiPicker {
        flat: true
    }
}
