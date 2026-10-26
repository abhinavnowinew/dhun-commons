import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: drawer

    property var app: null
    property var project: null
    property var now: Date.now()
    property string activeRole: "funder"
    property string editingMilestoneId: ""

    signal close()
    signal proposeRelease(var project, var milestone)
    signal submitEvidence(var project, var milestone, string text)
    signal awardBid(var project, var bid)
    signal submitBid(var project, int amount, int days, string plan)
    signal fundProject(var project)
    signal openProposal(var proposal)

    readonly property real progress: project ? Logic.projectProgress(project) : 0
    readonly property real released: project ? Logic.projectReleased(project) : 0
    readonly property var pendingForProject: {
        if (!app || !project) return [];
        return Logic.pendingProposals(app, now).filter(function (proposal) {
            return proposal.meta && proposal.meta.projectId === project.id;
        });
    }
    readonly property bool hasOwnBid: {
        if (!project) return false;
        for (var i = 0; i < project.bids.length; ++i)
            if (project.bids[i].bidder === activeRole) return true;
        return false;
    }

    anchors.fill: parent

    onProjectChanged: editingMilestoneId = ""

    SideSheet {
        open: drawer.project !== null
        eyebrow: project ? ("Programme · " + project.id + " · " + project.code) : ""
        title: project ? project.title : ""
        subtitle: project ? (project.window + " · " + project.season + " · " + project.bids.length + " bids") : ""
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: Theme.radiusLarge
                color: Theme.forest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: project && project.awardedName.length > 0
                                  ? ("AWARDED · " + project.awardedName.toUpperCase())
                                  : (project ? (project.status === "bidding" ? "OPEN COMPETITION" : "UNFUNDED DRAFT") : "")
                            color: Theme.limeDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.2
                            font.weight: Font.Bold
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            text: project ? project.conservationPct + "% covenant" : ""
                            fg: "#CFE3BE"
                            bg: "#25432F"
                            fontSize: 7
                        }
                    }

                    RowLayout {
                        spacing: 22

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "BUDGET"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: project ? (Logic.formatNumber(project.budget) + " DHN") : ""
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 23
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "RELEASED"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: Logic.formatNumber(drawer.released) + " DHN"
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 23
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: "IN ESCROW"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: project ? (Logic.formatNumber(Logic.projectEscrow(project)) + " DHN") : ""
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 23
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 3
                            Text {
                                text: Math.round(drawer.progress * 100) + "%"
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 23
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "complete"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 3
                        radius: 1.5
                        color: "#2C4634"

                        Rectangle {
                            width: parent.width * drawer.progress
                            height: 3
                            radius: 1.5
                            color: Theme.limeDeep
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: project ? project.summary : ""
                        color: "#A7BCA9"
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                visible: drawer.pendingForProject.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Theme.goldLight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 11
                        anchors.rightMargin: 8
                        spacing: 7

                        Icon {
                            name: "shield"
                            color: Theme.goldDeep
                            width: 13
                            height: 13
                        }

                        Text {
                            Layout.fillWidth: true
                            text: drawer.pendingForProject.length > 0
                                  ? (drawer.pendingForProject[0].title + " · " + Logic.stateLabel(Logic.proposalState(drawer.app, drawer.pendingForProject[0], drawer.now)))
                                  : ""
                            color: "#7C5A20"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            elide: Text.ElideRight
                        }

                        ActionButton {
                            compact: true
                            variant: "secondary"
                            text: "Review"
                            onClicked: if (drawer.pendingForProject.length) drawer.openProposal(drawer.pendingForProject[0])
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Milestones"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: project ? (project.milestones.length + " stages · release needs a second signature") : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: drawer.project ? drawer.project.milestones : []

                    delegate: Rectangle {
                        id: milestoneCard
                        required property var modelData
                        readonly property string status: modelData.status
                        readonly property bool editable: status === "active" && drawer.project && drawer.project.awardedTo === drawer.activeRole
                        readonly property bool reviewable: status === "evidence"

                        Layout.fillWidth: true
                        Layout.preferredHeight: milestoneColumn.implicitHeight + 24
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: milestoneCard.status === "evidence" ? "#DFC78A" : Theme.line

                        ColumnLayout {
                            id: milestoneColumn
                            x: 14
                            y: 12
                            width: parent.width - 28
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: milestoneCard.status === "released" ? Theme.sageLight
                                         : (milestoneCard.status === "evidence" ? Theme.goldLight : Theme.paper)

                                    Text {
                                        anchors.centerIn: parent
                                        text: milestoneCard.modelData.id
                                        color: milestoneCard.status === "released" ? Theme.forestMid
                                             : (milestoneCard.status === "evidence" ? Theme.goldDeep : Theme.muted)
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: milestoneCard.modelData.title
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: Logic.formatNumber(milestoneCard.modelData.amount) + " DHN · "
                                              + (milestoneCard.status === "evidence"
                                                 ? "evidence filed " + Logic.timeAgo(milestoneCard.modelData.submittedAt, drawer.now)
                                                 : Logic.dueLabel(milestoneCard.modelData.due, drawer.now))
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                    }
                                }

                                Pill {
                                    text: milestoneCard.status === "released" ? "Released"
                                         : (milestoneCard.status === "evidence" ? "In review"
                                            : (milestoneCard.status === "active" ? "Active" : "Planned"))
                                    fg: milestoneCard.status === "released" ? Theme.forestMid
                                         : (milestoneCard.status === "evidence" ? Theme.goldDeep : Theme.muted)
                                    bg: milestoneCard.status === "released" ? Theme.sageLight
                                         : (milestoneCard.status === "evidence" ? Theme.goldLight : Theme.paper)
                                    fontSize: 7
                                }

                                ActionButton {
                                    visible: milestoneCard.reviewable
                                    compact: true
                                    variant: "gold"
                                    text: "Propose release"
                                    onClicked: drawer.proposeRelease(drawer.project, milestoneCard.modelData)
                                }

                                ActionButton {
                                    visible: milestoneCard.editable
                                    compact: true
                                    variant: drawer.editingMilestoneId === milestoneCard.modelData.id ? "ghost" : "secondary"
                                    text: drawer.editingMilestoneId === milestoneCard.modelData.id ? "Cancel" : "Add evidence"
                                    onClicked: {
                                        drawer.editingMilestoneId = drawer.editingMilestoneId === milestoneCard.modelData.id
                                                ? "" : milestoneCard.modelData.id;
                                    }
                                }
                            }

                            Text {
                                visible: milestoneCard.modelData.evidence.length > 0
                                Layout.fillWidth: true
                                Layout.leftMargin: 33
                                text: milestoneCard.modelData.evidence
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
                visible: drawer.editingMilestoneId.length > 0
                Layout.fillWidth: true
                padding: 14
                gap: 8
                fill: Theme.sageLight
                stroke: "#D5E0C4"

                Text {
                    Layout.fillWidth: true
                    text: "Evidence for " + drawer.editingMilestoneId
                    color: Theme.forestMid
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    radius: 8
                    color: Theme.white
                    border.width: 1
                    border.color: "#C9D8BB"

                    TextArea {
                        id: evidenceArea
                        anchors.fill: parent
                        anchors.margins: 8
                        padding: 4
                        placeholderText: "Describe what was done, attach photo references and measurements."
                        placeholderTextColor: Theme.mutedLight
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        wrapMode: TextEdit.Wrap
                        background: null

                        Connections {
                            target: drawer
                            function onEditingMilestoneIdChanged() { evidenceArea.text = ""; }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        Layout.fillWidth: true
                        text: "Evidence is filed to the room and linked to this milestone."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                    }

                    ActionButton {
                        compact: true
                        variant: "primary"
                        text: "File evidence"
                        enabled: evidenceArea.text.trim().length > 10
                        onClicked: {
                            var milestone = Logic.findMilestone(drawer.project, drawer.editingMilestoneId);
                            if (milestone) drawer.submitEvidence(drawer.project, milestone, evidenceArea.text.trim());
                            drawer.editingMilestoneId = "";
                        }
                    }
                }
            }

            RowLayout {
                visible: drawer.project ? drawer.project.status === "bidding" || drawer.project.bids.length > 0 : false
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    text: drawer.project && drawer.project.status === "bidding" ? "Competing bids" : "Bid history"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: drawer.project ? !drawer.hasOwnBid && drawer.project.status === "bidding" : false
                    text: "You can compete for this award"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: -4
                spacing: 6

                Repeater {
                    model: drawer.project ? drawer.project.bids : []

                    delegate: Rectangle {
                        id: bidCard
                        required property var modelData
                        readonly property bool own: bidCard.modelData.bidder === drawer.activeRole

                        Layout.fillWidth: true
                        Layout.preferredHeight: bidColumn.implicitHeight + 22
                        radius: Theme.radiusMedium
                        color: own ? Theme.sageLight : Theme.white
                        border.width: 1
                        border.color: bidCard.modelData.status === "selected" ? "#B9CFA6" : Theme.line

                        ColumnLayout {
                            id: bidColumn
                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Avatar {
                                    role: bidCard.modelData.bidder
                                    size: 24
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: bidCard.modelData.team
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: Logic.formatNumber(bidCard.modelData.amount) + " DHN"
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: bidCard.modelData.days + " days"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                Pill {
                                    text: bidCard.modelData.status === "selected" ? "Selected" : "Open"
                                    fg: bidCard.modelData.status === "selected" ? Theme.forestMid : Theme.muted
                                    bg: bidCard.modelData.status === "selected" ? Theme.sage : Theme.paper
                                    fontSize: 7
                                }

                                ActionButton {
                                    visible: drawer.project ? drawer.project.status === "bidding" : false
                                    compact: true
                                    variant: "secondary"
                                    text: "Award"
                                    onClicked: drawer.awardBid(drawer.project, bidCard.modelData)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.leftMargin: 32
                                text: bidCard.modelData.plan
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
                visible: drawer.project ? drawer.project.status === "bidding" && !drawer.hasOwnBid : false
                Layout.fillWidth: true
                padding: 14
                gap: 9
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Submit a competing bid"
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "as " + (drawer.app ? drawer.app.roles[drawer.activeRole].org : "")
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    LabeledField {
                        id: bidAmountField
                        Layout.fillWidth: true
                        label: "Bid (DHN)"
                        text: drawer.project ? String(Math.round(drawer.project.budget * 0.93)) : ""
                        mono: true
                    }

                    LabeledField {
                        id: bidDaysField
                        Layout.fillWidth: true
                        label: "Duration (days)"
                        text: "20"
                        mono: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 72
                    radius: 8
                    color: Theme.paper
                    border.width: 1
                    border.color: Theme.line

                    TextArea {
                        id: bidPlanField
                        anchors.fill: parent
                        anchors.margins: 8
                        padding: 2
                        placeholderText: "How you would deliver, and what you would conserve."
                        placeholderTextColor: Theme.mutedLight
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: TextEdit.Wrap
                        background: null
                        text: "Local crew, existing stone plinth and a two-week fit-out that keeps spend in the village."
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Text {
                        Layout.fillWidth: true
                        text: "A competing bid is a public commitment, not a token transfer."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                    }

                    ActionButton {
                        compact: true
                        variant: "primary"
                        text: "Submit bid"
                        enabled: Number(bidAmountField.text) > 0 && Number(bidDaysField.text) > 0 && bidPlanField.text.trim().length > 10
                        onClicked: drawer.submitBid(drawer.project, Math.round(Number(bidAmountField.text)), Math.round(Number(bidDaysField.text)), bidPlanField.text.trim())
                    }
                }
            }

            RowLayout {
                visible: drawer.project ? !drawer.project.funded : false
                Layout.fillWidth: true
                spacing: 9

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 66
                    radius: Theme.radiusMedium
                    color: Theme.goldLight

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 8

                        Icon {
                            name: "wallet"
                            color: Theme.goldDeep
                            width: 15
                            height: 15
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "Not funded yet"
                                color: Theme.goldDeep
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Funding moves " + (drawer.project ? Logic.formatNumber(drawer.project.budget) : "") + " DHN from the vault into project escrow. 2-of-3 required."
                                color: "#7C5A20"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                wrapMode: Text.WordWrap
                            }
                        }

                        ActionButton {
                            compact: true
                            variant: "gold"
                            text: "Propose funding"
                            onClicked: drawer.fundProject(drawer.project)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8

                ActionButton {
                    text: "Close"
                    variant: "ghost"
                    onClicked: drawer.close()
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Conservation reserve accrues " + (drawer.project ? drawer.project.conservationPct : 0) + "% of every release"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }
            }
        }
    }
}
