pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Zustand von MangoWC aus `mmsg watch all-monitors`: schickt zuerst den
// ganzen Stand, dann bei jeder Änderung eine JSON-Zeile. Pro Monitor:
// name, active (fokussiert), tags [{ index, is_active, client_count,
// is_urgent }], layout_symbol, active_client { title, appid }, keyboardlayout
Singleton {
    id: root

    property var monitors: []
    readonly property string layout: monitors.length ? monitors[0].keyboardlayout || "" : ""

    function monitor(name) {
        return monitors.find(m => m.name === name) || null;
    }

    function view(tag, output) {
        Quickshell.execDetached(["mmsg", "dispatch", `viewcrossmon,${tag},${output}`]);
    }

    Process {
        id: watcher
        running: true
        command: ["mmsg", "watch", "all-monitors"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.monitors = JSON.parse(line).monitors || [];
                } catch (err) {}
            }
        }
        // Startet MangoWC neu (oder ist noch nicht bereit): nach 2 s nochmal
        onRunningChanged: if (!running)
            retry.start()
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: watcher.running = true
    }
}
