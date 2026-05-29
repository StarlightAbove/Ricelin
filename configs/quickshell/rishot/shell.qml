import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "lib/coords.js" as Coords
import "lib/AnnotationModel.js" as Ann

ShellRoot {
    id: root

    property var globalSel: null
    property var pressPoint: null
    property bool capturing: false
    property string phase: "selecting"
    property string activeTool: "rect"
    property color activeColor: vermilion
    property int activeWidth: 4

    property var model: Ann.create()
    property var draft: null
    property int annRevision: 0
    property bool settingsOpen: false
    property bool textEditing: false

    function textSize() { return activeWidth * 5 + 8; }

    property var overlays: []
    property int frozenCount: 0

    readonly property bool testRect: Quickshell.env("RISHOT_TESTRECT") === "1"
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string shotsDir: homeDir + "/Pictures/Screenshots"
    readonly property string rishotLuaPath: homeDir + "/.config/hypr/modules/rishot.lua"

    readonly property color vermilion: "#e0563b"

    function beginSelection(gx, gy) {
        pressPoint = { x: gx, y: gy };
        capturing = true;
        globalSel = { x: gx, y: gy, w: 0, h: 0 };
    }
    function updateSelection(gx, gy) {
        if (!pressPoint) return;
        globalSel = Coords.rectFromPoints(pressPoint, { x: gx, y: gy });
    }
    function endSelection() {
        capturing = false;
        pressPoint = null;
        if (globalSel && globalSel.w > 2 && globalSel.h > 2) phase = "editing";
        else globalSel = null;
    }

    function clampToSel(gx, gy) {
        var x = Math.max(globalSel.x, Math.min(gx, globalSel.x + globalSel.w));
        var y = Math.max(globalSel.y, Math.min(gy, globalSel.y + globalSel.h));
        return { x: x, y: y };
    }
    readonly property var freehandTools: ["pen", "marker"]
    function isFreehand(t) { return t === "pen" || t === "marker"; }

    function placeText(gx, gy) {
        if (textEditing) { commitText(); return; }
        var p = clampToSel(gx, gy);
        draft = { type: "text", points: [p], color: activeColor, text: "", size: textSize() };
        textEditing = true;
        bumpAnn();
    }
    function commitText() {
        if (draft && draft.type === "text") {
            if (draft.text && draft.text.length > 0) model.add(draft);
        }
        draft = null;
        textEditing = false;
        bumpAnn();
    }
    function cancelText() {
        draft = null;
        textEditing = false;
        bumpAnn();
    }

    function beginDraw(gx, gy) {
        if (!globalSel || activeTool === "select") return;
        if (activeTool === "text") { placeText(gx, gy); return; }
        var p = clampToSel(gx, gy);
        pressPoint = p;
        capturing = true;
        if (isFreehand(activeTool))
            draft = { type: activeTool, points: [p], color: activeColor, width: activeWidth };
        else
            draft = { type: activeTool, points: [p, p], color: activeColor, width: activeWidth, filled: false };
        bumpAnn();
    }
    function updateDraw(gx, gy) {
        if (!draft || !pressPoint || draft.type === "text") return;
        var p = clampToSel(gx, gy);
        if (isFreehand(draft.type)) {
            var last = draft.points[draft.points.length - 1];
            if (Math.abs(p.x - last.x) < 2 && Math.abs(p.y - last.y) < 2) return;
            draft.points = draft.points.concat([p]);
        } else {
            draft.points = [pressPoint, p];
        }
        bumpAnn();
    }
    function endDraw() {
        capturing = false;
        if (!draft || draft.type === "text") return;
        if (isFreehand(draft.type)) {
            if (draft.points.length >= 2) model.add(draft);
        } else {
            var p0 = draft.points[0], p1 = draft.points[1];
            var dx = Math.abs(p1.x - p0.x), dy = Math.abs(p1.y - p0.y);
            var big = draft.type === "line" || draft.type === "arrow"
                ? Math.hypot(dx, dy) > 4
                : dx > 2 && dy > 2;
            if (big) model.add(draft);
        }
        draft = null;
        pressPoint = null;
        bumpAnn();
    }
    function bumpAnn() { annRevision += 1; }

    function undo() { if (model.undo()) bumpAnn(); }
    function redo() { if (model.redo()) bumpAnn(); }

    function pointerPressed(gx, gy) {
        if (phase === "selecting") beginSelection(gx, gy);
        else beginDraw(gx, gy);
    }
    function pointerMoved(gx, gy) {
        if (phase === "selecting") updateSelection(gx, gy);
        else updateDraw(gx, gy);
    }
    function pointerReleased() {
        if (phase === "selecting") endSelection();
        else endDraw();
    }

    function timestampName() {
        var d = new Date();
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return "shot-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
            + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + ".png";
    }
    readonly property string defaultPath: shotsDir + "/" + timestampName()

    function anchorOverlay() {
        if (!globalSel) return null;
        for (var i = 0; i < overlays.length; i++) {
            var w = overlays[i];
            var s = w.modelData;
            if (globalSel.x >= s.x && globalSel.x < s.x + s.width
                && globalSel.y >= s.y && globalSel.y < s.y + s.height) return w;
        }
        return overlays.length ? overlays[0] : null;
    }

    function spansMonitors() {
        if (!globalSel) return false;
        var hit = 0;
        for (var i = 0; i < overlays.length; i++) {
            var s = overlays[i].modelData;
            if (Coords.intersectRect(globalSel, { x: s.x, y: s.y, width: s.width, height: s.height })) hit++;
        }
        return hit > 1;
    }

    function grabTo(path, after) {
        var w = anchorOverlay();
        if (!w) { if (after) after(false); return; }
        if (spansMonitors())
            console.log("rishot: TODO seam-stitch (Phase 6) — grabbing anchor-monitor portion only");
        w.grabExport(path, function (ok) {
            console.log("rishot: grab " + path + " => " + ok);
            if (after) after(ok);
        });
    }

    function doCopy() {
        var auto = defaultPath;
        grabTo(auto, function (ok) {
            if (ok) copyProc.run(auto);
            else Qt.quit();
        });
    }

    function doSave() { saveDialog.open(); }

    function commitSave(chosen) {
        var auto = defaultPath;
        grabTo(auto, function (ok) {
            if (chosen && chosen !== auto) grabTo(chosen, function () { Qt.quit(); });
            else Qt.quit();
        });
    }

    Process {
        id: saveDialog
        stdout: StdioCollector { id: saveOut }
        function open() {
            command = ["kdialog", "--getsavefilename", root.defaultPath, "*.png"];
            running = true;
        }
        onExited: (code) => {
            var chosen = saveOut.text.trim();
            console.log("rishot: kdialog exit " + code + " path=" + JSON.stringify(chosen));
            if (code === 0 && chosen.length > 0) root.commitSave(chosen);
        }
    }

    Process {
        id: copyProc
        function run(file) {
            command = ["sh", "-c", "wl-copy --type image/png < " + JSON.stringify(file)];
            running = true;
        }
        onExited: (code) => { console.log("rishot: wl-copy exit " + code); Qt.quit(); }
    }

    function noteFrozen() {
        frozenCount += 1;
        if (testRect && frozenCount >= Quickshell.screens.length) testDriver.start();
    }

    function toolbarFor(win) {
        if (phase !== "editing" || !globalSel) return { visible: false, x: 0, y: 0 };
        if (anchorOverlay() !== win) return { visible: false, x: 0, y: 0 };
        return { visible: true };
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "rishot"

            readonly property string scrName: win.modelData.name
            readonly property bool showToolbar: root.toolbarFor(win).visible

            readonly property var selLocal: root.globalSel
                ? Coords.intersectRect(root.globalSel,
                    { x: win.modelData.x, y: win.modelData.y, width: win.width, height: win.height })
                : null

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: {
                    if (root.textEditing) root.cancelText();
                    else if (root.settingsOpen) root.settingsOpen = false;
                    else Qt.quit();
                }
                Keys.onPressed: (e) => {
                    if (root.textEditing) return;
                    if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier)) { root.doCopy(); e.accepted = true; }
                    else if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) { root.undo(); e.accepted = true; }
                    else if (e.key === Qt.Key_Y && (e.modifiers & Qt.ControlModifier)) { root.redo(); e.accepted = true; }
                }

                Overlay {
                    id: ov
                    anchors.fill: parent
                    screenData: win.modelData
                    globalSel: root.globalSel
                    capturing: root.capturing
                    model: root.model
                    draft: root.draft
                    annRevision: root.annRevision
                    textEditing: root.textEditing

                    onPressedAt: (gx, gy) => root.pointerPressed(gx, gy)
                    onMovedTo: (gx, gy) => root.pointerMoved(gx, gy)
                    onReleased: root.pointerReleased()
                    onFrozen: root.noteFrozen()
                    onTextChanged: (t) => { if (root.draft && root.draft.type === "text") { root.draft.text = t; root.bumpAnn(); } }
                    onTextCommitted: root.commitText()
                }

                Toolbar {
                    id: toolbar
                    visible: win.showToolbar && win.selLocal !== null
                    activeTool: root.activeTool
                    activeColor: root.activeColor
                    activeWidth: root.activeWidth
                    canUndo: root.model ? root.model.canUndo() : false
                    canRedo: root.model ? root.model.canRedo() : false
                    settingsOpen: root.settingsOpen

                    x: {
                        if (!win.selLocal) return 0;
                        var cx = win.selLocal.x + win.selLocal.w / 2 - width / 2;
                        return Math.max(8, Math.min(cx, win.width - width - 8));
                    }
                    y: {
                        if (!win.selLocal) return 0;
                        var below = win.selLocal.y + win.selLocal.h + 12;
                        if (below + height > win.height - 8) below = win.selLocal.y - height - 12;
                        return Math.max(8, below);
                    }

                    onToolPicked: (t) => { if (root.textEditing) root.commitText(); root.activeTool = t; }
                    onColorPicked: (c) => root.activeColor = c
                    onWidthPicked: (w) => root.activeWidth = w
                    onUndoRequested: root.undo()
                    onRedoRequested: root.redo()
                    onCopyRequested: root.doCopy()
                    onSaveRequested: root.doSave()
                    onSettingsRequested: root.settingsOpen = toolbar.settingsOpen
                }

                SettingsPanel {
                    id: hotkeyPopover
                    visible: toolbar.visible && root.settingsOpen
                    luaPath: root.rishotLuaPath
                    x: Math.max(8, Math.min(toolbar.x + toolbar.gearCenterX - width / 2,
                                            win.width - width - 8))
                    y: toolbar.y - height - 6
                    onCloseRequested: root.settingsOpen = false
                    onRebound: Qt.quit()
                }
            }

            Component.onCompleted: root.overlays.push(win)

            function grabExport(path, cb) { ov.grabExport(path, cb); }
            function grabToolbar(path, cb) {
                var sched = toolbar.grabToImage(function (r) {
                    var ok = false;
                    try { ok = r ? r.saveToFile(path) : false; } catch (e) { ok = false; }
                    if (cb) cb(ok);
                });
                if (!sched && cb) cb(false);
            }
        }
    }

    Timer {
        id: testDriver
        interval: 400
        repeat: false
        onTriggered: {
            root.globalSel = { x: 2750, y: 350, w: 760, h: 480 };
            root.phase = "editing";
            var bx = 2750, by = 350;
            root.model.add({
                type: "ellipse",
                points: [{ x: bx + 40, y: by + 40 }, { x: bx + 240, y: by + 180 }],
                color: "#4f8fe0", width: 4, filled: false
            });
            root.model.add({
                type: "line",
                points: [{ x: bx + 300, y: by + 60 }, { x: bx + 700, y: by + 200 }],
                color: "#f2c14e", width: 7, filled: false
            });
            root.model.add({
                type: "arrow",
                points: [{ x: bx + 60, y: by + 440 }, { x: bx + 360, y: by + 260 }],
                color: "#e23b3b", width: 5, filled: false
            });
            var pen = [];
            for (var i = 0; i <= 40; i++) {
                var t = i / 40;
                pen.push({ x: bx + 300 + t * 380, y: by + 320 + Math.sin(t * 6.2832) * 60 });
            }
            root.model.add({ type: "pen", points: pen, color: "#5bbf73", width: 3 });
            var mk = [];
            for (var j = 0; j <= 20; j++) {
                var u = j / 20;
                mk.push({ x: bx + 100 + u * 560, y: by + 410 });
            }
            root.model.add({ type: "marker", points: mk, color: "#f2c14e", width: 4 });
            root.model.add({
                type: "blur",
                points: [{ x: bx + 40, y: by + 230 }, { x: bx + 360, y: by + 330 }]
            });
            root.model.add({
                type: "text",
                points: [{ x: bx + 60, y: by + 20 }],
                color: "#ffffff", text: "rishot p3b", size: 28
            });
            root.bumpAnn();
            grabTimer.start();
        }
    }

    Timer {
        id: grabTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.grabTo("/tmp/rishot-p3b.png", function (ok) {
                console.log("rishot-test: annotated grab ok=" + ok);
                var w = root.anchorOverlay();
                if (w) w.grabToolbar("/tmp/rishot-toolbar.png", function (tok) {
                    console.log("rishot-test: toolbar grab ok=" + tok);
                });
            });
        }
    }
}
