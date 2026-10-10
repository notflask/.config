import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Glasfläche über einem Element der Leiste, mittig darüber, 8px Abstand.
// Eigene Ebenen-Fläche (Namespace "taskbar-popup"), damit Niri/Hyprland
// sie weichzeichnen (layer-rule). Die Position kommt direkt vom Element
// (open(item)), nichts wird geraten.
//
// grab: Klick daneben schließt. Hyprland: Focus-Grab (Leiste bleibt
// bedienbar); Niri: unsichtbare Fläche über dem Bildschirm.
PanelWindow {
    id: popup

    required property var bar
    property bool shown: false
    property bool grab: true
    property int radius: 16
    property int padding: 14
    property real centerX: 0
    // Tastatur (Suchfeld im Startmenü). Hyprland: OnDemand, sonst nimmt
    // Exclusive anderen Flächen auch die Klicks; Niri: Exclusive.
    property bool keyboard: false
    default property alias content: box.data
    readonly property bool hovered: hover.hovered

    function open(item) {
        centerX = item.mapToItem(null, item.width / 2, 0).x;
        shown = true;
    }

    // mittig auf dem Monitor (Startmenü wie unter Windows 11)
    function openCentered() {
        centerX = screen.width / 2;
        shown = true;
    }

    function close() {
        shown = false;
    }

    screen: bar.screen
    // bleibt sichtbar, bis das Ausblenden fertig ist
    visible: shown || fade.running
    color: "transparent"
    anchors {
        bottom: true
        left: true
    }
    // sitzt schon über der reservierten Zone der Leiste: nur der Abstand
    margins.bottom: 8
    margins.left: Math.round(Math.max(8, Math.min(centerX - implicitWidth / 2, (screen ? screen.width : 1920) - implicitWidth - 8)))
    // ganze Pixel: Textzeilen sind oft krumm hoch, dann läge die 1px-Kante
    // oben/unten zwischen zwei Pixeln und wirkte doppelt so dick
    implicitWidth: Math.ceil(box.childrenRect.width) + 2 * padding
    implicitHeight: Math.ceil(box.childrenRect.height) + 2 * padding
    exclusiveZone: 0
    WlrLayershell.namespace: "taskbar-popup"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown && keyboard ? (Compositor.hyprland ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    // Öffnen/Schließen: einblenden und von 92 % auf volle Größe wachsen,
    // von unten (der Leiste) her – wie die Fenster-Animationen
    Item {
        anchors.fill: parent
        opacity: popup.shown ? 1 : 0
        scale: popup.shown ? 1 : 0.92
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: popup.shown ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.1
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: popup.radius
            color: Theme.glass
            border.width: 1
            border.color: Theme.rim
        }

        Item {
            id: box
            x: popup.padding
            y: popup.padding
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    HoverHandler {
        id: hover
    }

    HyprlandFocusGrab {
        active: popup.shown && popup.grab && Compositor.hyprland
        windows: [popup, popup.bar]
        onCleared: popup.shown = false
    }

    // Niri: kein Focus-Grab, also eine durchsichtige Fläche darunter
    PanelWindow {
        visible: popup.shown && popup.grab && !Compositor.hyprland
        screen: popup.bar.screen
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "taskbar-backdrop"
        WlrLayershell.layer: WlrLayer.Top

        MouseArea {
            anchors.fill: parent
            onPressed: popup.shown = false
        }
    }
}
