import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: page

    property var app: null
    property var now: Date.now()
    property string activeRole: "funder"
    property string category: "All"

    signal purchase(var offer)
    signal openSale()
    signal openMint()
    signal openProposal(var proposal)

    readonly property var categories: ["All", "Produce", "Seed & inputs", "Soil & compost", "Water & tools", "Processing & storage", "Labour", "Conservation"]
    readonly property var visibleOffers: {
        if (!app) return [];
        if (category === "All") return app.offers;
        return app.offers.filter(function (offer) { return offer.category === category; });
    }
    readonly property var marketProposals: {
        if (!app) return [];
        return Logic.pendingProposals(app, now).filter(function (proposal) {
            return proposal.kind === "sale" || proposal.kind === "mint" || proposal.kind === "purchase";
        });
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.implicitHeight + 60
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            x: Theme.pagePadding
            y: 24
            width: scroller.width - Theme.pagePadding * 2
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 152
                radius: Theme.radiusXL
                color: Theme.forest

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 26

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "DHN / INR FLOOR"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.4
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            spacing: 6
                            Text {
                                text: page.app ? ("₹" + page.app.token.floorINR) : ""
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 32
                            }
                            Text {
                                text: "per DHN"
                                color: "#A7BCA9"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 6
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "External holders buy DHN outside the commons. Proceeds fund the reserve; the floor is a program-level settlement rule, not a promise of liquidity."
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        color: "#2C4634"
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 330
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { label: "External float", value: page.app ? Logic.formatNumber(page.app.wallets.external) : "" },
                                    { label: "Fiat raised", value: page.app ? ("₹" + Logic.compact(page.app.token.fiatRaised)) : "" },
                                    { label: "Last price", value: "₹10.50" }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.label.toUpperCase()
                                        color: "#829887"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 6
                                        font.letterSpacing: 1
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: modelData.value
                                        color: "#EDF3E2"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            ActionButton {
                                variant: "lime"
                                compact: true
                                text: "Sell externally"
                                onClicked: page.openSale()
                            }

                            ActionButton {
                                variant: "ghost"
                                compact: true
                                text: "Issue tranche"
                                onClicked: page.openMint()
                            }
                        }

                        Text {
                            text: "Funder desk actions · both require a second signature"
                            color: "#7E9583"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    text: "Resource market"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 24
                }

                Text {
                    Layout.leftMargin: 8
                    text: page.app ? (page.app.offers.length + " verified offers · priced in DHN") : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: page.activeRole === "funder"
                          ? "Funder has no single-signer allowance"
                          : ("Single-signer allowance · " + (page.app ? page.app.token.allowance : 0) + " DHN")
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: page.categories

                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: page.category === modelData

                        implicitWidth: chipLabel.implicitWidth + 22
                        implicitHeight: 27
                        radius: 13.5
                        color: active ? Theme.forest : (chipMouse.containsMouse ? Theme.sageLight : Theme.white)
                        border.width: active ? 0 : 1
                        border.color: Theme.line

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: active ? "#F4F7E9" : Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            font.weight: active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.category = modelData
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: page.marketProposals.length > 0
                    text: page.marketProposals.length + " market proposals open"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }

                Rectangle {
                    visible: page.marketProposals.length > 0
                    implicitWidth: marketLink.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: marketLinkMouse.containsMouse ? Theme.sage : "transparent"

                    Text {
                        id: marketLink
                        anchors.centerIn: parent
                        text: "Review →"
                        color: Theme.forestMid
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: marketLinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (page.marketProposals.length) page.openProposal(page.marketProposals[0])
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: page.visibleOffers

                    delegate: OfferCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 320
                        app: page.app
                        offer: modelData
                        activeRole: page.activeRole
                        now: page.now
                        onPurchase: function (offer) { page.purchase(offer) }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    padding: 17
                    gap: 0
                    fill: Theme.white

                    Text {
                        text: "How a purchase clears"
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 8

                        Repeater {
                            model: [
                                { n: "1", title: "Under allowance", body: "One signer pays from the role float. Recorded in the ledger immediately." },
                                { n: "2", title: "Above allowance", body: "Creates a purchase proposal. A second current member must approve." },
                                { n: "3", title: "Settlement", body: "Suppliers redeem DHN against the fiat reserve. Conservation items route to the covenant." }
                            ]

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: Theme.paperDeep
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.n
                                        color: Theme.forestMid
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.body
                                    color: Theme.muted
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
                    Layout.preferredWidth: 300
                    padding: 17
                    gap: 0
                    fill: Theme.sageLight
                    stroke: "#D5E0C4"

                    Text {
                        text: "Market rules"
                        color: Theme.forestMid
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 9
                        spacing: 5

                        Repeater {
                            model: [
                                "Prices are quoted in DHN; fiat settlement happens at the ₹10 floor.",
                                "Only verified suppliers can receive market payments.",
                                "Above 500 DHN, every purchase is a multisig proposal.",
                                "Conservation-tagged stock draws from the covenant first."
                            ]

                            delegate: RowLayout {
                                required property string modelData
                                Layout.fillWidth: true
                                spacing: 6
                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.forestMid
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 5
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    lineHeight: 1.3
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
