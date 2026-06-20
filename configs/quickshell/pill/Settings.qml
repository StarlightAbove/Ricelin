pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 設 SETTINGS surface: Flags-persisted preferences grouped into sections of
 * rows, each a name with an optional faint caption and a right-aligned control.
 * Appearance covers the clock format and seconds, the Japanese-glyph toggle that
 * gates every surface header, and the accent-palette mode; Recording carries the
 * capture countdown. Toggles reuse LinkToggle; choice rows use an inline
 * mini-segmented control that flame-tints the selected pill. Exposes
 * `implicitHeight` from its content and rides the hovered row with a glowing
 * seam, like the link surface.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

    /**
     * Row-soul focus registry, mirroring the link surface: each row reports its
     * hover here and the bead docks as a glowing seam at the left edge of the
     * focused row, hidden when nothing is focused. Sticky while open so the seam
     * glides between rows instead of re-waking from the pill centre; cleared when
     * the surface closes.
     */
    property Item focusRowItem: null
    property int kbIndex: -1

    function reportRowHover(item, hovered) {
        if (hovered) {
            focusRowItem = item;
            kbIndex = rowIndexOf(item);
        }
    }
    onActiveChanged: if (!active) {
        focusRowItem = null;
        kbIndex = -1;
    }

    /**
     * Keyboard-navigable row registry: each entry pairs a row item with its
     * control kind and a getter/setter onto the backing flag. The host routes
     * arrow keys here — up/down move the focused row and carry the soul seam with
     * it, left/right step a segmented choice or set a toggle, return flips a
     * toggle. Hover keeps `kbIndex` in sync so the two never disagree.
     */
    readonly property var rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: accentRow, kind: "seg", vals: [false, true], get: function () { return Flags.dynamicPalette; }, set: function (v) { Flags.dynamicPalette = v; } },
        { item: keysRow, kind: "nav", surface: "keybinds" },
        { item: cdRow, kind: "seg", vals: [0, 3, 5, 10], get: function () { return Flags.recordCountdown; }, set: function (v) { Flags.recordCountdown = v; } }
    ]

    function rowIndexOf(item) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].item === item)
                return i;
        return -1;
    }

    function kbMove(dir) {
        kbIndex = Math.max(0, Math.min(rows.length - 1, (kbIndex < 0 ? 0 : kbIndex + dir)));
        focusRowItem = rows[kbIndex].item;
    }

    function kbAdjust(dir) {
        if (kbIndex < 0) {
            kbIndex = 0;
            focusRowItem = rows[0].item;
        }
        var r = rows[kbIndex];
        if (r.kind === "seg") {
            var i = r.vals.indexOf(r.get());
            r.set(r.vals[Math.max(0, Math.min(r.vals.length - 1, (i < 0 ? 0 : i) + dir))]);
        } else {
            r.set(dir > 0);
        }
    }

    function kbActivate() {
        if (kbIndex < 0)
            return;
        var r = rows[kbIndex];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
    }

    /**
     * A click anywhere on a row drives its control: toggles flip, nav rows open
     * their surface, and segmented rows step to the next value (wrapping). The
     * control's own hit areas stay on top, so clicking a specific segment still
     * picks it directly.
     */
    function activateRow(item) {
        var idx = rowIndexOf(item);
        if (idx < 0)
            return;
        kbIndex = idx;
        focusRowItem = item;
        var r = rows[idx];
        if (r.kind === "toggle")
            r.set(!r.get());
        else if (r.kind === "nav")
            root.requestSurface(r.surface);
        else if (r.kind === "seg") {
            var i = r.vals.indexOf(r.get());
            r.set(r.vals[((i < 0 ? 0 : i) + 1) % r.vals.length]);
        }
    }

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void content.implicitHeight;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    /**
     * Mini-segmented choice control. `options` is a list of `{ label, value }`;
     * the pill whose value equals `value` lights with a flame tint. Picking a
     * pill emits `picked(value)`; selection keys off the source value, never a
     * child's effective visibility.
     */
    component MiniSeg: Rectangle {
        id: seg
        property var options: []
        property var value
        signal picked(var value)

        readonly property real pad: 1

        width: pills.implicitWidth + 2 * pad
        height: pills.implicitHeight + 2 * pad
        radius: 9 * root.s
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border

        Row {
            id: pills
            anchors.centerIn: parent
            spacing: 2 * root.s

            Repeater {
                model: seg.options

                Rectangle {
                    id: opt
                    required property var modelData
                    readonly property bool current: seg.value === modelData.value

                    width: optLabel.implicitWidth + 18 * root.s
                    height: optLabel.implicitHeight + 12 * root.s
                    radius: 8 * root.s
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
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
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

    /**
     * One settings line: a name plus an optional faint sub caption on the left
     * and a control slot on the right, capped to a single bottom hairline. The
     * `control` default-property slot holds the toggle or segmented control.
     */
    component SRow: Item {
        id: srow
        property string name: ""
        property string sub: ""
        property bool last: false
        default property alias control: controlSlot.data

        width: parent ? parent.width : 0
        height: Math.max(textCol.implicitHeight, controlSlot.childrenRect.height) + 26 * root.s

        HoverHandler {
            id: srowHover
            onHoveredChanged: root.reportRowHover(srow, hovered)
        }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3 * root.s
            anchors.bottomMargin: 3 * root.s
            radius: 9 * root.s
            color: (srowHover.hovered || root.focusRowItem === srow) ? Theme.frameBg : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateRow(srow)
        }

        Column {
            id: textCol
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.right: controlSlot.left
            anchors.rightMargin: 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5 * root.s

            Text {
                text: srow.name
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                visible: srow.sub.length > 0
                text: srow.sub
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }

        Item {
            id: controlSlot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairSoft
            visible: !srow.last
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Flags.showGlyphs
                    text: "設"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SETTINGS"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            GlyphIcon {
                id: gear
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "cog"
                color: Theme.iconDim
                stroke: 1.7
            }
        }

        Text {
            topPadding: 17 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Appearance"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SRow {
            id: timeRow
            name: "Time format"
            sub: "24-hour stays the default"

            MiniSeg {
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SRow {
            id: secRow
            name: "Clock seconds"
            sub: "Show :SS in the pill clock"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SRow {
            id: glyphRow
            name: "Japanese glyphs"
            sub: "Kanji on surface headers (蓄 BATTERY…). Off swaps for plain labels."

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        SRow {
            id: accentRow
            name: "Accent palette"
            sub: "Static = fixed flame · Dynamic = recolor per wallpaper (matugen)"

            MiniSeg {
                options: [{ label: "Static", value: false }, { label: "Dynamic", value: true }]
                value: Flags.dynamicPalette
                onPicked: (v) => Flags.dynamicPalette = v
            }
        }

        Text {
            topPadding: 17 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Hotkeys"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SRow {
            id: keysRow
            name: "Edit keybinds"
            sub: "rebind shortcuts"

            Item {
                width: 16 * root.s
                height: 16 * root.s

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 13 * root.s
                    height: 13 * root.s
                    name: "chevron-right"
                    color: root.focusRowItem === keysRow ? Theme.cream : Theme.iconDim
                    stroke: 2.2
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8 * root.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestSurface("keybinds")
                }
            }
        }

        Text {
            topPadding: 17 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Recording"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SRow {
            id: cdRow
            name: "Countdown"
            sub: "Delay before capture starts"
            last: true

            MiniSeg {
                options: [
                    { label: "Off", value: 0 },
                    { label: "3s", value: 3 },
                    { label: "5s", value: 5 },
                    { label: "10s", value: 10 }
                ]
                value: Flags.recordCountdown
                onPicked: (v) => Flags.recordCountdown = v
            }
        }
    }
}
