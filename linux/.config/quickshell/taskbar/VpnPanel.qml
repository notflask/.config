import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets

// VPN-Fenster über dem VPN-Knopf (wie die Mullvad-App): verbinden/trennen,
// Server und Datenrate, Sperre ohne VPN und Split-Tunneling – Apps, die
// immer am VPN vorbei starten, und Ziele (Domains/IPs) für alle Programme.
// Daten und Befehle: Vpn.qml, scripts/vpn.sh und `vpn-split`.
Popup {
    id: panel

    // "apps" oder "domains"
    property string tab: "apps"
    property string query: ""
    property string error: ""

    readonly property color tint: Vpn.state === "on" ? Theme.ok : Vpn.state === "pending" ? Theme.warn : Theme.error

    // Apps zum Hinzufügen: passend zur Suche, noch nicht in der Liste
    readonly property var matches: {
        const q = query.trim().toLowerCase();
        if (tab !== "apps" || !q)
            return [];
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && !Vpn.splitApps.includes(e.id) && (e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q))).sort((a, b) => a.name.toLowerCase().startsWith(q) === b.name.toLowerCase().startsWith(q) ? a.name.localeCompare(b.name) : a.name.toLowerCase().startsWith(q) ? -1 : 1).slice(0, 5);
    }

    function status() {
        switch (Vpn.state) {
        case "on":
            return "Verbunden";
        case "pending":
            return "Verbindet …";
        case "open":
            return "Getrennt · Internet ungeschützt";
        default:
            return Vpn.locked ? "Getrennt · Internet gesperrt" : "Getrennt";
        }
    }

    function bytes(n) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < units.length - 1) {
            n /= 1000;
            i++;
        }
        return (i === 0 ? Math.round(n) : n.toFixed(n < 10 ? 1 : 0)) + " " + units[i];
    }

    function ago(t) {
        if (!t)
            return "–";
        const s = Math.max(0, Math.round(Date.now() / 1000 - t));
        return s < 60 ? "vor " + s + " s" : "vor " + Math.floor(s / 60) + " min";
    }

    function add() {
        const text = query.trim();
        if (!text)
            return;
        if (tab === "apps") {
            if (matches.length === 0)
                return;
            Vpn.split("add", matches[0].id);
        } else {
            // dieselbe Prüfung wie vpn-bypass-edit
            const ok = /^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$/i.test(text) || /^\d{1,3}(\.\d{1,3}){3}(\/\d{1,2})?$/.test(text);
            if (!ok) {
                error = "Nur Domain (beispiel.de) oder IPv4 (1.2.3.4, 10.0.0.0/8)";
                return;
            }
            Vpn.split("domain-add", text.toLowerCase());
        }
        input.text = "";
    }

    keyboard: true
    radius: 22
    padding: 18

    onShownChanged: {
        Vpn.watching = shown;
        input.text = "";
        error = "";
        if (shown)
            input.forceActiveFocus();
    }

    Column {
        width: 340
        spacing: 14

        // ── Kopf: Logo, Profil, Zustand ───────────────────────────────
        Row {
            spacing: 12

            Rectangle {
                width: 44
                height: 44
                radius: 22
                border.width: 1
                border.color: Qt.alpha(panel.tint, 0.45)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(panel.tint, 0.28)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(panel.tint, 0.08)
                    }
                }

                Shape {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillColor: panel.tint
                        fillRule: ShapePath.OddEvenFill
                        PathSvg {
                            path: Vpn.logo
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    text: Vpn.name || "WireGuard"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Label {
                    text: panel.status()
                    font.pixelSize: 12
                    color: panel.tint
                }
            }
        }

        // ── Verbinden / Trennen ───────────────────────────────────────
        Rectangle {
            id: connect

            readonly property bool on: Vpn.state === "on" || Vpn.state === "pending"
            readonly property color accent: on ? Theme.error : Theme.ok

            width: parent.width
            height: 46
            radius: 23
            color: Qt.alpha(accent, connectMouse.containsMouse ? 0.34 : 0.22)
            border.width: 1
            border.color: Qt.alpha(accent, 0.6)

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            // Lichtkante auf dem geraden Stück
            Rectangle {
                x: connect.radius
                y: 1
                width: parent.width - 2 * connect.radius
                height: 1
                color: Theme.shine
            }

            Label {
                anchors.centerIn: parent
                text: connect.on ? "Trennen" : "Verbinden"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: connect.accent
            }

            MouseArea {
                id: connectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Vpn.toggle()
            }
        }

        // ── Details, nur mit Tunnel ───────────────────────────────────
        Grid {
            visible: Vpn.state === "on" || Vpn.state === "pending"
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            // fester Index als Modell: ein Array-Literal würde mit jeder
            // Datenrate neu gebaut und die Kacheln jede Sekunde ersetzen
            Repeater {
                model: 4

                delegate: Rectangle {
                    id: cell

                    required property int index
                    readonly property var info: [
                        {
                            label: "Server",
                            value: Vpn.endpoint.replace(/:\d+$/, "") || "–"
                        },
                        {
                            label: "Handshake",
                            value: panel.ago(Vpn.handshake)
                        },
                        {
                            label: "↓ Empfangen",
                            value: panel.bytes(Vpn.rxRate) + "/s · " + panel.bytes(Vpn.rx)
                        },
                        {
                            label: "↑ Gesendet",
                            value: panel.bytes(Vpn.txRate) + "/s · " + panel.bytes(Vpn.tx)
                        }
                    ][index]

                    width: (340 - 8) / 2
                    height: 48
                    radius: 14
                    color: Theme.pill
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.08)

                    Column {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Label {
                            text: cell.info.label
                            font.pixelSize: 11
                            color: Theme.textDim
                        }
                        Label {
                            text: cell.info.value
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }

        // ── Sperre ────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 38

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    text: "Ohne VPN kein Internet"
                    font.pixelSize: 13
                }
                Label {
                    text: "Sperrt alles außer LAN, solange der Tunnel fehlt"
                    font.pixelSize: 11
                    color: Theme.textDim
                }
            }

            GlassSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Vpn.locked
                accent: Theme.ok
                onToggled: Vpn.setLocked(!Vpn.locked)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.rim
            opacity: 0.6
        }

        // ── Split-Tunneling ───────────────────────────────────────────
        Item {
            width: parent.width
            height: 30

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Split-Tunneling"
                font.weight: Font.Bold
            }

            // Umschalter Apps / Ziele
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                height: 28
                radius: 14
                color: Theme.pill
                border.width: 1
                border.color: Qt.alpha(Theme.text, 0.08)

                Rectangle {
                    width: parent.width / 2 - 2
                    height: parent.height - 4
                    y: 2
                    x: panel.tab === "apps" ? 2 : parent.width / 2
                    radius: height / 2
                    color: Qt.alpha(Theme.primary, 0.24)
                    border.width: 1
                    border.color: Qt.alpha(Theme.primary, 0.5)

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: [
                            {
                                id: "apps",
                                label: "Apps"
                            },
                            {
                                id: "domains",
                                label: "Ziele"
                            }
                        ]

                        delegate: Item {
                            required property var modelData

                            width: 75
                            height: 28

                            Label {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 12
                                color: panel.tab === modelData.id || tabMouse.containsMouse ? Theme.text : Theme.textDim
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    panel.tab = modelData.id;
                                    input.text = "";
                                    panel.error = "";
                                    input.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            font.pixelSize: 11
            color: Theme.textDim
            text: panel.tab === "apps" ? "Diese Apps starten immer am VPN vorbei (Startmenü, Rofi, Autostart). Läuft eine schon, einmal neu starten." : "Verbindungen zu diesen Domains und IPs gehen bei allen Programmen am VPN vorbei."
        }

        // Liste
        Rectangle {
            readonly property var items: panel.tab === "apps" ? Vpn.splitApps : Vpn.splitDomains

            width: parent.width
            height: Math.min(Math.max(items.length, 1), 5) * 40 + 8
            radius: 16
            color: Theme.pill
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.08)
            clip: true

            Label {
                anchors.centerIn: parent
                visible: parent.items.length === 0
                text: panel.tab === "apps" ? "Noch keine Apps – unten suchen" : "Noch keine Ziele – unten eintragen"
                font.pixelSize: 12
                color: Theme.textDim
            }

            ListView {
                anchors.fill: parent
                anchors.margins: 4
                model: parent.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row

                    required property string modelData
                    readonly property var entry: panel.tab === "apps" ? DesktopEntries.byId(modelData) : null
                    // läuft gerade am VPN vorbei (vpn-split running nennt Programmnamen)
                    readonly property bool active: {
                        if (!entry || !entry.command || entry.command.length === 0)
                            return false;
                        const exe = entry.command[entry.command[0] === "novpn" ? 1 : 0] || "";
                        return Vpn.splitRunning.includes(exe.split("/").pop());
                    }

                    width: ListView.view.width
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: rowMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Row {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        IconImage {
                            visible: panel.tab === "apps"
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            source: Quickshell.iconPath(row.entry && row.entry.icon ? row.entry.icon : row.modelData, "application-x-executable")
                        }

                        Glyph {
                            visible: panel.tab === "domains"
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F059F}"
                            font.pixelSize: 18
                            color: Theme.textDim
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 240
                            elide: Text.ElideRight
                            text: row.entry ? row.entry.name : row.modelData
                            font.pixelSize: 13
                        }
                    }

                    // grüner Punkt: läuft gerade am VPN vorbei
                    Rectangle {
                        visible: row.active
                        anchors.right: remove.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.ok
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    // Entfernen
                    Rectangle {
                        id: remove
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: removeMouse.containsMouse ? Qt.alpha(Theme.error, 0.22) : "transparent"

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{F0156}"
                            font.pixelSize: 16
                            color: removeMouse.containsMouse ? Theme.error : Theme.textDim
                        }

                        MouseArea {
                            id: removeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Vpn.split(panel.tab === "apps" ? "remove" : "domain-remove", row.modelData)
                        }
                    }
                }
            }
        }

        // Eingabe: App suchen bzw. Ziel eintragen
        Rectangle {
            width: parent.width
            height: 40
            radius: 20
            color: Theme.pill
            border.width: 1
            border.color: input.activeFocus ? Qt.alpha(Theme.primary, 0.5) : Qt.alpha(Theme.text, 0.08)

            Glyph {
                id: plus
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: panel.tab === "apps" ? "\u{F0349}" : "\u{F0415}"
                font.pixelSize: 16
                color: Theme.textDim
            }

            Label {
                anchors.left: input.left
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: panel.tab === "apps" ? "App suchen …" : "Domain oder IP, Enter fügt hinzu"
                font.pixelSize: 13
                color: Theme.textDim
            }

            TextInput {
                id: input
                anchors.left: plus.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
                selectionColor: Qt.alpha(Theme.primary, 0.4)
                clip: true
                onTextChanged: {
                    panel.query = text;
                    panel.error = "";
                }

                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape)
                        panel.close();
                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                        panel.add();
                    else
                        return;
                    e.accepted = true;
                }
            }
        }

        Label {
            visible: panel.error !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: panel.error
            font.pixelSize: 11
            color: Theme.error
        }

        // Treffer der App-Suche
        Column {
            visible: panel.matches.length > 0
            width: parent.width
            spacing: 2

            Repeater {
                model: panel.matches

                delegate: Item {
                    id: hit

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: hitMouse.containsMouse || hit.index === 0 ? Theme.hover : "transparent"
                    }

                    Row {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 22
                            source: Quickshell.iconPath(hit.modelData.icon || hit.modelData.id, "application-x-executable")
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: hit.modelData.name
                            font.pixelSize: 13
                        }
                    }

                    Glyph {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{F0415}"
                        font.pixelSize: 16
                        color: Theme.textDim
                    }

                    MouseArea {
                        id: hitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Vpn.split("add", hit.modelData.id);
                            input.text = "";
                        }
                    }
                }
            }
        }
    }
}
