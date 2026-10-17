import QtQuick
import QtQuick.Layouts
import Quickshell

// Menü eines Tray-Symbols im Stil der Leiste (wie VpnPanel): deckend,
// eckig, 1px Rahmen, nur Text. Häkchen und Auswahl wie in einer TUI –
// [x] / [ ] und (•) / ( ) –, Untermenüs öffnen sich an derselben Stelle
// („‹ zurück“ führt eine Ebene hoch). Ersetzt Qts eigenes Menü, das die
// Farben und die Schrift der Leiste nicht kennt.
PopupWindow {
    id: menu

    // Status.qml: Menü des Symbols (QsMenuHandle) und sein x in der Leiste
    property var handle: null
    property real atX: 0
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : handle
    readonly property var entries: opener.children ? opener.children.values : []
    readonly property bool anyToggle: entries.some(e => !e.isSeparator && kindOf(e) !== QsMenuButtonType.None)

    // Art des Eintrags (Häkchen/Auswahl) merken: Meldet die App nur den
    // neuen Zustand (z. B. Gigabyte Control Center nach einem Klick), setzt
    // Quickshell 0.3 die Art auf „keine“ zurück – die Kästchen verschwänden.
    property var kinds: ({})
    function kindOf(e) {
        const key = (stack.length ? stack.map(s => s.text).join("/") + "/" : "") + e.text;
        if (e.buttonType !== QsMenuButtonType.None)
            kinds[key] = e.buttonType;
        return kinds[key] !== undefined ? kinds[key] : QsMenuButtonType.None;
    }

    function open(h, x) {
        stack = [];
        handle = h;
        atX = x;
        visible = true;
    }

    function close() {
        visible = false;
        stack = [];
    }

    color: "transparent"
    implicitWidth: Math.min(360, Math.max(200, layout.implicitWidth + 2))
    implicitHeight: layout.implicitHeight + 14

    QsMenuOpener {
        id: opener
        menu: menu.current
    }

    // Ein Eintrag: Text, links das Kästchen, rechts „›“ bei Untermenüs
    component Entry: Rectangle {
        id: row

        property string label
        property string prefix
        property bool more: false
        property bool active: true
        signal activated

        Layout.fillWidth: true
        implicitWidth: text.implicitWidth + arrow.implicitWidth + 32
        implicitHeight: Theme.size + 12
        color: active && area.containsMouse ? Theme.accent : "transparent"

        Label {
            id: text
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24 - arrow.implicitWidth
            color: !row.active ? Theme.faint : area.containsMouse ? Theme.accentFg : Theme.fg
            text: row.prefix + row.label
        }

        Label {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.more
            color: text.color
            text: "›"
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.active
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: 1
        border.color: Theme.accent

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            anchors.topMargin: 7
            spacing: 0

            Entry {
                visible: menu.stack.length > 0
                label: "‹ zurück"
                onActivated: menu.stack = menu.stack.slice(0, -1)
            }

            Repeater {
                model: menu.entries

                delegate: Item {
                    id: slot

                    required property var modelData
                    readonly property var e: modelData

                    Layout.fillWidth: true
                    implicitWidth: e.isSeparator ? 0 : item.implicitWidth
                    implicitHeight: e.isSeparator ? 9 : item.implicitHeight

                    // Trennlinie wie die Linie unter der Leiste
                    Rectangle {
                        visible: slot.e.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        width: parent.width - 24
                        height: 1
                        color: Qt.alpha(Theme.faint, 0.5)
                    }

                    Entry {
                        id: item

                        visible: !slot.e.isSeparator
                        anchors.fill: parent
                        label: slot.e.text.replace(/_(?=[^_])/g, "")
                        active: slot.e.enabled
                        more: slot.e.hasChildren
                        prefix: {
                            const checked = slot.e.checkState === Qt.Checked;
                            const kind = menu.kindOf(slot.e);
                            if (kind === QsMenuButtonType.CheckBox)
                                return checked ? "[x] " : "[ ] ";
                            if (kind === QsMenuButtonType.RadioButton)
                                return checked ? "(•) " : "( ) ";
                            return menu.anyToggle ? "    " : "";
                        }
                        onActivated: {
                            if (slot.e.hasChildren) {
                                menu.stack = menu.stack.concat([slot.e]);
                            } else {
                                slot.e.triggered();
                                menu.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
