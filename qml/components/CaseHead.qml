import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

ColumnLayout {
    id: head

    property string number: ""
    property string kicker: ""
    property string title: ""
    property string accent: ""
    property string lede: ""
    property bool light: false
    property color accentColor: "#5E2A7D"
    property int titleSize: 38
    property int maxLedeWidth: 760

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            implicitWidth: numberLabel.implicitWidth + 12
            implicitHeight: 20
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: head.light ? "#5C7862" : "#CFC9B8"

            Text {
                id: numberLabel
                anchors.centerIn: parent
                text: head.number
                color: head.light ? "#B7CCB0" : "#6C6758"
                font.family: Theme.monoFont
                font.pixelSize: 9
            }
        }

        Text {
            text: head.kicker.toUpperCase()
            color: head.light ? "#A9C0A9" : "#6C6758"
            font.family: Theme.uiFont
            font.pixelSize: 9
            font.letterSpacing: 2
            font.weight: Font.DemiBold
        }

        Item { Layout.fillWidth: true }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 20
        text: head.title
        color: head.light ? "#F7F4E8" : Theme.ink
        font.family: Theme.displayFont
        font.pixelSize: head.titleSize
        font.letterSpacing: -0.6
        lineHeight: 0.98
        wrapMode: Text.WordWrap
    }

    Text {
        Layout.fillWidth: true
        visible: head.accent !== ""
        text: head.accent
        color: head.light ? Theme.lime : head.accentColor
        font.family: Theme.displayFont
        font.pixelSize: head.titleSize
        font.italic: true
        font.letterSpacing: -0.5
        lineHeight: 0.98
        wrapMode: Text.WordWrap
    }

    Text {
        Layout.fillWidth: true
        Layout.maximumWidth: head.maxLedeWidth
        Layout.topMargin: 18
        visible: head.lede !== ""
        text: head.lede
        color: head.light ? "#C3D2C0" : "#4C5A50"
        font.family: Theme.uiFont
        font.pixelSize: 15
        lineHeight: 1.45
        wrapMode: Text.WordWrap
    }
}
