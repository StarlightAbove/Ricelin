import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "lib/coords.js" as Coords

Item {
    id: overlay
    anchors.fill: parent

    required property var screenData
    property var globalSel: null
    property bool capturing: false
    property bool ready: false

    property var model: null
    property var draft: null
    property int annRevision: 0
    property bool textEditing: false

    signal pressedAt(real gx, real gy)
    signal movedTo(real gx, real gy)
    signal released()
    signal frozen()
    signal textChanged(string t)
    signal textCommitted()

    readonly property int sx: screenData.x
    readonly property int sy: screenData.y

    readonly property var localSel: globalSel
        ? Coords.intersectRect(globalSel, { x: sx, y: sy, width: width, height: height })
        : null

    readonly property color dimColor: Qt.rgba(8 / 255, 10 / 255, 16 / 255, 0.62)
    readonly property color vermilion: "#e0563b"

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

        function blurItems() {
            var src = overlay.model ? overlay.model.items : [];
            var out = [];
            for (var i = 0; i < src.length; i++)
                if (src[i] && src[i].type === "blur") out.push(src[i]);
            if (overlay.draft && overlay.draft.type === "blur") out.push(overlay.draft);
            return out;
        }

        Repeater {
            model: { overlay.annRevision; return scene.blurItems(); }

            Item {
                required property var modelData
                readonly property var a: modelData
                readonly property bool valid: a !== undefined && a !== null && a.points !== undefined && a.points.length >= 2
                readonly property real rx: valid ? Math.min(a.points[0].x, a.points[1].x) - overlay.sx : 0
                readonly property real ry: valid ? Math.min(a.points[0].y, a.points[1].y) - overlay.sy : 0
                readonly property real rw: valid ? Math.abs(a.points[1].x - a.points[0].x) : 0
                readonly property real rh: valid ? Math.abs(a.points[1].y - a.points[0].y) : 0
                x: rx
                y: ry
                width: rw
                height: rh
                visible: valid && rw > 0 && rh > 0
                clip: true

                ShaderEffectSource {
                    id: blurSrc
                    sourceItem: frozen
                    anchors.fill: parent
                    live: false
                    recursive: false
                    sourceRect: Qt.rect(parent.rx, parent.ry, parent.rw, parent.rh)
                    visible: false
                }

                FastBlur {
                    anchors.fill: parent
                    source: blurSrc
                    radius: 64
                }
            }
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
                running = false;
            } else {
                frozen.captureFrame();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: overlay.dimColor
        visible: overlay.ready && overlay.localSel === null
    }

    Item {
        anchors.fill: parent
        visible: overlay.ready && overlay.localSel !== null
        Rectangle {
            color: overlay.dimColor
            x: 0; y: 0; width: parent.width
            height: overlay.localSel ? overlay.localSel.y : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: 0; width: parent.width
            y: overlay.localSel ? overlay.localSel.y + overlay.localSel.h : 0
            height: overlay.localSel ? parent.height - (overlay.localSel.y + overlay.localSel.h) : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? overlay.localSel.x : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: overlay.localSel ? overlay.localSel.x + overlay.localSel.w : 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? parent.width - (overlay.localSel.x + overlay.localSel.w) : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
    }

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

    Item {
        id: exportClip
        clip: true
        visible: false
        width: overlay.localSel ? overlay.localSel.w : 0
        height: overlay.localSel ? overlay.localSel.h : 0

        ShaderEffectSource {
            sourceItem: scene
            width: scene.width
            height: scene.height
            x: overlay.localSel ? -overlay.localSel.x : 0
            y: overlay.localSel ? -overlay.localSel.y : 0
            live: true
            recursive: false
        }
    }

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

    TextInput {
        id: textEdit
        readonly property bool mine: overlay.textEditing && overlay.draft
            && overlay.draft.type === "text" && overlay.localSel !== null
            && (overlay.draft.points[0].x >= overlay.sx) && (overlay.draft.points[0].x < overlay.sx + overlay.width)
            && (overlay.draft.points[0].y >= overlay.sy) && (overlay.draft.points[0].y < overlay.sy + overlay.height)
        visible: mine
        enabled: mine
        x: mine ? overlay.draft.points[0].x - overlay.sx : 0
        y: mine ? overlay.draft.points[0].y - overlay.sy : 0
        color: mine ? overlay.draft.color : "transparent"
        font.family: "Inter"
        font.pixelSize: mine ? overlay.draft.size : 16
        renderType: Text.NativeRendering
        cursorVisible: mine
        autoScroll: false
        onTextEdited: overlay.textChanged(text)
        onMineChanged: if (mine) { text = overlay.draft.text || ""; forceActiveFocus(); }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { overlay.textCommitted(); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { e.accepted = false; }
        }
    }
}
