//@ pragma UseQApplication
//@ pragma Env QSG_RENDER_LOOP=threaded
// Leiste im Stil mono (Hyprland, `style mono`): fast schwarz, grau, ein
// rosa Akzent – feste Farben, unabhängig vom Wallpaper. Links Arbeitsflächen
// in chinesischen Ziffern, rechts Tray (eingeklappt), Lautstärke, Netz,
// Uhr und Datum.
// Alt+Tab und Tray-Menü wie im minimalen Stil (../minibar).
//
// Start: quickshell -p ~/.config/quickshell/mono (`wm autostart`).

import QtQuick
import Quickshell

ShellRoot {
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
