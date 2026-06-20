pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/binds.js" as Binds
import "lib/keychord.js" as Chord
import "Singletons"

/**
 * 鍵 KEYBINDS surface: lists the keyboard shortcuts parsed from
 * ~/.config/hypr/modules/binds.lua, each row a combo on the left and a derived
 * action label on the right. Selecting a row and pressing a new chord rewrites
 * that bind's key in place and reloads Hyprland; the action itself is never
 * touched. Arrow keys move the focused row and carry the soul seam like the
 * settings surface; Enter starts capture, Escape cancels it. A captured chord
 * that is already bound elsewhere is refused with an inline warning and capture
 * stays live so the user can pick another.
 *
 * The capture path mirrors the wallpaper strip's search handoff: while
 * `listening`, an Item with focus swallows every keystroke; when capture ends
 * the host hands focus back to the FocusScope so arrow-key nav never gets stuck.
 */
PillSurface {
    id: root

    mTop: 15
    mLeft: 19
    mRight: 19
    mBottom: 14

    implicitHeight: content.implicitHeight

    signal requestSurface(string name)

    readonly property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/modules/binds.lua"

    property var binds: []
    property int focusIndex: 0
    property bool listening: false
    property int listenLine: -1
    property string conflict: ""

    function refresh() {
        root.binds = Binds.parse(bindsFile.text());
        if (root.focusIndex >= root.binds.length)
            root.focusIndex = Math.max(0, root.binds.length - 1);
    }

    /**
     * Slide the focused row by `dir` (+1 down, -1 up), clamped over the bind
     * list, and keep it in view. No-op while a chord capture is live so the
     * arrow keys feed the catcher instead.
     */
    function move(dir) {
        if (root.listening)
            return;
        if (root.binds.length === 0)
            return;
        root.focusIndex = Math.max(0, Math.min(root.binds.length - 1, root.focusIndex + dir));
        list.positionViewAtIndex(root.focusIndex, ListView.Contain);
    }

    /**
     * Enter on the focused row: arm chord capture on that bind's source line and
     * clear any stale conflict. The keyCatcher grabs focus off `listening`.
     */
    function activate() {
        if (root.listening || root.focusIndex < 0 || root.focusIndex >= root.binds.length)
            return;
        root.conflict = "";
        root.listenLine = root.binds[root.focusIndex].lineIndex;
        root.listening = true;
    }

    /**
     * Apply a captured chord. A bare modifier is ignored (keep listening);
     * Escape cancels; a combo already bound elsewhere is refused with an inline
     * warning and capture stays live; otherwise the line is rewritten and the
     * write kicks the reload + re-parse from the writer's onSaved.
     */
    function capture(key, modifiers) {
        if (key === Qt.Key_Escape) {
            root.listening = false;
            root.conflict = "";
            return;
        }
        var combo = Chord.chord(key, modifiers);
        if (combo === null)
            return;
        var text = bindsFile.text();
        if (Binds.inUse(text, combo, root.listenLine)) {
            root.conflict = combo + " already bound";
            return;
        }
        var r = Binds.rebind(text, root.listenLine, combo);
        if (r.ok) {
            writer.setText(r.text);
        } else {
            root.conflict = r.error || "rebind failed";
        }
    }

    onActiveChanged: {
        if (active) {
            refresh();
            focusIndex = 0;
            listening = false;
            listenLine = -1;
            conflict = "";
        } else {
            listening = false;
            conflict = "";
        }
    }

    readonly property Item focusRowItem: list.focusRowItem

    readonly property bool rowFocused: focusRowItem !== null && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void root.focusIndex;
        void list.contentY;
        if (!focusRowItem)
            return Qt.point(4 * root.s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * root.s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    FileView {
        id: bindsFile
        path: root.bindsPath
        blockLoading: true
        printErrors: false
        onLoaded: root.refresh()
    }

    FileView {
        id: writer
        path: root.bindsPath
        atomicWrites: true
        printErrors: false
        onSaved: {
            reloadProc.running = true;
            root.listening = false;
            root.conflict = "";
            bindsFile.reload();
            root.refresh();
        }
        onSaveFailed: (err) => {
            root.conflict = "write failed";
            console.log("keybinds: write failed: " + err);
        }
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    Item {
        id: keyCatcher
        focus: root.listening
        Keys.onPressed: (e) => {
            if (!root.listening)
                return;
            e.accepted = true;
            root.capture(e.key, e.modifiers);
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.listening
        onClicked: root.requestSurface("settings")
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
                    text: "鍵"
                    color: Theme.cream
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KEYBINDS"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            GlyphIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "cog"
                color: Theme.iconDim
                stroke: 1.7
            }
        }

        Item { width: 1; height: 12 * root.s }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 282 * root.s)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.binds

            property Item focusRowItem: null

            delegate: Item {
                id: brow
                required property int index
                required property var modelData

                readonly property bool focused: root.focusIndex === brow.index
                readonly property bool capturing: focused && root.listening

                width: ListView.view.width
                height: 38 * root.s

                onFocusedChanged: if (focused) list.focusRowItem = brow

                HoverHandler {
                    id: rowHover
                    onHoveredChanged: if (hovered && !root.listening) root.focusIndex = brow.index
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 3 * root.s
                    anchors.bottomMargin: 3 * root.s
                    radius: 9 * root.s
                    color: brow.capturing ? Qt.alpha(Theme.vermLit, 0.14)
                        : ((rowHover.hovered || brow.focused) ? Theme.frameBg : "transparent")
                    border.width: 1
                    border.color: brow.capturing ? Qt.alpha(Theme.vermLit, 0.5) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Rectangle {
                    id: comboChip
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: comboText.implicitWidth + 16 * root.s
                    height: comboText.implicitHeight + 8 * root.s
                    radius: 7 * root.s
                    visible: !brow.capturing
                    color: brow.focused ? Qt.alpha(Theme.vermLit, 0.16) : Theme.tileBg
                    border.width: 1
                    border.color: brow.focused ? Qt.alpha(Theme.vermLit, 0.45) : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        id: comboText
                        anchors.centerIn: parent
                        text: brow.modelData.combo
                        color: brow.focused ? Theme.cream : Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3 * root.s
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16 * root.s
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: brow.capturing
                    text: root.conflict.length > 0 ? root.conflict : "press keys…  esc to cancel"
                    color: root.conflict.length > 0 ? Theme.vermLit : Theme.flameGlow
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: brow.width * 0.46
                    visible: !brow.capturing
                    horizontalAlignment: Text.AlignRight
                    text: brow.modelData.label
                    color: brow.focused ? Theme.subtle : Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.listening
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.focusIndex = brow.index;
                        root.activate();
                    }
                }
            }
        }

        Item { width: 1; height: 11 * root.s }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hairSoft
        }

        Item {
            width: parent.width
            height: 20 * root.s

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "enter rebind · esc close"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1 * root.s
            }
        }
    }
}
