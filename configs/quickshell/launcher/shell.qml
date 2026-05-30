import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "lib/fuzzy.js" as Fuzzy

ShellRoot {
    id: root

    property string query: ""
    property var usage: ({})
    property bool shown: false

    onShownChanged: if (shown) root.query = "";

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.shown = !root.shown; }
        function show(): void { root.shown = true; }
        function hide(): void { root.shown = false; }
    }

    FileView {
        id: usageStore
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ricelin/launcher-usage.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = usageStore.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }

    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    function run(entry) {
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
                usageStore.setText(JSON.stringify(root.usage));
                usageStore.waitForJob();
            }
            entry.execute();
        }
        root.shown = false;
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            id: win
            screen: {
                var m = Hyprland.focusedMonitor;
                return m && m.screen ? m.screen : Quickshell.screens[0];
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "launcher"

            anchors { top: true; left: true; right: true; bottom: true }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            Launcher {
                id: launcher
                anchors.centerIn: parent

                entries: root.results
                total: root.totalCount

                onLaunch: (entry) => root.run(entry)
                onQuit: root.shown = false
            }

            Connections {
                target: launcher
                function onQueryChanged() {
                    root.query = launcher.query;
                    launcher.selectedIndex = 0;
                }
            }

            Component.onCompleted: launcher.focusField()
        }
    }
}
