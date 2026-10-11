import QtQuick
import Quickshell
import Quickshell.Wayland

// Ausschalt-Menü (ersetzt wlogout): Reihe runder Glas-Knöpfe mitten auf dem
// fokussierten Monitor, dahinter der Bildschirm abgedunkelt und
// weichgezeichnet (layer-rule "power-menu" in niri/config.kdl bzw.
// hypr/hyprland.lua). Befehle und Öffnen: Power.qml.
// Tasten: L/E/S/R/P direkt, Pfeile/Tab wählen, Enter führt aus, Esc oder
// Klick daneben schließt.
PanelWindow {
    id: menu

    property int index: 0
    readonly property var actions: Power.actions

    function focusedScreen() {
        const name = Compositor.focusedOutput();
        return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
    }

    function move(dir) {
        index = (index + dir + actions.length) % actions.length;
    }

    Connections {
        target: Power
        function onShownChanged() {
            if (!Power.shown)
                return;
            // beim Öffnen festlegen, damit das Menü nicht mitwandert
            menu.screen = menu.focusedScreen();
            menu.index = 0;
            keys.forceActiveFocus();
        }
    }

    // bleibt sichtbar, bis das Ausblenden fertig ist
    visible: Power.shown || fade.running
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "power-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Power.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        opacity: Power.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Keys.onPressed: e => {
            const hit = menu.actions.find(a => a.key === e.key);
            if (hit)
                Power.run(hit);
            else if (e.key === Qt.Key_Escape)
                Power.shown = false;
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab)
                menu.move(-1);
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab)
                menu.move(1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                Power.run(menu.actions[menu.index]);
            else
                return;
            e.accepted = true;
        }

        // Schleier; Klick daneben schließt
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Theme.surface, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: Power.shown = false
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 28
            scale: Power.shown ? 1 : 0.94

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Power.shown ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.1
                }
            }

            Repeater {
                model: menu.actions

                delegate: Item {
                    id: button

                    required property var modelData
                    required property int index
                    readonly property bool selected: index === menu.index
                    readonly property color accent: modelData.id === "shutdown" ? Theme.error : Theme.primary

                    width: 150
                    height: 150

                    // ohne Lichtkante: bei so runden Knöpfen bleibt vom
                    // geraden Stück oben nur ein kurzer, dicker wirkender Strich
                    Rectangle {
                        anchors.fill: parent
                        radius: 56
                        color: button.selected ? Qt.alpha(button.accent, 0.26) : Qt.alpha(Theme.surfaceVariant, 0.30)
                        border.width: 1
                        border.color: button.selected ? Qt.alpha(button.accent, 0.70) : Qt.alpha(Theme.outline, 0.35)

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                    }

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40
                        text: button.modelData.glyph
                        font.pixelSize: 40
                        color: button.selected ? button.accent : Theme.textDim
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 104
                        text: button.modelData.label
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: button.selected ? button.accent : Theme.textDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: menu.index = button.index
                        onClicked: Power.run(button.modelData)
                    }
                }
            }
        }
    }
}
