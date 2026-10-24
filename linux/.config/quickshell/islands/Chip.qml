import QtQuick

// Knopf in der Leiste: Inhalt mittig, beim Überfahren eine Kapsel dahinter.
// Waagrecht 28 hoch, im Rahmen 34 breit.
Item {
    id: root

    default property alias content: box.data
    property bool vertical: false
    property alias hovered: mouse.containsMouse
    property alias mouse: mouse
    signal clicked(var m)
    signal wheel(var w)

    implicitWidth: vertical ? 34 : box.childrenRect.width + 16
    implicitHeight: vertical ? box.childrenRect.height + 14 : 28

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: mouse.containsMouse ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Item {
        id: box
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
