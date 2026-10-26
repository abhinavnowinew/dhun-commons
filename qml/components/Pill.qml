import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: pill

    property string text: ""
    property color fg: Theme.ink
    property color bg: Theme.sage
    property color stroke: "transparent"
    property color dotColor: "transparent"
    property int fontSize: 9
    property int horizontalPadding: 9
    property bool strong: false
    property bool mono: false

    implicitHeight: 22
    implicitWidth: pillRow.implicitWidth + horizontalPadding * 2
    radius: height / 2
    color: bg
    border.width: stroke.a > 0 ? 1 : 0
    border.color: stroke

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: 5

        Rectangle {
            visible: pill.dotColor.a > 0
            width: 5
            height: 5
            radius: 3
            color: pill.dotColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: pill.text
            color: pill.fg
            font.pixelSize: pill.fontSize
            font.family: pill.mono ? "Menlo" : Theme.uiFont
            font.weight: pill.strong ? Font.DemiBold : Font.Medium
            font.letterSpacing: pill.mono ? 0.3 : 0.4
            verticalAlignment: Text.AlignVCenter
        }
    }
}
