import QtQuick

// Kachel wie unter Windows: Fläche nur beim Hover, 27px hoch in der
// 40px-Leiste, Ecken 8px. Inhalt nebeneinander.
Item {
    id: tile

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 9
    property color background: mouse.containsMouse ? Theme.hover : "transparent"
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: 27

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: tile.background
        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => tile.clicked(m)
        onWheel: w => tile.wheel(w)
    }
}
