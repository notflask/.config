pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Zustand von Hyprland (Quickshell.Hyprland); Arbeitsflächen 1–9 sind die Tags.
// Pro Monitor: name, active (fokussiert), tags [{ index, is_active,
// client_count, is_urgent }], layout_symbol, active_client { title },
// keyboardlayout.
Singleton {
    id: root

    property string hyprLayout: ""

    readonly property var monitors: hyprMonitors()
    readonly property string layout: hyprLayout

    function monitor(name) {
        return monitors.find(m => m.name === name) || null;
    }

    // Tag/Arbeitsfläche auf diesem Monitor ansehen
    function view(tag, output) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "${tag}" })`);
    }

    // Mausrad: zum nächsten belegten Tag links (-1) oder rechts (+1)
    function scroll(step, output) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "m${step > 0 ? "+" : "-"}1" })`);
    }

    function hyprMonitors() {
        const active = Hyprland.activeToplevel;
        return Hyprland.monitors.values.map(m => {
            const current = m.activeWorkspace;
            const tags = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === m).sort((a, b) => a.id - b.id).map(w => ({
                        index: w.id,
                        is_active: w.active,
                        client_count: w.toplevels.values.length,
                        is_urgent: w.urgent
                    }));
            // Titel: das fokussierte Fenster, auf dem anderen Monitor das
            // erste der sichtbaren Arbeitsfläche
            let client = null;
            if (active && current && active.workspace === current)
                client = active;
            else if (current && current.toplevels.values.length)
                client = current.toplevels.values[0];
            const tiled = current && current.lastIpcObject ? current.lastIpcObject.tiledLayout || "" : "";
            return {
                name: m.name,
                active: m.focused,
                tags: tags,
                layout_symbol: tiled ? tiled[0].toUpperCase() : "",
                active_client: client ? {
                    title: client.title
                } : null,
                keyboardlayout: root.hyprLayout
            };
        });
    }

    // Tastaturlayout: Startwert aus `hyprctl devices`, dann Ereignisse
    // (activelayout>>Tastatur,Layoutname). Layout der Arbeitsfläche steht
    // nur in lastIpcObject, das nach Änderungen neu geholt wird.
    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards.find(k => k.main);
                    if (kb)
                        root.hyprLayout = kb.active_keymap;
                } catch (err) {}
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const comma = event.data.indexOf(",");
                root.hyprLayout = event.data.slice(comma + 1);
            } else if (["workspace", "workspacev2", "createworkspace", "focusedmon", "openwindow", "closewindow", "movewindow"].includes(event.name)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            }
        }
    }
}
