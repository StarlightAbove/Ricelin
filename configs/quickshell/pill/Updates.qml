pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "Singletons"

/**
 * 更 UPDATES sub-surface: reads the installed commit, checks origin/main for newer
 * work and fast-forwards in place, all without a terminal. The live config dir is a
 * symlink into the Ricelin clone, so every git op targets the real repo through
 * `git -C` and the commit short-SHA stands in for a version. Reached from the
 * settings index and morphs back to it on an empty click or the back chevron.
 *
 * The check fetches origin/main and compares local HEAD against FETCH_HEAD by SHA:
 * an inequality means an update is available and reveals the update button, while
 * the behind-count is only a hint (a shallow clone can report zero). Updating runs
 * a plain `pull --ff-only` that fails safely on a dirty tree or conflict; nothing
 * here ever discards or resets, since this is a live machine.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight
    rows: []

    readonly property string repoDir: "$HOME/.config/quickshell"

    property string version: ""
    property string status: ""
    property bool checking: false
    property bool behind: false
    property bool updating: false

    onActiveChanged: {
        if (active) {
            verProc.running = true;
        } else {
            focusRowItem = null;
            kbIndex = -1;
        }
    }

    Process {
        id: verProc
        command: ["sh", "-c", "git -C \"" + root.repoDir + "\" log -1 --format='%h %cs'"]
        stdout: StdioCollector {
            onStreamFinished: root.version = this.text.trim()
        }
    }

    Process {
        id: checkProc
        command: ["sh", "-c",
            "git -C \"" + root.repoDir + "\" fetch --quiet origin main"
            + " && L=$(git -C \"" + root.repoDir + "\" rev-parse HEAD)"
            + " && R=$(git -C \"" + root.repoDir + "\" rev-parse FETCH_HEAD)"
            + " && if [ \"$L\" = \"$R\" ]; then echo uptodate;"
            + " else echo \"behind $(git -C \"" + root.repoDir + "\" rev-list --count HEAD..FETCH_HEAD 2>/dev/null)\"; fi"]
        property string out: ""
        stdout: StdioCollector {
            onStreamFinished: checkProc.out = this.text.trim()
        }
        onExited: function (exitCode) {
            root.checking = false;
            var line = checkProc.out;
            checkProc.out = "";
            if (exitCode !== 0 || line.length === 0) {
                root.behind = false;
                root.status = "check failed (offline?)";
                return;
            }
            if (line === "uptodate") {
                root.behind = false;
                root.status = "up to date";
                return;
            }
            var n = parseInt(line.split(" ")[1], 10);
            root.behind = true;
            root.status = (n > 0 ? n + " update(s) available" : "an update is available");
        }
    }

    Process {
        id: pullProc
        command: ["sh", "-c", "git -C \"" + root.repoDir + "\" pull --ff-only"]
        property string err: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: pullProc.err = this.text.trim()
        }
        onExited: function (exitCode) {
            root.updating = false;
            var e = pullProc.err;
            pullProc.err = "";
            if (exitCode === 0) {
                root.behind = false;
                root.status = "updated · restart the shell to apply";
                verProc.running = true;
            } else {
                root.status = e.length > 0 ? e.split("\n")[0] : "update failed";
            }
        }
    }

    function startCheck() {
        if (root.checking || root.updating)
            return;
        root.checking = true;
        root.behind = false;
        root.status = "";
        checkProc.running = true;
    }

    function startUpdate() {
        if (root.updating)
            return;
        root.updating = true;
        root.status = "";
        pullProc.running = true;
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "更"
            title: "UPDATES"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        Text {
            leftPadding: 12 * root.s
            visible: root.version.length > 0
            text: "version " + root.version.replace(" ", " · ")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
        }

        Item { width: 1; height: 14 * root.s }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s
            spacing: 9 * root.s

            Rectangle {
                id: checkBtn
                width: parent.width
                height: 38 * root.s
                radius: 9 * root.s
                color: checkHover.hovered ? Theme.frameBg : Theme.tileBg
                border.width: 1
                border.color: Theme.border
                opacity: root.checking || root.updating ? 0.55 : 1
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                HoverHandler {
                    id: checkHover
                    enabled: !root.checking && !root.updating
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.checking && !root.updating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startCheck()
                }

                Text {
                    anchors.centerIn: parent
                    text: root.checking ? "Checking…" : "Check for updates"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                id: updateBtn
                width: parent.width
                height: 38 * root.s
                radius: 9 * root.s
                visible: root.behind
                color: Qt.alpha(Theme.vermLit, updateHover.hovered ? 0.30 : 0.20)
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, 0.55)
                opacity: root.updating ? 0.55 : 1
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                HoverHandler {
                    id: updateHover
                    enabled: !root.updating
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.updating
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startUpdate()
                }

                Text {
                    anchors.centerIn: parent
                    text: root.updating ? "Updating…" : "Update now"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                visible: root.status.length > 0
                text: root.status
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
        }
    }
}
