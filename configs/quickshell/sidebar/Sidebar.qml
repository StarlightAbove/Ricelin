import QtQuick
import "Singletons"

Item {
    id: sidebar
    required property real s
    property bool opened: false
    signal requestClose()

    readonly property real panelWidth: 372 * s
    implicitWidth: panelWidth

    focus: opened
    Keys.onEscapePressed: sidebar.requestClose()

    Rectangle {
        id: card
        width: sidebar.panelWidth
        height: parent.height
        radius: 22 * s
        color: "transparent"
        border.width: 1
        border.color: Theme.border

        opacity: sidebar.opened ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 90 } }

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }

        MouseArea { anchors.fill: parent }

        Flickable {
            id: stack
            anchors.fill: parent
            anchors.margins: 14 * sidebar.s
            contentHeight: inner.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: inner
                width: stack.width
                spacing: 12 * sidebar.s

                Header { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                QuickStrip { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                Network { s: sidebar.s; width: parent.width }
                Bluetooth { s: sidebar.s; width: parent.width }
                Audio { s: sidebar.s; width: parent.width }
                Display { s: sidebar.s; width: parent.width; opened: sidebar.opened }
                Media { s: sidebar.s; width: parent.width; opened: sidebar.opened }
            }
        }
    }
}
