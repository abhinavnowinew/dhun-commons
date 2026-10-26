import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: tile

    property string label: ""
    property string value: ""
    property string caption: ""
    property color accent: Theme.limeDeep
    property string glyph: ""

    implicitHeight: 112
    radius: Theme.radiusLarge
    color: Theme.white
    border.width: 1
    border.color: Theme.line

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 5
                height: 5
                radius: 3
                color: tile.accent
            }

            Text {
                text: tile.label
                color: Theme.muted
                font.pixelSize: 8
                font.letterSpacing: 1.1
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: tile.glyph.length > 0
                text: tile.glyph
                color: tile.accent
                font.pixelSize: 13
            }
        }

        Text {
            Layout.fillWidth: true
            text: tile.value
            color: Theme.ink
            font.family: Theme.displayFont
            font.pixelSize: 26
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: tile.caption
            color: Theme.muted
            font.pixelSize: 9
            lineHeight: 1.2
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }
    }
}
