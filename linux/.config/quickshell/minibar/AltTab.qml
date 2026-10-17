import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Alt+Tab im Stil der Leiste: Kacheln mit Vorschau, zuletzt benutzte Fenster
// zuerst, deckend, eckig, 1px Rahmen, mitten auf dem fokussierten Monitor. Gleiche
// Logik wie ../taskbar/AltTab.qml, gleiche Global Shortcuts (binds in
// hypr/hyprland.lua):
//   quickshell:alttab-next / -prev   öffnen bzw. weiter / zurück
//   quickshell:alttab-commit         Alt loslassen: zum gewählten Fenster
//   quickshell:alttab-cancel         Esc: zu, nichts wechseln
// Maus: Kachel anklicken wechselt, mittlere Taste schließt das Fenster.
Scope {
    id: root

    property bool shown: false
    property int index: 0
    // beim Öffnen festgehalten, damit die Reihenfolge nicht springt
    property var list: []

    // Fenster → wann zuletzt aktiv; sonst Hyprlands focusHistoryID
    property var lastActive: ({})
    property int tick: 0

    function rank(t) {
        if (t === Hyprland.activeToplevel)
            return Infinity;
        const seen = lastActive[t.address];
        if (seen !== undefined)
            return seen;
        const ipc = t.lastIpcObject;
        return ipc && ipc.focusHistoryID !== undefined ? -ipc.focusHistoryID : -1e6;
    }

    function appIdOf(t) {
        if (t.wayland && t.wayland.appId)
            return t.wayland.appId;
        return t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : "";
    }

    // kurzer App-Name: Desktop-Eintrag, sonst letzter Teil der App-ID
    function appName(app) {
        const entry = DesktopEntries.heuristicLookup(app);
        return (entry && entry.name ? entry.name : app.split(".").pop()).toLowerCase();
    }

    function collect() {
        return Hyprland.toplevels.values.filter(t => t.workspace && t.wayland && t.workspace.id > 0).sort((a, b) => rank(b) - rank(a));
    }

    function step(dir) {
        if (!shown) {
            list = collect();
            if (list.length === 0)
                return;
            index = dir > 0 ? Math.min(1, list.length - 1) : list.length - 1;
            shown = true;
            return;
        }
        index = (index + dir + list.length) % list.length;
    }

    function commit() {
        if (!shown)
            return;
        pending = list[index] || null;
        shown = false;
        if (pending)
            focusLater.restart();
    }

    function cancel() {
        shown = false;
    }

    // Erst fokussieren, wenn die Liste weg ist (sonst fokussiert Hyprland
    // das Fenster unter dem Zeiger, bei Spielen wieder das Spiel)
    property var pending: null
    Timer {
        id: focusLater
        interval: 40
        onTriggered: {
            if (root.pending) {
                const a = root.pending.address;
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:${a.startsWith("0x") ? a : "0x" + a}" })`);
            }
            root.pending = null;
        }
    }

    onShownChanged: if (!shown)
        list = []

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (!t)
                return;
            const copy = root.lastActive;
            copy[t.address] = ++root.tick;
            root.lastActive = copy;
            Hyprland.refreshToplevels();
        }
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    GlobalShortcut {
        name: "alttab-next"
        description: "Alt+Tab: nächstes Fenster"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        name: "alttab-prev"
        description: "Alt+Tab: vorheriges Fenster"
        onPressed: root.step(-1)
    }
    GlobalShortcut {
        name: "alttab-commit"
        description: "Alt+Tab: zum gewählten Fenster"
        // Hyprland meldet Binds mit release = true als „released“
        onPressed: root.commit()
        onReleased: root.commit()
    }
    GlobalShortcut {
        name: "alttab-cancel"
        description: "Alt+Tab: abbrechen"
        onPressed: root.cancel()
    }

    // ── Aussehen ──────────────────────────────────────────────────────
    property int columns: 4
    property int previewWidth: 240
    property int previewHeight: 135

    PanelWindow {
        id: panel

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || null
        visible: root.shown
        color: Theme.bg
        implicitWidth: grid.implicitWidth + 2 * 12
        implicitHeight: grid.implicitHeight + 2 * 12
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "alttab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // 1px Rahmen wie Rofi (flat.rasi)
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.accent
            z: 1
        }

        Grid {
            id: grid

            x: 12
            y: 12
            columns: Math.max(1, Math.min(root.columns, root.list.length))
            spacing: 8

            Repeater {
                model: root.list

                // Kachel: Vorschau, darunter Arbeitsfläche · App · Titel
                delegate: Rectangle {
                    id: tile

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.index
                    readonly property string app: root.appIdOf(modelData)

                    implicitWidth: root.previewWidth + 2 * 6
                    implicitHeight: root.previewHeight + 2 * 6 + Theme.height
                    color: selected ? Theme.accent : mouse.containsMouse ? Qt.alpha(Theme.accent, 0.15) : "transparent"
                    border.width: 1
                    border.color: selected ? Theme.accent : Qt.alpha(Theme.faint, 0.5)

                    // Vorschau (einmal beim Öffnen aufgenommen); bis sie da
                    // ist: App-Symbol
                    Rectangle {
                        x: 6
                        y: 6
                        width: root.previewWidth
                        height: root.previewHeight
                        color: Qt.alpha(Theme.fg, 0.05)

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 48
                            visible: !shot.hasContent
                            source: {
                                const entry = DesktopEntries.heuristicLookup(tile.app);
                                return Quickshell.iconPath(entry && entry.icon ? entry.icon : tile.app, "application-x-executable");
                            }
                        }

                        ScreencopyView {
                            id: shot
                            anchors.centerIn: parent
                            captureSource: root.shown ? tile.modelData.wayland : null
                            live: false
                            constraintSize: Qt.size(root.previewWidth, root.previewHeight)
                        }
                    }

                    Label {
                        id: ws
                        x: 8
                        y: root.previewHeight + 12
                        height: Theme.height - 6
                        color: tile.selected ? Theme.accentFg : Theme.faint
                        text: tile.modelData.workspace ? tile.modelData.workspace.name : ""
                    }
                    Label {
                        anchors.left: ws.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        y: ws.y
                        height: ws.height
                        color: tile.selected ? Theme.accentFg : Theme.fg
                        font.bold: tile.selected
                        text: root.appName(tile.app) + (tile.modelData.title ? " · " + tile.modelData.title : "")
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton) {
                                tile.modelData.wayland.close();
                                root.list = root.list.filter(t => t !== tile.modelData);
                                if (root.list.length === 0)
                                    root.cancel();
                                else
                                    root.index = Math.min(root.index, root.list.length - 1);
                            } else {
                                root.index = tile.index;
                                root.commit();
                            }
                        }
                    }
                }
            }
        }
    }
}
