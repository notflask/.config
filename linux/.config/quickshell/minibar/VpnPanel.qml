import QtQuick
import Quickshell

// VPN-Fenster unter „vpn“ in der Leiste, im Stil der Leiste: deckend,
// eckig, 1px Rahmen, nur Text. Zeigt Profil, Server, Handshake, Verkehr
// und schaltet Verbindung und Sperre (../taskbar/scripts/vpn.sh).
PopupWindow {
    id: panel

    // Status.qml: vpn-Label (state, details, run(…))
    required property var vpn

    color: "transparent"
    implicitWidth: 300
    implicitHeight: box.implicitHeight

    function ago(t) {
        if (!t)
            return "–";
        const s = Math.max(0, Math.round(Date.now() / 1000 - t));
        return s < 60 ? s + " s" : Math.floor(s / 60) + " min";
    }

    function bytes(n) {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1024 && i < u.length - 1) {
            n /= 1024;
            i++;
        }
        return (i ? n.toFixed(1) : n) + " " + u[i];
    }

    component Row2: Item {
        property string key
        property string value
        property color valueColor: Theme.fg

        width: parent.width
        height: Theme.size + 8

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.faint
            text: parent.key
        }
        Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 100
            horizontalAlignment: Text.AlignRight
            color: parent.valueColor
            text: parent.value
        }
    }

    // Knopf als Text in eckigen Klammern, wie in einer TUI
    component Action: Label {
        id: action

        signal activated

        height: Theme.size + 10
        color: area.containsMouse ? Theme.onAccent : Theme.fg
        text: "[ " + label + " ]"
        property string label

        Rectangle {
            anchors.fill: parent
            z: -1
            color: area.containsMouse ? Theme.accent : "transparent"
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }
    }

    Rectangle {
        id: box

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 24
        color: Theme.bg
        border.width: 1
        border.color: Theme.vpnColor(panel.vpn.state)

        Column {
            id: content

            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            Label {
                width: parent.width
                height: Theme.size + 10
                font.bold: true
                color: Theme.vpnColor(panel.vpn.state)
                text: {
                    const n = panel.vpn.details.name || "wireguard";
                    const s = {
                        on: "verbunden",
                        pending: "verbindet …",
                        open: "getrennt, ohne sperre",
                        off: "getrennt"
                    }[panel.vpn.state] || panel.vpn.state;
                    return n + " · " + s;
                }
            }

            // Noch keine Config: wie man sie holt
            Label {
                visible: panel.vpn.details.setup === "no"
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.warn
                text: "keine config – im terminal:\nvpn import datei.conf [name]"
            }

            Column {
                visible: panel.vpn.details.setup !== "no"
                width: parent.width

                Row2 {
                    key: "server"
                    value: panel.vpn.details.endpoint || "–"
                }
                Row2 {
                    key: "handshake"
                    value: panel.ago(Number(panel.vpn.details.handshake))
                }
                Row2 {
                    key: "empfangen"
                    value: panel.bytes(Number(panel.vpn.details.rx) || 0)
                }
                Row2 {
                    key: "gesendet"
                    value: panel.bytes(Number(panel.vpn.details.tx) || 0)
                }
                Row2 {
                    key: "sperre"
                    value: panel.vpn.details.lock === "on" ? "an – ohne vpn kein internet" : "aus"
                    valueColor: panel.vpn.details.lock === "on" ? Theme.ok : Theme.error
                }
            }

            Item {
                width: 1
                height: 6
            }

            Row {
                visible: panel.vpn.details.setup !== "no"
                spacing: 8

                Action {
                    label: panel.vpn.state === "on" || panel.vpn.state === "pending" ? "trennen" : "verbinden"
                    onActivated: panel.vpn.run("toggle")
                }
                Action {
                    label: panel.vpn.details.lock === "on" ? "sperre aus" : "sperre an"
                    onActivated: panel.vpn.run(panel.vpn.details.lock === "on" ? "unlock" : "lock")
                }
            }
        }
    }
}
