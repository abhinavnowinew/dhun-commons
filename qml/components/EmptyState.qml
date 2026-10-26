import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    id: empty

    property string title: "Nothing here yet"
    property string body: ""
    property string glyph: "◇"

    implicitHeight: 150

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 420)
        spacing: 7

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: empty.glyph
            color: Theme.mutedLight
            font.pixelSize: 28
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: empty.title
            color: Theme.ink
            font.family: Theme.displayFont
            font.pixelSize: 17
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: empty.body
            color: Theme.muted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
