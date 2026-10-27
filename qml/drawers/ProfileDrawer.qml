import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../rewards.js" as Rewards
import "../components"

SideSheet {
    id: drawer

    property var app: null
    property string activePersonId: ""

    signal createProfile(string name, string place, string note)
    signal selectProfile(string id)
    signal openRewards()

    panelWidth: 540

    eyebrow: "Steward signup"
    title: "Your name is the whole account."
    subtitle: "Anyone can join as a steward. Pick a name, say where you work, and the profile is saved on this device — the funder and Dhun parties stay seeded rehearsal roles."

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 78
        radius: 12
        color: Theme.sageLight

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 10

            Rectangle {
                width: 34
                height: 34
                radius: 10
                color: Theme.forest

                Icon {
                    anchors.centerIn: parent
                    name: "user"
                    color: Theme.lime
                    width: 16
                    height: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "You get the steward role"
                    color: Theme.forest
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Stewards file field work, evidence and kitchen plans. Treasury payouts still need two of three signatures."
                    color: Theme.forestMid
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    LabeledField {
        id: nameField
        Layout.fillWidth: true
        label: "Your name"
        placeholder: "e.g. Meera Rathore"
        hint: "Shown on the field calendar and in the coordination room. Two characters minimum."
        maximumLength: 60
    }

    LabeledField {
        id: placeField
        Layout.fillWidth: true
        label: "Place"
        placeholder: "e.g. Khejri Mandal, Barmer"
        maximumLength: 80
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "What do you work on?"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 7
        font.letterSpacing: 1.1
        font.weight: Font.DemiBold
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: 9
        color: Theme.white
        border.width: 1
        border.color: noteField.activeFocus ? "#A8BE9B" : Theme.line

        TextArea {
            id: noteField
            anchors.fill: parent
            anchors.margins: 9
            placeholderText: "Beds, orchard, seed bank, nursery…"
            placeholderTextColor: Theme.mutedLight
            color: Theme.ink
            font.family: Theme.uiFont
            font.pixelSize: 10
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: null
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        ActionButton {
            Layout.fillWidth: true
            variant: "lime"
            text: "Create my steward profile"
            onClicked: drawer.createProfile(nameField.text, placeField.text, noteField.text)
        }

        ActionButton {
            compact: true
            variant: "secondary"
            text: "How DHN is earned"
            onClicked: drawer.openRewards()
        }
    }

    Text {
        Layout.fillWidth: true
        text: "The profile is stored in Basecamp's local settings for this module. It is not a chain account, it does not have its own key, and clearing the app state removes it. Rewards accrue to the profile; payment still moves DHN into the shared steward wallet."
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 8
        lineHeight: 1.45
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.line
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "PROFILES ON THIS DEVICE"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 7
            font.letterSpacing: 1.3
            font.weight: Font.DemiBold
        }

        Pill {
            text: drawer.app && drawer.app.people ? (drawer.app.people.length + " total") : "0"
            fg: Theme.forestMid
            bg: Theme.sageLight
            fontSize: 8
        }
    }

    Repeater {
        model: drawer.app && drawer.app.people ? drawer.app.people : []

        delegate: Rectangle {
            required property var modelData
            readonly property bool active: modelData.id === drawer.activePersonId
            readonly property var totals: Rewards.profileTotals(drawer.app, modelData.id)

            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 10
            color: active ? Theme.white : Theme.paperWarm
            border.width: 1
            border.color: active ? "#A8BE9B" : Theme.lineSoft

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.roleSoft(modelData.role)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name.substring(0, 1).toUpperCase()
                        color: Theme.roleText(modelData.role)
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (modelData.role === "steward" ? "Steward" : (modelData.role === "dhun" ? "Dhun field unit" : "Funder"))
                              + (modelData.place ? " · " + modelData.place : "")
                              + " · " + totals.pending + " DHN queued"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                ActionButton {
                    compact: true
                    variant: active ? "secondary" : "ghost"
                    text: active ? "Signing" : "Sign as"
                    enabled: !active
                    onClicked: drawer.selectProfile(modelData.id)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "The funder and Dhun profiles are seeded for the rehearsal. New profiles always receive the steward role."
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 8
        wrapMode: Text.WordWrap
        lineHeight: 1.4
    }
}
