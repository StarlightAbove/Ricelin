import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Self-contained vector glyph drawn from baked SVG path data, so the pill never
 * depends on the system icon theme or external asset files. Set `name` to pick a
 * glyph, `color` to tint it; stroked glyphs use `stroke` width, filled glyphs
 * (media transport) paint solid. Paths live in a 24x24 space and scale to the
 * item's size.
 */
Item {
    id: root

    property string name: ""
    property color color: Theme.iconDim
    property real stroke: 1.8
    property real fillProgress: 1

    readonly property real u: Math.min(width, height) / 24

    readonly property var glyphs: ({
        "sun": { d: "M16 12a4 4 0 1 0-8 0a4 4 0 1 0 8 0 M12 2v2 M12 20v2 M4.2 4.2l1.4 1.4 M18.4 18.4l1.4 1.4 M2 12h2 M20 12h2 M4.2 19.8l1.4-1.4 M18.4 5.6l1.4-1.4", fill: false },
        "monitor": { d: "M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-16a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z M8 21h8 M12 17v4 M7 13c1.5-4 3-4 5-1s3.5 2 5-2", fill: false },
        "speaker": { d: "M4 9v6h4l5 4V5L8 9z M16 9.5a3 3 0 0 1 0 5 M18.5 7.5a6 6 0 0 1 0 9", fill: false },
        "mic": { d: "M9 9V6a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0 M5 11a7 7 0 0 0 14 0 M12 18v3", fill: false },
        "mic-off": { d: "M9 9V6a3 3 0 0 1 6 0v3 M15 12v0a3 3 0 0 1-5.6 1.5 M5 11a7 7 0 0 0 11 5.5 M12 19v3 M3 3l18 18", fill: false },
        "lock": { d: "M6 10h12a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 1-1.5 1.5H6a1.5 1.5 0 0 1-1.5-1.5v-6A1.5 1.5 0 0 1 6 10z M8.5 10V7a3.5 3.5 0 0 1 7 0v3", fill: false },
        "logout": { d: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4 M16 17l5-5-5-5 M21 12H9", fill: false },
        "suspend": { d: "M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z", fill: false },
        "reboot": { d: "M21 12a9 9 0 1 1-2.6-6.4 M21 3v5h-5", fill: false },
        "shutdown": { d: "M12 3v9 M7.8 6.3a8 8 0 1 0 8.4 0", fill: false },
        "play": { d: "M7 5l12 7-12 7z", fill: true },
        "pause": { d: "M8 5h3v14H8z M13 5h3v14h-3z", fill: true },
        "next": { d: "M6 5l9 7-9 7z M16 5h2v14h-2z", fill: true },
        "prev": { d: "M18 5l-9 7 9 7z M6 5h2v14H6z", fill: true }
    })

    readonly property var g: glyphs[name] !== undefined ? glyphs[name] : ({ d: "", fill: false })

    Shape {
        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.g.fill ? "transparent" : root.color
            fillColor: root.g.fill ? root.color : "transparent"
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.d }
        }
    }
}
