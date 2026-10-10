import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Startmenü wie unter Windows 11: mittig über der Taskleiste, Suchfeld
// oben, Apps als Raster 6 × 3 (Symbol über Name, oft gestartete zuerst),
// unten Benutzer und Ein/Aus. Tippen sucht, Pfeile wählen, Enter startet,
// Esc schließt.
Popup {
    id: menu

    property string query: ""
    property bool powerMode: false
    // Starts je App (Desktop-ID), für die Reihenfolge
    property var counts: ({})

    readonly property var apps: {
        const list = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const q = query.trim().toLowerCase();
        const score = e => {
            if (!q)
                return 0;
            const name = e.name.toLowerCase();
            if (name.startsWith(q))
                return 3;
            if (name.includes(q))
                return 2;
            if ((e.genericName + " " + e.keywords + " " + e.categories + " " + e.id).toLowerCase().includes(q))
                return 1;
            return -1;
        };
        return list.map(e => ({
                    entry: e,
                    score: score(e)
                })).filter(x => x.score >= 0).sort((a, b) => b.score - a.score || (counts[b.entry.id] || 0) - (counts[a.entry.id] || 0) || a.entry.name.localeCompare(b.entry.name)).map(x => x.entry);
    }

    function launch(entry) {
        const c = Object.assign({}, counts);
        c[entry.id] = (c[entry.id] || 0) + 1;
        counts = c;
        usage.setText(JSON.stringify(c));
        entry.execute();
        close();
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
        close();
    }

    keyboard: true
    padding: 0
    radius: 16

    onShownChanged: {
        if (shown) {
            query = "";
            search.text = "";
            powerMode = false;
            grid.currentIndex = 0;
            grid.targetY = 0;
            grid.contentY = 0;
            search.forceActiveFocus();
        }
    }

    FileView {
        id: usage
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-start.json"
        printErrors: false
        onLoaded: {
            try {
                menu.counts = JSON.parse(text());
            } catch (err) {}
        }
    }

    Column {
        width: 640

        // ── Suchfeld ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28 + 40

            Rectangle {
                x: 32
                y: 28
                width: parent.width - 64
                height: 40
                radius: 20
                color: Theme.pill
                border.width: search.activeFocus ? 1 : 0
                border.color: Qt.alpha(Theme.primary, 0.5)

                Glyph {
                    id: lens
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F0349}"
                    color: Theme.textDim
                }

                TextInput {
                    id: search
                    anchors.left: lens.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Theme.text
                    selectionColor: Qt.alpha(Theme.primary, 0.4)
                    clip: true
                    onTextChanged: {
                        menu.query = text;
                        menu.powerMode = false;
                        grid.currentIndex = 0;
                    }

                    Keys.onPressed: e => {
                        const n = grid.count;
                        if (e.key === Qt.Key_Escape) {
                            menu.close();
                        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (n > 0)
                                menu.launch(menu.apps[grid.currentIndex]);
                        } else if (e.key === Qt.Key_Down) {
                            grid.currentIndex = Math.min(n - 1, grid.currentIndex + 6);
                        } else if (e.key === Qt.Key_Up) {
                            grid.currentIndex = Math.max(0, grid.currentIndex - 6);
                        } else if (e.key === Qt.Key_Right && search.cursorPosition === search.text.length) {
                            grid.currentIndex = Math.min(n - 1, grid.currentIndex + 1);
                        } else if (e.key === Qt.Key_Left && search.cursorPosition === search.text.length) {
                            grid.currentIndex = Math.max(0, grid.currentIndex - 1);
                        } else {
                            return;
                        }
                        grid.showCurrent();
                        e.accepted = true;
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Nach Apps suchen"
                        font.pixelSize: 15
                        color: Theme.textDim
                        opacity: 0.7
                    }
                }
            }
        }

        // ── Überschrift ───────────────────────────────────────────────
        Item {
            width: parent.width
            height: 22 + 18 + 6

            Label {
                x: 48
                y: 22
                text: menu.powerMode ? "Ein/Aus" : menu.query ? "Beste Treffer" : "Alle Apps"
                font.weight: Font.DemiBold
                font.pixelSize: 14
            }
        }

        // ── Apps: 6 × 3, Rest per Scrollen ────────────────────────────
        Item {
            width: parent.width
            height: 3 * 92 + 8 + 20

            GridView {
                id: grid

                // Ziel der laufenden Scroll-Animation (mehrere Rad-Rasten
                // hintereinander addieren sich)
                property real targetY: 0
                readonly property real maxY: Math.max(0, contentHeight - height)

                // weich zu einer Position scrollen
                function scrollTo(y) {
                    targetY = Math.max(0, Math.min(maxY, y));
                    scroll.to = targetY;
                    scroll.restart();
                }

                // Auswahl per Tastatur sichtbar halten
                function showCurrent() {
                    const top = Math.floor(currentIndex / 6) * cellHeight;
                    if (top < contentY)
                        scrollTo(top);
                    else if (top + cellHeight > contentY + height)
                        scrollTo(top + cellHeight - height);
                }

                x: 32
                y: 4
                width: parent.width - 64
                height: 3 * 92
                visible: !menu.powerMode
                clip: true
                cellWidth: width / 6
                cellHeight: 92
                model: menu.apps
                // Scrollen übernimmt der WheelHandler unten (Qt springt sonst
                // pro Raste ohne Animation)
                interactive: false
                highlightFollowsCurrentItem: false
                // Zeilen außerhalb schon vorbereiten: kein Nachladen beim Scrollen
                cacheBuffer: 2 * 92
                reuseItems: true
                onModelChanged: {
                    scroll.stop();
                    targetY = 0;
                    contentY = 0;
                }

                NumberAnimation {
                    id: scroll
                    target: grid
                    property: "contentY"
                    duration: 260
                    easing.type: Easing.OutCubic
                }


                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 12
                        color: cellMouse.containsMouse || grid.currentIndex === cell.index ? Theme.hover : "transparent"
                    }

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        implicitSize: 36
                        source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 60
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: grid.currentIndex = cell.index
                        onClicked: menu.launch(cell.modelData)
                    }
                }
            }

            // Rad/Touchpad über dem Raster. Nimmt keine Klicks und kein Hover,
            // die gehen weiter an die Apps darunter.
            MouseArea {
                anchors.fill: grid
                visible: grid.visible
                acceptedButtons: Qt.NoButton
                onWheel: e => {
                    // Touchpad: Pixel 1:1 folgen; Mausrad: eine Zeile je Raste, animiert
                    if (e.pixelDelta.y !== 0) {
                        scroll.stop();
                        grid.contentY = grid.targetY = Math.max(0, Math.min(grid.maxY, grid.contentY - e.pixelDelta.y));
                    } else {
                        const from = scroll.running ? grid.targetY : grid.contentY;
                        grid.scrollTo(from - e.angleDelta.y / 120 * grid.cellHeight);
                    }
                }
            }

            Label {
                anchors.centerIn: grid
                visible: !menu.powerMode && grid.count === 0
                text: "Keine Treffer"
                color: Theme.textDim
            }

            // Ein/Aus: dieselben Befehle wie wlogout/layout
            Row {
                anchors.centerIn: grid
                visible: menu.powerMode
                spacing: 4

                Repeater {
                    model: [
                        {
                            glyph: "\u{F033E}",
                            label: "Sperren",
                            cmd: ["hyprlock"]
                        },
                        {
                            glyph: "\u{F0343}",
                            label: "Abmelden",
                            cmd: ["session-logout"]
                        },
                        {
                            glyph: "\u{F0904}",
                            label: "Standby",
                            cmd: ["systemctl", "suspend"]
                        },
                        {
                            glyph: "\u{F0709}",
                            label: "Neu starten",
                            cmd: ["systemctl", "reboot"]
                        },
                        {
                            glyph: "\u{F0425}",
                            label: "Ausschalten",
                            cmd: ["systemctl", "poweroff"]
                        }
                    ]

                    delegate: Item {
                        id: action

                        required property var modelData

                        width: 96
                        height: 92

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 12
                            color: actionMouse.containsMouse ? Theme.hover : "transparent"
                        }

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 18
                            text: action.modelData.glyph
                            font.pixelSize: 30
                            color: action.modelData.label === "Ausschalten" ? Theme.error : Theme.text
                        }

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 60
                            text: action.modelData.label
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: menu.run(action.modelData.cmd)
                        }
                    }
                }
            }
        }

        // ── Benutzer und Ein/Aus ──────────────────────────────────────
        Item {
            width: parent.width
            height: 60

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rim
                opacity: 0.6
            }

            Row {
                x: 40
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Theme.pill

                    Glyph {
                        anchors.centerIn: parent
                        text: "\u{F0004}"
                        font.pixelSize: 18
                    }
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: user.name
                }
            }

            Tile {
                anchors.right: parent.right
                anchors.rightMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 34
                padding: 10
                background: hovered || menu.powerMode ? Theme.hover : "transparent"
                onClicked: menu.powerMode = !menu.powerMode

                Glyph {
                    text: "\u{F0425}"
                }
            }
        }
    }

    // voller Name aus /etc/passwd, sonst der Benutzername
    QtObject {
        id: user
        property string name: Quickshell.env("USER") || ""
    }

    Process {
        running: true
        command: ["getent", "passwd", Quickshell.env("USER") || ""]
        stdout: StdioCollector {
            id: passwd
            onStreamFinished: {
                const full = (passwd.text.split(":")[4] || "").split(",")[0];
                if (full)
                    user.name = full;
            }
        }
    }
}
