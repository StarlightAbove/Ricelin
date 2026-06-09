pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Singletons"

/**
 * Media surface: a warm lacquer now-playing card — a prominent shadowed album
 * cover, the track text under a 奏 marker, hand-drawn transport controls with a
 * softly breathing play button, and a clean seekable progress bar. Driven by the
 * active MPRIS player; the pill body shows through as the warm background.
 */
Item {
    id: root

    property real s: 1
    property bool active: false
    signal requestClose()

    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return controllable ? controllable : list[0];
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property string title: hasPlayer && player.trackTitle ? player.trackTitle : "Nothing playing"
    readonly property string artist: {
        if (!hasPlayer)
            return "";
        if (player.trackArtists && player.trackArtists.length > 0)
            return player.trackArtists;
        return player.trackArtist ? player.trackArtist : "";
    }
    readonly property string artUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property bool hasArt: cover.status === Image.Ready && artUrl != ""
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real frac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    Timer {
        interval: 1000
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    ClippingRectangle {
        id: coverBox
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: height
        radius: 13 * root.s
        color: Theme.tileBg

        Image {
            id: cover
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.hasArt
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: parent.width * 0.32
            height: width
            name: "music"
            color: Theme.subtle
            visible: !root.hasArt
        }
    }

    Rectangle {
        anchors.fill: coverBox
        radius: coverBox.radius
        color: "transparent"
        z: -1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.7
            shadowVerticalOffset: 3 * root.s
        }
    }

    Item {
        anchors.left: coverBox.right
        anchors.leftMargin: 16 * root.s
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Row {
            id: marker
            anchors.top: parent.top
            spacing: 7 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "奏"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: 13 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.playing ? "NOW PLAYING" : "PAUSED"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.5 * root.s
            }
        }

        Text {
            id: titleText
            anchors.top: marker.bottom
            anchors.topMargin: 7 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.title
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 16 * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            anchors.top: titleText.bottom
            anchors.topMargin: 2 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            text: root.artist
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
            visible: text.length > 0
        }

        Row {
            id: controls
            anchors.left: parent.left
            anchors.bottom: progress.top
            anchors.bottomMargin: 12 * root.s
            spacing: 18 * root.s

            Item {
                width: 21 * root.s
                height: 21 * root.s
                anchors.verticalCenter: parent.verticalCenter
                GlyphIcon {
                    anchors.fill: parent
                    name: "prev"
                    color: prevArea.containsMouse ? Theme.vermLit : (prevArea.enabled ? Theme.cream : Theme.disabled)
                }
                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.previous();
                }
            }

            Item {
                width: 34 * root.s
                height: 34 * root.s
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: glow
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    radius: width / 2
                    color: Theme.vermLit
                    visible: root.playing
                    opacity: 0.0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 24
                    }
                    SequentialAnimation {
                        running: root.playing
                        loops: Animation.Infinite
                        NumberAnimation { target: glow; property: "opacity"; from: 0.18; to: 0.5; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { target: glow; property: "opacity"; from: 0.5; to: 0.18; duration: 900; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: ppArea.containsMouse ? Theme.vermLit : Theme.verm
                    Behavior on color { ColorAnimation { duration: 120 } }

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 15 * root.s
                        height: width
                        name: root.playing ? "pause" : "play"
                        color: Theme.onAccent
                    }
                    MouseArea {
                        id: ppArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.hasPlayer && root.player.canTogglePlaying
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.togglePlaying();
                    }
                }
            }

            Item {
                width: 21 * root.s
                height: 21 * root.s
                anchors.verticalCenter: parent.verticalCenter
                GlyphIcon {
                    anchors.fill: parent
                    name: "next"
                    color: nextArea.containsMouse ? Theme.vermLit : (nextArea.enabled ? Theme.cream : Theme.disabled)
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canGoNext
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.next();
                }
            }
        }

        Item {
            id: progress
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2 * root.s
            height: 14 * root.s

            Text {
                id: tcur
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmt(root.positionSec)
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
            }
            Text {
                id: ttot
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.fmt(root.lengthSec)
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.features: { "tnum": 1 }
            }
            Rectangle {
                id: track
                anchors.left: tcur.right
                anchors.leftMargin: 10 * root.s
                anchors.right: ttot.left
                anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 4 * root.s
                radius: height / 2
                color: Theme.trackBg

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * root.frac
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.verm }
                        GradientStop { position: 1.0; color: Theme.vermLit }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7 * root.s
                    enabled: root.hasPlayer && root.player.canSeek && root.lengthSec > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (e) => {
                        var f = Math.max(0, Math.min(1, (e.x + 7 * root.s) / track.width));
                        if (root.player)
                            root.player.position = f * root.lengthSec;
                    }
                }
            }
        }
    }
}
