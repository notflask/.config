import QtQuick
import QtQuick.Layouts
import Quickshell

// Uhr: waagrecht „Sa. 24. Okt.  10:33“, im Rahmen Stunden über Minuten
Item {
    id: root

    property bool vertical: false

    implicitWidth: vertical ? Theme.frameBar : line.implicitWidth
    implicitHeight: vertical ? stack.implicitHeight : Theme.pill

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: line
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 10

        Label {
            color: Theme.dim
            text: Qt.locale("de_DE").toString(clock.date, "ddd d. MMM")
        }
        Label {
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            text: Qt.formatTime(clock.date, "HH:mm")
        }
    }

    Column {
        id: stack
        visible: root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: -2

        Repeater {
            model: [Qt.formatTime(clock.date, "HH"), Qt.formatTime(clock.date, "mm")]

            delegate: Label {
                required property string modelData
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                font.pixelSize: 15
                font.weight: index === 0 ? Font.Bold : Font.Medium
                font.features: { "tnum": 1 }
                color: index === 0 ? Theme.fg : Theme.dim
                text: modelData
            }
        }
    }
}
