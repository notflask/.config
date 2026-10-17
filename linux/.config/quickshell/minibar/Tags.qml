import QtQuick
import Quickshell

// Tags in römischen Ziffern: gerade angezeigte in der Akzentfarbe
// hinterlegt, belegte normal, leere ausgeblendet (wie Arbeitsflächen in
// Niri), dringende rot. Klick wechselt dorthin, Mausrad blättert.
Row {
    id: root

    required property string output
    readonly property var mon: Wm.monitor(output)
    readonly property var roman: ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

    Repeater {
        model: root.mon ? root.mon.tags.filter(t => t.is_active || t.client_count > 0) : []

        delegate: Rectangle {
            id: tag

            required property var modelData

            height: parent.height
            width: label.implicitWidth + 16
            color: tag.modelData.is_active ? Theme.accent : mouse.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent"

            Label {
                id: label
                anchors.centerIn: parent
                text: root.roman[tag.modelData.index] || String(tag.modelData.index)
                color: tag.modelData.is_active ? Theme.accentFg : tag.modelData.is_urgent ? Theme.error : Theme.fg
                font.bold: tag.modelData.is_active
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Wm.view(tag.modelData.index, root.output)
                onWheel: w => Wm.scroll(w.angleDelta.y > 0 ? -1 : 1, root.output)
            }
        }
    }
}
