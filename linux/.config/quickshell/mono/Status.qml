import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Rechte Seite wie im Bild:  󰅁 [Tray]  󰕾 󰖩 | 05:20 Jun 30, 2023
// Tray eingeklappt, der Pfeil klappt es auf und zu
// Symbole aus Symbols Nerd Font (Icon)
Row {
    id: root

    required property var bar
    readonly property bool hasTray: SystemTray.items.values.length > 0
    property bool trayOpen: false

    spacing: 0

    component Sep: Label {
        height: parent.height
        leftPadding: 10
        rightPadding: 10
        color: Theme.faint
        text: "|"
    }

    // Symbole direkt aus Symbols Nerd Font: Iosevka belegt dieselben
    // Codepunkte selbst und zeigt sonst nur Kästchen
    component Icon: Label {
        height: parent.height
        rightPadding: 12
        font.family: "Symbols Nerd Font Mono"
    }

    // ── Pfeil: Tray auf- und zuklappen ─────────────────────────────────
    Icon {
        visible: root.hasTray
        text: root.trayOpen ? "󰅂" : "󰅁"
        color: trayToggle.containsMouse ? Theme.fg : Theme.dim

        MouseArea {
            id: trayToggle
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                root.trayOpen = !root.trayOpen;
                if (!root.trayOpen)
                    trayMenu.close();
            }
        }
    }

    // ── Tray (Discord, Telegram, Control Center …): kleine Symbole ─────
    Row {
        height: parent.height
        spacing: 8
        visible: root.hasTray && root.trayOpen

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: entry

                required property var modelData

                width: 16
                height: parent.height

                // Symbole einfarbig in der Schriftfarbe: viele Tray-Symbole
                // (Steam …) sind weiß und verschwinden sonst auf hellem Grund.
                // Erst ganz hell (brightness), dann einfärben: jedes Symbol wird
                // genau Theme.fg, auch dunkle. Quickshell lädt Symbole nach Namen
                // nicht neu, wenn theme.sh Papirus-Light/-Dark wechselt – so ist
                // egal, welche Variante es noch hat.
                IconImage {
                    id: trayIcon
                    anchors.centerIn: parent
                    implicitSize: 16
                    source: entry.modelData.icon
                    visible: false
                }

                MultiEffect {
                    anchors.fill: trayIcon
                    source: trayIcon
                    brightness: 1
                    colorization: 1
                    colorizationColor: Theme.fg
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
                                if (trayMenu.visible && trayMenu.handle === item.menu)
                                    trayMenu.close();
                                else
                                    trayMenu.open(item.menu, entry.mapToItem(null, 0, 0).x);
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

    // Menü der Tray-Symbole im Stil der Leiste (TrayMenu.qml)
    TrayMenu {
        id: trayMenu

        anchor.window: root.bar
        anchor.rect.x: Math.max(4, Math.min(atX - 12, root.bar.width - implicitWidth - 4))
        anchor.rect.y: root.bar.height
        visible: false
    }

    // Klick außerhalb schließt das Menü. Erst kurz nach dem Öffnen
    // aktivieren: Beim Öffnen existiert die Fläche des Popups noch nicht,
    // die Sperre zählte Klicks ins Menü sonst als „außerhalb“.
    HyprlandFocusGrab {
        id: trayGrab
        windows: [trayMenu, root.bar]
        onCleared: trayMenu.close()
    }

    Timer {
        id: trayGrabLater
        interval: 50
        onTriggered: trayGrab.active = trayMenu.visible
    }

    Connections {
        target: trayMenu
        function onVisibleChanged() {
            if (trayMenu.visible)
                trayGrabLater.restart();
            else
                trayGrab.active = false;
        }
    }

    Item {
        width: 14
        height: parent.height
        visible: root.hasTray && root.trayOpen
    }

    // ── Lautstärke: Mausrad ändert, Klick stumm, Rechtsklick pavucontrol ─
    Icon {
        id: volume

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real level: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

        text: muted || level === 0 ? "󰖁" : level < 0.34 ? "󰕿" : level < 0.67 ? "󰖀" : "󰕾"
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
                const v = volume.level + (w.angleDelta.y > 0 ? 0.01 : -0.01);
                volume.sink.audio.volume = Math.max(0, Math.min(1, v));
            }
        }
    }

    // ── Netz (NetworkManager): WLAN, Kabel oder getrennt (rot) ─────────
    Icon {
        id: net

        property string kind: ""

        rightPadding: 0
        text: kind === "wifi" ? "󰖩" : kind === "ethernet" ? "󰈀" : "󰖪"
        color: kind ? Theme.fg : Theme.error

        Process {
            id: netPoll
            command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    const up = text.split("\n").filter(l => l.endsWith(":connected")).map(l => l.split(":")[0]);
                    net.kind = up.includes("ethernet") ? "ethernet" : up.includes("wifi") ? "wifi" : "";
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["nm-connection-editor"])
        }
    }

    // Netz alle 5 s
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netPoll.running = true
    }

    Sep {}

    // ── Uhr und Datum ──────────────────────────────────────────────────
    Label {
        height: parent.height
        rightPadding: 12
        text: Qt.formatTime(clock.date, "HH:mm") + "  " + Qt.locale("en_US").toString(clock.date, "MMM dd, yyyy")

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }
    }
}
