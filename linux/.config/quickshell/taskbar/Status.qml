import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower

// Rechte Seite: Sprache, Energieprofil, hell/dunkel, Netzwerk,
// Lautstärke, Akku, Uhr, VPN, Ein/Aus
Row {
    id: root

    required property var bar
    readonly property string home: Quickshell.env("HOME")

    spacing: 2

    Tray {
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
    }

    // ── Sprache: nur das Kürzel ───────────────────────────────────────
    Tile {
        id: language

        property string layout: ""

        function code(name) {
            const known = {
                "English (US)": "US",
                "English": "US",
                "German": "DE",
                "Russian": "RU",
                "Ukrainian": "UA"
            };
            if (known[name])
                return known[name];
            for (const k in known)
                if (name.startsWith(k))
                    return known[k];
            return name.slice(0, 2).toUpperCase();
        }

        anchors.verticalCenter: parent.verticalCenter
        visible: langLabel.text !== ""

        Label {
            id: langLabel
            text: Compositor.niri ? language.code(Compositor.niriLayouts[Compositor.niriLayout] || "") : language.code(language.layout)
            font.weight: Font.Bold
        }

        // Hyprland: Layout der Haupttastatur, beim Start und bei jedem Wechsel
        Process {
            id: keymap
            running: Compositor.hyprland
            command: ["hyprctl", "-j", "devices"]
            stdout: StdioCollector {
                id: devices
                onStreamFinished: {
                    try {
                        const kb = JSON.parse(devices.text).keyboards;
                        const main = kb.find(k => k.main) || kb[0];
                        if (main)
                            language.layout = main.active_keymap;
                    } catch (err) {
                        console.warn("hyprctl devices:", err);
                    }
                }
            }
        }

        Connections {
            target: Compositor.hyprland ? Hyprland : null
            function onRawEvent(event) {
                // Ereignisse kommen von jedem Eingabegerät (auch Mäusen mit
                // Tastatur-Teil, mit eigenem Layout): Haupttastatur neu lesen
                if (event.name === "activelayout")
                    keymap.running = true;
            }
        }
    }

    // ── Energieprofil: Klick schaltet weiter ──────────────────────────
    Tile {
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            const next = {
                [PowerProfile.PowerSaver]: PowerProfile.Balanced,
                [PowerProfile.Balanced]: PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver,
                [PowerProfile.Performance]: PowerProfile.PowerSaver
            };
            PowerProfiles.profile = next[PowerProfiles.profile];
        }

        Glyph {
            text: PowerProfiles.profile === PowerProfile.Performance ? "\u{F04C5}" : PowerProfiles.profile === PowerProfile.PowerSaver ? "\u{F0F86}" : "\u{F0F85}"
        }
    }

    // ── hell/dunkel (scripts/theme.sh) ────────────────────────────────
    Tile {
        id: theme

        anchors.verticalCenter: parent.verticalCenter
        onClicked: Quickshell.execDetached([Quickshell.shellDir + "/scripts/theme.sh"])

        Glyph {
            text: mode.text().trim() === "light" ? "\u{F05A8}" : "\u{F0594}"
        }

        FileView {
            id: mode
            path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/theme-mode"
            watchChanges: true
            onFileChanged: reload()
        }
    }

    // ── Netzwerk ──────────────────────────────────────────────────────
    Tile {
        anchors.verticalCenter: parent.verticalCenter

        Glyph {
            text: {
                const devices = Networking.devices.values;
                const wired = devices.find(d => d.type === DeviceType.Wired && d.connected);
                if (wired)
                    return "\u{F0200}";
                const wifi = devices.find(d => d.type === DeviceType.Wifi && d.connected);
                if (wifi) {
                    const net = wifi.networks.values.find(n => n.connected);
                    const s = net ? net.signalStrength : 1;
                    return ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][Math.min(4, Math.floor(s * 5))];
                }
                return "\u{F092E}";
            }
        }
    }

    Volume {
        anchors.verticalCenter: parent.verticalCenter
        bar: root.bar
    }

    // ── Akku ──────────────────────────────────────────────────────────
    Tile {
        id: battery

        readonly property var dev: UPower.displayDevice
        readonly property real percent: dev ? (dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage) : 0
        readonly property bool charging: dev && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)

        anchors.verticalCenter: parent.verticalCenter
        visible: dev && dev.isPresent && dev.isLaptopBattery

        Glyph {
            text: battery.charging ? "\u{F0084}" : ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"][Math.min(9, Math.floor(battery.percent / 10))]
            color: battery.percent <= 15 && !battery.charging ? Theme.error : battery.percent <= 30 && !battery.charging ? Theme.warn : Theme.text
        }

        Label {
            text: Math.round(battery.percent) + "%"
        }
    }

    // ── Uhr: Zeit über Datum, Klick: Wochentag ────────────────────────
    Tile {
        id: clock

        property bool alt: false

        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: 33
        onClicked: alt = !alt

        Label {
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 12
            lineHeight: 0.95
            text: clock.alt ? Qt.locale("de_DE").toString(time.date, "dddd\nd. MMMM") : Qt.formatDateTime(time.date, "HH:mm\ndd.MM.yyyy")
        }

        SystemClock {
            id: time
            precision: SystemClock.Minutes
        }
    }

    // ── VPN: runder Knopf (Vpn.qml, scripts/vpn.sh) ──────────────────
    Item {
        id: vpn

        readonly property color tint: Vpn.state === "on" ? Theme.ok : Vpn.state === "pending" ? Theme.warn : Theme.error

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 26 + 12
        implicitHeight: 26

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: 13
            color: Vpn.state === "open" ? Theme.error : Qt.alpha(vpn.tint, 0.15)

            Glyph {
                anchors.centerIn: parent
                text: Vpn.glyph
                font.pixelSize: 15
                color: Vpn.state === "open" ? Theme.onError : vpn.tint
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Vpn.toggle()
        }
    }

    // ── Ein/Aus: wlogout ──────────────────────────────────────────────
    Tile {
        anchors.verticalCenter: parent.verticalCenter
        onClicked: Quickshell.execDetached([root.home + "/.config/wlogout/launch.sh"])

        Glyph {
            text: "\u{F0425}"
            color: Theme.error
        }
    }

    Item {
        width: 6
        height: 1
    }
}
