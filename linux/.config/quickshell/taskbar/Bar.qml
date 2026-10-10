import QtQuick
import Quickshell
import Quickshell.Wayland

// Taskleiste eines Monitors: unten, volle Breite, eckig, 40px (Windows 10),
// Liquid Glass (Blur: layer-rule "taskbar" in Niri/Hyprland).
PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 40
    color: "transparent"
    WlrLayershell.namespace: "taskbar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: Theme.glass

        // Kante und Lichtkante oben
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.rim
        }
        Rectangle {
            y: 1
            width: parent.width
            height: 1
            color: Theme.shine
            opacity: 0.6
        }
    }

    // Inhalt unter der 1px-Kante zentriert (39px)
    Item {
        anchors.fill: parent
        anchors.topMargin: 1

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        TaskApps {
            anchors.centerIn: parent
            height: parent.height
            bar: bar
        }

        Status {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }
    }
}
