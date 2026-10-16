import QtQuick
import Quickshell
import Quickshell.Wayland

// Leiste eines Monitors: oben, volle Breite, deckend, 1px Linie unten
PanelWindow {
    id: bar

    required property var modelData
    readonly property var mon: Wm.monitor(modelData.name)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.height
    color: Theme.bg
    WlrLayershell.namespace: "minibar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Theme.faint, 0.5)
    }

    // ── links: Tags, Layout, Fenstertitel ──────────────────────────────
    Row {
        id: left
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1

        Tags {
            height: parent.height
            output: bar.modelData.name
        }

        Label {
            height: parent.height
            leftPadding: 8
            rightPadding: 10
            color: Theme.faint
            text: bar.mon ? "[" + bar.mon.layout_symbol + "]" : ""
        }
    }

    Label {
        anchors.left: left.right
        anchors.right: right.left
        anchors.rightMargin: 16
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        color: Theme.dim
        text: bar.mon && bar.mon.active_client && bar.mon.active_client.title ? bar.mon.active_client.title : ""
    }

    // ── rechts: Status ─────────────────────────────────────────────────
    Status {
        id: right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        bar: bar
    }
}
