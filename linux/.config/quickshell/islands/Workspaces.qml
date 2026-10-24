import QtQuick

// Arbeitsflächen als Punkte: belegte kräftig, die angezeigte als lange
// Kapsel in der Akzentfarbe, dringende rot. Leere erscheinen nicht (wie
// in Niri). Klick wechselt, Mausrad blättert. vertical: für den Rahmen.
Item {
    id: root

    required property string output
    property bool vertical: false
    readonly property var mon: Wm.monitor(output)
    readonly property int dot: 8
    readonly property int long: 26

    implicitWidth: vertical ? Theme.frameBar : flow.implicitWidth
    implicitHeight: vertical ? flow.implicitHeight : Theme.pill

    MouseArea {
        anchors.fill: parent
        onWheel: w => Wm.scroll(w.angleDelta.y > 0 ? -1 : 1, root.output)
    }

    Grid {
        id: flow

        anchors.centerIn: parent
        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        rows: root.vertical ? 99 : 1
        columns: root.vertical ? 1 : 99
        spacing: 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: root.mon ? root.mon.tags.filter(t => t.is_active || t.client_count > 0) : []

            delegate: Item {
                id: ws

                required property var modelData
                readonly property bool active: modelData.is_active

                // Trefferfläche größer als der Punkt
                width: root.vertical ? Theme.frameBar : pip.width + 10
                height: root.vertical ? pip.height + 10 : Theme.pill

                Rectangle {
                    id: pip
                    anchors.centerIn: parent
                    width: root.vertical ? root.dot : ws.active ? root.long : root.dot
                    height: root.vertical ? (ws.active ? root.long : root.dot) : root.dot
                    radius: root.dot / 2
                    color: ws.modelData.is_urgent ? Theme.error : ws.active ? Theme.accent : Qt.alpha(Theme.fg, mouse.containsMouse ? 0.7 : 0.4)

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.view(ws.modelData.index, root.output)
                }
            }
        }
    }
}
