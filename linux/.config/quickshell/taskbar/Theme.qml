pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Farben aus colors.css und glass.css hier im Ordner (matugen, hell oder
// dunkel; dieselben Dateien binden hyprshell und wlogout ein). Ändert
// theme.sh sie, färbt sich alles sofort neu.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/"
    property var c: ({})

    readonly property string font: "Inter"
    readonly property string icons: "Symbols Nerd Font"
    readonly property int iconSize: 18
    readonly property int textSize: 14

    readonly property color glass: get("glass", "#8c121218")
    readonly property color rim: get("glass_rim", "#24ffffff")
    readonly property color shine: get("glass_shine", "#38ffffff")
    readonly property color shineLow: get("glass_shine_low", "#0affffff")
    readonly property color hover: get("glass_hover", "#14ffffff")
    readonly property color hoverStrong: get("glass_hover_strong", "#21ffffff")
    readonly property color pill: get("glass_pill", "#12ffffff")
    readonly property color pillShine: get("glass_pill_shine", "#24ffffff")
    readonly property color shadow: get("glass_shadow", "#59000000")
    readonly property color text: get("on_surface", "#e5e2e3")
    readonly property color textDim: get("on_surface_variant", "#c8c6c7")
    readonly property color primary: get("primary", "#c3c6d6")
    readonly property color error: get("error", "#ffb4ab")
    readonly property color onError: get("on_error", "#690005")
    readonly property color ok: get("ok", "#8fd19e")
    readonly property color warn: get("warn", "#f0c674")

    function get(name, fallback) {
        return c[name] !== undefined ? c[name] : fallback;
    }

    function toColor(v) {
        const m = v.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+))?\s*\)/);
        if (m)
            return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : Number(m[4]));
        return v;
    }

    function update() {
        const out = {};
        for (const text of [colors.text(), glass.text()]) {
            const re = /@define-color\s+(\w+)\s+([^;]+);/g;
            let m;
            while ((m = re.exec(text)) !== null)
                out[m[1]] = toColor(m[2].trim());
        }
        c = out;
    }

    FileView {
        id: colors
        path: root.dir + "colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.update()
    }

    FileView {
        id: glass
        path: root.dir + "glass.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.update()
    }
}
