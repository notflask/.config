import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Alt+Tab für Hyprland (Niri hat das eingebaut): zuletzt benutzte Fenster
// zuerst, als Glasfläche mitten auf dem fokussierten Monitor. Hyprland ruft
// das direkt über Global Shortcuts auf (binds in hypr/hyprland.lua), ohne
// eigenen Prozess pro Tastendruck:
//   quickshell:alttab-next / -prev   öffnen bzw. weiter / zurück
//   quickshell:alttab-commit         Alt loslassen: zum gewählten Fenster
//   quickshell:alttab-cancel         Esc: zu, nichts wechseln
// Maus: Kachel anklicken wechselt, mittlere Taste schließt das Fenster.
Scope {
    id: root

    // ── Einstellungen (Quickshell lädt Änderungen sofort) ─────────────
    // Fenster aller Monitore, sonst nur vom fokussierten
    property bool allMonitors: true
    // nur die aktuelle Arbeitsfläche (je Monitor)
    property bool currentWorkspaceOnly: false
    // Scratchpad-Fenster (special workspaces) mit anzeigen
    property bool includeSpecial: false
    // Vorschau der Fenster, sonst nur großes App-Symbol (schneller)
    property bool previews: true
    // Vorschau laufend aktualisieren statt einmal beim Öffnen aufnehmen
    property bool livePreviews: false
    // Arbeitsfläche (und bei mehreren Monitoren den Monitor) in der Kachel
    property bool showWorkspace: true
    // Kacheln pro Zeile und Größe der Vorschau
    property int columns: 5
    property int previewWidth: 220
    property int previewHeight: 124
    // Einblenden in ms (0 = sofort)
    property int fadeIn: 70

    // ── Zustand ───────────────────────────────────────────────────────
    property bool shown: false
    property int index: 0
    // beim Öffnen festgehalten, damit die Reihenfolge nicht springt
    property var list: []

    // Fenster → wann zuletzt aktiv. Das aktive Fenster steht immer vorn;
    // Fenster, die seit dem Start von Quickshell nicht aktiv waren, ordnet
    // Hyprlands focusHistoryID (0 = zuletzt aktiv, bei jedem Fokuswechsel
    // neu abgefragt).
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

    function iconFor(app) {
        const entry = DesktopEntries.heuristicLookup(app);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : app, "application-x-executable");
    }

    function collect() {
        const focusedMon = Hyprland.focusedMonitor;
        return Hyprland.toplevels.values.filter(t => {
            const ws = t.workspace;
            if (!ws || !t.wayland)
                return false;
            if (ws.id < 0 && !root.includeSpecial)
                return false;
            if (!root.allMonitors && ws.monitor !== focusedMon)
                return false;
            if (root.currentWorkspaceOnly && !ws.active)
                return false;
            return true;
        }).sort((a, b) => rank(b) - rank(a));
    }

    function step(dir) {
        if (!shown) {
            list = collect();
            if (list.length === 0)
                return;
            // Start beim vorletzten Fenster (Alt+Tab) bzw. beim ältesten (Alt+Shift+Tab)
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

    // Erst fokussieren, wenn die Fläche weg ist: Beim Ausblenden fokussiert
    // Hyprland sonst das Fenster unter dem Zeiger neu – bei einem Spiel, das
    // den Zeiger festhält, wieder das Spiel.
    property var pending: null
    Timer {
        id: focusLater
        interval: 40
        onTriggered: {
            if (root.pending)
                root.focus(root.pending);
            root.pending = null;
        }
    }

    // Direkt per Hyprland-Dispatcher (wayland.activate() ist nur eine Bitte)
    function focus(t) {
        const addr = t.address.startsWith("0x") ? t.address : "0x" + t.address;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
        else
            Hyprland.dispatch(`focuswindow address:${addr}`);
    }

    function cancel() {
        shown = false;
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

    // focusHistoryID für die Startreihenfolge
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
        // Hyprland meldet Binds mit release = true als „released“, nicht „pressed“
        onPressed: root.commit()
        onReleased: root.commit()
    }
    GlobalShortcut {
        name: "alttab-cancel"
        description: "Alt+Tab: abbrechen"
        onPressed: root.cancel()
    }

    PanelWindow {
        id: panel

        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || null
        visible: root.shown
        color: "transparent"
        // ohne Anker: mittig auf dem Monitor
        implicitWidth: Math.min(grid.implicitWidth, (screen ? screen.width : 1920) - 64) + 2 * 14
        implicitHeight: grid.implicitHeight + 2 * 14
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "alttab"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            opacity: root.shown ? 1 : 0
            Behavior on opacity {
                enabled: root.fadeIn > 0
                NumberAnimation {
                    duration: root.fadeIn
                    easing.type: Easing.OutCubic
                }
            }

            // äußere Glasfläche wie Rofi
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: Theme.glass
                border.width: 1
                border.color: Theme.rim

                Rectangle {
                    x: 20
                    y: 1
                    width: parent.width - 40
                    height: 1
                    color: Theme.shine
                    opacity: 0.6
                }
            }

            Grid {
                id: grid

                x: 14
                y: 14
                columns: Math.max(1, Math.min(root.columns, root.list.length))
                spacing: 8

                Repeater {
                    model: root.list

                    delegate: Item {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property bool selected: index === root.index
                        readonly property string app: root.appIdOf(modelData)
                        readonly property var ws: modelData.workspace

                        implicitWidth: root.previewWidth + 16
                        implicitHeight: (root.previews ? root.previewHeight + 8 : 64) + 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: tile.selected ? Qt.alpha(Theme.primary, 0.22) : mouse.containsMouse ? Theme.hoverStrong : Theme.pill
                            border.width: 1
                            border.color: tile.selected ? Qt.alpha(Theme.primary, 0.75) : Qt.alpha(Theme.text, 0.12)

                            // Lichtkante oben
                            Rectangle {
                                x: 12
                                y: 1
                                width: parent.width - 24
                                height: 1
                                color: tile.selected ? Theme.shine : Theme.pillShine
                            }
                        }

                        Row {
                            x: 10
                            y: 9
                            width: parent.width - 20
                            spacing: 6

                            IconImage {
                                implicitSize: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: root.iconFor(tile.app)
                            }

                            Label {
                                width: parent.width - 22 - (badge.visible ? badge.width + 6 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                text: tile.modelData.title || tile.app
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            // Arbeitsfläche, bei mehreren Monitoren mit Monitor
                            Rectangle {
                                id: badge
                                visible: root.showWorkspace && !!tile.ws
                                anchors.verticalCenter: parent.verticalCenter
                                width: badgeText.implicitWidth + 10
                                height: 16
                                radius: 8
                                color: Theme.pill

                                Label {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    font.pixelSize: 10
                                    color: Theme.textDim
                                    text: !tile.ws ? "" : (Quickshell.screens.length > 1 && tile.ws.monitor ? tile.ws.monitor.name + " · " : "") + tile.ws.name
                                }
                            }
                        }

                        // Vorschau; bis sie da ist (oder ohne Vorschau): App-Symbol
                        Item {
                            x: 8
                            y: 34
                            width: root.previewWidth
                            height: root.previews ? root.previewHeight : 64

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: root.previews ? 48 : 40
                                visible: !root.previews || !shot.hasContent
                                source: root.iconFor(tile.app)
                            }

                            ScreencopyView {
                                id: shot
                                anchors.centerIn: parent
                                visible: root.previews
                                captureSource: root.previews && root.shown ? tile.modelData.wayland : null
                                live: root.livePreviews
                                constraintSize: Qt.size(root.previewWidth, root.previewHeight)
                            }
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
}
