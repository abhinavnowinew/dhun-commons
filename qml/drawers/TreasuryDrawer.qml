import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: drawer

    property var app: null
    property bool open: false
    property string mode: "sale"
    property real now: Date.now()

    signal close()
    signal proposeSale(string buyer, int amount, real price)
    signal proposeMint(int amount, int collateral, string purpose)

    readonly property bool saleMode: mode === "sale"
    readonly property int amount: Math.max(0, Math.floor(Number(amountField.text) || 0))
    readonly property real price: Math.max(0, Number(priceField.text) || 0)
    readonly property int collateral: Math.max(0, Math.floor(Number(collateralField.text) || 0))
    readonly property string buyer: buyerField.text
    readonly property string purpose: purposeField.text
    readonly property real proceeds: Math.round(amount * price)
    readonly property real vaultBalance: app ? Number(app.wallets.vault) : 0
    readonly property int mintedAfter: app ? Number(app.token.issued) + amount : 0
    readonly property bool amountOk: amount > 0 && amount <= vaultBalance
    readonly property bool saleOk: amountOk && buyer.trim().length > 2 && price >= (app ? app.token.floorINR : 10)
    readonly property bool mintOk: amount > 0 && collateral >= amount * (app ? app.token.floorINR : 10) && purpose.trim().length > 3

    anchors.fill: parent

    SideSheet {
        open: drawer.open
        eyebrow: drawer.saleMode ? "Treasury · external placement" : "Treasury · issuance"
        title: drawer.saleMode ? "Sell DHN outside the commons" : "Issue a collateralised tranche"
        subtitle: drawer.saleMode
                  ? "Move DHN from the vault to an external buyer at or above the floor. Proceeds settle into the fiat reserve."
                  : "Create new DHN against fiat collateral. Supply grows only when the collateral is locked and a second signer approves."
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: Theme.radiusLarge
                color: Theme.forest

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 18

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: drawer.saleMode ? "EXTERNAL FLOAT" : "CIRCULATING SUPPLY"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.2
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: drawer.app
                                  ? Logic.formatNumber(drawer.saleMode ? drawer.app.wallets.external : drawer.app.token.issued)
                                  : ""
                            color: "#F6F4E8"
                            font.family: Theme.displayFont
                            font.pixelSize: 25
                        }
                        Text {
                            text: drawer.saleMode ? "held by outside buyers" : "backed at the floor"
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle { width: 1; height: 46; color: "#2C4634" }

                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: "VAULT"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.2
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: drawer.app ? Logic.formatNumber(drawer.vaultBalance) : ""
                            color: "#F6F4E8"
                            font.family: Theme.displayFont
                            font.pixelSize: 25
                        }
                        Text {
                            text: "2-of-3 custody"
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Icon {
                        name: drawer.saleMode ? "external" : "plus"
                        color: Theme.limeDeep
                        width: 22
                        height: 22
                        strokeWidth: 1.4
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 12
                fill: Theme.white

                LabeledField {
                    id: amountField
                    objectName: "amountField"
                    Layout.fillWidth: true
                    label: drawer.saleMode ? "Amount to place" : "Tranche size"
                    placeholder: "DHN"
                    text: "2500"
                    mono: true
                    hint: drawer.saleMode
                          ? "Available to place from the vault: " + Logic.formatNumber(drawer.vaultBalance) + " DHN"
                          : "New supply after issuance: " + Logic.formatNumber(drawer.mintedAfter) + " DHN"
                }

                LabeledField {
                    id: buyerField
                    visible: drawer.saleMode
                    Layout.fillWidth: true
                    label: "External buyer"
                    placeholder: "Buyer or institution"
                    text: "Jaipur Food Co-op"
                }

                LabeledField {
                    id: priceField
                    visible: drawer.saleMode
                    Layout.fillWidth: true
                    label: "Price per DHN (INR)"
                    placeholder: "At or above the floor"
                    text: "10.50"
                    mono: true
                    hint: drawer.price >= (drawer.app ? drawer.app.token.floorINR : 10)
                          ? "At or above the ₹" + (drawer.app ? drawer.app.token.floorINR : 10) + " floor · proceeds " + Logic.formatINR(drawer.proceeds)
                          : "Below the ₹" + (drawer.app ? drawer.app.token.floorINR : 10) + " floor · the program will reject this"
                }

                LabeledField {
                    id: collateralField
                    visible: !drawer.saleMode
                    Layout.fillWidth: true
                    label: "Fiat collateral to lock (INR)"
                    placeholder: "Collateral"
                    text: "25000"
                    mono: true
                    hint: "Required at 1:1 with the ₹" + (drawer.app ? drawer.app.token.floorINR : 10) + " floor · minimum " + Logic.formatINR(drawer.amount * (drawer.app ? drawer.app.token.floorINR : 10))
                }

                LabeledField {
                    id: purposeField
                    visible: !drawer.saleMode
                    Layout.fillWidth: true
                    label: "Tranche purpose"
                    placeholder: "What this issuance funds"
                    text: "Rabi field operations and the seed-bank fit-out"
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
                    Layout.preferredHeight: previewColumn.implicitHeight + 20
                    radius: 10
                    color: Theme.paper

                    ColumnLayout {
                        id: previewColumn
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 6

                        Repeater {
                            model: drawer.saleMode
                                   ? [
                                       { label: "Program", value: "dhun_commons.policy.v1" },
                                       { label: "Instruction", value: "sell_external(buyer=\"" + drawer.buyer + "\", amount=" + drawer.amount + ", price_inr=" + drawer.price + ")" },
                                       { label: "Source → recipient", value: "Multisig vault → external holders" },
                                       { label: "Proceeds", value: Logic.formatINR(drawer.proceeds) },
                                       { label: "Quorum", value: "2 of 3 · expiry 72h" }
                                     ]
                                   : [
                                       { label: "Program", value: "dhun_commons.policy.v1" },
                                       { label: "Instruction", value: "mint(tranche=\"" + drawer.purpose + "\", amount=" + drawer.amount + ", collateral_inr=" + drawer.collateral + ")" },
                                       { label: "Source → recipient", value: "Funder → multisig vault" },
                                       { label: "Collateral lock", value: Logic.formatINR(drawer.collateral) },
                                       { label: "Quorum", value: "2 of 3 · expiry 72h" }
                                     ]

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    visible: modelData.label !== "Instruction"

                                    Text {
                                        Layout.preferredWidth: 110
                                        text: modelData.label
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: modelData.label === "Program" ? Theme.ink : Theme.inkSoft
                                        font.family: modelData.label === "Program" ? Theme.monoFont : Theme.uiFont
                                        font.pixelSize: 9
                                        wrapMode: Text.WrapAnywhere
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                Text {
                                    visible: modelData.label === "Instruction"
                                    Layout.topMargin: 2
                                    text: "INSTRUCTION"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    visible: modelData.label === "Instruction"
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Theme.ink
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                    lineHeight: 1.35
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: ["Distinct second signer", "Expiry enforced on-chain", "No real funds"]
                    delegate: RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 5
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.limeDeep
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 5
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    text: drawer.saleMode ? "Propose external sale" : "Propose issuance"
                    variant: "primary"
                    enabled: drawer.saleMode ? drawer.saleOk : drawer.mintOk
                    onClicked: {
                        if (drawer.saleMode) drawer.proposeSale(drawer.buyer.trim(), drawer.amount, drawer.price);
                        else drawer.proposeMint(drawer.amount, drawer.collateral, drawer.purpose.trim());
                    }
                }

                ActionButton {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: drawer.close()
                }
            }
        }
    }
}
