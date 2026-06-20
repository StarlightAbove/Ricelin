pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 設 SETTINGS index: a short list of categories grouped into Shell and Control.
 * Each row carries its kanji, name and caption, and morphs the pill into that
 * category's sub-surface. Arrow keys move the focused row with the glowing seam
 * and Return opens it. Appearance, Keybinds and Recording exist today; Display
 * and Updates join the list as their surfaces land.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: keybindsRow, kind: "nav", surface: "keybinds" },
        { item: recordingRow, kind: "nav", surface: "recording" }
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Shell"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SettingsRow {
            id: appearanceRow
            surface: root
            glyph: "相"
            name: "Appearance"
            sub: "Clock, glyphs, accent palette"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        Text {
            topPadding: 16 * root.s
            bottomPadding: 2 * root.s
            leftPadding: 12 * root.s
            text: "Control"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 8.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
        }

        SettingsRow {
            id: keybindsRow
            surface: root
            glyph: "鍵"
            name: "Keybinds"
            sub: "Rebind, add, set commands"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === keybindsRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: recordingRow
            surface: root
            glyph: "録"
            name: "Recording"
            sub: "Capture countdown"
            last: true

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === recordingRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }
    }
}
