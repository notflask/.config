import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Stil frame: die Leiste ist ein Rahmen um den ganzen Bildschirm, links
// breiter (Logo, Arbeitsflächen; unten Status und Uhr), sonst 8 px. Die
// Öffnung hat runde Ecken und eine feine Kante.
// Vier schmale Fenster statt einem über den ganzen Bildschirm (das kostete
// pro Monitor Puffer in Bildschirmgröße, ~90 MB): links die Leiste in voller
// Höhe, oben und unten die Kanten samt runder Ecken, rechts der Rest. Jedes
// zeichnet seinen Ausschnitt derselben Form.
Scope {
    id: root

    required property var modelData
    readonly property int corner: Theme.frameEdge + Theme.frameRadius

    // Rahmen = Bildschirm minus runde Öffnung (gerade/ungerade) plus Kante,
    // in Bildschirmkoordinaten; ox/oy = Lage des Fensters
    component Cut: Shape {
        property real ox: 0
        property real oy: 0
        readonly property real sw: root.modelData.width
        readonly property real sh: root.modelData.height

        x: -ox
        y: -oy
        width: sw
        height: sh
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: Theme.frameColor
            fillRule: ShapePath.OddEvenFill

            PathRectangle {
                width: sw
                height: sh
            }
            PathRectangle {
                x: Theme.frameBar
                y: Theme.frameEdge
                width: sw - Theme.frameBar - Theme.frameEdge
                height: sh - 2 * Theme.frameEdge
                radius: Theme.frameRadius
            }
        }

        ShapePath {
            strokeWidth: 1
            strokeColor: Theme.rim
            fillColor: "transparent"

            PathRectangle {
                x: Theme.frameBar + 0.5
                y: Theme.frameEdge + 0.5
                width: sw - Theme.frameBar - Theme.frameEdge - 1
                height: sh - 2 * Theme.frameEdge - 1
                radius: Theme.frameRadius
            }
        }
    }

    component Piece: PanelWindow {
        screen: root.modelData
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "frame"
        WlrLayershell.layer: WlrLayer.Top
    }

    // links: die Leiste in voller Höhe, Klicks nur hier. Als erstes Fenster,
    // damit die anderen ihr Platz lassen (sie richten sich nach schon
    // reservierten Rändern, also ohne eigenen Abstand links)
    PanelWindow {
        id: win

        screen: root.modelData
        anchors {
            top: true
            bottom: true
            left: true
        }
        implicitWidth: Theme.frameBar
        exclusiveZone: Theme.frameBar
        color: Theme.frameColor
        WlrLayershell.namespace: "frame"
        WlrLayershell.layer: WlrLayer.Top

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

    // oben und unten: rechts der Leiste, mit den runden Ecken
    Piece {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: root.corner
        exclusiveZone: Theme.frameEdge

        Cut {
            ox: Theme.frameBar
        }
    }
    Piece {
        anchors {
            bottom: true
            left: true
            right: true
        }
        implicitHeight: root.corner
        exclusiveZone: Theme.frameEdge

        Cut {
            ox: Theme.frameBar
            oy: root.modelData.height - root.corner
        }
    }
    // rechts: zwischen den Ecken
    Piece {
        anchors {
            top: true
            bottom: true
            right: true
        }
        // oben/unten schon 8 px reserviert, dazu die Ecke
        margins.top: Theme.frameRadius
        margins.bottom: Theme.frameRadius
        implicitWidth: Theme.frameEdge
        exclusiveZone: Theme.frameEdge

        Cut {
            ox: root.modelData.width - Theme.frameEdge
            oy: root.corner
        }
    }
}
