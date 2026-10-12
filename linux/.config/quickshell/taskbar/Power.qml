pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ein/Aus: Befehle für das Ausschalt-Menü (PowerMenu.qml) und die
// Ein/Aus-Ansicht im Startmenü. loginctl statt systemctl: geht mit systemd
// (NixOS) und mit elogind (Void Linux). Öffnen per Knopf in der Leiste oder von
// außen (Super+Shift+E in niri/config.kdl, hypr/hyprland.lua bzw. mango/config.conf):
//   qs -c taskbar ipc call power toggle
Singleton {
    id: root

    property bool shown: false

    // key: Taste im Menü
    readonly property var actions: [
        {
            id: "lock",
            glyph: "\u{F033E}",
            label: "Sperren",
            key: Qt.Key_L,
            cmd: ["wm", "lock"]
        },
        {
            id: "logout",
            glyph: "\u{F0343}",
            label: "Abmelden",
            key: Qt.Key_E,
            cmd: ["session-logout"]
        },
        {
            id: "suspend",
            glyph: "\u{F0904}",
            label: "Standby",
            key: Qt.Key_S,
            cmd: ["loginctl", "suspend"]
        },
        {
            id: "reboot",
            glyph: "\u{F0709}",
            label: "Neu starten",
            key: Qt.Key_R,
            cmd: ["loginctl", "reboot"]
        },
        {
            id: "shutdown",
            glyph: "\u{F0425}",
            label: "Ausschalten",
            key: Qt.Key_P,
            cmd: ["loginctl", "poweroff"]
        }
    ]

    function run(action) {
        shown = false;
        Quickshell.execDetached(action.cmd);
    }

    function toggle() {
        shown = !shown;
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.shown = true;
        }
        function close(): void {
            root.shown = false;
        }
    }
}
