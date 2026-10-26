import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../components"

Item {
    id: drawer

    property var app: null
    property bool open: false

    signal close()
    signal reset()

    anchors.fill: parent

    SideSheet {
        open: drawer.open
        eyebrow: "Dhun Commons · reference wallet"
        title: "A wallet for a working landscape"
        subtitle: "Three parties, one seasonal treasury, and a policy surface built to answer RFP-005."
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 118
                radius: Theme.radiusLarge
                color: Theme.forest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 5

                    RowLayout {
                        spacing: 7
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 7
                            color: Theme.lime
                            Icon {
                                anchors.centerIn: parent
                                name: "leaf"
                                color: Theme.forest
                                width: 12
                                height: 12
                            }
                        }
                        Text {
                            text: "DHUN COMMONS"
                            color: "#F4F7E9"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: "RFP-005 · MULTISIG & COORDINATION"
                            fg: "#CFE3BE"
                            bg: "#25432F"
                            fontSize: 7
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "An application-first reference wallet: funders issue and place DHN, Dhun and steward collectives compete for project escrow, the field claims time-boxed cultivation challenges, and a conservation covenant is paid before the grower."
                        color: "#B7C8B7"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "Proposal draft for RFP-005 · Logos Collective"
                        color: "#7E9583"
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 0
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "What is real in this build"
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    Pill {
                        text: "Basecamp module"
                        fg: Theme.forestMid
                        bg: Theme.sageLight
                        fontSize: 7
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 9
                    spacing: 6

                    Repeater {
                        model: [
                            "A packaged Logos Basecamp QML module with seven working screens and persistent local state.",
                            "A real 2-of-3 approval state machine: distinct signers, expiry, timelock, rejection, execution and ledger effects.",
                            "Decode-before-sign rows generated from the action payload, with program checks and a derived payload digest.",
                            "Role separation, a 500 DHN single-signer allowance, project escrow and challenge escrow accounting.",
                            "Conservation splits applied on release, with every wallet summing to the 150,000 DHN supply."
                        ]

                        delegate: RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 7
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: Theme.sageLight
                                Icon {
                                    anchors.centerIn: parent
                                    name: "check"
                                    color: Theme.forestMid
                                    width: 8
                                    height: 8
                                    strokeWidth: 2
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 0
                fill: Theme.goldLight
                stroke: "#E4CE9E"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Icon {
                        name: "info"
                        color: Theme.goldDeep
                        width: 13
                        height: 13
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "What is deliberately simulated"
                        color: Theme.goldDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 7
                    spacing: 5

                    Repeater {
                        model: [
                            "No LEZ chain, sequencer or local node is running. There are no keys, no real signatures and no chain state.",
                            "Balances, txids, signatures and fiat figures are seeded demo data. The resident programme is not deployed.",
                            "Rooms are a local preview. Production binds a signed LEZ identity to a Logos Chat E2EE room.",
                            "The ₹10 floor and reserve backing are illustrated settlement rules, not a live market."
                        ]

                        delegate: RowLayout {
                            required property string modelData
                            Layout.fillWidth: true
                            spacing: 6
                            Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: Theme.goldDeep
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 4
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: "#7C5A20"
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 0
                fill: Theme.white

                Text {
                    text: "What the production wallet adds"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: "The proposal commits to a private-by-default M-of-N implementation on LEZ testnet 0.4: private accounts and group-owned shared private accounts, BIP-340 approvals verified at execution, a SPEL policy registry with decode-before-sign, a mandatory time lock, public/private/mixed posture, encrypted coordination rooms, a QML module, a headless CLI, real proving benchmarks and a tier-1 audit milestone."
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.preferredHeight: 58
                    radius: 9
                    color: Theme.paper

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Read RFP-005"
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "github.com/logos-co/rfp · RFPs/RFP-005-multisig-and-coordination.md"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                elide: Text.ElideMiddle
                            }
                        }

                        ActionButton {
                            compact: true
                            variant: "secondary"
                            text: "Open ↗"
                            onClicked: Qt.openUrlExternally("https://github.com/logos-co/rfp/blob/master/RFPs/RFP-005-multisig-and-coordination.md")
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    text: "Reset rehearsal"
                    variant: "danger"
                    onClicked: drawer.reset()
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    text: "Close"
                    variant: "ghost"
                    onClicked: drawer.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "RFP-005 submission deadline listed in the repository: 23/10/26. This build and the accompanying draft are prepared after that date; confirm the current status with the maintainers before filing."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
