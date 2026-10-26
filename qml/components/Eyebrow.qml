import QtQuick
import "../theme.js" as Theme

Text {
    property color tone: Theme.muted
    color: tone
    font.pixelSize: 8
    font.family: Theme.uiFont
    font.letterSpacing: 1.5
    font.weight: Font.DemiBold
}
