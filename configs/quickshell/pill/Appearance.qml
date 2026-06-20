pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 相 APPEARANCE sub-surface: the clock format and seconds, the Japanese-glyph
 * toggle that gates every surface header, and the accent-palette mode. Reached
 * from the settings index and morphs back to it on an empty click or the back
 * chevron.
 */
SettingsSurface {
    id: root

    backSurface: "settings"
    implicitHeight: content.implicitHeight

    rows: [
        { item: timeRow, kind: "seg", vals: [false, true], get: function () { return Flags.time12h; }, set: function (v) { Flags.time12h = v; } },
        { item: secRow, kind: "toggle", get: function () { return Flags.clockSeconds; }, set: function (v) { Flags.clockSeconds = v; } },
        { item: glyphRow, kind: "toggle", get: function () { return Flags.showGlyphs; }, set: function (v) { Flags.showGlyphs = v; } },
        { item: accentRow, kind: "seg", vals: [false, true], get: function () { return Flags.dynamicPalette; }, set: function (v) { Flags.dynamicPalette = v; } }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "相"
            title: "APPEARANCE"
            showBack: true
            onBack: root.requestSurface("settings")
        }

        Item { width: 1; height: 12 * root.s }

        SettingsRow {
            id: timeRow
            surface: root
            name: "Time format"
            sub: "24-hour stays the default"

            SettingsSeg {
                s: root.s
                options: [{ label: "24H", value: false }, { label: "12H", value: true }]
                value: Flags.time12h
                onPicked: (v) => Flags.time12h = v
            }
        }

        SettingsRow {
            id: secRow
            surface: root
            name: "Clock seconds"
            sub: "Show :SS in the pill clock"

            LinkToggle {
                s: root.s
                on: Flags.clockSeconds
                onToggled: Flags.clockSeconds = !Flags.clockSeconds
            }
        }

        SettingsRow {
            id: glyphRow
            surface: root
            name: "Japanese glyphs"
            sub: "Kanji on surface headers (蓄 BATTERY…). Off swaps for plain labels."

            LinkToggle {
                s: root.s
                on: Flags.showGlyphs
                onToggled: Flags.showGlyphs = !Flags.showGlyphs
            }
        }

        SettingsRow {
            id: accentRow
            surface: root
            name: "Accent palette"
            sub: "Static = fixed flame · Dynamic = recolor per wallpaper (matugen)"
            last: true

            SettingsSeg {
                s: root.s
                options: [{ label: "Static", value: false }, { label: "Dynamic", value: true }]
                value: Flags.dynamicPalette
                onPicked: (v) => Flags.dynamicPalette = v
            }
        }
    }
}
