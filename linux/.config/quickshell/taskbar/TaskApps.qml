import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Startknopf und offene Fenster dieses Monitors, wie unter Windows 11:
// gleiche Apps in einem Symbol, kurzer Strich darunter, langer in der
// Akzentfarbe unter der aktiven App. Hover zeigt die Fenster der App als
// Live-Vorschau (ScreencopyView).
Row {
    id: root

    required property var bar
    spacing: 2

    // Apps in der Reihenfolge ihres Auftauchens, Fenster je App
    property var order: []
    // Toplevel → wann zuletzt aktiv (für den Klick aufs Symbol)
    property var lastActive: new Map()
    property int tick: 0

    readonly property var groups: {
        const name = bar.screen ? bar.screen.name : "";
        const byApp = {};
        for (const t of ToplevelManager.toplevels.values) {
            if (!t.appId)
                continue;
            let here = false;
            for (const s of t.screens)
                if (s.name === name)
                    here = true;
            if (!here)
                continue;
            (byApp[t.appId] = byApp[t.appId] || []).push(t);
            void t.activated; // neu berechnen, wenn sich die Aktivierung ändert
        }
        for (const app of Object.keys(byApp))
            if (order.indexOf(app) < 0)
                order.push(app);
        return order.filter(app => byApp[app]).map(app => ({
                    app: app,
                    toplevels: byApp[app],
                    active: byApp[app].some(t => t.activated)
                }));
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (ToplevelManager.activeToplevel)
                root.lastActive.set(ToplevelManager.activeToplevel, ++root.tick);
        }
    }

    function iconFor(app) {
        const entry = DesktopEntries.heuristicLookup(app);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : app, "application-x-executable");
    }

    // Klick aufs Symbol: zuletzt benutztes Fenster nach vorn; ist es schon
    // vorn, das nächste der App
    function activate(group) {
        const list = group.toplevels.slice().sort((a, b) => (lastActive.get(b) || 0) - (lastActive.get(a) || 0));
        if (list[0].activated && list.length > 1)
            list[list.length - 1].activate();
        else
            list[0].activate();
    }

    // Vorschau: nach kurzem Verweilen zeigen, beim Wechsel sofort umschalten
    property var hoverItem: null
    property string previewApp: ""
    readonly property var previewGroup: groups.find(g => g.app === previewApp) || null

    function hoverEnter(item, app) {
        hoverItem = item;
        hideTimer.stop();
        if (preview.shown) {
            previewApp = app;
            preview.open(item);
        } else {
            showTimer.restart();
        }
    }

    function hoverLeave() {
        hoverItem = null;
        showTimer.stop();
        hideTimer.restart();
    }

    onPreviewGroupChanged: if (!previewGroup)
        preview.close()

    Timer {
        id: showTimer
        interval: 350
        onTriggered: if (root.hoverItem) {
            root.previewApp = root.hoverItem.app;
            preview.open(root.hoverItem);
        }
    }

    Timer {
        id: hideTimer
        interval: 250
        onTriggered: if (!root.hoverItem && !preview.hovered)
            preview.close()
    }

    // Startmenü (rofi/start.sh)
    Tile {
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 29
        padding: 10
        background: hovered || start.shown ? Theme.hover : "transparent"
        onClicked: start.shown ? start.close() : start.openCentered()

        Glyph {
            text: ""
            color: Theme.primary
            font.pixelSize: 20
        }
    }

    StartMenu {
        id: start
        bar: root.bar
    }

    Repeater {
        model: root.groups

        delegate: Item {
            id: button

            required property var modelData
            readonly property string app: modelData.app

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 36
            implicitHeight: 29

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: mouse.containsMouse ? Theme.hover : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }

            IconImage {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                implicitSize: 20
                source: root.iconFor(button.app)
            }

            // Strich unten: kurz = offen, lang + Akzent = aktiv
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 3
                height: 2
                radius: 1
                width: button.modelData.active ? 12 : 5
                color: button.modelData.active ? Theme.primary : Qt.alpha(Theme.textDim, 0.75)
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onEntered: root.hoverEnter(button, button.app)
                onExited: root.hoverLeave()
                onClicked: m => {
                    if (m.button === Qt.LeftButton) {
                        preview.close();
                        root.activate(button.modelData);
                    }
                }
            }
        }
    }

    Popup {
        id: preview

        bar: root.bar
        grab: false
        padding: 8
        onHoveredChanged: if (!hovered && !root.hoverItem)
            hideTimer.restart()

        Row {
            spacing: 6

            Repeater {
                // bleibt beim Ausblenden stehen; aufgenommen wird nur, solange offen
                model: root.previewGroup ? root.previewGroup.toplevels : []

                delegate: Item {
                    id: card

                    required property var modelData
                    readonly property bool hot: cardMouse.containsMouse || close.containsMouse

                    implicitWidth: 236
                    implicitHeight: 172

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: card.hot ? Theme.hover : "transparent"
                        border.width: card.modelData.activated ? 1 : 0
                        border.color: Qt.alpha(Theme.text, 0.10)
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton) {
                                card.modelData.close();
                            } else {
                                card.modelData.activate();
                                preview.close();
                            }
                        }
                    }

                    Row {
                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 6

                        IconImage {
                            implicitSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.iconFor(card.modelData.appId)
                        }

                        Label {
                            width: parent.width - 16 - 22 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.modelData.title || card.modelData.appId
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        // Schließen: erscheint beim Hover, rot unter dem Zeiger
                        Rectangle {
                            width: 22
                            height: 20
                            radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: card.hot ? 1 : 0
                            color: close.containsMouse ? Qt.alpha(Theme.error, 0.85) : "transparent"

                            Glyph {
                                anchors.centerIn: parent
                                text: "\u{F0156}"
                                font.pixelSize: 13
                                color: close.containsMouse ? Theme.onError : Theme.text
                            }

                            MouseArea {
                                id: close
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: card.modelData.close()
                            }
                        }
                    }

                    // Live-Vorschau, bis sie da ist: App-Symbol
                    Rectangle {
                        x: 8
                        y: 34
                        width: 220
                        height: 130
                        radius: 6
                        color: Theme.pill
                        clip: true

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 48
                            visible: !shot.hasContent
                            source: root.iconFor(card.modelData.appId)
                        }

                        ScreencopyView {
                            id: shot
                            anchors.centerIn: parent
                            captureSource: preview.shown ? card.modelData : null
                            live: true
                            constraintSize: Qt.size(220, 130)
                        }
                    }
                }
            }
        }
    }
}
