pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "lib/setDeco.js" as SetDeco
import "Singletons"

/**
 * 飾 LOOK sub-surface: edits the window-decoration knobs that live in
 * decoration.lua and writes each change straight back to its source so the choice
 * survives a restart. Window gaps, rounding and border size, the two opacity
 * fields and the blur block all rewrite the Lua and reload Hyprland so the change
 * lands at once. Blur fields are rewritten scoped to the `blur` block, since
 * `enabled` is shared with the sibling `shadow` block. The border colours are
 * sourced from the palette pipeline and never touched here. Reached from the
 * settings index; morphs back on the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property string decoPath: Quickshell.env("HOME") + "/.config/hypr/modules/decoration.lua"

    property int gapsIn: 6
    property int gapsOut: 12
    property int rounding: 12
    property int borderSize: 2
    property bool blurOn: true
    property int blurSize: 8
    property int blurPasses: 3
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0

    onActiveChanged: {
        if (active) {
            decoFile.reload();
            seed();
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    /**
     * Seeds every control from the live decoration.lua. Numbers fall back to the
     * shipped defaults when a field is missing so a partially hand-edited config
     * never leaves a control blank. Blur fields read from the `blur` block so a
     * field name shared with the `shadow` block resolves correctly.
     */
    function seed() {
        var t = decoFile.text();

        var gi = parseInt(SetDeco.getField(t, "gaps_in"), 10);
        root.gapsIn = isNaN(gi) ? 6 : gi;
        var go = parseInt(SetDeco.getField(t, "gaps_out"), 10);
        root.gapsOut = isNaN(go) ? 12 : go;
        var rd = parseInt(SetDeco.getField(t, "rounding"), 10);
        root.rounding = isNaN(rd) ? 12 : rd;
        var bs = parseInt(SetDeco.getField(t, "border_size"), 10);
        root.borderSize = isNaN(bs) ? 2 : bs;

        root.blurOn = SetDeco.getBlockField(t, "blur", "enabled") === "true";
        var bz = parseInt(SetDeco.getBlockField(t, "blur", "size"), 10);
        root.blurSize = isNaN(bz) ? 8 : bz;
        var bp = parseInt(SetDeco.getBlockField(t, "blur", "passes"), 10);
        root.blurPasses = isNaN(bp) ? 3 : bp;

        var ao = parseFloat(SetDeco.getField(t, "active_opacity"));
        root.activeOpacity = isNaN(ao) ? 1.0 : ao;
        var io = parseFloat(SetDeco.getField(t, "inactive_opacity"));
        root.inactiveOpacity = isNaN(io) ? 1.0 : io;
    }

    /**
     * Rewrites one top-level decoration.lua field to `literal` (already formatted
     * by the caller) and reloads Hyprland so the change takes effect at once.
     */
    function writeDeco(name, literal) {
        var res = SetDeco.setField(decoFile.text(), name, literal);
        if (!res.ok)
            return;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Rewrites one field inside the `blur` block to `literal` and reloads
     * Hyprland. Scoping to the block keeps `enabled` from hitting the sibling
     * `shadow` block's `enabled` first.
     */
    function writeBlur(name, literal) {
        var res = SetDeco.setBlockField(decoFile.text(), "blur", name, literal);
        if (!res.ok)
            return;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    FileView {
        id: decoFile
        path: root.decoPath
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: decoWriter
        path: root.decoPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: reloadProc
        command: ["setsid", "-f", "sh", "-c", "sleep 0.4; hyprctl reload"]
    }

    component Stepper: Row {
        id: step

        property real value: 0
        property string display: ""
        signal stepped(int dir)

        spacing: 6 * root.s

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * root.s
            height: 26 * root.s
            radius: Motion.rSmall * root.s
            color: minusArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "−"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.Bold
            }

            MouseArea {
                id: minusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: step.stepped(-1)
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 44 * root.s
            horizontalAlignment: Text.AlignHCenter
            text: step.display
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26 * root.s
            height: 26 * root.s
            radius: Motion.rSmall * root.s
            color: plusArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.Bold
            }

            MouseArea {
                id: plusArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: step.stepped(1)
            }
        }
    }

    component GroupLabel: Text {
        topPadding: 16 * root.s
        bottomPadding: 6 * root.s
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 8.5 * root.s
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2 * root.s
    }

    component FieldRow: Item {
        id: frow
        property string label: ""
        property string caption: ""
        default property alias control: ctrl.data

        width: parent ? parent.width : 0
        height: 34 * root.s

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * root.s

            Text {
                text: frow.label
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
            }

            Text {
                visible: frow.caption.length > 0
                text: frow.caption
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
            }
        }

        Item {
            id: ctrl
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Column {
        id: content
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0
        height: root.height + root.mBottom * root.s
        clip: true

        SettingsHeader {
            s: root.s
            glyph: "飾"
            title: "LOOK"
            showBack: true
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 0

            GroupLabel { text: "Window" }

            FieldRow {
                label: "Gaps inner"
                caption: "Space between tiled windows"
                Stepper {
                    value: root.gapsIn
                    display: String(root.gapsIn)
                    onStepped: (dir) => {
                        var next = Math.max(0, Math.min(40, root.gapsIn + dir));
                        if (next === root.gapsIn)
                            return;
                        root.gapsIn = next;
                        root.writeDeco("gaps_in", String(next));
                    }
                }
            }

            FieldRow {
                label: "Gaps outer"
                caption: "Space to the screen edge"
                Stepper {
                    value: root.gapsOut
                    display: String(root.gapsOut)
                    onStepped: (dir) => {
                        var next = Math.max(0, Math.min(60, root.gapsOut + dir));
                        if (next === root.gapsOut)
                            return;
                        root.gapsOut = next;
                        root.writeDeco("gaps_out", String(next));
                    }
                }
            }

            FieldRow {
                label: "Rounding"
                caption: "Corner radius in pixels"
                Stepper {
                    value: root.rounding
                    display: String(root.rounding)
                    onStepped: (dir) => {
                        var next = Math.max(0, Math.min(30, root.rounding + dir));
                        if (next === root.rounding)
                            return;
                        root.rounding = next;
                        root.writeDeco("rounding", String(next));
                    }
                }
            }

            FieldRow {
                label: "Border size"
                caption: "Window outline thickness"
                Stepper {
                    value: root.borderSize
                    display: String(root.borderSize)
                    onStepped: (dir) => {
                        var next = Math.max(0, Math.min(8, root.borderSize + dir));
                        if (next === root.borderSize)
                            return;
                        root.borderSize = next;
                        root.writeDeco("border_size", String(next));
                    }
                }
            }

            GroupLabel { text: "Blur" }

            FieldRow {
                label: "Enabled"
                caption: "Blur behind transparent windows"
                LinkToggle {
                    s: root.s
                    on: root.blurOn
                    onToggled: {
                        root.blurOn = !root.blurOn;
                        root.writeBlur("enabled", root.blurOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Strength"
                caption: "Blur radius"
                visible: root.blurOn
                height: root.blurOn ? 34 * root.s : 0
                Stepper {
                    value: root.blurSize
                    display: String(root.blurSize)
                    onStepped: (dir) => {
                        var next = Math.max(1, Math.min(20, root.blurSize + dir));
                        if (next === root.blurSize)
                            return;
                        root.blurSize = next;
                        root.writeBlur("size", String(next));
                    }
                }
            }

            FieldRow {
                label: "Passes"
                caption: "More passes, smoother blur"
                visible: root.blurOn
                height: root.blurOn ? 34 * root.s : 0
                Stepper {
                    value: root.blurPasses
                    display: String(root.blurPasses)
                    onStepped: (dir) => {
                        var next = Math.max(1, Math.min(5, root.blurPasses + dir));
                        if (next === root.blurPasses)
                            return;
                        root.blurPasses = next;
                        root.writeBlur("passes", String(next));
                    }
                }
            }

            GroupLabel { text: "Opacity" }

            FieldRow {
                label: "Active window"
                caption: "Focused window transparency"
                Stepper {
                    value: root.activeOpacity
                    display: root.activeOpacity.toFixed(2)
                    onStepped: (dir) => {
                        var next = Math.max(0.5, Math.min(1.0, Math.round((root.activeOpacity + dir * 0.05) * 100) / 100));
                        if (next === root.activeOpacity)
                            return;
                        root.activeOpacity = next;
                        root.writeDeco("active_opacity", next.toFixed(2));
                    }
                }
            }

            FieldRow {
                label: "Inactive window"
                caption: "Unfocused window transparency"
                Stepper {
                    value: root.inactiveOpacity
                    display: root.inactiveOpacity.toFixed(2)
                    onStepped: (dir) => {
                        var next = Math.max(0.5, Math.min(1.0, Math.round((root.inactiveOpacity + dir * 0.05) * 100) / 100));
                        if (next === root.inactiveOpacity)
                            return;
                        root.inactiveOpacity = next;
                        root.writeDeco("inactive_opacity", next.toFixed(2));
                    }
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
