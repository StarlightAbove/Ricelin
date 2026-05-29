// rishot — per-screen overlay: frozen capture bg + annotation canvas (the "scene"), with dim,
// selection chrome and toolbar layered ABOVE as separate siblings so they never enter the export.
// Export-clip: a ShaderEffectSource mirrors the scene's rendered texture (no re-capture, so the
// frozen frame is reused without polluting it), cropped+offset to the local selection rect, then
// grabToImage'd. Capture freezes one frame (captureFrame until hasContent, then stop); dim/chrome
// only paint after the frame is frozen so wlr-screencopy never grabs our own surface.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "lib/coords.js" as Coords

Item {
    id: overlay
    anchors.fill: parent

    required property var screenData          // ShellScreen for this output
    property var globalSel: null              // shared global selection {x,y,w,h} | null
    property bool capturing: false            // true while drag in progress
    property bool ready: false                // frozen frame captured

    property var model: null                  // shared AnnotationModel instance
    property var draft: null                  // in-progress annotation | null
    property int annRevision: 0               // bump to refresh annotation render

    signal pressedAt(real gx, real gy)
    signal movedTo(real gx, real gy)
    signal released()
    signal frozen()

    readonly property int sx: screenData.x
    readonly property int sy: screenData.y

    // local sub-rect of the global selection that lands on this output, or null
    readonly property var localSel: globalSel
        ? Coords.intersectRect(globalSel, { x: sx, y: sy, width: width, height: height })
        : null

    readonly property color dimColor: Qt.rgba(8 / 255, 10 / 255, 16 / 255, 0.62)
    readonly property color vermilion: "#e0563b"

    // ---- scene: frozen frame + annotation canvas (the only thing exported) ----
    Item {
        id: scene
        anchors.fill: parent

        ScreencopyView {
            id: frozen
            anchors.fill: parent
            captureSource: overlay.screenData
            live: false
            paintCursor: false
        }

        AnnLayer {
            id: annCanvas
            anchors.fill: parent
            sx: overlay.sx
            sy: overlay.sy
            model: overlay.model
            draft: overlay.draft
            revision: overlay.annRevision
        }
    }

    // Drive a single frozen capture: call captureFrame() until content arrives, then STOP.
    Timer {
        id: capTimer
        interval: 50
        repeat: true
        running: true
        property int tries: 0
        onTriggered: {
            tries += 1;
            if (frozen.hasContent) {
                running = false;
                overlay.ready = true;
                overlay.frozen();
            } else if (tries > 60) {
                running = false;          // give up; surface stays transparent
            } else {
                frozen.captureFrame();
            }
        }
    }

    // ---- chrome (NOT exported): dim, selection border, handles, label ----
    Rectangle {            // full dim when no selection on this output
        anchors.fill: parent
        color: overlay.dimColor
        visible: overlay.ready && overlay.localSel === null
    }

    Item {                 // four-band dim around the selection
        anchors.fill: parent
        visible: overlay.ready && overlay.localSel !== null
        Rectangle {        // top
            color: overlay.dimColor
            x: 0; y: 0; width: parent.width
            height: overlay.localSel ? overlay.localSel.y : 0
        }
        Rectangle {        // bottom
            color: overlay.dimColor
            x: 0; width: parent.width
            y: overlay.localSel ? overlay.localSel.y + overlay.localSel.h : 0
            height: overlay.localSel ? parent.height - (overlay.localSel.y + overlay.localSel.h) : 0
        }
        Rectangle {        // left
            color: overlay.dimColor
            x: 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? overlay.localSel.x : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
        Rectangle {        // right
            color: overlay.dimColor
            x: overlay.localSel ? overlay.localSel.x + overlay.localSel.w : 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? parent.width - (overlay.localSel.x + overlay.localSel.w) : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
    }

    // Selection chrome: vermilion border + corner handles + dimensions label.
    Item {
        id: chrome
        visible: overlay.ready && overlay.localSel !== null
        x: overlay.localSel ? overlay.localSel.x : 0
        y: overlay.localSel ? overlay.localSel.y : 0
        width: overlay.localSel ? overlay.localSel.w : 0
        height: overlay.localSel ? overlay.localSel.h : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: overlay.vermilion
            border.width: 1.5
        }

        Repeater {
            model: [
                { hx: 0, hy: 0 },
                { hx: 1, hy: 0 },
                { hx: 0, hy: 1 },
                { hx: 1, hy: 1 }
            ]
            Rectangle {
                required property var modelData
                width: 8; height: 8
                color: overlay.vermilion
                x: modelData.hx * (chrome.width - width)
                y: modelData.hy * (chrome.height - height)
            }
        }

        Text {
            text: overlay.globalSel
                ? "⛩ rishot · " + Math.round(overlay.globalSel.w) + "×" + Math.round(overlay.globalSel.h)
                : ""
            color: overlay.vermilion
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            x: 0
            y: -height - 4
        }
    }

    // ---- export-clip: mirrors the scene texture, cropped to the local selection ----
    // Hidden from view (placed off-window); used only as a grabToImage target.
    Item {
        id: exportClip
        clip: true
        visible: false
        width: overlay.localSel ? overlay.localSel.w : 0
        height: overlay.localSel ? overlay.localSel.h : 0

        ShaderEffectSource {
            sourceItem: scene
            // Show the whole scene texture, shifted so the selection origin lands at 0,0.
            width: scene.width
            height: scene.height
            x: overlay.localSel ? -overlay.localSel.x : 0
            y: overlay.localSel ? -overlay.localSel.y : 0
            live: true
            recursive: false
        }
    }

    // Grab ONLY the selection region (frozen pixels + annotations, no dim/chrome). cb(ok).
    function grabExport(path, cb) {
        if (!overlay.localSel) { cb(false); return; }
        var scheduled = exportClip.grabToImage(function (result) {
            var ok = false;
            try { ok = result ? result.saveToFile(path) : false; }
            catch (e) { console.log("rishot: saveToFile failed: " + e); }
            if (cb) cb(ok);
        });
        if (!scheduled && cb) cb(false);
    }

    MouseArea {
        anchors.fill: parent
        enabled: overlay.ready
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor
        onPressed: (m) => overlay.pressedAt(m.x + overlay.sx, m.y + overlay.sy)
        onPositionChanged: (m) => { if (overlay.capturing) overlay.movedTo(m.x + overlay.sx, m.y + overlay.sy); }
        onReleased: overlay.released()
    }
}
