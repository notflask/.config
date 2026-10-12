pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Hyprland, Niri oder MangoWC. Niri und MangoWC haben kein Quickshell-Modul:
// Arbeitsflächen und Tastaturlayout kommen aus `niri msg -j event-stream`
// bzw. `mmsg watch all-monitors` (beide schicken zuerst den ganzen Stand,
// dann Änderungen, eine JSON-Zeile pro Ereignis).
Singleton {
    id: root

    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property bool niri: !hyprland && !!Quickshell.env("NIRI_SOCKET")
    readonly property bool mango: !hyprland && !niri && !!Quickshell.env("MANGO_INSTANCE_SIGNATURE")

    // Niri: [{ id, idx, name, output, is_active, is_focused }]
    property var niriWorkspaces: []
    property var niriLayouts: []
    property int niriLayout: 0

    // MangoWC: [{ name, active, tags: [{ index, is_active, client_count, is_urgent }],
    // keyboardlayout, … }] – active ist der fokussierte Monitor
    property var mangoMonitors: []
    readonly property string mangoLayout: mangoMonitors.length ? mangoMonitors[0].keyboardlayout || "" : ""

    // Name des fokussierten Monitors
    function focusedOutput() {
        if (hyprland)
            return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        if (mango) {
            const mon = mangoMonitors.find(m => m.active);
            return mon ? mon.name : "";
        }
        const ws = niriWorkspaces.find(w => w.is_focused);
        return ws ? ws.output : "";
    }

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

    Process {
        running: root.mango
        command: ["mmsg", "watch", "all-monitors"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.mangoMonitors = JSON.parse(line).monitors || [];
                } catch (err) {}
            }
        }
    }
}
