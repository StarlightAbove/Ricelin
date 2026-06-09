pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * The single living flame — the only glowing element in the shell. It orbits the
 * pill's rounded-rectangle edge on a continuous fading trail and flickers. With
 * music it wakes (faster orbit, audio-driven pulse, full brightness); without
 * music it sleeps (slow orbit, dimmed). In "held" mode it parks where it sits and
 * keeps pulsing so the pill can turn it into a click target. "fly" arcs the flame
 * to a target along a quadratic bezier; "off" hides it.
 */
Item {
    id: root

    property real s: 1
    property real pillW: 160
    property real pillH: 38
    property string mode: "orbit"
    property bool musicActive: false
    property real pulse: 0
    property point flyTarget: Qt.point(0, 0)
    property point dockPoint: Qt.point(0, 0)
    property real heat: 0
    signal flightDone()

    readonly property real perim: 2 * (pillW - pillH) + Math.PI * pillH
    property real t: 0.1
    property real px: 0
    property real py: 0
    property real lapFade: 1
    property real lapAngle: 0
    readonly property real lapRadius: 16 * s
    visible: mode !== "off"

    function pathPoint(tt) {
        const r = pillH / 2;
        const a = pillW - 2 * r;
        let sLen = (((tt % 1) + 1) % 1) * perim;
        if (sLen < a) return Qt.point(r + sLen, 0);
        sLen -= a;
        if (sLen < Math.PI * r) {
            const p = sLen / r;
            return Qt.point((pillW - r) + r * Math.sin(p), r - r * Math.cos(p));
        }
        sLen -= Math.PI * r;
        if (sLen < a) return Qt.point(pillW - r - sLen, pillH);
        const q = (sLen - a) / r;
        return Qt.point(r - r * Math.sin(q), r + r * Math.cos(q));
    }

    function syncPoint() {
        const p = pathPoint(t);
        px = p.x;
        py = p.y;
    }

    onPillWChanged: if (mode === "held") syncPoint()
    onPillHChanged: if (mode === "held") syncPoint()

    onDockPointChanged: if (mode === "dock" || mode === "caret") {
        px = dockPoint.x;
        py = dockPoint.y;
    }

    property real flyT: 0
    property point flyStart: Qt.point(0, 0)
    property point flyCtrl: Qt.point(0, 0)

    property var sparkTargets: []
    property real sparkT: 0
    property point sparkStart: Qt.point(0, 0)
    property real headFade: 1

    onModeChanged: {
        if (mode !== "lap") {
            lapFade = 1;
            lapAnim.stop();
        }
        if (mode !== "spark") {
            headFade = 1;
            sparkAnim.stop();
            headFadeAnim.stop();
        }
        if (mode === "fly") {
            flyStart = Qt.point(px, py);
            flyCtrl = Qt.point((px + flyTarget.x) / 2, Math.min(py, flyTarget.y) - pillH);
            flyT = 0;
            flyAnim.restart();
        } else if (mode === "spark") {
            sparkStart = Qt.point(px, py);
            sparkT = 0;
            headFade = 1;
            headFadeAnim.restart();
            sparkAnim.restart();
        } else if (mode === "dock" || mode === "caret") {
            px = dockPoint.x;
            py = dockPoint.y;
        } else if (mode === "lap") {
            lapAngle = -Math.PI / 2;
            lapFade = 1;
            lapAnim.restart();
        } else if (mode === "held" || mode === "orbit") {
            syncPoint();
        }
    }

    onLapAngleChanged: if (mode === "lap") {
        px = dockPoint.x + lapRadius * Math.cos(lapAngle);
        py = dockPoint.y + lapRadius * Math.sin(lapAngle);
    }

    SequentialAnimation {
        id: lapAnim
        NumberAnimation {
            target: root
            property: "lapAngle"
            from: -Math.PI / 2
            to: -Math.PI / 2 + 2 * Math.PI
            duration: 700
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "lapFade"
            from: 1
            to: 0
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: flyAnim
        target: root
        property: "flyT"
        from: 0
        to: 1
        duration: Motion.flight
        easing.type: Motion.easeMorph
        onFinished: root.flightDone()
    }

    NumberAnimation {
        id: sparkAnim
        target: root
        property: "sparkT"
        from: 0
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: headFadeAnim
        target: root
        property: "headFade"
        from: 1
        to: 0
        duration: Motion.fast
        easing.type: Easing.OutCubic
    }

    FrameAnimation {
        running: root.visible && root.mode === "orbit"
        onTriggered: {
            root.t += frameTime * (root.musicActive ? 0.085 : 0.03);
            if (root.t > 1)
                root.t -= 1;
            root.syncPoint();
        }
    }

    onFlyTChanged: {
        if (mode !== "fly") return;
        const u = 1 - flyT;
        px = u * u * flyStart.x + 2 * u * flyT * flyCtrl.x + flyT * flyT * flyTarget.x;
        py = u * u * flyStart.y + 2 * u * flyT * flyCtrl.y + flyT * flyT * flyTarget.y;
    }

    readonly property int trailCount: 22
    readonly property real trailStep: 0.0055

    Repeater {
        model: root.trailCount
        delegate: Rectangle {
            id: trailDot
            required property int index

            readonly property real f: (index + 1) / root.trailCount
            readonly property point pt: root.pathPoint(root.t - (index + 1) * root.trailStep)
            readonly property real sz: (5 - 4 * f) * root.s
            readonly property color tint: f < 0.35 ? Theme.flameGlow : (f < 0.7 ? Theme.vermLit : Theme.verm)

            visible: root.mode === "orbit"
            width: sz
            height: sz
            radius: sz / 2
            antialiasing: true
            x: pt.x - sz / 2
            y: pt.y - sz / 2
            color: Qt.rgba(tint.r, tint.g, tint.b, Math.pow(1 - f, 1.35) * 0.85)
        }
    }

    Repeater {
        model: 4
        delegate: Rectangle {
            id: spark
            required property int index

            readonly property bool live: root.mode === "spark" && root.sparkTargets.length === 4
            readonly property point target: live ? root.sparkTargets[index] : Qt.point(0, 0)
            readonly property real sz: (5 - 3 * root.sparkT) * root.s

            visible: live
            width: sz
            height: sz
            radius: sz / 2
            antialiasing: true
            x: (root.sparkStart.x + (target.x - root.sparkStart.x) * root.sparkT) - sz / 2
            y: (root.sparkStart.y + (target.y - root.sparkStart.y) * root.sparkT) - sz / 2
            color: Qt.rgba(Theme.flameCore.r + (Theme.flameGlow.r - Theme.flameCore.r) * root.sparkT,
                           Theme.flameCore.g + (Theme.flameGlow.g - Theme.flameCore.g) * root.sparkT,
                           Theme.flameCore.b + (Theme.flameGlow.b - Theme.flameCore.b) * root.sparkT,
                           1 - root.sparkT)
        }
    }

    readonly property real heatScale: 1 - 0.4 * root.heat

    Rectangle {
        id: halo
        readonly property real sz: head.sz * (root.mode === "dock" ? 2.0 : 2.8)
        visible: root.mode === "held" || root.mode === "dock"
        width: sz
        height: sz
        radius: sz / 2
        antialiasing: true
        x: root.px - sz / 2
        y: root.py - sz / 2
        color: Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.3)
        opacity: root.lapFade
    }

    Rectangle {
        id: head
        readonly property bool caret: root.mode === "caret"
        readonly property real sz: (root.mode === "dock" ? (7 + 2 * root.pulse) * root.heatScale
            : ((root.mode === "held" ? 9 : 6) + 3 * root.pulse)) * root.s
        width: caret ? 2.5 * root.s : sz
        height: caret ? 15 * root.s : sz
        radius: caret ? 1.5 * root.s : sz / 2
        antialiasing: true
        x: root.px - width / 2
        y: root.py - height / 2
        color: Theme.flameCore
        opacity: ((root.musicActive || root.mode !== "orbit") ? 1 : 0.45) * root.lapFade * root.headFade

        SequentialAnimation on scale {
            running: root.visible && root.mode !== "caret"
            loops: Animation.Infinite
            NumberAnimation { from: 0.88; to: 1.06; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.06; to: 0.88; duration: 700; easing.type: Easing.InOutSine }
        }

        SequentialAnimation on opacity {
            running: root.mode === "caret"
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.25; duration: 550; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.25; to: 1; duration: 550; easing.type: Easing.InOutSine }
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        blurEnabled: true
        blur: 0.42
        blurMax: 10
    }
}
