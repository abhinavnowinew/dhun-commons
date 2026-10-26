import QtQuick
import "../theme.js" as Theme
import "../logic.js" as Logic

Rectangle {
    id: avatar

    property string role: "system"
    property string label: ""
    property int size: 32
    property bool outline: false

    width: size
    height: size
    radius: size / 2
    color: role === "system" ? Theme.forest : Logic.roleSoft(role)
    border.width: outline ? 1 : 0
    border.color: Theme.line

    Text {
        anchors.centerIn: parent
        text: {
            if (avatar.label.length > 0) return avatar.label
            if (avatar.role === "system") return "◇"
            var role = avatar.role
            return String(role).charAt(0).toUpperCase()
        }
        color: avatar.role === "system" ? Theme.lime : Logic.roleColor(avatar.role) === "#E0B25C" ? "#5A4218" : Theme.forest
        font.pixelSize: Math.round(avatar.size * 0.36)
        font.family: avatar.role === "system" ? Theme.uiFont : Theme.displayFont
        font.weight: Font.DemiBold
    }
}
