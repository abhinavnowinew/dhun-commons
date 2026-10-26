import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme

ColumnLayout {
    id: root

    property string label: ""
    property string hint: ""
    property string placeholder: ""
    property alias text: field.text
    property alias input: field
    property bool mono: false
    property int maximumLength: 120

    spacing: 4

    Text {
        text: root.label.toUpperCase()
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 7
        font.letterSpacing: 1.1
        font.weight: Font.DemiBold
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 9
        color: Theme.white
        border.width: 1
        border.color: field.activeFocus ? "#A8BE9B" : Theme.line

        TextField {
            id: field
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            placeholderText: root.placeholder
            placeholderTextColor: Theme.mutedLight
            color: Theme.ink
            font.family: root.mono ? Theme.monoFont : Theme.uiFont
            font.pixelSize: 10
            background: null
            selectByMouse: true
            maximumLength: root.maximumLength
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.hint.length > 0
        text: root.hint
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 7
        wrapMode: Text.WordWrap
        lineHeight: 1.3
    }
}
