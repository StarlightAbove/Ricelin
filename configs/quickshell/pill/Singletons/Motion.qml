pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property int fast:     120
    readonly property int standard: 220
    readonly property int morph:    320
    readonly property int flight:   600
    readonly property int heat:     1100
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.OutQuint
    readonly property real rSmall: 7
    readonly property real rTile:  13
    readonly property real rCard:  18
}
