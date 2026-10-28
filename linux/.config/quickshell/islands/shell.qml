//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
// Leiste der Stile islands und frame (Hyprland, `style islands|frame`):
//   islands  drei deckende Inseln oben (Bar.qml)
//   frame    Rahmen um den Bildschirm, Leiste links (Frame.qml)
// Logik (Arbeitsflächen, Tray, VPN, Alt+Tab) wie ../minibar, Farben aus
// ../taskbar/colors.css (matugen).
//
// Start: quickshell -p ~/.config/quickshell/islands (`wm autostart`).

import QtQuick
import Quickshell

ShellRoot {
    Osd {
        background: Theme.bg
        foreground: Theme.fg
        accent: Theme.accent
        rim: Qt.alpha(Theme.fg, 0.25)
        fontFamily: Theme.font
        cornerRadius: Theme.radius
    }

    Variants {
        model: Theme.frame ? [] : Quickshell.screens

        Bar {}
    }

    Variants {
        model: Theme.frame ? Quickshell.screens : []

        Frame {}
    }

    AltTab {}

    // Emoji-Auswahl (Super+., ../shared/EmojiPicker.qml), deckend
    EmojiPicker {
        flat: true
    }
}
