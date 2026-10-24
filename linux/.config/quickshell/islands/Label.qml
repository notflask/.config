import QtQuick

// Text in der Schrift der Leiste (eigener Name: eine Datei Text.qml würde
// QtQuicks Text im ganzen Ordner verdecken)
Text {
    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: Theme.size
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
