pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Farben aus ../taskbar/colors.css (matugen, hell oder dunkel), Stil aus
// ~/.config/g5/style (islands oder frame). Ändert theme.sh die Farben,
// färbt sich alles sofort neu.
Singleton {
    id: root

    property var c: ({})
    property string style: "islands"
    readonly property bool frame: style === "frame"

    readonly property string font: "Inter"
    readonly property string icons: "Symbols Nerd Font"
    readonly property int size: 13
    readonly property int iconSize: 16
    // Zeilenhöhe in Alt+Tab
    readonly property int height: 30
    // Popups und Alt+Tab
    readonly property int radius: 18

    // islands: Inselhöhe, Abstand zum Rand (= gaps_out in hypr/soft.lua)
    readonly property int pill: 38
    readonly property int top: 10
    readonly property int side: 14
    // frame: Breite der Leiste links, Rahmen an den anderen Seiten, Radius
    // der Öffnung (Fenster: 14 + 6 Abstand, konzentrisch)
    readonly property int frameBar: 46
    readonly property int frameEdge: 8
    readonly property int frameRadius: 20

    readonly property bool dark: Qt.color(get("surface", "#151311")).hslLightness < 0.5
    readonly property color bg: get("surface_container", "#211f1d")
    readonly property color island: bg
    readonly property color island2: get("surface_container_highest", "#373432")
    readonly property color frameColor: get("surface_container", "#211f1d")
    readonly property color rim: get("outline_variant", "#4a4544")
    readonly property color fg: get("on_surface", "#e5e2e3")
    readonly property color dim: get("on_surface_variant", "#c8c6c7")
    readonly property color faint: get("outline", "#95908c")
    readonly property color accent: get("primary", "#c3c6d6")
    readonly property color selection: get("secondary_container", "#4a4458")
    readonly property color selectionFg: get("on_secondary_container", "#e8def8")
    readonly property color hover: Qt.alpha(fg, 0.08)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.45 : 0.16)
    readonly property color error: get("error", "#ffb4ab")
    readonly property color ok: dark ? "#8fd19e" : "#2e8b4a"
    readonly property color warn: dark ? "#f0c674" : "#b7791f"
    readonly property color orange: dark ? "#f5a35c" : "#c8641c"

    // VPN-Zustand (vpn.sh) → Farbe: grün verbunden, orange verbindet, rot sonst
    function vpnColor(state) {
        return state === "on" ? ok : state === "pending" ? orange : error;
    }

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

    FileView {
        id: styleFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/g5/style"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.style = styleFile.text().trim() || "islands"
    }
}
