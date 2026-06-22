pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Numeric value control for the settings tabs. At rest it is just the number, so
 * a column of them stays clean instead of a grid of boxes. Hover wakes a faint
 * accent backdrop and the ghost − / + glyphs: click them to step exactly, or drag
 * the number left/right to scrub. Every path runs through `snap`, so the emitted
 * value is always clamped to `from..to`, landed on the `step` grid and rounded to
 * `decimals` — the host just stores it and writes it back. `value` stays a plain
 * one-way binding to the backing field; edits flow out through `edited`.
 */
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""
    property real s: 1
    signal edited(real value)

    /**
     * Value the host captured when the tab opened. While the live value differs
     * from it the undo glyph surfaces, so a stray scrub is always one click away
     * from the value it had on open. `undefined` until the host snapshots.
     */
    property var openValue: undefined
    readonly property bool dirty: openValue !== undefined && !isNaN(openValue) && root.value !== openValue

    readonly property bool hovered: hh.hovered || scrub.containsMouse || scrub.pressed
                                     || minusMA.containsMouse || plusMA.containsMouse
    readonly property real pxPerStep: 5 * root.s

    HoverHandler { id: hh }

    implicitWidth: content.implicitWidth + 14 * root.s
    implicitHeight: content.implicitHeight + 8 * root.s

    function snap(v) {
        var n = root.from + Math.round((v - root.from) / root.step) * root.step;
        n = Math.max(root.from, Math.min(root.to, n));
        var p = Math.pow(10, root.decimals);
        return Math.round(n * p) / p;
    }

    function bump(dir) {
        var n = snap(root.value + dir * root.step);
        if (n !== root.value)
            root.edited(n);
    }

    Rectangle {
        anchors.fill: parent
        radius: Motion.rSmall * root.s
        color: Qt.alpha(Theme.onGlow, root.hovered ? 0.14 : 0)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6 * root.s

        GlyphIcon {
            id: undoG
            anchors.verticalCenter: parent.verticalCenter
            name: "undo"
            height: 14 * root.s
            width: root.dirty ? 14 * root.s : 0
            opacity: root.dirty ? 1 : 0
            clip: true
            stroke: 1.9
            color: undoMA.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.55)
            Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            MouseArea {
                id: undoMA
                anchors.fill: parent
                anchors.margins: -4 * root.s
                enabled: root.dirty
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.edited(root.openValue)
            }
        }

        Text {
            id: minusG
            anchors.verticalCenter: parent.verticalCenter
            text: "−"
            width: root.hovered ? implicitWidth : 0
            opacity: root.hovered ? 1 : 0
            clip: true
            color: minusMA.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
            font.family: Theme.font
            font.pixelSize: 15 * root.s
            font.weight: Font.Medium
            Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            MouseArea {
                id: minusMA
                anchors.fill: parent
                anchors.margins: -4 * root.s
                enabled: root.hovered
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.bump(-1)
            }
        }

        Item {
            id: valueWrap
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(28 * root.s, vrow.implicitWidth)
            implicitHeight: vrow.implicitHeight

            Row {
                id: vrow
                anchors.centerIn: parent
                spacing: 1 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.value.toFixed(root.decimals)
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1 * root.s
                    visible: root.unit.length > 0
                    text: root.unit
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: scrub
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeHorCursor

                property real pressX: 0
                property real pressVal: 0

                onPressed: mouse => {
                    pressX = mouse.x;
                    pressVal = root.value;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    var steps = Math.round((mouse.x - pressX) / root.pxPerStep);
                    var cand = root.snap(pressVal + steps * root.step);
                    if (cand !== root.value)
                        root.edited(cand);
                }
            }
        }

        Text {
            id: plusG
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            width: root.hovered ? implicitWidth : 0
            opacity: root.hovered ? 1 : 0
            clip: true
            color: plusMA.containsMouse ? Theme.bright : Qt.alpha(Theme.onGlow, 0.6)
            font.family: Theme.font
            font.pixelSize: 15 * root.s
            font.weight: Font.Medium
            Behavior on width { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

            MouseArea {
                id: plusMA
                anchors.fill: parent
                anchors.margins: -4 * root.s
                enabled: root.hovered
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.bump(1)
            }
        }
    }
}
