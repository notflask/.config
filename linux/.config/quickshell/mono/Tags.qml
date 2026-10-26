import QtQuick
import Quickshell

// Arbeitsflächen 1–7 in chinesischen Ziffern, immer alle sichtbar: die
// gerade angezeigte in der Akzentfarbe, belegte hell, leere dunkel,
// dringende rot. Höhere Nummern nur, solange es sie gibt. Klick wechselt
// dorthin, Mausrad blättert.
Row {
    id: root

    required property string output
    readonly property var mon: Wm.monitor(output)
    readonly property var digits: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property var tags: {
        const known = root.mon ? root.mon.tags : [];
        const last = Math.max(7, ...known.map(t => t.index));
        const out = [];
        for (let i = 1; i <= last; i++)
            out.push(known.find(t => t.index === i) || {
                index: i,
                is_active: false,
                client_count: 0,
                is_urgent: false
            });
        return out;
    }

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
