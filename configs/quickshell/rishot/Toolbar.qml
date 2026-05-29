// rishot — Vermilion glass toolbar shown under the selection. Tool row (Rect implemented,
// rest inert placeholders flagged `implemented:false`), undo/redo, copy, save (inline path
// field), and a far-right gear (inert in 2a, Phase 2b hook). Emits intent signals only.
import QtQuick
import QtQuick.Layouts

Item {
    id: tb
    implicitWidth: glass.implicitWidth
    implicitHeight: glass.implicitHeight

    property string activeTool: "rect"
    property bool canUndo: false
    property bool canRedo: false
    property string savePath: ""
    property bool saving: false       // inline path field revealed

    signal toolPicked(string tool)
    signal undoRequested()
    signal redoRequested()
    signal copyRequested()
    signal saveRequested(string path)
    signal settingsRequested()        // gear hook (inert in 2a)

    readonly property color glassBg: Qt.rgba(20 / 255, 24 / 255, 34 / 255, 0.92)
    readonly property color glassBorder: "#313a4d"
    readonly property color vermilion: "#e0563b"
    readonly property color idle: "#c4ccda"
    readonly property color sep: "#313a4d"

    // Tool set: only `rect` is wired in 2a; the rest render but are inert (Phase 3).
    readonly property var tools: [
        { id: "rect",    glyph: "▭", implemented: true },
        { id: "ellipse", glyph: "◯", implemented: false },
        { id: "line",    glyph: "╱", implemented: false },
        { id: "arrow",   glyph: "↗", implemented: false },
        { id: "pen",     glyph: "✎", implemented: false },
        { id: "text",    glyph: "T", implemented: false },
        { id: "marker",  glyph: "▰", implemented: false },
        { id: "blur",    glyph: "▒", implemented: false }
    ]

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: 10
        color: tb.glassBg
        border.color: tb.glassBorder
        border.width: 1
        implicitWidth: row.implicitWidth + 12
        implicitHeight: row.implicitHeight + 12

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: tb.tools
                IconButton {
                    required property var modelData
                    label: modelData.glyph
                    active: tb.activeTool === modelData.id
                    dim: !modelData.implemented
                    onClicked: { if (modelData.implemented) tb.toolPicked(modelData.id); }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { label: "↶"; dim: !tb.canUndo; onClicked: { if (tb.canUndo) tb.undoRequested(); } }
            IconButton { label: "↷"; dim: !tb.canRedo; onClicked: { if (tb.canRedo) tb.redoRequested(); } }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            IconButton { label: "⧉"; onClicked: tb.copyRequested() }
            IconButton { label: "▤"; onClicked: tb.saving = true }

            // Inline editable save-path field, revealed by the Save button.
            Rectangle {
                visible: tb.saving
                Layout.preferredWidth: 320
                Layout.preferredHeight: 28
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: tb.glassBorder
                border.width: 1
                TextInput {
                    id: pathField
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#e8ecf4"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 13
                    clip: true
                    text: tb.savePath
                    focus: tb.saving
                    onAccepted: tb.saveRequested(text)
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 20; color: tb.sep; Layout.leftMargin: 3; Layout.rightMargin: 3 }

            // Gear, far right. Inert in 2a — Phase 2b wires settingsRequested().
            IconButton { label: "⚙"; dim: true; onClicked: tb.settingsRequested() }
        }
    }

    onSavingChanged: if (saving) pathField.forceActiveFocus()
}
