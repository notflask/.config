import QtQuick

// Schalter in Glas-Optik: Spur in der Akzentfarbe, wenn an; Knopf gleitet.
Item {
    id: root

    property bool checked: false
    property color accent: Theme.primary

    signal toggled

    implicitWidth: 44
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Qt.alpha(root.accent, 0.45) : Theme.pill
        border.width: 1
        border.color: root.checked ? Qt.alpha(root.accent, 0.7) : Qt.alpha(Theme.text, 0.15)

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.text : Theme.textDim

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
