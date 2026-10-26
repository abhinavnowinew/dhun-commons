import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../data.js" as Data
import "../components"

Item {
    id: drawer

    property var app: null
    property var now: Date.now()
    property string activeRole: "dhun"
    property bool open: false
    property string projectId: "PRJ-01"
    property string zone: "farms"
    property int windowHours: 72

    signal close()
    signal propose(string title, string summary, string zone, int bounty, int hours, string evidenceSpec, string projectId)

    readonly property int bounty: Math.max(0, Math.floor(Number(bountyField.text) || 0))
    readonly property string evidenceSpec: evidenceField.text
    readonly property string title: titleField.text
    readonly property string summary: summaryField.text
    readonly property int freePool: app ? Logic.unallocatedChallengePool(app) : 0
    readonly property bool valid: title.trim().length > 4 && summary.trim().length > 8 &&
                                  evidenceSpec.trim().length > 8 && bounty > 0 && bounty <= freePool

    anchors.fill: parent

    SideSheet {
        open: drawer.open
        eyebrow: "Challenge escrow · allocation"
        title: "Open a cultivation window"
        subtitle: "Reserve a bounty against a hard agronomic deadline. Dhun and stewards can allocate to each other; the field claims, executes and returns evidence."
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: Theme.radiusMedium
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 1
                        Text {
                            text: "UNALLOCATED POOL"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Logic.formatNumber(drawer.freePool) + " DHN"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 21
                        }
                        Text {
                            text: "inside the challenge escrow"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: Theme.radiusMedium
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 1
                        Text {
                            text: "CURRENTLY RESERVED"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: drawer.app ? (Logic.formatNumber(Logic.reservedChallenges(drawer.app)) + " DHN") : ""
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 21
                        }
                        Text {
                            text: "across open and field windows"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: Theme.radiusMedium
                    color: Theme.goldLight
                    border.width: 1
                    border.color: "#E4CE9E"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 1
                        Text {
                            text: "AUTHORISATION"
                            color: Theme.goldDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "2-of-3"
                            color: Theme.goldDeep
                            font.family: Theme.displayFont
                            font.pixelSize: 21
                        }
                        Text {
                            text: "distinct signatures"
                            color: "#7C5A20"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 11
                fill: Theme.white

                LabeledField {
                    id: titleField
                    Layout.fillWidth: true
                    label: "Challenge title"
                    placeholder: "What must happen, by when"
                    text: "Sow the north block before the window closes"
                    maximumLength: 90
                }

                LabeledField {
                    id: summaryField
                    Layout.fillWidth: true
                    label: "Field brief"
                    placeholder: "The agronomic reason this is time-sensitive"
                    text: "Sow the north rabi block while soil moisture holds."
                    hint: "Late sowing loses the December establishment window."
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "LINKED PROGRAMME"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.letterSpacing: 1.1
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: drawer.app ? Logic.fundedProjects(drawer.app) : []

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: drawer.projectId === modelData.id
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 8
                                color: active ? Theme.forest : Theme.paper
                                border.width: active ? 0 : 1
                                border.color: Theme.line

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.code
                                    color: active ? "#F4F7E9" : Theme.muted
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: drawer.projectId = modelData.id
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: "ZONE"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.letterSpacing: 1.1
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Repeater {
                            model: Data.zones

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: drawer.zone === modelData.id
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 8
                                color: active ? modelData.color : Theme.paper
                                border.width: active ? 0 : 1
                                border.color: Theme.line

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.short
                                    color: active ? "#2A2410" : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: active ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: drawer.zone = modelData.id
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    LabeledField {
                        id: bountyField
                        Layout.fillWidth: true
                        label: "Bounty (DHN)"
                        placeholder: "Reserved from the pool"
                        text: "1800"
                        mono: true
                        hint: drawer.bounty > drawer.freePool ? "Exceeds the unallocated pool" : "Held in challenge escrow until release"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "WINDOW"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.1
                            font.weight: Font.DemiBold
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [36, 48, 72, 168]
                                delegate: Rectangle {
                                    required property int modelData
                                    readonly property bool active: drawer.windowHours === modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: 8
                                    color: active ? Theme.forest : Theme.paper
                                    border.width: active ? 0 : 1
                                    border.color: Theme.line
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "h"
                                        color: active ? "#F4F7E9" : Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: active ? Font.DemiBold : Font.Normal
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: drawer.windowHours = modelData
                                    }
                                }
                            }
                        }
                    }
                }

                LabeledField {
                    id: evidenceField
                    Layout.fillWidth: true
                    label: "Evidence the field must return"
                    placeholder: "Photos, measurements, geotagged points"
                    text: "Seed lot photo, drill calibration sheet and 12 geotagged points across the north block."
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 0
                fill: Theme.white

                Text {
                    text: "Instruction preview"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 9
                    Layout.preferredHeight: instructionText.implicitHeight + 18
                    radius: 10
                    color: Theme.paper

                    Text {
                        id: instructionText
                        x: 12
                        y: 9
                        width: parent.width - 24
                        text: "allocate_challenge(project=\"" + drawer.projectId + "\", zone=\"" + drawer.zone + "\", bounty=" + drawer.bounty + ", window=" + drawer.windowHours + "h)"
                        color: Theme.inkSoft
                        font.family: Theme.monoFont
                        font.pixelSize: 7
                        wrapMode: Text.WrapAnywhere
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: "A bounty is reserved when the proposal executes. The claimer must submit evidence inside the window; release is a second multisig proposal."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.3
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    text: "Propose challenge · " + Logic.formatNumber(drawer.bounty) + " DHN"
                    variant: "primary"
                    enabled: drawer.valid
                    onClicked: drawer.propose(drawer.title.trim(), drawer.summary.trim(), drawer.zone,
                                              drawer.bounty, drawer.windowHours, drawer.evidenceSpec.trim(), drawer.projectId)
                }

                ActionButton {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: drawer.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: drawer.title.trim().length <= 4
                      ? "Add a specific title before proposing."
                      : (drawer.bounty <= 0 ? "Set a bounty above zero."
                         : (drawer.bounty > drawer.freePool ? "The bounty is larger than the free challenge pool." : ""))
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
