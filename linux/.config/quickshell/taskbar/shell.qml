//@ pragma UseQApplication
// Qt nimmt sonst die "basic"-Renderschleife: alle Fenster (Leiste je Monitor
// + Popup) nacheinander im Hauptthread, jedes wartet auf VSync – Animationen
// laufen dann mit einem Bruchteil der 180 Hz. "threaded": eigener Thread je
// Fenster, Animationen im Takt des Monitors.
//@ pragma Env QSG_RENDER_LOOP=threaded
// Taskleiste im Stil von Windows 11 (Höhe wie Windows 10) für Niri und
// Hyprland: Arbeitsflächen, Startmenü, App-Symbole mit Fenster-Vorschau,
// Tray, Lautstärke-Regler, Status und Ausschalt-Menü; unter Hyprland auch
// Alt+Tab.
//
// Start: quickshell -p ~/.config/quickshell/taskbar (`wm autostart`).
// Quickshell lädt Änderungen an den .qml-Dateien sofort neu.

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // Ausschalt-Menü (Power.qml)
    PowerMenu {}

    // Emoji-Auswahl (Super+., ../shared/EmojiPicker.qml)
    EmojiPicker {}

    // Alt+Tab, nur Hyprland (Niri hat es eingebaut)
    LazyLoader {
        active: Compositor.hyprland

        AltTab {}
    }
}
