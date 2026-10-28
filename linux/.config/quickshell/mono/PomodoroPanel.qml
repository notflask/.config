import QtQuick
import Quickshell

// Pomodoro-Fenster unter dem Zähler in der Leiste, im Stil von
// ../minibar/VpnPanel.qml: deckend, eckig, 1px Rahmen, nur Text. Oben
// Phase, Restzeit, Fortschritt und die Runden von heute, darunter die
// Einstellungen (Pomodoro.qml, ~/.config/g5/pomodoro.json).
PopupWindow {
    id: panel

    readonly property var cfg: Pomodoro.settings
    readonly property color tint: Pomodoro.phase === "idle" ? Theme.dim : Pomodoro.isBreak ? Theme.ok : Theme.accent

    color: "transparent"
    implicitWidth: 300
    implicitHeight: box.implicitHeight

    // Knopf als Text in eckigen Klammern (wie VpnPanel)
    component Action: Rectangle {
        id: action

        property string label
        signal activated

        implicitWidth: caption.implicitWidth + 16
        implicitHeight: Theme.size + 10
        color: area.containsMouse ? Theme.accent : "transparent"

        Label {
            id: caption
            anchors.centerIn: parent
            color: area.containsMouse ? Theme.accentFg : Theme.fg
            text: "[ " + action.label + " ]"
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }
    }

    // Zahl mit ‹ › daneben; Klick auf die Pfeile oder Mausrad ändert sie
    component Stepper: Item {
        id: stepper

        property string key
        property string key2: ""
        property string unit: ""
        property int value
        property int min: 1
        property int max: 180
        property int step: 1
        signal picked(int v)

        function bump(n) {
            stepper.picked(Math.max(min, Math.min(max, value + n * step)));
        }

        width: parent.width
        height: Theme.size + 8

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.faint
            text: stepper.key
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Label {
                text: "‹"
                width: 18
                horizontalAlignment: Text.AlignHCenter
                color: down.containsMouse ? Theme.accent : Theme.dim

                MouseArea {
                    id: down
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: stepper.bump(-1)
                }
            }
            Label {
                width: 64
                horizontalAlignment: Text.AlignHCenter
                text: stepper.value + stepper.unit
            }
            Label {
                text: "›"
                width: 18
                horizontalAlignment: Text.AlignHCenter
                color: up.containsMouse ? Theme.accent : Theme.dim

                MouseArea {
                    id: up
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: stepper.bump(1)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: w => stepper.bump(w.angleDelta.y > 0 ? 1 : -1)
        }
    }

    // Häkchen wie im Tray-Menü: [x] / [ ]
    component Check: Rectangle {
        id: check

        property string label
        property bool checked
        signal toggled

        width: parent.width
        height: Theme.size + 8
        color: area.containsMouse ? Theme.faint : "transparent"

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: check.checked ? Theme.fg : Theme.dim
            text: (check.checked ? "[x] " : "[ ] ") + check.label
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: check.toggled()
        }
    }

    Rectangle {
        id: box

        anchors.fill: parent
        implicitHeight: content.implicitHeight + 24
        color: Theme.bg
        border.width: 1
        border.color: panel.tint

        Column {
            id: content

            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            // ── Phase und Zeit ─────────────────────────────────────────
            Item {
                width: parent.width
                height: big.implicitHeight

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    font.bold: true
                    color: panel.tint
                    text: ({
                            idle: "bereit",
                            focus: "fokus",
                            short: "pause",
                            long: "lange pause"
                        })[Pomodoro.phase] + (Pomodoro.phase !== "idle" && !Pomodoro.running ? " · angehalten" : "")
                }

                Label {
                    id: big
                    anchors.right: parent.right
                    font.pixelSize: Theme.size * 2
                    color: Pomodoro.running ? Theme.fg : Theme.dim
                    text: Pomodoro.clock(Pomodoro.left)
                }
            }

            // Fortschritt der Phase: dünne Linie
            Rectangle {
                width: parent.width
                height: 2
                color: Theme.faint

                Rectangle {
                    width: parent.width * Pomodoro.progress
                    height: parent.height
                    color: panel.tint
                }
            }

            Item {
                width: 1
                height: 6
            }

            // Runden: bis zur langen Pause und heute (Punkte bis zum Ziel)
            Item {
                width: parent.width
                height: Theme.size + 8

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.faint
                    text: "heute"
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const done = Pomodoro.doneToday;
                        const goal = panel.cfg.goal;
                        let dots = "";
                        for (let i = 0; i < Math.max(goal, done); i++)
                            dots += i < done ? "●" : "○";
                        return dots + "  " + done + "/" + goal;
                    }
                    color: Pomodoro.doneToday >= panel.cfg.goal ? Theme.ok : Theme.fg
                }
            }

            Item {
                width: parent.width
                height: Theme.size + 8

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.faint
                    text: "bis lange pause"
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: (panel.cfg.longEvery - Pomodoro.round % panel.cfg.longEvery) + " runden"
                }
            }

            Item {
                width: 1
                height: 6
            }

            Row {
                spacing: 8

                Action {
                    label: Pomodoro.phase === "idle" ? "start" : Pomodoro.running ? "pause" : "weiter"
                    onActivated: Pomodoro.toggle()
                }
                Action {
                    visible: Pomodoro.phase !== "idle"
                    label: "skip"
                    onActivated: Pomodoro.skip()
                }
                Action {
                    visible: Pomodoro.phase !== "idle"
                    label: "reset"
                    onActivated: Pomodoro.reset()
                }
            }

            // ── Einstellungen ──────────────────────────────────────────
            Item {
                width: 1
                height: 10
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.faint
            }

            Item {
                width: 1
                height: 6
            }

            Stepper {
                key: "fokus"
                unit: " min"
                value: panel.cfg.focus
                step: 5
                onPicked: v => panel.cfg.focus = v
            }
            Stepper {
                key: "pause"
                unit: " min"
                value: panel.cfg.shortBreak
                max: 60
                onPicked: v => panel.cfg.shortBreak = v
            }
            Stepper {
                key: "lange pause"
                unit: " min"
                value: panel.cfg.longBreak
                max: 90
                step: 5
                onPicked: v => panel.cfg.longBreak = v
            }
            Stepper {
                key: "lange pause alle"
                value: panel.cfg.longEvery
                max: 12
                onPicked: v => panel.cfg.longEvery = v
            }
            Stepper {
                key: "tagesziel"
                value: panel.cfg.goal
                max: 24
                onPicked: v => panel.cfg.goal = v
            }

            Item {
                width: 1
                height: 4
            }

            Check {
                label: "pause von selbst starten"
                checked: panel.cfg.autoBreak
                onToggled: panel.cfg.autoBreak = !checked
            }
            Check {
                label: "fokus von selbst starten"
                checked: panel.cfg.autoFocus
                onToggled: panel.cfg.autoFocus = !checked
            }
            Check {
                label: "nachricht"
                checked: panel.cfg.notify
                onToggled: panel.cfg.notify = !checked
            }
            Check {
                label: "ton"
                checked: panel.cfg.sound
                onToggled: panel.cfg.sound = !checked
            }
            Check {
                label: "nicht stören im fokus"
                checked: panel.cfg.dnd
                onToggled: panel.cfg.dnd = !checked
            }
            Check {
                label: "in der leiste, wenn aus"
                checked: panel.cfg.showIdle
                onToggled: panel.cfg.showIdle = !checked
            }

            Item {
                width: 1
                height: 6
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: Theme.size - 3
                color: Theme.faint
                text: "töne und befehle: ~/.config/g5/pomodoro.json"
            }
        }
    }
}
