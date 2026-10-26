pragma Singleton

import QtQuick
import Quickshell

// Feste Farben (nicht aus matugen): fast schwarz, Grautöne, rosa Akzent
Singleton {
    // schmal; Symbole kommen aus Symbols Nerd Font (Status.qml, Icon)
    readonly property string font: "Iosevka Fixed"
    readonly property int size: 16
    readonly property int height: 32

    readonly property color bg: "#0b0b0b"
    readonly property color fg: "#d0d0d0"
    readonly property color dim: "#8a8a8a"
    readonly property color faint: "#4a4a4a"
    readonly property color accent: "#e0607e"
    readonly property color accentFg: "#0b0b0b"
    readonly property color error: "#e06c75"
    readonly property color ok: "#8fd19e"
    readonly property color warn: "#f0c674"
    readonly property color orange: "#f5a35c"
}
