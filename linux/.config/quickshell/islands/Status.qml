import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets

// Rechte Insel bzw. unterer Teil des Rahmens:
//   Tray · Tastatur · VPN · Lautstärke · Akku · Ausschalten
// Logik wie ../minibar/Status.qml, nur mit Symbolen statt Text.
Grid {
    id: root

    // Fenster der Leiste (für die Popups) und Ausrichtung
    required property var bar
    property bool vertical: false

    flow: vertical ? Grid.TopToBottom : Grid.LeftToRight
    rows: vertical ? 99 : 1
    columns: vertical ? 1 : 99
    spacing: 2
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    // Popup neben dem Element: waagrecht darunter, im Rahmen rechts daneben
    function popX(item, w) {
        if (!item)
            return 0;
        const p = item.mapToItem(null, 0, 0);
        return vertical ? Theme.frameBar + 8 : Math.max(8, Math.min(p.x + item.width / 2 - w / 2, bar.width - w - 8));
    }
    function popY(item, h) {
        if (!item)
            return 0;
        const p = item.mapToItem(null, 0, 0);
        return vertical ? Math.max(Theme.frameEdge + 8, Math.min(p.y + item.height / 2 - h / 2, bar.height - h - Theme.frameEdge - 8)) : Theme.top + Theme.pill + 8;
    }

    component Dot: Rectangle {
        width: root.vertical ? 14 : 1
        height: root.vertical ? 1 : 14
        color: Theme.rim
    }

    // ── Tray (Discord, Telegram, Control Center …) ─────────────────────
    Grid {
        id: tray

        property var at: null

        visible: SystemTray.items.values.length > 0
        flow: root.flow
        rows: root.rows
        columns: root.columns
        spacing: 0

        Repeater {
            model: SystemTray.items

            delegate: Chip {
                id: entry

                required property var modelData

                vertical: root.vertical

                // Symbole einfarbig wie die Schrift: viele Tray-Symbole sind
                // weiß und verschwänden auf hellem Grund (wie in der minibar)
                Item {
                    width: 16
                    height: 16

                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        source: entry.modelData.icon
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: trayIcon
                        source: trayIcon
                        brightness: 1
                        colorization: 1
                        colorizationColor: entry.hovered ? Theme.fg : Theme.dim
                    }
                }

                onClicked: m => {
                    const item = entry.modelData;
                    if (m.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (m.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) {
                            if (trayMenu.visible && trayMenu.handle === item.menu) {
                                trayMenu.close();
                            } else {
                                tray.at = entry;
                                trayMenu.open(item.menu, 0);
                            }
                        }
                    } else {
                        item.activate();
                    }
                }
                onWheel: w => entry.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }

    TrayMenu {
        id: trayMenu

        anchor.window: root.bar
        anchor.rect.x: root.popX(tray.at, implicitWidth)
        anchor.rect.y: root.popY(tray.at, implicitHeight)
        visible: false
    }

    // Klick außerhalb schließt das Menü (erst kurz nach dem Öffnen
    // aktivieren, sonst zählen Klicks ins neue Menü als „außerhalb“)
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

    Dot {
        visible: tray.visible
    }

    // ── Tastaturlayout (Alt+Shift wechselt) ───────────────────────────
    Chip {
        vertical: root.vertical

        Label {
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: Theme.dim
            text: {
                const name = Wm.layout;
                const known = {
                    "English (US)": "US",
                    "English": "US",
                    "German": "DE",
                    "Russian": "RU",
                    "Ukrainian": "UA"
                };
                for (const k in known)
                    if (name.startsWith(k))
                        return known[k];
                return name.slice(0, 2).toUpperCase();
            }
        }
        onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
    }

    // ── VPN (../taskbar/scripts/vpn.sh): WireGuard-Drache, grün verbunden,
    //    orange verbindet, rot getrennt. Klick: Fenster, Rechtsklick: an/aus
    Chip {
        id: vpn

        property string state: "off"
        property var details: ({})
        readonly property string script: Quickshell.shellDir + "/../taskbar/scripts/vpn.sh"

        function parse(text) {
            const rows = text.trim().split("\n");
            state = (rows[0] || "off").trim();
            const kv = {};
            for (const row of rows.slice(1)) {
                const i = row.indexOf("=");
                if (i > 0)
                    kv[row.slice(0, i)] = row.slice(i + 1);
            }
            details = kv;
        }

        function run(action) {
            Quickshell.execDetached([script, action]);
            vpnAgain.restart();
        }

        vertical: root.vertical

        // WireGuard-Logo (Simple Icons, CC0, 24×24)
        Item {
            width: 16
            height: 16

            Shape {
                anchors.centerIn: parent
                width: 24
                height: 24
                scale: 16 / 24
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillColor: Theme.vpnColor(vpn.state)
                    fillRule: ShapePath.OddEvenFill
                    PathSvg {
                        path: "M8.155 7.576c2.4-1.47 5.469-.571 6.618 1.638.218.419.246 1.063.108 1.503-.477 1.516-1.601 2.366-3.145 2.728.455-.39.817-.832.933-1.442a2.112 2.112 0 0 0-.364-1.677 2.14 2.14 0 0 0-2.465-.75c-.95.36-1.47 1.228-1.377 2.294.087.99.839 1.632 2.245 1.876-.21.111-.372.193-.53.281a5.113 5.113 0 0 0-1.644 1.43c-.143.192-.24.208-.458.075-2.827-1.729-3.009-6.067.078-7.956zM6.04 18.258c-.455.116-.895.286-1.359.438.227-1.532 2.021-2.943 3.539-2.782a3.91 3.91 0 0 0-.74 2.072c-.504.093-.98.155-1.44.272zM15.703 3.3c.448.017.898.01 1.347.02a2.324 2.324 0 0 1 .334.047 3.249 3.249 0 0 1-.34.434c-.16.15-.341.296-.573.069-.055-.055-.187-.042-.283-.044-.447-.005-.894-.02-1.34-.003a8.323 8.323 0 0 0-1.154.118c-.072.013-.178.25-.146.338.078.207.191.435.359.567.619.49 1.277.928 1.9 1.413.604.472 1.167.99 1.51 1.7.446.928.46 1.9.267 2.877-.322 1.63-1.147 2.98-2.483 3.962-.538.395-1.205.62-1.821.903-.543.25-1.1.465-1.644.712-.98.446-1.53 1.51-1.369 2.615.149 1.015 1.04 1.862 2.059 2.037 1.223.21 2.486-.586 2.785-1.83.336-1.397-.423-2.646-1.845-3.024l-.256-.066c.38-.17.708-.291 1.012-.458q.793-.437 1.558-.925c.15-.096.231-.096.36.014.977.846 1.56 1.898 1.724 3.187.27 2.135-.74 4.096-2.646 5.101-2.948 1.555-6.557-.215-7.208-3.484-.558-2.8 1.418-5.34 3.797-5.83 1.023-.211 1.958-.637 2.685-1.425.47-.508.697-.944.775-1.141a3.165 3.165 0 0 0 .217-1.158 2.71 2.71 0 0 0-.237-.992c-.248-.566-1.2-1.466-1.435-1.656l-2.24-1.754c-.079-.065-.168-.06-.36-.047-.23.016-.815.048-1.067-.018.204-.155.76-.38 1-.56-.726-.49-1.554-.314-2.315-.46.176-.328 1.046-.831 1.541-.888a7.323 7.323 0 0 0-.135-.822c-.03-.111-.154-.22-.263-.283-.262-.154-.541-.281-.843-.434a1.755 1.755 0 0 1 .906-.28 3.385 3.385 0 0 1 .908.088c.54.123.97.042 1.399-.324-.338-.136-.676-.26-1.003-.407a9.843 9.843 0 0 1-.942-.493c.85.118 1.671.437 2.54.32l.022-.118-2.018-.47c1.203-.11 2.323-.128 3.384.388.299.146.61.266.897.432.14.08.233.24.348.365.09.098.164.23.276.29.424.225.89.234 1.366.223l.01-.16c.479.15 1.017.702 1.017 1.105-.776 0-1.55-.003-2.325.004-.083 0-.165.061-.247.094.078.046.155.128.235.131zM14.703 2.153a.118.118 0 0 0-.016.19.179.179 0 0 0 .246.065c.075-.038.148-.078.238-.125-.072-.062-.13-.114-.19-.163-.106-.087-.193-.032-.278.033z"
                    }
                }
            }
        }

        onClicked: m => {
            if (m.button === Qt.RightButton) {
                vpn.run("toggle");
            } else {
                vpnPanel.visible = !vpnPanel.visible;
                if (vpnPanel.visible)
                    vpnPoll.running = true;
            }
        }

        Process {
            id: vpnPoll
            command: [vpn.script]
            running: true
            stdout: StdioCollector {
                onStreamFinished: vpn.parse(text)
            }
        }

        // Fenster offen: jede Sekunde (Handshake, Verkehr), sonst alle 5 s
        Timer {
            interval: vpnPanel.visible ? 1000 : 5000
            running: true
            repeat: true
            onTriggered: vpnPoll.running = true
        }

        Timer {
            id: vpnAgain
            interval: 1500
            onTriggered: vpnPoll.running = true
        }
    }

    VpnPanel {
        id: vpnPanel

        vpn: vpn
        anchor.window: root.bar
        anchor.rect.x: root.popX(vpn, implicitWidth)
        anchor.rect.y: root.popY(vpn, implicitHeight)
        visible: false
    }

    HyprlandFocusGrab {
        id: vpnGrab
        windows: [vpnPanel, root.bar]
        onCleared: vpnPanel.visible = false
    }

    Timer {
        id: vpnGrabLater
        interval: 50
        onTriggered: vpnGrab.active = vpnPanel.visible
    }

    Connections {
        target: vpnPanel
        function onVisibleChanged() {
            if (vpnPanel.visible)
                vpnGrabLater.restart();
            else
                vpnGrab.active = false;
        }
    }

    // ── Lautstärke: Mausrad ändert, Klick stumm, Rechtsklick pavucontrol ─
    Chip {
        id: volume

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real level: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

        vertical: root.vertical

        PwObjectTracker {
            objects: [volume.sink]
        }

        Grid {
            flow: root.flow
            rows: root.rows
            columns: root.columns
            spacing: root.vertical ? 1 : 6
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Glyph {
                color: volume.muted ? Theme.faint : Theme.fg
                code: volume.muted ? 0xF0581 : volume.level < 0.34 ? 0xF057F : volume.level < 0.67 ? 0xF0580 : 0xF057E
            }
            Label {
                font.pixelSize: root.vertical ? 10 : Theme.size
                font.features: { "tnum": 1 }
                color: volume.muted ? Theme.faint : Theme.dim
                text: Math.round(volume.level * 100) + (root.vertical ? "" : "%")
            }
        }

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

    // ── Akku (nur mit Akku) ────────────────────────────────────────────
    Chip {
        id: battery

        readonly property var dev: UPower.displayDevice
        readonly property real percent: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
        readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
        readonly property color tone: percent <= 15 && !charging ? Theme.error : percent <= 30 && !charging ? Theme.warn : Theme.fg

        vertical: root.vertical
        visible: dev && dev.isPresent && dev.isLaptopBattery

        Grid {
            flow: root.flow
            rows: root.rows
            columns: root.columns
            spacing: root.vertical ? 1 : 6
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // 0xF007A … 0xF0082 = 10 … 90 %, 0xF0079 voll, 0xF0084 lädt
            Glyph {
                color: battery.tone
                code: battery.charging ? 0xF0084 : battery.percent >= 95 ? 0xF0079 : 0xF007A + Math.max(0, Math.min(8, Math.round(battery.percent / 10) - 1))
            }
            Label {
                font.pixelSize: root.vertical ? 10 : Theme.size
                font.features: { "tnum": 1 }
                color: battery.tone === Theme.fg ? Theme.dim : battery.tone
                text: Math.round(battery.percent) + (root.vertical ? "" : "%")
            }
        }
    }

    Dot {}

    // ── Ausschalten (power-menu) ───────────────────────────────────────
    Chip {
        id: power

        vertical: root.vertical

        Glyph {
            code: 0xF0425
            color: power.hovered ? Theme.error : Theme.dim
        }
        onClicked: Quickshell.execDetached(["power-menu"])
    }
}
