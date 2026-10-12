pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Farben aus ../taskbar/colors.css (matugen, hell oder dunkel). Ändert
// theme.sh sie, färbt sich die Leiste sofort neu.
Singleton {
    id: root

    property var c: ({})

    readonly property string font: "JetBrains Mono"
    readonly property int size: 12
    readonly property int height: 24

    readonly property color bg: get("surface", "#151311")
    readonly property color fg: get("on_surface", "#e5e2e3")
    readonly property color dim: get("on_surface_variant", "#c8c6c7")
    readonly property color faint: get("outline", "#95908c")
    readonly property color accent: get("primary", "#c3c6d6")
    readonly property color onAccent: get("on_primary", "#2c2f3a")
    readonly property color error: get("error", "#ffb4ab")
    readonly property color ok: "#8fd19e"
    readonly property color warn: "#f0c674"

    function get(name, fallback) {
        return c[name] !== undefined ? c[name] : fallback;
    }

    FileView {
        id: colors
        path: Quickshell.shellDir + "/../taskbar/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const out = {};
            const re = /@define-color\s+(\w+)\s+([^;]+);/g;
            let m;
            while ((m = re.exec(colors.text())) !== null)
                out[m[1]] = m[2].trim();
            root.c = out;
        }
    }
}
