import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

ShellRoot {
    id: root

    property bool shown: false
    property string targetMonitor: ""

    FileView {
        id: vibState
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/nvibrant-value"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = vibState.text();
        if (raw && raw.trim().length) {
            var pct = parseInt(raw.trim());
            if (!isNaN(pct)) {
                var v = Math.round(pct * 1023 / 100);
                Quickshell.execDetached(["nvibrant", String(v), "0", String(v)]);
            }
        }
    }

    PanelWindow {
        id: inhibitWin
        visible: Store.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "sidebar-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Store.keepAwake }
    }

    IpcHandler {
        target: "sidebar"
        function show(mon: string): void {
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
        function hide(): void { root.shown = false; }
        function toggle(mon: string): void {
            if (root.shown) { root.shown = false; return; }
            if (mon && mon.length) root.targetMonitor = mon;
            root.shown = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: modelData ? Math.min(modelData.height / 1080, 1.0) : 1

            screen: modelData
            visible: root.shown && (root.targetMonitor === "" || root.targetMonitor === modelData.name)
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            WlrLayershell.namespace: "sidebar"

            anchors { top: true; right: true; bottom: true; left: true }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            Sidebar {
                id: panel
                s: win.s
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 10 * win.s
                opened: win.visible
                onRequestClose: root.shown = false
            }
        }
    }
}
