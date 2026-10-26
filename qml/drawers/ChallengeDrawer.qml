import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../data.js" as Data
import "../components"

Item {
    id: drawer

    property var app: null
    property var challenge: null
    property var now: Date.now()
    property string activeRole: "funder"

    signal close()
    signal claim(var challenge)
    signal submitEvidence(var challenge, string text)
    signal proposeRelease(var challenge)
    signal openProposal(var proposal)

    readonly property string stateValue: challenge ? Logic.challengeState(challenge, now) : "unknown"
    readonly property var project: challenge ? Logic.findProject(app, challenge.projectId) : null
    readonly property var releaseProposal: {
        if (!app || !challenge) return null;
        for (var i = 0; i < app.proposals.length; ++i) {
            var proposal = app.proposals[i];
            if (proposal.kind === "challenge_release" && proposal.meta && proposal.meta.challengeId === challenge.id &&
                Logic.isOpen(proposal, app, now))
                return proposal;
        }
        return null;
    }
    readonly property bool claimedByMe: challenge ? challenge.claimedBy === activeRole : false
    readonly property bool canClaim: stateValue === "open" && activeRole !== "funder"
    readonly property bool canFileEvidence: stateValue === "claimed" && claimedByMe
    readonly property bool canProposeRelease: stateValue === "evidence" && releaseProposal === null
    readonly property real timeLeft: challenge ? Math.max(0, Number(challenge.windowEnd) - Number(now)) : 0
    readonly property real urgency: challenge ? Math.min(1, timeLeft / (72 * 3600000)) : 0

    anchors.fill: parent

    onChallengeChanged: evidenceArea.text = ""

    SideSheet {
        open: drawer.challenge !== null
        eyebrow: challenge ? ("Cultivation window · " + challenge.id + " · " + challenge.code) : ""
        title: challenge ? challenge.title : ""
        subtitle: challenge ? (drawer.project ? drawer.project.title : "") : ""
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 142
                radius: Theme.radiusLarge
                color: drawer.stateValue === "evidence" ? "#F1E4CC" : Theme.forest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: {
                                if (drawer.stateValue === "open") return "OPEN TO CLAIM";
                                if (drawer.stateValue === "claimed") return "IN THE FIELD";
                                if (drawer.stateValue === "evidence") return "EVIDENCE IN REVIEW";
                                if (drawer.stateValue === "released") return "RELEASED";
                                return "WINDOW CLOSED";
                            }
                            color: drawer.stateValue === "evidence" ? Theme.clayDeep : Theme.limeDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.3
                            font.weight: Font.Bold
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            text: Logic.challengeLabel(drawer.stateValue)
                            fg: drawer.stateValue === "evidence" ? Theme.clayDeep : "#CFE3BE"
                            bg: drawer.stateValue === "evidence" ? "#FBF4E6" : "#25432F"
                            fontSize: 7
                        }
                    }

                    RowLayout {
                        spacing: 20

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "BOUNTY"
                                color: drawer.stateValue === "evidence" ? "#9A7B45" : "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            RowLayout {
                                spacing: 5
                                Text {
                                    text: drawer.challenge ? Logic.formatNumber(drawer.challenge.bounty) : ""
                                    color: drawer.stateValue === "evidence" ? Theme.ink : "#F6F4E8"
                                    font.family: Theme.displayFont
                                    font.pixelSize: 27
                                }
                                Text {
                                    text: "DHN"
                                    color: drawer.stateValue === "evidence" ? Theme.goldDeep : Theme.limeDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignBottom
                                    Layout.bottomMargin: 5
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "WINDOW CLOSES"
                                color: drawer.stateValue === "evidence" ? "#9A7B45" : "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: drawer.challenge ? Logic.countdown(drawer.challenge.windowEnd, drawer.now) : ""
                                color: drawer.stateValue === "evidence" ? Theme.clayDeep : "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 27
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "COVENANT"
                                color: drawer.stateValue === "evidence" ? "#9A7B45" : "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: drawer.challenge ? (drawer.challenge.conservationPct + "%") : ""
                                color: drawer.stateValue === "evidence" ? Theme.forestMid : "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 27
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignRight
                            Text {
                                text: "ZONE"
                                color: drawer.stateValue === "evidence" ? "#9A7B45" : "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: drawer.challenge ? Data.zoneById(drawer.challenge.zone).name : ""
                                color: drawer.stateValue === "evidence" ? Theme.ink : "#F6F4E8"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: drawer.challenge ? drawer.challenge.summary : ""
                        color: drawer.stateValue === "evidence" ? Theme.inkSoft : "#A7BCA9"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 1.5
                        color: drawer.stateValue === "evidence" ? "#DFC79F" : "#2C4634"

                        Rectangle {
                            width: parent.width * drawer.urgency
                            height: 3
                            radius: 1.5
                            color: drawer.stateValue === "evidence" ? Theme.clay : Theme.limeDeep
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
                    text: "Evidence to return"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: drawer.challenge ? drawer.challenge.evidenceSpec : ""
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    visible: drawer.challenge && drawer.challenge.evidence.length > 0
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.preferredHeight: evidenceText.implicitHeight + 20
                    radius: 9
                    color: Theme.sageLight

                    ColumnLayout {
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 3

                        Text {
                            text: "FILED BY " + (drawer.challenge ? drawer.challenge.claimedName.toUpperCase() : "")
                            color: Theme.forestMid
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            font.letterSpacing: 1
                            font.weight: Font.Bold
                        }

                        Text {
                            id: evidenceText
                            Layout.fillWidth: true
                            text: drawer.challenge ? drawer.challenge.evidence : ""
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: drawer.challenge && drawer.challenge.claimedName.length > 0
                              ? ("Claimed by " + drawer.challenge.claimedName + " · " + Logic.timeAgo(drawer.challenge.claimedAt, drawer.now))
                              : "No one has claimed this window yet."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                    }

                    Text {
                        visible: drawer.releaseProposal !== null
                        text: drawer.releaseProposal
                              ? (drawer.releaseProposal.id + " · " + Logic.stateLabel(Logic.proposalState(drawer.app, drawer.releaseProposal, drawer.now)))
                              : ""
                        color: Theme.goldDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }

            Card {
                visible: drawer.canFileEvidence
                Layout.fillWidth: true
                padding: 14
                gap: 8
                fill: Theme.sageLight
                stroke: "#D5E0C4"

                Text {
                    text: "File evidence before the window closes"
                    color: Theme.forestMid
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: 8
                    color: Theme.white
                    border.width: 1
                    border.color: "#C9D8BB"

                    TextArea {
                        id: evidenceArea
                        anchors.fill: parent
                        anchors.margins: 8
                        padding: 4
                        placeholderText: "What was done, measurements, photo references, geotagged points."
                        placeholderTextColor: Theme.mutedLight
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        wrapMode: TextEdit.Wrap
                        background: null
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "Filing moves the window to review. Release still needs two signatures."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        wrapMode: Text.WordWrap
                    }

                    ActionButton {
                        compact: true
                        variant: "primary"
                        text: "File evidence"
                        enabled: evidenceArea.text.trim().length > 10
                        onClicked: {
                            drawer.submitEvidence(drawer.challenge, evidenceArea.text.trim());
                            evidenceArea.text = "";
                        }
                    }
                }
            }

            Rectangle {
                visible: drawer.stateValue === "open"
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: Theme.radiusMedium
                color: Theme.forest

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: drawer.canClaim
                              ? "Claim as " + (drawer.app ? drawer.app.roles[drawer.activeRole].org : "")
                              : "Field windows are claimed by Dhun and stewards"
                            color: "#F6F4E8"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: drawer.canClaim
                                  ? "The bounty is reserved under your name. If you miss the window, the claim lapses and the funds return to the pool."
                                  : "Switch to the Dhun or steward role to claim this window. Capital approves; the field executes."
                            color: "#A7BCA9"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            wrapMode: Text.WordWrap
                        }
                    }

                    ActionButton {
                        visible: drawer.canClaim
                        variant: "lime"
                        text: "Claim window"
                        onClicked: drawer.claim(drawer.challenge)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    visible: drawer.canProposeRelease
                    text: "Propose release · " + (drawer.challenge ? Logic.formatNumber(drawer.challenge.bounty) : "") + " DHN"
                    variant: "gold"
                    onClicked: drawer.proposeRelease(drawer.challenge)
                }

                ActionButton {
                    visible: drawer.releaseProposal !== null
                    text: "Open release proposal"
                    variant: "primary"
                    onClicked: drawer.openProposal(drawer.releaseProposal)
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
                text: drawer.stateValue === "expired"
                      ? "This window has closed. A new allocation is required to reopen the work."
                      : "Bounties are reserved, not paid, at claim. Execution of the reward is a distinct multisig action."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
