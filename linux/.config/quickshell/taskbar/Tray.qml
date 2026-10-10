import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Tray wie unter Windows: nur ein Pfeil, Klick klappt die Symbole links
// daneben aus. Linksklick: App, Rechtsklick: Menü im Glas-Stil
// (TrayMenu.qml), Mittelklick: zweite Aktion.
Row {
    id: root

    required property var bar
    property bool open: false

    spacing: 2

    // klappt nach links auf: Breite wächst, Symbole blenden ein
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: width > 0
        height: 27
        width: root.open && SystemTray.items.values.length > 0 ? icons.implicitWidth + 16 : 0
        radius: 8
        color: Theme.pill
        clip: true
        opacity: root.open ? 1 : 0

        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: icons
            // rechts verankert: die Symbole gleiten beim Aufklappen herein
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    id: entry

                    required property var modelData

                    width: 20
                    height: 20

                    IconImage {
                        anchors.fill: parent
                        source: entry.modelData.icon
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 6
                        visible: entry.modelData.status === Status.NeedsAttention
                        color: Qt.alpha(Theme.error, 0.25)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const item = entry.modelData;
                            if (m.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            } else if (m.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu)
                                    trayMenu.openFor(entry, item.menu);
                            } else {
                                item.activate();
                            }
                        }
                        onWheel: w => entry.modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }
    }

    TrayMenu {
        id: trayMenu
        bar: root.bar
    }

    Tile {
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.open = !root.open

        Glyph {
            text: "\u{F0143}"
            color: Theme.textDim
            rotation: root.open ? -90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
