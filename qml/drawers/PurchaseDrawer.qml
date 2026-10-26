import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: drawer

    property var app: null
    property var offer: null
    property var now: Date.now()
    property string activeRole: "funder"
    property int qty: 1
    property int initialQty: 1

    signal close()
    signal confirm()

    readonly property real total: offer ? Number(offer.price) * qty : 0
    readonly property real available: app ? Number(app.wallets[activeRole] || 0) : 0
    readonly property real allowance: {
        if (!app) return 0;
        if (app.roles[activeRole] && app.roles[activeRole].allowance !== undefined)
            return Number(app.roles[activeRole].allowance);
        return Number(app.token.allowance);
    }
    readonly property bool underAllowance: activeRole !== "funder" && total <= allowance
    readonly property bool affordable: total <= available && qty <= (offer ? offer.stock : 0)
    readonly property real covenantPart: offer && offer.covenant ? total * 0.05 : 0

    anchors.fill: parent

    onOfferChanged: {
        var stock = offer ? Math.max(1, Number(offer.stock) || 1) : 1;
        qty = Math.max(1, Math.min(Number(initialQty) || 1, stock));
    }

    SideSheet {
        open: drawer.offer !== null
        eyebrow: offer ? (offer.category + " · " + offer.id) : ""
        title: offer ? offer.title : ""
        subtitle: offer ? offer.supplier : ""
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Card {
                Layout.fillWidth: true
                padding: 15
                gap: 0
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 10
                        color: Theme.sageLight
                        Icon {
                            anchors.centerIn: parent
                            name: "market"
                            color: Theme.forestMid
                            width: 16
                            height: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: offer ? offer.description : ""
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            text: offer
                                  ? (offer.unit + " · " + offer.stock + " in stock · ready in " + offer.lead)
                                  : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    height: 1
                    color: Theme.lineSoft
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 9

                    Text {
                        text: offer ? ("₹" + offer.price) : ""
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 22
                    }
                    Text {
                        text: "per " + (offer ? offer.unit : "")
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: minusMouse.containsMouse ? Theme.paperDeep : Theme.paper

                            Text {
                                anchors.centerIn: parent
                                text: "−"
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: minusMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: drawer.qty = Math.max(1, drawer.qty - 1)
                            }
                        }

                        Text {
                            text: String(drawer.qty)
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: 18
                        }

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: plusMouse.containsMouse ? Theme.paperDeep : Theme.paper

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: plusMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: drawer.qty = Math.min(drawer.offer ? drawer.offer.stock : 1, drawer.qty + 1)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                radius: Theme.radiusLarge
                color: Theme.forest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "PAYMENT"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.4
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: drawer.underAllowance ? "SINGLE SIGNER" : "2-OF-3 PROPOSAL"
                            color: drawer.underAllowance ? Theme.limeDeep : Theme.gold
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.Bold
                        }
                    }

                    RowLayout {
                        spacing: 7
                        Text {
                            text: Logic.formatNumber(drawer.total)
                            color: "#F6F4E8"
                            font.family: Theme.displayFont
                            font.pixelSize: 30
                        }
                        Text {
                            text: "DHN"
                            color: Theme.limeDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                        }
                        Text {
                            text: "≈ " + Logic.formatINR(drawer.total * (drawer.app ? drawer.app.token.floorINR : 10))
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "from " + (drawer.app ? drawer.app.roles[drawer.activeRole].org : "")
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 5
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: drawer.allowance <= 0
                              ? "This role has no single-signer allowance. A purchase proposal opens for a second signature; funds move only on execution."
                              : (drawer.underAllowance
                                 ? "Within the " + Logic.formatNumber(drawer.allowance) + " DHN allowance. This settles immediately and is signed by you alone."
                                 : "Above the " + Logic.formatNumber(drawer.allowance) + " DHN allowance. A purchase proposal opens for a second signature; funds move only on execution.")
                        color: "#B7C8B7"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMedium
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 2
                        Text {
                            text: "WALLET AVAILABLE"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: Logic.formatNumber(drawer.available) + " DHN"
                            color: drawer.affordable ? Theme.ink : Theme.danger
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Theme.radiusMedium
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 2
                        Text {
                            text: "SINGLE-SIGNER ALLOWANCE"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: drawer.allowance > 0 ? (Logic.formatNumber(drawer.allowance) + " DHN") : "None for this role"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Rectangle {
                visible: drawer.offer ? drawer.offer.covenant === true : false
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusMedium
                color: Theme.sageLight

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 8

                    Icon {
                        name: "leaf"
                        color: Theme.forestMid
                        width: 14
                        height: 14
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Covenant supplier. 5% of this purchase (" + Logic.formatNumber(drawer.covenantPart) + " DHN) is routed to the habitat reserve."
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !drawer.affordable
                text: drawer.qty > (drawer.offer ? drawer.offer.stock : 0)
                      ? "Quantity exceeds available stock."
                      : "The operating wallet does not cover this purchase. Request a float transfer through a proposal."
                color: Theme.danger
                font.family: Theme.uiFont
                font.pixelSize: 8
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    text: drawer.underAllowance
                          ? ("Pay " + Logic.formatNumber(drawer.total) + " DHN")
                          : ("Propose " + Logic.formatNumber(drawer.total) + " DHN purchase")
                    variant: "primary"
                    enabled: drawer.affordable
                    onClicked: drawer.confirm()
                }

                ActionButton {
                    text: "Cancel"
                    variant: "ghost"
                    onClicked: drawer.close()
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Rehearsal settlement · no fiat or tokens leave this device. Market prices are seeded for the demo."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
