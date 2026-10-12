import QtQuick
import Quickshell
import Quickshell.Hyprland

// Arbeitsflächen dieses Monitors als runde Glas-Pillen (25px)
Row {
    id: root

    required property var screen

    spacing: 4

    readonly property var items: {
        const name = screen ? screen.name : "";
        if (Compositor.hyprland) {
            return Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name === name).sort((a, b) => a.id - b.id).map(w => ({
                        label: w.name,
                        active: w.active,
                        activate: () => w.activate()
                    }));
        }
        return Compositor.niriWorkspaces.filter(w => w.output === name).sort((a, b) => a.idx - b.idx).map(w => ({
                    label: w.name || String(w.idx),
                    active: w.is_active,
                    activate: () => Quickshell.execDetached(["sh", "-c", `niri msg action focus-monitor '${name}' && niri msg action focus-workspace ${w.idx}`])
                }));
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: pill

            required property var modelData

            implicitWidth: Math.max(25, label.implicitWidth + 18)
            implicitHeight: 25

            // aktiv: Milchglas mit heller Kante oben, wie in style.css
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: !pill.modelData.active && mouse.containsMouse ? Theme.hover : "transparent"
                gradient: pill.modelData.active ? activeGradient : null
                border.width: pill.modelData.active ? 1 : 0
                border.color: Qt.alpha(Theme.text, 0.22)

                Gradient {
                    id: activeGradient
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.text, 0.16)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(Theme.text, 0.05)
                    }
                }
            }

            Label {
                id: label
                anchors.centerIn: parent
                text: pill.modelData.label
                color: pill.modelData.active ? Theme.text : Theme.textDim
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: pill.modelData.activate()
            }
        }
    }
}
