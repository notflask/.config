pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland oder Niri. Niri hat kein Quickshell-Modul: Arbeitsflächen und
// Tastaturlayout kommen aus `niri msg -j event-stream` (schickt zuerst den
// ganzen Stand, dann Änderungen).
Singleton {
    id: root

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property bool niri: !hyprland && !!Quickshell.env("NIRI_SOCKET")

    // Niri: [{ id, idx, name, output, is_active, is_focused }]
    property var niriWorkspaces: []
    property var niriLayouts: []
    property int niriLayout: 0

    function niriEvent(e) {
        if (e.WorkspacesChanged) {
            niriWorkspaces = e.WorkspacesChanged.workspaces;
        } else if (e.WorkspaceActivated) {
            const id = e.WorkspaceActivated.id;
            const focused = e.WorkspaceActivated.focused;
            const target = niriWorkspaces.find(w => w.id === id);
            if (!target)
                return;
            niriWorkspaces = niriWorkspaces.map(w => {
                const copy = Object.assign({}, w);
                if (w.output === target.output)
                    copy.is_active = w.id === id;
                if (focused)
                    copy.is_focused = w.id === id;
                return copy;
            });
        } else if (e.KeyboardLayoutsChanged) {
            niriLayouts = e.KeyboardLayoutsChanged.keyboard_layouts.names;
            niriLayout = e.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (e.KeyboardLayoutSwitched) {
            niriLayout = e.KeyboardLayoutSwitched.idx;
        }
    }

    Process {
        running: root.niri
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.niriEvent(JSON.parse(line));
                } catch (err) {}
            }
        }
    }
}
