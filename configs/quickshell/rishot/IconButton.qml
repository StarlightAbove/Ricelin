import QtQuick

Rectangle {
    id: btn
    property string icon: ""
    property bool active: false
    property bool dim: false

    signal clicked()

    width: 32
    height: 32
    radius: 7
    color: active ? "#e0563b" : (hover.hovered && !dim ? Qt.rgba(1, 1, 1, 0.06) : "transparent")

    readonly property color idle: "#c4ccda"

    Icon {
        anchors.centerIn: parent
        name: btn.icon
        size: 18
        tint: btn.active ? "#ffffff" : (btn.dim ? Qt.rgba(0.77, 0.80, 0.85, 0.35) : btn.idle)
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: btn.clicked() }
}
