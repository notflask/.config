import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Stil islands: drei Inseln oben, dazwischen das Wallpaper.
//   links   Gentoo-Logo (Starter), Arbeitsflächen, Fenstertitel
//   Mitte   was läuft, Datum und Uhr
//   rechts  Status.qml
// Das Fenster ist höher als der reservierte Streifen, damit der Schatten
// der Inseln Platz hat; Klicks gehen nur an die Inseln (mask).
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
    implicitHeight: Theme.top + Theme.pill + 20
    exclusiveZone: Theme.top + Theme.pill
    color: "transparent"
    WlrLayershell.namespace: "islands"
    WlrLayershell.layer: WlrLayer.Top

    mask: Region {
        item: left
        Region {
            item: center
        }
        Region {
            item: right
        }
    }

    Island {
        id: left

        x: Theme.side
        y: Theme.top
        pad: 8
        spacing: 4

        Chip {
            id: logo
            Layout.leftMargin: 2

            GentooLogo {
                size: 18
                active: logo.hovered
            }
            onClicked: Quickshell.execDetached(["sh", "-c", "rofi -show drun -theme ~/.config/rofi/soft.rasi"])
        }

        Workspaces {
            output: bar.modelData.name
        }

        Label {
            id: title

            readonly property string text0: bar.mon && bar.mon.active_client && bar.mon.active_client.title ? bar.mon.active_client.title : ""

            visible: text0 !== ""
            Layout.leftMargin: 6
            Layout.rightMargin: 8
            Layout.maximumWidth: Math.max(80, bar.width / 2 - center.width / 2 - Theme.side - 24 - (left.implicitWidth - width))
            Layout.preferredWidth: Math.min(implicitWidth, 420)
            color: Theme.dim
            text: text0
        }
    }

    Island {
        id: center

        x: (bar.width - width) / 2
        y: Theme.top
        pad: 18

        Media {}
        Clock {}
    }

    Island {
        id: right

        x: bar.width - width - Theme.side
        y: Theme.top
        pad: 6

        Status {
            bar: bar
        }
    }
}
