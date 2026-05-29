// rishot — single toolbar button. Vermilion fill + white glyph when active; dim glyph when inert.
import QtQuick

Rectangle {
    id: btn
    property string label: ""
    property bool active: false
    property bool dim: false       // inert / disabled look

    signal clicked()

    width: 32
    height: 32
    radius: 7
    color: active ? "#e0563b" : (hover.hovered && !dim ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

    readonly property color idle: "#c4ccda"

    Text {
        anchors.centerIn: parent
        text: btn.label
        color: btn.active ? "#ffffff" : (btn.dim ? Qt.rgba(0.77, 0.80, 0.85, 0.35) : btn.idle)
        font.pixelSize: 16
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: btn.clicked() }
}
