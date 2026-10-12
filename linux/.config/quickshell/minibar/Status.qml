import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets

// Rechte Seite, nur Text mit „·“ dazwischen:
//   Tray · us · vpn · vol 40% · bat 87% · Mo. 12.10. 11:40
Row {
    id: root

    required property var bar
    spacing: 0

    component Sep: Label {
        height: parent.height
        leftPadding: 7
        rightPadding: 7
        color: Qt.alpha(Theme.faint, 0.7)
        text: "·"
    }

    // ── Tray (Discord, Telegram, Control Center …): kleine Symbole ─────
    Row {
        height: parent.height
        spacing: 8
        visible: SystemTray.items.values.length > 0

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: entry

                required property var modelData

                width: 14
                height: parent.height

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 14
                    source: entry.modelData.icon
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: m => {
                        const item = entry.modelData;
                        if (m.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else if (m.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) {
                                const p = entry.mapToItem(null, 0, entry.height);
                                item.display(root.bar, p.x, p.y);
                            }
                        } else {
                            item.activate();
                        }
                    }
                    onWheel: w => entry.modelData.scroll(w.angleDelta.y, false)
                }
            }
        }
    }

    Sep {
        visible: SystemTray.items.values.length > 0
    }

    // ── Tastaturlayout klein (us, de, ru, ua – Alt+Shift wechselt) ─────
    Label {
        height: parent.height
        text: {
            const name = Mango.layout;
            const known = {
                "English (US)": "us",
                "English": "us",
                "German": "de",
                "Russian": "ru",
                "Ukrainian": "ua"
            };
            for (const k in known)
                if (name.startsWith(k))
                    return known[k];
            return name.slice(0, 2).toLowerCase();
        }
    }

    Sep {}

    // ── VPN (../taskbar/scripts/vpn.sh): Klick verbindet/trennt ────────
    Label {
        id: vpn

        property string state: "off"
        readonly property string script: Quickshell.shellDir + "/../taskbar/scripts/vpn.sh"

        height: parent.height
        text: state === "open" ? "vpn aus" : "vpn"
        color: state === "on" ? Theme.ok : state === "pending" ? Theme.warn : Theme.error
        font.bold: state === "open"

        Process {
            id: vpnPoll
            command: [vpn.script]
            running: true
            stdout: StdioCollector {
                onStreamFinished: vpn.state = (text.split("\n")[0] || "off").trim()
            }
        }

        Timer {
            interval: 5000
            running: true
            repeat: true
            onTriggered: vpnPoll.running = true
        }

        Timer {
            id: vpnAgain
            interval: 1500
            onTriggered: vpnPoll.running = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Quickshell.execDetached([vpn.script, "toggle"]);
                vpnAgain.restart();
            }
        }
    }

    Sep {}

    // ── Lautstärke: Mausrad ändert, Klick stumm, Rechtsklick pavucontrol ─
    Label {
        id: volume

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real level: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

        height: parent.height
        text: muted ? "vol stumm" : "vol " + Math.round(level * 100) + "%"
        color: muted ? Theme.faint : Theme.fg

        PwObjectTracker {
            objects: [volume.sink]
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Quickshell.execDetached(["pavucontrol"]);
                else if (volume.sink && volume.sink.audio)
                    volume.sink.audio.muted = !volume.sink.audio.muted;
            }
            onWheel: w => {
                if (!volume.sink || !volume.sink.audio)
                    return;
                const v = volume.level + (w.angleDelta.y > 0 ? 0.05 : -0.05);
                volume.sink.audio.volume = Math.max(0, Math.min(1, v));
            }
        }
    }

    // ── Akku (nur mit Akku) ────────────────────────────────────────────
    Sep {
        visible: battery.visible
    }

    Label {
        id: battery

        readonly property var dev: UPower.displayDevice
        readonly property real percent: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
        readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)

        height: parent.height
        visible: dev && dev.isPresent && dev.isLaptopBattery
        text: "bat " + Math.round(percent) + "%" + (charging ? "+" : "")
        color: percent <= 15 && !charging ? Theme.error : percent <= 30 && !charging ? Theme.warn : Theme.fg
    }

    Sep {}

    // ── Uhr ────────────────────────────────────────────────────────────
    Label {
        height: parent.height
        rightPadding: 10
        text: Qt.locale("de_DE").toString(clock.date, "ddd dd.MM. HH:mm")

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }
    }
}
