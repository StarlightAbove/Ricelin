// rishot — entry / coordinator. One keyboard-exclusive overlay window per screen over a frozen
// capture. Flow: drag region (phase "selecting") -> release locks it (phase "editing") -> toolbar
// appears under the selection on its monitor -> draw Rect annotations inside the selection ->
// Copy / Save / Esc. Auto-save always fires on any export action. Selection + annotations live in
// GLOBAL coords; each overlay renders the intersecting sub-rect.
// Pollution rule (Spike 0): each screen captures its frozen frame, then dim/chrome paint after.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "lib/coords.js" as Coords
import "lib/AnnotationModel.js" as Ann

ShellRoot {
    id: root

    // ---- shared state (global coordinate space) ----
    property var globalSel: null      // {x,y,w,h} | null
    property var pressPoint: null     // {x,y} | null
    property bool capturing: false
    property string phase: "selecting"   // "selecting" | "editing"
    property string activeTool: "rect"

    property var model: Ann.create()
    property var draft: null           // in-progress annotation | null
    property int annRevision: 0

    property var overlays: []
    property int frozenCount: 0

    readonly property bool testRect: Quickshell.env("RISHOT_TESTRECT") === "1"
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string shotsDir: homeDir + "/Pictures/Screenshots"

    readonly property color vermilion: "#e0563b"

    // ---- region selection (phase: selecting) ----
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

    // ---- annotation drawing (phase: editing) ----
    function clampToSel(gx, gy) {
        var x = Math.max(globalSel.x, Math.min(gx, globalSel.x + globalSel.w));
        var y = Math.max(globalSel.y, Math.min(gy, globalSel.y + globalSel.h));
        return { x: x, y: y };
    }
    function beginDraw(gx, gy) {
        if (!globalSel || activeTool !== "rect") return;
        var p = clampToSel(gx, gy);
        pressPoint = p;
        draft = { type: "rect", points: [p, p], color: vermilion, width: 3, filled: false };
        bumpAnn();
    }
    function updateDraw(gx, gy) {
        if (!draft || !pressPoint) return;
        draft.points = [pressPoint, clampToSel(gx, gy)];
        bumpAnn();
    }
    function endDraw() {
        if (!draft) return;
        var p0 = draft.points[0], p1 = draft.points[1];
        if (Math.abs(p1.x - p0.x) > 2 && Math.abs(p1.y - p0.y) > 2) model.add(draft);
        draft = null;
        pressPoint = null;
        bumpAnn();
    }
    function bumpAnn() { annRevision += 1; }

    function undo() { if (model.undo()) bumpAnn(); }
    function redo() { if (model.redo()) bumpAnn(); }

    // ---- pointer routing by phase ----
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

    // ---- export ----
    function timestampName() {
        var d = new Date();
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return "shot-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
            + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + ".png";
    }
    readonly property string defaultPath: shotsDir + "/" + timestampName()

    // The overlay whose monitor contains the selection anchor (top-left). Single-monitor case.
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

    // Grab the selection to `path`. Then run `after(ok)` (e.g. copy/quit). Auto-save handled by caller.
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

    // Copy action: auto-save, then wl-copy the PNG, then quit.
    function doCopy() {
        var auto = defaultPath;
        grabTo(auto, function (ok) {
            if (ok) copyProc.run(auto);
            else Qt.quit();
        });
    }

    // Save action: auto-save to default, then ALSO write the chosen path, then quit.
    function doSave(chosen) {
        var auto = defaultPath;
        grabTo(auto, function (ok) {
            if (chosen && chosen !== auto) {
                grabTo(chosen, function () { Qt.quit(); });
            } else {
                Qt.quit();
            }
        });
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

    // ---- toolbar placement: below the selection, clamped, on the selection's monitor ----
    function toolbarFor(win) {
        // returns {visible, x, y} in this win's LOCAL coords, or {visible:false}
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

            // toolbar position in local coords (below selection, clamped on-screen)
            readonly property var selLocal: root.globalSel
                ? Coords.intersectRect(root.globalSel,
                    { x: win.modelData.x, y: win.modelData.y, width: win.width, height: win.height })
                : null

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: Qt.quit()
                Keys.onPressed: (e) => {
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

                    onPressedAt: (gx, gy) => root.pointerPressed(gx, gy)
                    onMovedTo: (gx, gy) => root.pointerMoved(gx, gy)
                    onReleased: root.pointerReleased()
                    onFrozen: root.noteFrozen()
                }

                Toolbar {
                    id: toolbar
                    visible: win.showToolbar && win.selLocal !== null
                    activeTool: root.activeTool
                    canUndo: root.model ? root.model.canUndo() : false
                    canRedo: root.model ? root.model.canRedo() : false
                    savePath: root.defaultPath

                    // place centered under the selection, clamped to the screen
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

                    onToolPicked: (t) => root.activeTool = t
                    onUndoRequested: root.undo()
                    onRedoRequested: root.redo()
                    onCopyRequested: root.doCopy()
                    onSaveRequested: (p) => root.doSave(p)
                    onSettingsRequested: console.log("rishot: settings (inert in 2a — Phase 2b)")
                }
            }

            Component.onCompleted: root.overlays.push(win)

            function grabExport(path, cb) { ov.grabExport(path, cb); }
        }
    }

    // ---- gated self-validation (RISHOT_TESTRECT=1) ----
    // Seed a within-DP-1 selection, enter editing, add a Rect annotation inside it, grab the
    // export to /tmp, and fire a real Copy (auto-save + wl-copy). Leaves PNGs for inspection.
    Timer {
        id: testDriver
        interval: 400
        repeat: false
        onTriggered: {
            root.globalSel = { x: 2750, y: 350, w: 760, h: 480 };
            root.phase = "editing";
            // a vermilion rect annotation inside the selection
            root.model.add({
                type: "rect",
                points: [{ x: 2850, y: 450 }, { x: 3300, y: 700 }],
                color: root.vermilion, width: 4, filled: false
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
            root.grabTo("/tmp/rishot-p2-annotated.png", function (ok) {
                console.log("rishot-test: annotated grab ok=" + ok);
                // also exercise the real Copy path (auto-save + wl-copy + quit)
                root.doCopy();
            });
        }
    }
}
