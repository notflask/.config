import QtQuick
import Quickshell
import Quickshell.Widgets

// Menü eines Tray-Symbols im Glas-Stil statt des Qt/KDE-Menüs.
// Untermenüs öffnen sich an derselben Stelle, oben führt „Zurück“ zurück.
Popup {
    id: menu

    // Menü des Symbols (SystemTrayItem.menu) und der Weg in Untermenüs
    property var root: null
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : root

    function openFor(item, handle) {
        root = handle;
        stack = [];
        open(item);
    }

    padding: 6

    QsMenuOpener {
        id: opener
        menu: menu.current
    }

    Column {
        width: 240

        // Zurück aus einem Untermenü
        Item {
            width: parent.width
            height: visible ? 30 : 0
            visible: menu.stack.length > 0

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: backMouse.containsMouse ? Theme.hover : "transparent"
            }

            Row {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Glyph {
                    text: "\u{F0141}"
                    font.pixelSize: 16
                    color: Theme.textDim
                }

                Label {
                    text: "Zurück"
                    font.pixelSize: 13
                    color: Theme.textDim
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: menu.stack = menu.stack.slice(0, -1)
            }
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: row

                required property var modelData

                width: parent.width
                height: modelData.isSeparator ? 9 : 30

                Rectangle {
                    visible: row.modelData.isSeparator
                    x: 8
                    width: parent.width - 16
                    height: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.rim
                }

                Rectangle {
                    visible: !row.modelData.isSeparator
                    anchors.fill: parent
                    radius: 7
                    color: rowMouse.containsMouse && row.modelData.enabled ? Theme.hover : "transparent"
                }

                Row {
                    visible: !row.modelData.isSeparator
                    x: 8
                    width: parent.width - 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    opacity: row.modelData.enabled ? 1 : 0.4

                    // Haken/Auswahl oder Symbol der App, sonst Platz halten
                    Item {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        Glyph {
                            anchors.centerIn: parent
                            visible: row.modelData.buttonType !== QsMenuButtonType.None
                            font.pixelSize: 15
                            color: Theme.primary
                            text: row.modelData.buttonType === QsMenuButtonType.RadioButton ? (row.modelData.checkState === Qt.Checked ? "\u{F043E}" : "\u{F043D}") : (row.modelData.checkState === Qt.Checked ? "\u{F0132}" : "\u{F0131}")
                        }

                        IconImage {
                            anchors.fill: parent
                            visible: row.modelData.buttonType === QsMenuButtonType.None && row.modelData.icon !== ""
                            source: row.modelData.icon
                        }
                    }

                    Label {
                        width: parent.width - 16 - 8 - (row.modelData.hasChildren ? 24 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text.replace(/_(?=\S)/, "")
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Glyph {
                        visible: row.modelData.hasChildren
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0142}"
                        font.pixelSize: 16
                        color: Theme.textDim
                        rotation: -90
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !row.modelData.isSeparator && row.modelData.enabled
                    onClicked: {
                        if (row.modelData.hasChildren) {
                            menu.stack = menu.stack.concat([row.modelData]);
                        } else {
                            row.modelData.triggered();
                            menu.close();
                        }
                    }
                }
            }
        }
    }
}
