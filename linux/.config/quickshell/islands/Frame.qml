import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Stil frame: die Leiste ist ein Rahmen um den ganzen Bildschirm, links
// breiter (Logo, Arbeitsflächen; unten Status und Uhr), sonst 8 px. Die
// Öffnung hat runde Ecken, der Rahmen wirft einen weichen Schatten hinein.
// Ein Fenster über den ganzen Bildschirm zeichnet ihn (Klicks nur links,
// mask); vier leere Streifen reservieren den Platz für Hyprland.
Scope {
    id: root

    required property var modelData

    component Edge: PanelWindow {
        screen: root.modelData
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "frame-edge"
    }

    Edge {
        anchors {
            top: true
            bottom: true
            left: true
        }
        implicitWidth: Theme.frameBar
        exclusiveZone: Theme.frameBar
    }
    Edge {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.frameEdge
        exclusiveZone: Theme.frameEdge
    }
    Edge {
        anchors {
            top: true
            bottom: true
            right: true
        }
        implicitWidth: Theme.frameEdge
        exclusiveZone: Theme.frameEdge
    }
    Edge {
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: Theme.frameEdge
        exclusiveZone: Theme.frameEdge
    }

    PanelWindow {
        id: win

        readonly property var mon: Wm.monitor(root.modelData.name)

        screen: root.modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "frame"
        WlrLayershell.layer: WlrLayer.Top

        mask: Region {
            item: strip
        }

        // Rahmen = Bildschirm minus runde Öffnung (gerade/ungerade)
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                shadowBlur: 0.7
                blurMax: 24
                shadowVerticalOffset: 1
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.frameColor
                    fillRule: ShapePath.OddEvenFill

                    PathRectangle {
                        x: 0
                        y: 0
                        width: win.width
                        height: win.height
                    }
                    PathRectangle {
                        x: Theme.frameBar
                        y: Theme.frameEdge
                        width: win.width - Theme.frameBar - Theme.frameEdge
                        height: win.height - 2 * Theme.frameEdge
                        radius: Theme.frameRadius
                    }
                }
            }
        }

        // linke Leiste
        Item {
            id: strip

            width: Theme.frameBar
            height: parent.height

            Column {
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Chip {
                    id: logo
                    vertical: true
                    anchors.horizontalCenter: parent.horizontalCenter

                    GentooLogo {
                        size: 20
                        active: logo.hovered
                    }
                    onClicked: Quickshell.execDetached(["sh", "-c", "rofi -show drun -theme ~/.config/rofi/soft.rasi"])
                }

                Workspaces {
                    vertical: true
                    output: root.modelData.name
                }
            }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Status {
                    anchors.horizontalCenter: parent.horizontalCenter
                    bar: win
                    vertical: true
                }

                Clock {
                    vertical: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
