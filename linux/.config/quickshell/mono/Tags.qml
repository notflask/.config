import QtQuick
import Quickshell

// Arbeitsflächen in chinesischen Ziffern, nur die vorhandenen (belegte und
// die gerade angezeigte): die angezeigte in der Akzentfarbe, belegte hell,
// leere dunkel, dringende rot. Klick wechselt dorthin, Mausrad blättert.
Row {
    id: root

    required property string output
    readonly property var mon: Wm.monitor(output)
    readonly property var digits: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property var tags: root.mon ? root.mon.tags : []

    leftPadding: 6

    Repeater {
        model: root.tags

        delegate: Item {
            id: tag

            required property var modelData

            height: parent.height
            width: label.implicitWidth + 12

            Label {
                id: label
                anchors.centerIn: parent
                text: root.digits[tag.modelData.index] || String(tag.modelData.index)
                color: tag.modelData.is_active ? Theme.accent : tag.modelData.is_urgent ? Theme.error : tag.modelData.client_count > 0 ? Theme.fg : mouse.containsMouse ? Theme.dim : Theme.faint
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
