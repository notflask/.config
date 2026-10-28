import QtQuick
import Quickshell

// Pomodoro-Fenster unter dem Zähler in der Leiste, im Stil von
// VpnPanel.qml: deckend, eckig, 1px Rahmen, nur Text. Oben Phase und
// heute geschaffte Runden, groß die Restzeit, Fortschritt, Punkte bis zur
// langen Pause und drei Knöpfe; die Einstellungen (Pomodoro.qml,
// ~/.config/g5/pomodoro.json) sind eingeklappt.
PopupWindow {
    id: panel

    readonly property var cfg: Pomodoro.settings
    readonly property color tint: Pomodoro.phase === "idle" || !Pomodoro.running ? Theme.dim : Pomodoro.isBreak ? Theme.ok : Theme.accent
    property bool more: false

    color: "transparent"
    implicitWidth: 260
    implicitHeight: box.implicitHeight

    onVisibleChanged: {
        if (!visible)
            more = false;
    }

    // Knopf als schlichtes Wort, beim Überfahren rosa
    component Action: Label {
        id: action

        property string label
        signal activated

        leftPadding: 6
        rightPadding: 6
        height: Theme.size + 10
        color: area.containsMouse ? Theme.accent : Theme.dim
        text: action.label

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
        height: Theme.size + 6

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.dim
            text: stepper.key
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Label {
                text: "‹"
                width: 16
                horizontalAlignment: Text.AlignHCenter
                color: down.containsMouse ? Theme.accent : Theme.faint

                MouseArea {
                    id: down
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: stepper.bump(-1)
                }
            }
            Label {
                width: 56
                horizontalAlignment: Text.AlignHCenter
                text: stepper.value + stepper.unit
            }
            Label {
                text: "›"
                width: 16
                horizontalAlignment: Text.AlignHCenter
                color: up.containsMouse ? Theme.accent : Theme.faint

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

    // Schalter: Punkt rosa an, grau aus
    component Check: Item {
        id: check

        property string label
        property bool checked
        signal toggled

        width: parent.width
        height: Theme.size + 6

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: area.containsMouse ? Theme.fg : Theme.dim
            text: check.label
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 40
            anchors.verticalCenter: parent.verticalCenter
            color: check.checked ? Theme.accent : Theme.faint
            text: check.checked ? "●" : "○"
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
        implicitHeight: content.implicitHeight + 32
        color: Theme.bg
        border.width: 1
        border.color: Theme.faint

        Column {
            id: content

            anchors.fill: parent
            anchors.margins: 16
            spacing: 0

            // ── Phase, heute ───────────────────────────────────────────
            Item {
                width: parent.width
                height: Theme.size + 4

                Label {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: panel.tint
                    text: ({
                            idle: "bereit",
                            focus: "fokus",
                            short: "pause",
                            long: "lange pause"
                        })[Pomodoro.phase] + (Pomodoro.fresh || Pomodoro.running ? "" : " · angehalten")
                }
                Label {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Pomodoro.doneToday >= panel.cfg.goal ? Theme.ok : Theme.faint
                    text: Pomodoro.doneToday + "/" + panel.cfg.goal + " heute"
                }
            }

            // ── Restzeit groß ──────────────────────────────────────────
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                bottomPadding: 12
                font.pixelSize: Theme.size * 3
                font.weight: Font.Light
                color: Pomodoro.running ? Theme.fg : Theme.dim
                text: Pomodoro.clock(Pomodoro.left)
            }

            // Fortschritt der Phase: dünne Linie
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.faint

                Rectangle {
                    width: parent.width * Pomodoro.progress
                    height: 1
                    color: panel.tint
                }
            }

            // Runden bis zur langen Pause
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                font.letterSpacing: 4
                color: Theme.dim
                text: {
                    const n = panel.cfg.longEvery;
                    const done = Pomodoro.round % n;
                    let dots = "";
                    for (let i = 0; i < n; i++)
                        dots += i < done ? "●" : "○";
                    return dots;
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                spacing: 8

                Action {
                    label: Pomodoro.fresh ? "start" : Pomodoro.running ? "pause" : "weiter"
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

            // ── Einstellungen, eingeklappt ─────────────────────────────
            Item {
                width: parent.width
                height: Theme.size + 14

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    font.pixelSize: Theme.size - 3
                    color: moreArea.containsMouse ? Theme.fg : Theme.faint
                    text: panel.more ? "weniger" : "einstellungen"

                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.more = !panel.more
                    }
                }
            }

            Column {
                width: parent.width
                visible: panel.more
                topPadding: 10

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
                    key: "lange alle"
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
                    height: 8
                }

                Check {
                    label: "pause von selbst"
                    checked: panel.cfg.autoBreak
                    onToggled: panel.cfg.autoBreak = !checked
                }
                Check {
                    label: "fokus von selbst"
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
                    label: "nicht stören"
                    checked: panel.cfg.dnd
                    onToggled: panel.cfg.dnd = !checked
                }

                Label {
                    width: parent.width
                    topPadding: 8
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.size - 3
                    color: Theme.faint
                    text: "töne und befehle: ~/.config/g5/pomodoro.json"
                }
            }
        }
    }
}
