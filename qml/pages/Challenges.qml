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
    property string filter: "All"

    signal openChallenge(var challenge)
    signal allocate()
    signal openProposal(var proposal)

    readonly property var filters: ["All", "Open", "In field", "Evidence"]
    readonly property var nextWindow: app ? Logic.nextChallenge(app, now) : null
    readonly property var visibleChallenges: {
        if (!app) return [];
        if (filter === "All") return app.challenges;
        return app.challenges.filter(function (challenge) {
            return Logic.challengeState(challenge, now) === (filter === "Open" ? "open" : (filter === "In field" ? "claimed" : "evidence"));
        });
    }
    readonly property var releaseProposals: {
        if (!app) return [];
        return Logic.pendingProposals(app, now).filter(function (proposal) {
            return proposal.kind === "challenge_release";
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
                Layout.preferredHeight: 164
                radius: Theme.radiusXL
                color: "#F1E4CC"
                border.width: 1
                border.color: "#E2CFAC"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 20

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        RowLayout {
                            spacing: 6

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: Theme.clay

                                Icon {
                                    anchors.centerIn: parent
                                    name: "clock"
                                    color: "#FCF6E9"
                                    width: 10
                                    height: 10
                                    strokeWidth: 1.8
                                }
                            }

                            Text {
                                text: "TIME-SENSITIVE · NEXT WINDOW CLOSES"
                                color: Theme.clayDeep
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1.3
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.nextWindow ? page.nextWindow.title : "No challenge is open"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 23
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.nextWindow ? page.nextWindow.summary : "Allocators can open a new cultivation window from the challenge escrow."
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.topMargin: 2
                            spacing: 14

                            Text {
                                text: page.nextWindow ? (Logic.findProject(page.app, page.nextWindow.projectId).title) : ""
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }

                            Text {
                                text: page.nextWindow ? ("bounty " + Logic.formatNumber(page.nextWindow.bounty) + " DHN") : ""
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: page.nextWindow ? (page.nextWindow.conservationPct + "% covenant") : ""
                                color: Theme.forestMid
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 210
                        Layout.fillHeight: true
                        radius: Theme.radiusLarge
                        color: "#FBF4E6"
                        border.width: 1
                        border.color: "#E1CFAD"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 3

                            Text {
                                text: "TIME LEFT"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1.2
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: page.nextWindow ? Logic.countdown(page.nextWindow.windowEnd, page.now) : "—"
                                color: Theme.clayDeep
                                font.family: Theme.displayFont
                                font.pixelSize: 30
                            }

                            Text {
                                Layout.fillWidth: true
                                text: page.nextWindow ? page.nextWindow.code : ""
                                color: Theme.muted
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                            }

                            Item { Layout.fillHeight: true }

                            ActionButton {
                                Layout.fillWidth: true
                                compact: true
                                variant: "primary"
                                text: "Open window"
                                onClicked: if (page.nextWindow) page.openChallenge(page.nextWindow)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: "EVIDENCE THE FIELD MUST RETURN"
                            color: Theme.clayDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.1
                            font.weight: Font.Bold
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.nextWindow ? page.nextWindow.evidenceSpec : "—"
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            ActionButton {
                                compact: true
                                variant: "secondary"
                                text: "+ Allocate"
                                onClicked: page.allocate()
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "pool " + (page.app ? Logic.formatNumber(Logic.unallocatedChallengePool(page.app)) : "0") + " free"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2

                Text {
                    text: "Cultivation windows"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 19
                }

                Text {
                    Layout.leftMargin: 8
                    text: page.app ? (page.app.challenges.length + " windows · " + Logic.formatNumber(Logic.reservedChallenges(page.app)) + " DHN reserved") : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4

                    Repeater {
                        model: page.filters

                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool active: page.filter === modelData

                            implicitWidth: filterLabel.implicitWidth + 18
                            implicitHeight: 26
                            radius: 13
                            color: active ? Theme.forest : (filterMouse.containsMouse ? Theme.sageLight : "transparent")
                            border.width: active ? 0 : 1
                            border.color: Theme.line

                            Text {
                                id: filterLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: active ? "#F4F7E9" : Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: active ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: filterMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.filter = modelData
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: page.visibleChallenges

                    delegate: ChallengeCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 460
                        app: page.app
                        challenge: modelData
                        now: page.now
                        activeRole: page.activeRole
                        onOpenChallenge: function (challenge) { page.openChallenge(challenge) }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    padding: 17
                    gap: 0
                    fill: Theme.white

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Challenge escrow"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.app ? (Logic.formatNumber(page.app.wallets.challengeEscrow) + " DHN held") : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        value: page.app ? Logic.reservedChallenges(page.app) / Math.max(1, page.app.wallets.challengeEscrow) : 0
                        fill: Theme.gold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 7
                        spacing: 10

                        Text {
                            text: page.app ? (Logic.formatNumber(Logic.reservedChallenges(page.app)) + " reserved") : ""
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }

                        Text {
                            text: page.app ? (Logic.formatNumber(Logic.unallocatedChallengePool(page.app)) + " unallocated") : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "Claims reserve the bounty; release needs a second signature."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        visible: page.releaseProposals.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 11
                        Layout.preferredHeight: releaseRow.implicitHeight + 20
                        radius: 10
                        color: Theme.paper

                        RowLayout {
                            id: releaseRow
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Icon {
                                name: "shield"
                                color: Theme.goldDeep
                                width: 14
                                height: 14
                            }

                            Text {
                                Layout.fillWidth: true
                                text: page.releaseProposals.length > 0
                                      ? (page.releaseProposals[0].title + " is waiting for a second signature.")
                                      : ""
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                            }

                            ActionButton {
                                compact: true
                                variant: "secondary"
                                text: "Review"
                                onClicked: if (page.releaseProposals.length) page.openProposal(page.releaseProposals[0])
                            }
                        }
                    }
                }

                Card {
                    Layout.preferredWidth: 330
                    padding: 17
                    gap: 0
                    fill: Theme.forest
                    stroke: Theme.forest

                    Text {
                        text: "WHY WINDOWS CLOSE"
                        color: Theme.limeDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.letterSpacing: 1.3
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 7
                        text: "Sowing, selective harvest and trench checks only work inside a short agronomic window. A challenge carries a hard expiry so the bounty cannot be claimed after the crop has moved on."
                        color: "#C4D3C2"
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.45
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 8

                        Text {
                            text: "Unallocated"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.app ? (Logic.formatNumber(Logic.unallocatedChallengePool(page.app)) + " DHN") : ""
                            color: "#F4F7E9"
                            font.family: Theme.displayFont
                            font.pixelSize: 20
                        }
                    }
                }
            }
        }
    }
}
