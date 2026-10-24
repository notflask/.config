import QtQuick
import QtQuick.Shapes

// Gentoo-Logo für den Startknopf in den matugen-Farben: Innenform in der
// Akzentfarbe, Umriss und Auge als hellere Abstufung davon, jeweils mit
// leichtem Verlauf (Licht von oben).
// Form: Simple Icons „Gentoo“ (CC0), 24 × 24.
Item {
    id: root

    property int size: 20
    property color tint: Theme.accent
    // beim Überfahren etwas heller
    property bool active: false

    implicitWidth: size
    implicitHeight: size

    // Außenumriss
    readonly property string outer: "M9.94 0a7.31 7.31 0 00-1.26.116c-4.344.795-7.4 4.555-7.661 7.031-.126 1.215.53 2.125.89 2.526.977 1.085 2.924 1.914 4.175 2.601-1.81 1.543-2.64 2.296-3.457 3.154C1.403 16.712.543 18.125.54 19.138c0 .325-.053 1.365.371 2.187.16.309.613 1.338 1.98 2.109.874.494 2.119.675 3.337.501 3.772-.538 8.823-3.737 12.427-6.716 2.297-1.9 3.977-3.739 4.462-4.644.39-.731.434-2.043.207-2.866-.645-2.337-5.887-7.125-10.172-9.051A7.824 7.824 0 009.94 0z"
    // Innenform, Auge als Loch, Pupille wieder voll (gerade/ungerade)
    readonly property string inner: "M9.82.588a5.647 5.647 0 00-.506.032c-2.337.245-2.785.547-4.903 2.149-.71.537-2.016 1.844-2.35 3.393-.128.59.024 1.1.448 1.458 1.36 1.144 3.639 2.072 5.509 2.97.547.263.185.74-.698 1.505-2.227 1.928-5.24 4.276-5.45 6.066-.099.842.19 1.988 1.213 2.574 1.195.685 3.676.238 5.333-.379 2.422-.902 5.602-2.892 8.127-4.848 2.625-2.034 5.067-4.617 5.188-5.038.148-.517.133-.996-.154-1.546-.448-.862-1.049-1.503-1.694-2.22-1.732-1.825-3.563-3.43-5.754-4.658C12.694 1.242 11.417.564 9.82.588z M10.895 4.211c.546 0 1.176.173 1.853.5 1.688.817 3.422 2.961-.015 4.195-.935.336-3.9-.824-3.81-2.407.09-1.57.854-2.289 1.972-2.288zM11.18 5.578c-.317-.002-.575.079-.694.263-.557.861-.303 1.472.212 1.862.192-.457 2.156.043 2.148.472a.32.32 0 00.055-.032c1.704-1.282-.472-2.557-1.72-2.565z"

    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 4; y1: 0
                x2: 16; y2: 24
                GradientStop { position: 0.0; color: Qt.tint(root.tint, Qt.rgba(1, 1, 1, 0.8)) }
                GradientStop { position: 1.0; color: Qt.tint(root.tint, Qt.rgba(1, 1, 1, root.active ? 0.6 : 0.45)) }
            }
            PathSvg { path: root.outer }
        }

        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 6; y1: 2
                x2: 14; y2: 22
                GradientStop { position: 0.0; color: root.active ? Qt.lighter(root.tint, 1.1) : root.tint }
                GradientStop { position: 1.0; color: Qt.darker(root.tint, root.active ? 1.5 : 1.7) }
            }
            PathSvg { path: root.inner }
        }
    }
}
