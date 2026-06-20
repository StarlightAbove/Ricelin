pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 録 RECORDING sub-surface: the capture countdown delay before a screen recording
 * starts. Reached from the settings index and morphs back to it on an empty click
 * or the back chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: cdRow, kind: "seg", vals: [0, 3, 5, 10], get: function () { return Flags.recordCountdown; }, set: function (v) { Flags.recordCountdown = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "録"
            title: "RECORDING"
            showBack: true
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: cdRow
            surface: root
            name: "Countdown"
            sub: "Delay before capture starts"
            last: true

            SettingsSeg {
                s: root.s
                options: [
                    { label: "Off", value: 0 },
                    { label: "3s", value: 3 },
                    { label: "5s", value: 5 },
                    { label: "10s", value: 10 }
                ]
                value: Flags.recordCountdown
                onPicked: (v) => Flags.recordCountdown = v
            }
        }
    }
}
