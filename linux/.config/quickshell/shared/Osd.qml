import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// One event-driven OSD per shell, on the focused output. Never takes focus.
Scope {
    id: root
    property color background: "#171717"
    property color foreground: "#eeeeee"
    property color accent: "#c4b5fd"
    property color rim: "#555555"
    property string fontFamily: "Inter"
    property int cornerRadius: 0
    property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    property bool ready: false
    property bool shown: false
    property string kind: "volume"
    property string language: ""
    property string lastLayout: ""
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    function show(type) {
        if (!ready) return;
        kind = type;
        shown = true;
        expiry.restart();
    }
    function languageName(layout) {
        if (/English/i.test(layout)) return "English";
        if (/German|Deutsch/i.test(layout)) return "Deutsch";
        if (/Ukrainian|Україн/i.test(layout)) return "Українська";
        if (/Russian|Русск/i.test(layout)) return "Русский";
        return layout;
    }
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    // Suppress initial PipeWire discovery; subsequent external changes also show the OSD.
    Timer { interval: 1000; running: true; onTriggered: root.ready = true }
    Timer { id: expiry; interval: 1400; onTriggered: root.shown = false }
    Connections {
        target: root.audio
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            const layout = event.data.slice(event.data.indexOf(",") + 1);
            // The layout shortcut updates all keyboards: show once for each actual change.
            if (layout === root.lastLayout) return;
            root.lastLayout = layout;
            root.language = root.languageName(layout);
            root.show("language");
        }
    }
    PanelWindow {
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0] || null
        visible: root.shown
        anchors.bottom: true
        margins.bottom: 72
        implicitWidth: 240
        implicitHeight: 40
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "g5-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {} // Click through, including while a game grabs the pointer.
        Rectangle {
            anchors.fill: parent
            radius: Math.min(root.cornerRadius, 8)
            color: root.background
            border.width: 1
            border.color: root.rim
            Row {
                anchors.centerIn: parent
                visible: root.kind === "language"
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.foreground
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 17
                    text: "\u{F030C}"
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 14
                    text: root.language
                }
            }
            Row {
                anchors.centerIn: parent
                visible: root.kind === "volume"
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    horizontalAlignment: Text.AlignHCenter
                    color: root.foreground
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 17
                    text: root.muted ? "\u{F075F}" : root.volume <= 0 ? "\u{F057F}" : root.volume < 0.5 ? "\u{F0580}" : "\u{F057E}"
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 138
                    height: 4
                    radius: root.cornerRadius ? 2 : 0
                    color: Qt.alpha(root.foreground, 0.16)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.volume))
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Qt.alpha(root.foreground, 0.35) : root.accent
                        Behavior on width { NumberAnimation { duration: 90 } }
                    }
                }
                Text {
                    width: 32
                    horizontalAlignment: Text.AlignLeft
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    text: Math.round(root.volume * 100) + "%"
                }
            }
        }
    }
}
