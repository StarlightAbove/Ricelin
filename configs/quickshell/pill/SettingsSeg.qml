pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Mini-segmented choice control. `options` is a list of `{ label, value }`; the
 * pill whose value equals `value` lights with a flame tint. Picking a pill emits
 * `picked(value)`; selection keys off the source value, never a child's effective
 * visibility. The host passes `s` for scale.
 */
Rectangle {
    id: seg

    property real s: 1
    property var options: []
    property var value
    signal picked(var value)

    readonly property real pad: 1

    width: pills.implicitWidth + 2 * pad
    height: pills.implicitHeight + 2 * pad
    radius: 9 * seg.s
    color: Theme.tileBg
    border.width: 1
    border.color: Theme.border

    Row {
        id: pills
        anchors.centerIn: parent
        spacing: 2 * seg.s

        Repeater {
            model: seg.options

            Rectangle {
                id: opt
                required property var modelData
                readonly property bool current: seg.value === modelData.value

                width: optLabel.implicitWidth + 18 * seg.s
                height: optLabel.implicitHeight + 12 * seg.s
                radius: 8 * seg.s
                color: opt.current ? Qt.alpha(Theme.vermLit, 0.20) : "transparent"
                border.width: 1
                border.color: opt.current ? Qt.alpha(Theme.vermLit, 0.55) : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData.label
                    color: opt.current ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * seg.s
                    font.weight: Font.Bold
                    font.letterSpacing: 0.3 * seg.s
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(opt.modelData.value)
                }
            }
        }
    }
}
