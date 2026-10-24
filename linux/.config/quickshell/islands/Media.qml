import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Was gerade läuft (MPRIS: Spotify, Browser …): Note, Titel · Künstler.
// Nur sichtbar, solange etwas spielt. Klick: Pause/weiter, Mausrad: nächster/
// voriger Titel.
Item {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null

    visible: player !== null
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: Theme.pill
    Layout.preferredWidth: implicitWidth

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Glyph {
            code: 0xF075A
            color: Theme.accent
            font.pixelSize: 15
        }
        Label {
            Layout.maximumWidth: 260
            color: Theme.dim
            text: root.player ? root.player.trackTitle + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "") : ""
        }
        Rectangle {
            Layout.leftMargin: 4
            width: 1
            height: 14
            color: Theme.rim
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.player && root.player.canTogglePlaying)
            root.player.togglePlaying()
        onWheel: w => {
            if (!root.player)
                return;
            if (w.angleDelta.y < 0 && root.player.canGoNext)
                root.player.next();
            else if (w.angleDelta.y > 0 && root.player.canGoPrevious)
                root.player.previous();
        }
    }
}
