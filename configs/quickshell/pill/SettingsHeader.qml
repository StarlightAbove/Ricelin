import QtQuick
import "Singletons"

/**
 * Settings surface header: the surface kanji (gated by Flags.showGlyphs) and its
 * uppercase title on the left, with a cog at the index or a back chevron on a
 * sub-surface at the right. Clicking the chevron emits `back()`.
 */
Item {
    id: head

    property real s: 1
    property string glyph: ""
    property string title: ""
    property bool showBack: false
    signal back()

    width: parent ? parent.width : 0
    height: 22 * head.s

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * head.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Flags.showGlyphs && head.glyph.length > 0
            text: head.glyph
            color: Theme.cream
            font.family: Theme.fontJp
            font.weight: Font.Medium
            font.pixelSize: 16 * head.s
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: head.title
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * head.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.6 * head.s
        }
    }

    GlyphIcon {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 16 * head.s
        height: 16 * head.s
        name: head.showBack ? "chevron-left" : "cog"
        color: Theme.iconDim
        stroke: head.showBack ? 2.2 : 1.7

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8 * head.s
            enabled: head.showBack
            cursorShape: Qt.PointingHandCursor
            onClicked: head.back()
        }
    }
}
