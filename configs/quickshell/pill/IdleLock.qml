pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * 錠 IDLE / LOCK sub-surface: the three idle timeouts that drive hypridle, each
 * held in minutes (0 = off). Auto-lock runs the lock script, screen-off blanks
 * the display through DPMS, and suspend sleeps the machine. Any pick regenerates
 * the whole hypridle.conf from the current values and restarts hypridle, so the
 * change lands without a hand edit. Keep-awake in the mixer already inhibits the
 * Wayland idle notification, which pauses every listener while it is on, so this
 * surface never touches that wiring. Reached from the settings index and morphs
 * back to it on an empty click or the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    readonly property string confPath: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
    readonly property string lockScript: Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"

    readonly property var lockOptions: [
        { label: "Off", value: 0 }, { label: "1 min", value: 1 }, { label: "3 min", value: 3 },
        { label: "5 min", value: 5 }, { label: "10 min", value: 10 }, { label: "15 min", value: 15 }
    ]
    readonly property var screenOptions: [
        { label: "Off", value: 0 }, { label: "3 min", value: 3 }, { label: "5 min", value: 5 },
        { label: "10 min", value: 10 }, { label: "15 min", value: 15 }
    ]
    readonly property var suspendOptions: [
        { label: "Off", value: 0 }, { label: "15 min", value: 15 },
        { label: "30 min", value: 30 }, { label: "60 min", value: 60 }
    ]

    rows: []

    /**
     * Builds the full hypridle.conf from the three flag values. The general block
     * is always present; a listener block is appended only for each non-zero
     * timeout, in the order lock, screen-off, suspend. Minutes are written out as
     * seconds.
     */
    function buildConf() {
        var out = "general {\n"
            + "    lock_cmd = " + root.lockScript + "\n"
            + "    before_sleep_cmd = loginctl lock-session\n"
            + "    after_sleep_cmd = hyprctl dispatch dpms on\n"
            + "}\n";

        if (Flags.idleLockMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleLockMin * 60) + "\n"
                + "    on-timeout = " + root.lockScript + "\n"
                + "}\n";

        if (Flags.idleScreenOffMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleScreenOffMin * 60) + "\n"
                + "    on-timeout = hyprctl dispatch dpms off\n"
                + "    on-resume = hyprctl dispatch dpms on\n"
                + "}\n";

        if (Flags.idleSuspendMin > 0)
            out += "\nlistener {\n"
                + "    timeout = " + (Flags.idleSuspendMin * 60) + "\n"
                + "    on-timeout = systemctl suspend\n"
                + "}\n";

        return out;
    }

    function apply() {
        confWriter.setText(buildConf());
        restartProc.running = true;
    }

    FileView {
        id: confWriter
        path: root.confPath
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: restartProc
        command: ["systemctl", "--user", "restart", "hypridle"]
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "錠"
            title: "IDLE / LOCK"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: lockRow
            surface: root
            name: "Auto-lock"
            sub: "Lock the screen after idle"

            SettingsSeg {
                s: root.s
                options: root.lockOptions
                value: Flags.idleLockMin
                onPicked: (v) => { Flags.idleLockMin = v; root.apply(); }
            }
        }

        SettingsRow {
            id: screenRow
            surface: root
            name: "Screen off"
            sub: "Blank the display after idle"

            SettingsSeg {
                s: root.s
                options: root.screenOptions
                value: Flags.idleScreenOffMin
                onPicked: (v) => { Flags.idleScreenOffMin = v; root.apply(); }
            }
        }

        SettingsRow {
            id: suspendRow
            surface: root
            name: "Suspend"
            sub: "Sleep the machine after idle"
            last: true

            SettingsSeg {
                s: root.s
                options: root.suspendOptions
                value: Flags.idleSuspendMin
                onPicked: (v) => { Flags.idleSuspendMin = v; root.apply(); }
            }
        }

        Text {
            topPadding: 12 * root.s
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            width: parent.width
            text: "Keep-awake (in the mixer) pauses all of this while it is on."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 9.5 * root.s
            font.weight: Font.Medium
            wrapMode: Text.WordWrap
        }

        Item { width: 1; height: 10 * root.s }
    }
}
