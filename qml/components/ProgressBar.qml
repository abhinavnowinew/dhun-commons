import QtQuick
import "../theme.js" as Theme

Item {
    id: bar

    property real value: 0
    property color fill: Theme.limeDeep
    property color track: Theme.lineSoft
    property int thickness: 6

    implicitHeight: thickness
    height: thickness

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: bar.track
    }

    Rectangle {
        width: Math.max(0, Math.min(1, bar.value)) * parent.width
        height: parent.height
        radius: height / 2
        color: bar.fill

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
