import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme

Button {
    id: button

    property string variant: "primary"
    property string iconText: ""
    property int fontSize: 11
    property int hPadding: 15
    property bool compact: false

    implicitHeight: compact ? 30 : 38
    implicitWidth: buttonRow.implicitWidth + hPadding * 2
    hoverEnabled: true
    enabled: true

    readonly property color baseColor: {
        if (!button.enabled) return Theme.lineSoft
        if (button.variant === "primary") return button.hovered ? Theme.forestSoft : Theme.forest
        if (button.variant === "lime") return button.hovered ? Theme.lime : Theme.limeDeep
        if (button.variant === "secondary") return button.hovered ? Theme.sageLight : Theme.white
        if (button.variant === "danger") return button.hovered ? Theme.clayLight : "transparent"
        if (button.variant === "gold") return button.hovered ? "#EFCB8E" : Theme.gold
        return button.hovered ? Theme.sageLight : "transparent"
    }
    readonly property color textColor: {
        if (!button.enabled) return Theme.mutedLight
        if (button.variant === "primary") return "#FFFFFF"
        if (button.variant === "lime") return Theme.forest
        if (button.variant === "danger") return Theme.danger
        if (button.variant === "gold") return "#3E2A0B"
        if (button.variant === "ghost") return button.hovered ? Theme.ink : Theme.muted
        return Theme.ink
    }
    readonly property color strokeColor: {
        if (!button.enabled) return Theme.line
        if (button.variant === "secondary") return Theme.line
        if (button.variant === "danger") return "#D8A18E"
        return "transparent"
    }

    background: Rectangle {
        radius: button.compact ? 8 : 10
        color: button.baseColor
        border.width: button.strokeColor.a > 0 ? 1 : 0
        border.color: button.strokeColor
    }

    contentItem: RowLayout {
        id: buttonRow
        spacing: 7

        Text {
            visible: button.iconText.length > 0
            text: button.iconText
            color: button.textColor
            font.pixelSize: button.fontSize + 2
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: button.text
            color: button.textColor
            font.pixelSize: button.fontSize
            font.family: Theme.uiFont
            font.weight: Font.DemiBold
            font.letterSpacing: 0.2
            verticalAlignment: Text.AlignVCenter
        }
    }
}
