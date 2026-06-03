pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string currentUser: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    Auth {
        id: auth
        user: root.currentUser
        onSucceeded: sessionLock.locked = false
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                s: lockSurface.screen ? lockSurface.screen.height / 1080 : 1
                auth: auth
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { sessionLock.locked = true; }
        function unlock(): void { sessionLock.locked = false; }
    }
}
