import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Emoji-Auswahl wie Win+. unter Windows 11: kleine Glasfläche direkt unter
// dem Mauszeiger (dort, wo man gerade schreibt – die Textmarke selbst
// verrät Wayland anderen Programmen nicht), Suchfeld oben, zuletzt benutzte zuerst, darunter
// alle Emojis nach Gruppen. Tippen sucht (englische Namen und Stichwörter,
// z. B. "laugh", "exhausted"), Pfeile wählen, Enter/Klick tippt das Emoji
// ins Fenster, das vorher den Fokus hatte (wtype), Esc schließt.
//
// Geteilt von taskbar (Glas) und minibar (flach, flat: true) – beide
// verlinken diese Datei. Hyprland ruft es über den Global Shortcut
// quickshell:emoji auf (Super+., hypr/hyprland.lua).
// Daten: emoji.tsv hier im Ordner (emojibase, erzeugt einmalig).
Scope {
    id: root

    // flach und eckig (minimaler Stil) statt Glas
    property bool flat: false
    property bool shown: false
    property string query: ""
    property var all: []
    property var recent: []
    readonly property int columns: 8
    readonly property int cell: 36
    readonly property int rows: 5
    // wo die Fläche erscheint: Monitor und Zeiger (Hyprland), beim Öffnen gelesen
    property string screenName: ""
    property real px: 0
    property real py: 0
    readonly property int maxRecent: 18
    readonly property string shared: Quickshell.shellDir + "/../shared/"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/g5"

    // Gruppen von emojibase (2 = Hautfarben-Bausteine, nicht enthalten)
    readonly property var groups: [
        { id: 0, icon: "😀", name: "Smileys" },
        { id: 1, icon: "👋", name: "People" },
        { id: 3, icon: "🐶", name: "Animals & nature" },
        { id: 4, icon: "🍔", name: "Food & drink" },
        { id: 5, icon: "✈️", name: "Travel & places" },
        { id: 6, icon: "⚽", name: "Activities" },
        { id: 7, icon: "💡", name: "Objects" },
        { id: 8, icon: "❤️", name: "Symbols" },
        { id: 9, icon: "🏳️", name: "Flags" }
    ]
    property int group: -1 // -1 = zuletzt benutzt + alles

    // Treffer: Name beginnt mit Suche > Wort im Namen > Stichwort
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (!q) {
            if (group >= 0)
                return all.filter(e => e.g === group);
            const seen = new Set(recent);
            return recent.map(u => all.find(e => e.u === u) || { u: u, n: "", k: "", g: -1 }).concat(all.filter(e => !seen.has(e.u)));
        }
        const words = q.split(/\s+/);
        const scored = [];
        for (const e of all) {
            let s = 0;
            for (const w of words) {
                let ws = 0;
                if (e.n.startsWith(w))
                    ws = 4;
                else if ((" " + e.n).includes(" " + w))
                    ws = 3;
                else if ((" " + e.k).includes(" " + w))
                    ws = 2;
                else if (e.n.includes(w) || e.k.includes(w))
                    ws = 1;
                if (!ws) {
                    s = 0;
                    break;
                }
                s += ws;
            }
            if (s)
                scored.push({ e: e, s: s + (recent.includes(e.u) ? 2 : 0) });
        }
        return scored.sort((a, b) => b.s - a.s || a.e.o - b.e.o).map(x => x.e);
    }

    function toggle() {
        shown ? close() : open();
    }

    function open() {
        query = "";
        group = -1;
        where.running = true;
    }

    // Monitor unter dem Zeiger und Position darauf: "DP-2 1052 755"
    Process {
        id: where
        command: ["sh", "-c", "c=$(hyprctl cursorpos -j) && hyprctl monitors -j | jq -r --argjson c \"$c\" 'first(.[] | select($c.x >= .x and $c.x < .x + .width / .scale and $c.y >= .y and $c.y < .y + .height / .scale)) | \"\\(.name) \\($c.x - .x) \\($c.y - .y)\"'"]
        stdout: StdioCollector {
            id: whereOut
            onStreamFinished: {
                const f = whereOut.text.trim().split(" ");
                root.screenName = f.length === 3 ? f[0] : (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
                root.px = Number(f[1]) || 0;
                root.py = Number(f[2]) || 0;
                root.shown = true;
            }
        }
    }

    function close() {
        shown = false;
    }

    // Erst schließen, dann tippen: der Fokus muss zurück beim Fenster sein
    function pick(u) {
        if (!u)
            return;
        recent = [u].concat(recent.filter(x => x !== u)).slice(0, maxRecent);
        recentFile.setText(recent.join("\n") + "\n");
        close();
        Quickshell.execDetached(["sh", "-c", "sleep 0.12; exec wtype -- \"$1\"", "emoji", u]);
    }

    function parse(text) {
        const out = [];
        let o = 0;
        for (const line of text.split("\n")) {
            if (!line || line.startsWith("#"))
                continue;
            const f = line.split("\t");
            out.push({ u: f[0], n: f[1] || "", k: f[2] || "", g: Number(f[3]), o: o++ });
        }
        all = out;
    }

    FileView {
        path: root.shared + "emoji.tsv"
        onLoaded: root.parse(text())
    }

    FileView {
        id: recentFile
        path: root.stateDir + "/emoji-recent"
        printErrors: false
        onLoaded: root.recent = text().split("\n").filter(l => l !== "")
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.stateDir])

    GlobalShortcut {
        name: "emoji"
        description: "Emoji-Auswahl (Win+.)"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void {
            root.toggle();
        }
    }

    // ── Farben: wie die Taskleiste (matugen) ─────────────────────────
    property var c: ({})
    function col(name, fallback) {
        return c[name] !== undefined ? c[name] : fallback;
    }
    function readColors() {
        const out = {};
        for (const text of [colorsCss.text(), glassCss.text()]) {
            const re = /@define-color\s+(\w+)\s+([^;]+);/g;
            let m;
            while ((m = re.exec(text)) !== null) {
                const v = m[2].trim();
                const rgba = v.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+))?\s*\)/);
                out[m[1]] = rgba ? Qt.rgba(rgba[1] / 255, rgba[2] / 255, rgba[3] / 255, rgba[4] === undefined ? 1 : Number(rgba[4])) : v;
            }
        }
        c = out;
    }
    FileView {
        id: colorsCss
        path: Quickshell.shellDir + "/../taskbar/colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.readColors()
    }
    FileView {
        id: glassCss
        path: Quickshell.shellDir + "/../taskbar/glass.css"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readColors()
    }
    readonly property color bg: flat ? col("surface", "#151311") : col("glass", "#8c121218")
    readonly property color rim: flat ? col("outline", "#95908c") : col("glass_rim", "#24ffffff")
    readonly property color shine: col("glass_shine", "#38ffffff")
    readonly property color pill: flat ? Qt.alpha(col("on_surface", "#e5e2e3"), 0.06) : col("glass_pill", "#12ffffff")
    readonly property color hover: flat ? Qt.alpha(col("on_surface", "#e5e2e3"), 0.10) : col("glass_hover_strong", "#21ffffff")
    readonly property color fg: col("on_surface", "#e5e2e3")
    readonly property color dim: col("on_surface_variant", "#c8c6c7")
    readonly property color accent: col("primary", "#c3c6d6")
    readonly property string font: flat ? "JetBrains Mono" : "Inter"
    readonly property int r: flat ? 0 : 18

    PanelWindow {
        id: panel

        readonly property int sw: screen ? screen.width : 1920
        readonly property int sh: screen ? screen.height : 1080

        screen: Quickshell.screens.find(s => s.name === root.screenName) || null
        visible: root.shown
        color: "transparent"
        implicitWidth: 2 * 10 + root.columns * root.cell
        implicitHeight: body.implicitHeight + 2 * 10
        exclusionMode: ExclusionMode.Ignore
        // unter dem Zeiger, ist dort kein Platz: darüber; nie über den Rand
        anchors {
            top: true
            left: true
        }
        margins.left: Math.round(Math.max(8, Math.min(root.px - 24, sw - implicitWidth - 8)))
        margins.top: Math.round(root.py + 20 + implicitHeight <= sh - 8 ? root.py + 20 : Math.max(8, root.py - implicitHeight - 12))
        WlrLayershell.namespace: "emoji"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: if (visible) {
            search.text = "";
            grid.currentIndex = 0;
            grid.positionViewAtBeginning();
            search.forceActiveFocus();
        }

        Rectangle {
            anchors.fill: parent
            radius: root.r
            color: root.bg
            border.width: 1
            border.color: root.rim

            // Lichtkante oben (nur Glas)
            Rectangle {
                visible: !root.flat
                x: 24
                y: 1
                width: parent.width - 48
                height: 1
                color: root.shine
                opacity: 0.6
            }
        }

        Column {
            id: body
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 6

            // ── Suchfeld ─────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 32
                radius: root.flat ? 0 : 16
                color: root.pill
                border.width: 1
                border.color: Qt.alpha(root.accent, search.activeFocus ? 0.5 : 0)

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.font
                    font.pixelSize: 13
                    color: root.fg
                    selectionColor: Qt.alpha(root.accent, 0.4)
                    clip: true
                    onTextChanged: {
                        root.query = text;
                        grid.currentIndex = 0;
                        grid.positionViewAtBeginning();
                    }

                    Keys.onPressed: e => {
                        const n = grid.count;
                        const step = {
                            [Qt.Key_Right]: 1,
                            [Qt.Key_Left]: -1,
                            [Qt.Key_Down]: root.columns,
                            [Qt.Key_Up]: -root.columns
                        }[e.key];
                        if (e.key === Qt.Key_Escape) {
                            root.close();
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (n > 0)
                                root.pick(root.results[grid.currentIndex].u);
                        } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
                            // Gruppen durchschalten (nur ohne Suche)
                            const ids = [-1].concat(root.groups.map(g => g.id));
                            const i = ids.indexOf(root.group) + (e.key === Qt.Key_Tab ? 1 : -1);
                            root.group = ids[(i + ids.length) % ids.length];
                            grid.currentIndex = 0;
                            grid.positionViewAtBeginning();
                        } else if (step !== undefined && (step % root.columns !== 0 ? !search.text || search.cursorPosition === search.text.length : true)) {
                            grid.currentIndex = Math.max(0, Math.min(n - 1, grid.currentIndex + step));
                            grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
                        } else {
                            return;
                        }
                        e.accepted = true;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search emoji…"
                        font.family: root.font
                        font.pixelSize: 13
                        color: root.dim
                        opacity: 0.7
                    }
                }
            }

            // ── Überschrift ──────────────────────────────────────────
            Text {
                text: root.query ? (grid.count ? "Results" : "No emoji found") : root.group >= 0 ? root.groups.find(g => g.id === root.group).name : root.recent.length ? "Recently used" : "All emoji"
                font.family: root.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.dim
            }

            // ── Raster ───────────────────────────────────────────────
            GridView {
                id: grid
                width: parent.width
                height: root.rows * cellHeight
                cellWidth: width / root.columns
                cellHeight: root.cell
                clip: true
                model: root.results
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                cacheBuffer: 360

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: root.flat ? 0 : 8
                        color: cell.index === grid.currentIndex ? Qt.alpha(root.accent, 0.22) : mouse.containsMouse ? root.hover : "transparent"
                        border.width: cell.index === grid.currentIndex ? 1 : 0
                        border.color: Qt.alpha(root.accent, 0.7)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.u
                        font.family: "Apple Color Emoji"
                        font.pixelSize: 23
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: grid.currentIndex = cell.index
                        onClicked: root.pick(cell.modelData.u)
                    }
                }
            }

            // Name des gewählten Emojis
            Text {
                width: parent.width
                height: 14
                elide: Text.ElideRight
                text: grid.count && root.results[grid.currentIndex] ? root.results[grid.currentIndex].n : ""
                font.family: root.font
                font.pixelSize: 11
                color: root.dim
            }

            // ── Gruppen (Tab schaltet weiter) ────────────────────────
            Row {
                visible: !root.query
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                Repeater {
                    model: [{ id: -1, icon: "🕘" }].concat(root.groups)

                    delegate: Rectangle {
                        required property var modelData
                        width: Math.floor(body.width / 10)
                        height: 26
                        radius: root.flat ? 0 : 8
                        color: root.group === modelData.id ? Qt.alpha(root.accent, 0.22) : tab.containsMouse ? root.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.icon
                            font.family: "Apple Color Emoji"
                            font.pixelSize: 15
                        }

                        MouseArea {
                            id: tab
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.group = parent.modelData.id;
                                grid.currentIndex = 0;
                                grid.positionViewAtBeginning();
                                search.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }
}
