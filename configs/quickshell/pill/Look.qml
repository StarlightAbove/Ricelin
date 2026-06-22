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
    readonly property string pillBlurRule: 'hl.layer_rule({ name = "pill-blur", match = { namespace = "pill" }, blur = true, ignore_alpha = 0.05 })\n'

    property int gapsIn: 6
    property int gapsOut: 12
    property int rounding: 12
    property int roundingPower: 4
    property int borderSize: 2
    property bool resizeOnBorder: true
    property string layout: "dwindle"
    property bool blurOn: true
    property int blurSize: 8
    property int blurPasses: 3
    property real blurVibrancy: 0.17
    property real blurNoise: 0.01
    property bool shadowOn: true
    property int shadowRange: 12
    property int shadowRenderPower: 3
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0

    readonly property var layoutOptions: [
        { label: "Dwindle", value: "dwindle" },
        { label: "Master", value: "master" }
    ]

    property string decoText: ""

    /** Per-field values captured on each open; the ScrubValue undo glyphs revert to these. */
    property var base: ({})

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
        root.decoText = decoFile.text();
        var t = root.decoText;

        var gi = parseInt(SetDeco.getField(t, "gaps_in"), 10);
        root.gapsIn = isNaN(gi) ? 6 : gi;
        var go = parseInt(SetDeco.getField(t, "gaps_out"), 10);
        root.gapsOut = isNaN(go) ? 12 : go;
        var rd = parseInt(SetDeco.getField(t, "rounding"), 10);
        root.rounding = isNaN(rd) ? 12 : rd;
        var rp = parseInt(SetDeco.getField(t, "rounding_power"), 10);
        root.roundingPower = isNaN(rp) ? 4 : rp;
        var bs = parseInt(SetDeco.getField(t, "border_size"), 10);
        root.borderSize = isNaN(bs) ? 2 : bs;
        root.resizeOnBorder = SetDeco.getField(t, "resize_on_border") === "true";
        var lo = SetDeco.getField(t, "layout");
        root.layout = lo.length > 0 ? lo : "dwindle";

        root.blurOn = SetDeco.getBlockField(t, "blur", "enabled") === "true";
        var bz = parseInt(SetDeco.getBlockField(t, "blur", "size"), 10);
        root.blurSize = isNaN(bz) ? 8 : bz;
        var bp = parseInt(SetDeco.getBlockField(t, "blur", "passes"), 10);
        root.blurPasses = isNaN(bp) ? 3 : bp;
        var vb = parseFloat(SetDeco.getBlockField(t, "blur", "vibrancy"));
        root.blurVibrancy = isNaN(vb) ? 0.17 : vb;
        var nz = parseFloat(SetDeco.getBlockField(t, "blur", "noise"));
        root.blurNoise = isNaN(nz) ? 0.01 : nz;

        root.shadowOn = SetDeco.getBlockField(t, "shadow", "enabled") === "true";
        var sr = parseInt(SetDeco.getBlockField(t, "shadow", "range"), 10);
        root.shadowRange = isNaN(sr) ? 12 : sr;
        var sp = parseInt(SetDeco.getBlockField(t, "shadow", "render_power"), 10);
        root.shadowRenderPower = isNaN(sp) ? 3 : sp;

        var ao = parseFloat(SetDeco.getField(t, "active_opacity"));
        root.activeOpacity = isNaN(ao) ? 1.0 : ao;
        var io = parseFloat(SetDeco.getField(t, "inactive_opacity"));
        root.inactiveOpacity = isNaN(io) ? 1.0 : io;

        Flags.pillBlur = SetDeco.hasNamedRule(t, "pill-blur");

        root.base = {
            gapsIn: root.gapsIn,
            gapsOut: root.gapsOut,
            rounding: root.rounding,
            roundingPower: root.roundingPower,
            borderSize: root.borderSize,
            blurSize: root.blurSize,
            blurPasses: root.blurPasses,
            blurVibrancy: root.blurVibrancy,
            blurNoise: root.blurNoise,
            shadowRange: root.shadowRange,
            shadowRenderPower: root.shadowRenderPower,
            activeOpacity: root.activeOpacity,
            inactiveOpacity: root.inactiveOpacity,
            pillOpacity: Flags.pillOpacity
        };
    }

    /**
     * Rewrites one top-level decoration.lua field to `literal` (already formatted
     * by the caller) and reloads Hyprland so the change takes effect at once.
     */
    function writeDeco(name, literal) {
        var res = SetDeco.setField(root.decoText, name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Same as writeDeco, but for the two opacity fields. A plain reload re-reads
     * the file yet only animates windows on their next focus change, so a window
     * that was inactive when the value changed keeps its stale alpha. Pushing the
     * value through hl.config hits Hyprland's REFRESH_WINDOW_STATES path, which
     * recomputes every existing window's active/inactive alpha at once. Sends both
     * fields so lowering one then restoring the other never leaves a window stuck,
     * and the push fires even when the value lands back on 1.0.
     */
    function writeOpacity(name, literal) {
        writeDeco(name, literal);
        opacityRefresh.command = ["hyprctl", "eval",
            "hl.config({ decoration = { active_opacity = " + root.activeOpacity.toFixed(2)
            + ", inactive_opacity = " + root.inactiveOpacity.toFixed(2) + " } })"];
        opacityRefresh.running = true;
    }

    /**
     * Rewrites one field inside the `blur` block to `literal` and reloads
     * Hyprland. Scoping to the block keeps `enabled` from hitting the sibling
     * `shadow` block's `enabled` first.
     */
    function writeBlur(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "blur", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Rewrites one field inside the `shadow` block to `literal` and reloads
     * Hyprland. Scoped to the block so `enabled` lands on shadow, not the sibling
     * `blur` block.
     */
    function writeShadow(name, literal) {
        var res = SetDeco.setBlockField(root.decoText, "shadow", name, literal);
        if (!res.ok)
            return;
        root.decoText = res.text;
        decoWriter.setText(res.text);
        reloadProc.running = true;
    }

    /**
     * Adds or removes the pill-blur layer_rule in decoration.lua and reloads
     * Hyprland so the frosted-glass effect behind the pill turns on or off at
     * once. The rule lives in the Lua source (the live config parser rejects a
     * runtime `layerrule` keyword), so it has to be written, not pushed.
     */
    function applyPillBlur(on) {
        var t = root.decoText;
        var res;
        if (on) {
            if (SetDeco.hasNamedRule(t, "pill-blur"))
                return;
            res = SetDeco.addNamedRule(t, root.pillBlurRule);
        } else {
            res = SetDeco.removeNamedRule(t, "pill-blur");
        }
        if (!res.ok)
            return;
        root.decoText = res.text;
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

    Process {
        id: opacityRefresh
        command: []
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
                ScrubValue {
                    s: root.s
                    value: root.gapsIn
                    openValue: root.base.gapsIn
                    from: 0; to: 40; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsIn = v;
                        root.writeDeco("gaps_in", String(v));
                    }
                }
            }

            FieldRow {
                label: "Gaps outer"
                caption: "Space to the screen edge"
                ScrubValue {
                    s: root.s
                    value: root.gapsOut
                    openValue: root.base.gapsOut
                    from: 0; to: 60; step: 1; unit: "px"
                    onEdited: v => {
                        root.gapsOut = v;
                        root.writeDeco("gaps_out", String(v));
                    }
                }
            }

            FieldRow {
                label: "Rounding"
                caption: "Corner radius in pixels"
                ScrubValue {
                    s: root.s
                    value: root.rounding
                    openValue: root.base.rounding
                    from: 0; to: 30; step: 1; unit: "px"
                    onEdited: v => {
                        root.rounding = v;
                        root.writeDeco("rounding", String(v));
                    }
                }
            }

            FieldRow {
                label: "Rounding power"
                caption: "Higher bends corners to a squircle"
                ScrubValue {
                    s: root.s
                    value: root.roundingPower
                    openValue: root.base.roundingPower
                    from: 1; to: 10; step: 1
                    onEdited: v => {
                        root.roundingPower = v;
                        root.writeDeco("rounding_power", String(v));
                    }
                }
            }

            FieldRow {
                label: "Border size"
                caption: "Window outline thickness"
                ScrubValue {
                    s: root.s
                    value: root.borderSize
                    openValue: root.base.borderSize
                    from: 0; to: 8; step: 1; unit: "px"
                    onEdited: v => {
                        root.borderSize = v;
                        root.writeDeco("border_size", String(v));
                    }
                }
            }

            FieldRow {
                label: "Resize on border"
                caption: "Drag a window edge to resize"
                LinkToggle {
                    s: root.s
                    on: root.resizeOnBorder
                    onToggled: {
                        root.resizeOnBorder = !root.resizeOnBorder;
                        root.writeDeco("resize_on_border", root.resizeOnBorder ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Layout"
                caption: "Tiling layout for new windows"
                SettingsSeg {
                    s: root.s
                    options: root.layoutOptions
                    value: root.layout
                    onPicked: v => {
                        root.layout = v;
                        root.writeDeco("layout", "\"" + v + "\"");
                    }
                }
            }

            GroupLabel { text: "Shadow" }

            FieldRow {
                label: "Enabled"
                caption: "Drop shadow under windows"
                LinkToggle {
                    s: root.s
                    on: root.shadowOn
                    onToggled: {
                        root.shadowOn = !root.shadowOn;
                        root.writeShadow("enabled", root.shadowOn ? "true" : "false");
                    }
                }
            }

            FieldRow {
                label: "Range"
                caption: "How far the shadow spreads"
                visible: root.shadowOn
                height: root.shadowOn ? 34 * root.s : 0
                ScrubValue {
                    s: root.s
                    value: root.shadowRange
                    openValue: root.base.shadowRange
                    from: 0; to: 50; step: 1; unit: "px"
                    onEdited: v => {
                        root.shadowRange = v;
                        root.writeShadow("range", String(v));
                    }
                }
            }

            FieldRow {
                label: "Render power"
                caption: "Shadow falloff sharpness"
                visible: root.shadowOn
                height: root.shadowOn ? 34 * root.s : 0
                ScrubValue {
                    s: root.s
                    value: root.shadowRenderPower
                    openValue: root.base.shadowRenderPower
                    from: 1; to: 4; step: 1
                    onEdited: v => {
                        root.shadowRenderPower = v;
                        root.writeShadow("render_power", String(v));
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
                ScrubValue {
                    s: root.s
                    value: root.blurSize
                    openValue: root.base.blurSize
                    from: 1; to: 20; step: 1; unit: "px"
                    onEdited: v => {
                        root.blurSize = v;
                        root.writeBlur("size", String(v));
                    }
                }
            }

            FieldRow {
                label: "Passes"
                caption: "More passes, smoother blur"
                visible: root.blurOn
                height: root.blurOn ? 34 * root.s : 0
                ScrubValue {
                    s: root.s
                    value: root.blurPasses
                    openValue: root.base.blurPasses
                    from: 1; to: 5; step: 1
                    onEdited: v => {
                        root.blurPasses = v;
                        root.writeBlur("passes", String(v));
                    }
                }
            }

            FieldRow {
                label: "Vibrancy"
                caption: "Color saturation behind the blur"
                visible: root.blurOn
                height: root.blurOn ? 34 * root.s : 0
                ScrubValue {
                    s: root.s
                    value: root.blurVibrancy
                    openValue: root.base.blurVibrancy
                    from: 0; to: 1; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurVibrancy = v;
                        root.writeBlur("vibrancy", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                label: "Noise"
                caption: "Grain mixed into the blur"
                visible: root.blurOn
                height: root.blurOn ? 34 * root.s : 0
                ScrubValue {
                    s: root.s
                    value: root.blurNoise
                    openValue: root.base.blurNoise
                    from: 0; to: 0.2; step: 0.01; decimals: 2
                    onEdited: v => {
                        root.blurNoise = v;
                        root.writeBlur("noise", v.toFixed(2));
                    }
                }
            }

            GroupLabel { text: "Opacity" }

            FieldRow {
                label: "Active window"
                caption: "Focused window transparency"
                ScrubValue {
                    s: root.s
                    value: root.activeOpacity
                    openValue: root.base.activeOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.activeOpacity = v;
                        root.writeOpacity("active_opacity", v.toFixed(2));
                    }
                }
            }

            FieldRow {
                label: "Inactive window"
                caption: "Unfocused window transparency"
                ScrubValue {
                    s: root.s
                    value: root.inactiveOpacity
                    openValue: root.base.inactiveOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => {
                        root.inactiveOpacity = v;
                        root.writeOpacity("inactive_opacity", v.toFixed(2));
                    }
                }
            }

            GroupLabel { text: "Pill" }

            FieldRow {
                label: "Pill opacity"
                caption: "How see-through the pill sits"
                ScrubValue {
                    s: root.s
                    value: Flags.pillOpacity
                    openValue: root.base.pillOpacity
                    from: 0.5; to: 1.0; step: 0.05; decimals: 2
                    onEdited: v => Flags.pillOpacity = v
                }
            }

            FieldRow {
                label: "Pill blur"
                caption: "Frosts what is behind the pill. Needs opacity below 100%."
                height: 42 * root.s
                LinkToggle {
                    s: root.s
                    on: Flags.pillBlur
                    onToggled: {
                        Flags.pillBlur = !Flags.pillBlur;
                        root.applyPillBlur(Flags.pillBlur);
                    }
                }
            }

            Item { width: 1; height: 10 * root.s }
        }
    }
}
