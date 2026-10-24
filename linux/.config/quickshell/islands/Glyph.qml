import QtQuick

// Symbol aus Symbols Nerd Font (Material Design), Codepunkt als Zahl
Text {
    property int code: 0

    text: code ? String.fromCodePoint(code) : ""
    color: Theme.fg
    font.family: Theme.icons
    font.pixelSize: Theme.iconSize
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
