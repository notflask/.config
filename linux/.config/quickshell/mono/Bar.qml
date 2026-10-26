import QtQuick
import Quickshell
import Quickshell.Wayland

// Leiste eines Monitors: oben, volle Breite, deckend. Links Arbeitsflächen,
// rechts Status, kein Fenstertitel
PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.height
    color: Theme.bg
    WlrLayershell.namespace: "mono"
    WlrLayershell.layer: WlrLayer.Top

    Tags {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        output: bar.modelData.name
    }

    Status {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        bar: bar
    }
}
