import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Lautstärke: nur das Symbol (wechselt mit der Lautstärke). Klick öffnet
// den Regler wie unter macOS direkt darüber, Scrollen ändert die
// Lautstärke, Rechtsklick öffnet pavucontrol.
Tile {
    id: root

    required property var bar
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    function glyph() {
        if (muted || volume <= 0)
            return "\u{F075F}";
        return ["\u{F057F}", "\u{F0580}", "\u{F057E}"][Math.min(2, Math.floor(volume * 3))];
    }

    function setVolume(v) {
        if (!sink || !sink.audio)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (sink.audio.muted && v > 0)
            sink.audio.muted = false;
    }

    background: hovered || popup.shown ? Theme.hover : "transparent"

    onClicked: m => {
        if (m.button === Qt.RightButton)
            Quickshell.execDetached(["pavucontrol"]);
        else if (popup.shown)
            popup.close();
        else
            popup.open(root);
    }
    onWheel: w => setVolume(volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

    PwObjectTracker {
        objects: [root.sink]
    }

    Glyph {
        text: root.glyph()
    }

    Popup {
        id: popup

        bar: root.bar

        Column {
            spacing: 10
            width: 300

            Label {
                text: "Ton"
                font.weight: Font.Bold
            }

            Row {
                spacing: 10
                width: parent.width

                // Lautsprecher: stumm schalten
                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: muteMouse.containsMouse ? Theme.hoverStrong : Theme.pill

                    Glyph {
                        anchors.centerIn: parent
                        text: root.glyph()
                        font.pixelSize: 16
                        color: root.muted ? Theme.error : Theme.text
                    }

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                }

                // Regler: Rinne 22px, voll gerundet, heller Füllstand, runder Knopf
                Item {
                    id: slider
                    width: parent.width - 28 - 44 - 20
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.pill
                        border.width: 1
                        border.color: Qt.alpha(Theme.shadow, 0.25)
                    }

                    Rectangle {
                        width: Math.max(slider.height, slider.height / 2 + root.volume * (slider.width - slider.height))
                        height: parent.height
                        radius: height / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: Qt.alpha(Theme.text, root.muted ? 0.30 : 0.92)
                            }
                            GradientStop {
                                position: 1
                                color: Qt.alpha(Theme.text, root.muted ? 0.25 : 0.72)
                            }
                        }
                    }

                    Rectangle {
                        width: slider.height
                        height: slider.height
                        radius: height / 2
                        x: root.volume * (slider.width - slider.height)
                        color: "white"
                        border.width: 1
                        border.color: Qt.alpha(Theme.shadow, 0.35)
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        function apply(x) {
                            root.setVolume((x - 6 - slider.height / 2) / (slider.width - slider.height));
                        }
                        onPressed: m => apply(m.x)
                        onPositionChanged: m => apply(m.x)
                        onWheel: w => root.setVolume(root.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                    }
                }

                Label {
                    width: 44
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.volume * 100) + "%"
                    color: Theme.textDim
                    font.features: {
                        "tnum": 1
                    }
                }
            }

            Label {
                width: parent.width
                text: root.sink ? (root.sink.description || root.sink.nickname || root.sink.name) : ""
                font.pixelSize: 12
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }
    }
}
