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

    signal openProposal(var proposal)
    signal openOffer(var offer)
    signal openChallenge(var challenge)
    signal openProject(var project)
    signal navigate(string pageKey)

    readonly property var pending: app ? Logic.pendingProposals(app, now) : []
    readonly property var activeProjectList: app ? Logic.activeProjects(app) : []
    readonly property var featuredOffer: app && app.offers.length ? app.offers[0] : null
    readonly property var nextChallenge: app ? Logic.nextChallenge(app, now) : null

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
            spacing: 18

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 196
                radius: Theme.radiusXL
                color: Theme.forest
                clip: true

                Image {
                    anchors.fill: parent
                    source: "../assets/dhun-satellite.jpg"
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.4
                    visible: status === Image.Ready
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#10231A" }
                        GradientStop { position: 0.55; color: "#10231AEE" }
                        GradientStop { position: 1.0; color: "#10231A66" }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 24

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 600
                        spacing: 7

                        RowLayout {
                            spacing: 7

                            Rectangle {
                                implicitWidth: seasonRow.implicitWidth + 16
                                implicitHeight: 22
                                radius: 11
                                color: "#2B4530"

                                RowLayout {
                                    id: seasonRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Theme.lime
                                    }
                                    Text {
                                        text: "RABI 2026–27 · SITE OPEN"
                                        color: "#DDE9C9"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.letterSpacing: 1
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                text: "26.7113° N · 75.5901° E"
                                color: "#93AB98"
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "The commons is\nsolvent and in season."
                            color: "#F5F3E6"
                            font.family: Theme.displayFont
                            font.pixelSize: 29
                            lineHeight: 1.04
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Three parties hold one treasury. Funder issues and places capital, Dhun coordinates the field, stewards execute the season. Every release needs a second signature."
                            color: "#B7C8B7"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.preferredWidth: 286
                        spacing: 9

                        Text {
                            text: "THIS SEASON"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Repeater {
                                model: [
                                    { label: "Treasury", value: app ? Logic.formatNumber(app.wallets.vault) : "", unit: "DHN" },
                                    { label: "In field", value: app ? String(activeProjectList.length) : "", unit: "projects" },
                                    { label: "Covenant", value: app ? Logic.formatNumber(app.wallets.conservation) : "", unit: "DHN" }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.value
                                        color: "#F4F7E9"
                                        font.family: Theme.displayFont
                                        font.pixelSize: 21
                                    }
                                    Text {
                                        text: modelData.unit
                                        color: "#8FA795"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#2C4634"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: app ? Object.keys(app.roles) : []

                                delegate: Rectangle {
                                    required property string modelData
                                    width: 23
                                    height: 23
                                    radius: 11.5
                                    color: Theme.roleColor(modelData)

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData === "funder" ? "A" : (modelData === "dhun" ? "M" : "K")
                                        color: Theme.roleText(modelData)
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Text {
                                text: app ? ("2-of-" + app.token.members + " quorum · " + pending.length + " open") : ""
                                color: "#9DB29F"
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                Layout.leftMargin: 3
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatTile {
                    Layout.fillWidth: true
                    label: "TOTAL SUPPLY"
                    value: app ? Logic.formatNumber(Logic.totalSupply(app)) : ""
                    caption: app ? ("fully backed at a ₹" + app.token.floorINR + " floor") : ""
                    accent: Theme.limeDeep
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "MULTISIG VAULT"
                    value: app ? Logic.formatNumber(app.wallets.vault) : ""
                    caption: "2 signatures required"
                    accent: Theme.gold
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "CONSERVATION RESERVE"
                    value: app ? Logic.formatNumber(app.wallets.conservation) : ""
                    caption: "water · habitat · nesting"
                    accent: Theme.forestMid
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "EXTERNAL HOLDERS"
                    value: app ? Logic.formatNumber(app.wallets.external) : ""
                    caption: app ? ("₹" + Logic.formatNumber(app.token.fiatRaised / 100000) + "k raised") : ""
                    accent: Theme.clay
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 640
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Needs a signature"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 19
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: allText.implicitWidth + 14
                            implicitHeight: 24
                            radius: 12
                            color: allMouse.containsMouse ? Theme.sage : "transparent"

                            Text {
                                id: allText
                                anchors.centerIn: parent
                                text: "Wallet →"
                                color: Theme.forestMid
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: allMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.navigate("wallet")
                            }
                        }
                    }

                    Repeater {
                        model: page.pending.slice(0, 3)

                        delegate: ProposalRow {
                            required property var modelData
                            Layout.fillWidth: true
                            app: page.app
                            proposal: modelData
                            now: page.now
                            activeRole: page.activeRole
                            onOpen: function (proposal) { page.openProposal(proposal) }
                        }
                    }

                    Card {
                        visible: page.pending.length === 0
                        Layout.fillWidth: true
                        padding: 20
                        fill: Theme.white

                        EmptyState {
                            Layout.fillWidth: true
                            glyph: "✓"
                            title: "Nothing waiting"
                            body: "Every proposal has the signatures it needs. The next release can be executed from the wallet."
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 310
                    spacing: 12

                    Card {
                        Layout.fillWidth: true
                        padding: 16
                        gap: 0
                        fill: Theme.forest
                        stroke: Theme.forest

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "MARKET WINDOW"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1.4
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: Theme.lime
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            text: page.featuredOffer ? page.featuredOffer.title : ""
                            color: "#F4F7E9"
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                            text: page.featuredOffer
                                  ? page.featuredOffer.supplier + " · " + page.featuredOffer.unit
                                  : ""
                            color: "#A5B9A7"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            spacing: 6

                            Text {
                                text: page.featuredOffer ? Logic.formatNumber(page.featuredOffer.price) : ""
                                color: "#F4F7E9"
                                font.family: Theme.displayFont
                                font.pixelSize: 22
                            }
                            Text {
                                text: "DHN"
                                color: Theme.limeDeep
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 4
                            }

                            Item { Layout.fillWidth: true }

                            ActionButton {
                                compact: true
                                variant: "lime"
                                text: "Buy"
                                onClicked: page.openOffer(page.featuredOffer)
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
                                text: "NEXT CLOSING WINDOW"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1.4
                                font.weight: Font.DemiBold
                            }

                            Item { Layout.fillWidth: true }

                            Pill {
                                visible: page.nextChallenge !== null
                                text: page.nextChallenge ? Logic.countdown(page.nextChallenge.windowEnd, page.now) : ""
                                fg: Theme.clayDeep
                                bg: Theme.clayLight
                                fontSize: 8
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            text: page.nextChallenge ? page.nextChallenge.title : "No open challenge"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            text: page.nextChallenge
                                  ? Logic.findProject(page.app, page.nextChallenge.projectId).title
                                  : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 10

                            Text {
                                text: page.nextChallenge ? Logic.formatNumber(page.nextChallenge.bounty) : ""
                                color: Theme.ink
                                font.family: Theme.displayFont
                                font.pixelSize: 18
                            }
                            Text {
                                text: "DHN"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 3
                            }

                            Item { Layout.fillWidth: true }

                            ActionButton {
                                compact: true
                                variant: "secondary"
                                text: "View"
                                onClicked: if (page.nextChallenge) page.openChallenge(page.nextChallenge)
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        padding: 16
                        gap: 0
                        fill: Theme.sageLight
                        stroke: "#D5E0C4"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Icon {
                                name: "leaf"
                                color: Theme.forestMid
                                width: 13
                                height: 13
                            }

                            Text {
                                text: "COVENANT IN FORCE"
                                color: Theme.forestMid
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1.2
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 7
                            text: page.app ? page.app.covenants[0].title : ""
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 3
                            text: page.app ? page.app.covenants[0].rule : ""
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        ProgressBar {
                            Layout.fillWidth: true
                            Layout.topMargin: 9
                            value: page.app ? page.app.covenants[0].progress : 0
                            fill: Theme.forestMid
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Text {
                    text: "Live programmes"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 19
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Dhun and stewards compete for every award"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }

                Rectangle {
                    implicitWidth: projectsLink.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: projectsLinkMouse.containsMouse ? Theme.sage : "transparent"

                    Text {
                        id: projectsLink
                        anchors.centerIn: parent
                        text: "All projects →"
                        color: Theme.forestMid
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: projectsLinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.navigate("projects")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Repeater {
                    model: page.activeProjectList

                    delegate: ProjectCard {
                        required property var modelData
                        Layout.fillWidth: true
                        app: page.app
                        project: modelData
                        now: page.now
                        activeRole: page.activeRole
                        onOpenProject: function (project) { page.openProject(project) }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "Local rehearsal · seeded balances and locally derived signatures. No LEZ chain, no real funds. The production wallet binds these screens to the dhun_commons program on LEZ testnet 0.4."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
