import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Eine Insel der Leiste: deckende Kapsel mit feinem Rand und weichem
// Schatten. Inhalt liegt in einer Zeile mittig.
Item {
    id: root

    default property alias content: row.data
    property int pad: 14
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + 2 * pad
    implicitHeight: Theme.pill

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    RectangularShadow {
        anchors.fill: bg
        radius: bg.radius
        offset.y: 3
        blur: 14
        color: Theme.shadow
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: Theme.island
        border.width: 1
        border.color: Qt.alpha(Theme.rim, 0.6)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: 12
    }
}
