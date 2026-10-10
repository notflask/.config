pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Zustand des VPN (scripts/vpn.sh): on | pending | off | open. Einmal für
// alle Monitore abgefragt, alle 5 s und kurz nach einem Klick.
Singleton {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/vpn.sh"
    property string state: "off"
    // Schild mit Haken, Uhr oder Kreuz
    readonly property string glyph: state === "on" ? "\u{F099D}" : state === "pending" ? "\u{F0996}" : "\u{F099E}"

    function toggle() {
        Quickshell.execDetached([script, "toggle"]);
        again.restart();
    }

    Process {
        id: poll
        command: [root.script]
        running: true
        stdout: StdioCollector {
            id: out
            onStreamFinished: root.state = out.text.trim() || "off"
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: poll.running = true
    }

    // nach dem Klick: Polkit-Abfrage und Verbindungsaufbau abwarten
    Timer {
        id: again
        interval: 1500
        repeat: true
        property int left: 0
        onTriggered: {
            poll.running = true;
            if (++left >= 6) {
                left = 0;
                stop();
            }
        }
    }
}
