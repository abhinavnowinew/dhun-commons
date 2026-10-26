import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: card

    property int padding: 18
    property int gap: 10
    property color fill: Theme.white
    property color stroke: Theme.line
    property int corner: Theme.radiusLarge
    default property alias content: contentColumn.data

    color: fill
    radius: corner
    border.width: 1
    border.color: stroke
    implicitHeight: contentColumn.implicitHeight + padding * 2
    implicitWidth: contentColumn.implicitWidth + padding * 2

    ColumnLayout {
        id: contentColumn
        x: card.padding
        y: card.padding
        width: Math.max(0, card.width - card.padding * 2)
        spacing: card.gap
    }
}
