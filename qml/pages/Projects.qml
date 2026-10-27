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

    signal openProject(var project)
    signal awardBid(var project, var bid)

    readonly property var filters: ["All", "Active", "Bidding", "Draft"]
    readonly property var biddingProject: {
        if (!app) return null;
        for (var i = 0; i < app.projects.length; ++i)
            if (app.projects[i].status === "bidding") return app.projects[i];
        return null;
    }
    readonly property var visibleProjects: {
        if (!app) return [];
        if (filter === "All") return app.projects;
        if (filter === "Active") return app.projects.filter(function (project) { return project.status === "active"; });
        if (filter === "Bidding") return app.projects.filter(function (project) { return project.status === "bidding"; });
        return app.projects.filter(function (project) { return project.status === "draft"; });
    }
    readonly property var evidenceMilestones: {
        if (!app) return [];
        var rows = [];
        for (var i = 0; i < app.projects.length; ++i) {
            var project = app.projects[i];
            for (var j = 0; j < project.milestones.length; ++j) {
                var milestone = project.milestones[j];
                if (milestone.status === "evidence")
                    rows.push({ project: project, milestone: milestone });
            }
        }
        return rows;
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

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Programme board"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 24
                }

                Text {
                    Layout.leftMargin: 8
                    text: page.app ? (page.app.projects.length + " programmes · " + Logic.formatNumber(page.app.wallets.projectEscrow) + " DHN in escrow") : ""
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
                    model: page.visibleProjects

                    delegate: ProjectCard {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 460
                        app: page.app
                        project: modelData
                        now: page.now
                        activeRole: page.activeRole
                        onOpenProject: function (project) { page.openProject(project) }
                    }
                }
            }

            Card {
                visible: page.biddingProject !== null
                Layout.fillWidth: true
                Layout.topMargin: 4
                padding: 0
                gap: 0
                fill: Theme.white

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    color: Theme.forest
                    radius: Theme.radiusLarge

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 18
                        color: Theme.forest
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 12

                        ColumnLayout {
                            spacing: 2

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "OPEN COMPETITION"
                                    color: Theme.limeDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 1.4
                                    font.weight: Font.DemiBold
                                }
                                Rectangle { width: 3; height: 3; radius: 1.5; color: "#5C7563" }
                                Text {
                                    text: page.biddingProject ? (page.biddingProject.id + " · " + page.biddingProject.code) : ""
                                    color: "#8FA795"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                }
                            }

                            Text {
                                text: page.biddingProject ? page.biddingProject.title : ""
                                color: "#F4F7E9"
                                font.family: Theme.displayFont
                                font.pixelSize: 20
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignRight
                            Text {
                                text: "ESCROW"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: page.biddingProject ? (Logic.formatNumber(page.biddingProject.budget) + " DHN") : ""
                                color: "#F4F7E9"
                                font.family: Theme.uiFont
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignRight
                                Layout.fillWidth: true
                            }
                        }

                        ActionButton {
                            variant: "lime"
                            compact: true
                            text: "Open brief"
                            onClicked: if (page.biddingProject) page.openProject(page.biddingProject)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 18
                    Layout.topMargin: 12
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: "Dhun and stewards compete in the same market. The award goes to the bid that balances price, speed and the conservation plan — not to the incumbent by default."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 8

                        Text {
                            Layout.preferredWidth: 200
                            text: "TEAM"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.preferredWidth: 80
                            text: "BID"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.preferredWidth: 54
                            text: "DAYS"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "PLAN"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.preferredWidth: 64
                            text: "SCORE"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.preferredWidth: 100
                            text: ""
                        }
                    }

                    Repeater {
                        model: page.biddingProject ? page.biddingProject.bids : []

                        delegate: Rectangle {
                            id: bidRow
                            required property var modelData
                            readonly property bool own: bidRow.modelData.bidder === page.activeRole

                            Layout.fillWidth: true
                            Layout.preferredHeight: 60
                            color: own ? Theme.sageLight : "transparent"
                            radius: 8

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Theme.lineSoft
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                RowLayout {
                                    Layout.preferredWidth: 192
                                    spacing: 7

                                    Avatar {
                                        role: bidRow.modelData.bidder
                                        size: 25
                                    }

                                    ColumnLayout {
                                        spacing: 0
                                        Text {
                                            text: bidRow.modelData.team
                                            color: Theme.ink
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                        RowLayout {
                                            spacing: 4
                                            Text {
                                                text: "rep " + bidRow.modelData.reputation
                                                color: Theme.muted
                                                font.family: Theme.uiFont
                                                font.pixelSize: 7
                                            }
                                            Text {
                                                visible: bidRow.own
                                                text: "· your bid"
                                                color: Theme.forestMid
                                                font.family: Theme.uiFont
                                                font.pixelSize: 7
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 80
                                    text: Logic.formatNumber(bidRow.modelData.amount) + " DHN"
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    Layout.preferredWidth: 54
                                    text: bidRow.modelData.days + " days"
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: bidRow.modelData.plan
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                }

                                RowLayout {
                                    Layout.preferredWidth: 64
                                    spacing: 4
                                    Rectangle {
                                        width: 30
                                        height: 4
                                        radius: 2
                                        color: Theme.paperDeep
                                        Rectangle {
                                            width: 30 * bidRow.modelData.score / 100
                                            height: 4
                                            radius: 2
                                            color: Theme.limeDeep
                                        }
                                    }
                                    Text {
                                        text: String(bidRow.modelData.score)
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ActionButton {
                                    Layout.preferredWidth: 100
                                    compact: true
                                    variant: "secondary"
                                    text: "Propose award"
                                    onClicked: page.awardBid(page.biddingProject, bidRow.modelData)
                                }
                            }
                        }
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
                            text: "Milestones in review"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: page.evidenceMilestones.length + " awaiting release"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 7

                        Repeater {
                            model: page.evidenceMilestones

                            delegate: RowLayout {
                                id: milestoneRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 9

                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 8
                                    color: Theme.goldLight
                                    Icon {
                                        anchors.centerIn: parent
                                        name: "clock"
                                        color: Theme.goldDeep
                                        width: 12
                                        height: 12
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: milestoneRow.modelData.milestone.title
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: milestoneRow.modelData.project.id + " · " + milestoneRow.modelData.project.awardedName + " · " + Logic.timeAgo(milestoneRow.modelData.milestone.submittedAt, page.now)
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: Logic.formatNumber(milestoneRow.modelData.milestone.amount) + " DHN"
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }

                                ActionButton {
                                    compact: true
                                    variant: "secondary"
                                    text: "Review"
                                    onClicked: page.openProject(milestoneRow.modelData.project)
                                }
                            }
                        }

                        Text {
                            visible: page.evidenceMilestones.length === 0
                            text: "No milestone evidence is waiting. Released work appears in the ledger."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            Layout.topMargin: 4
                        }
                    }
                }

                Card {
                    Layout.preferredWidth: 320
                    padding: 17
                    gap: 0
                    fill: Theme.sageLight
                    stroke: "#D5E0C4"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        Icon {
                            name: "leaf"
                            color: Theme.forestMid
                            width: 12
                            height: 12
                        }
                        Text {
                            text: "Conservation covenant"
                            color: Theme.forestMid
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        text: "Every project reserves a share of its escrow for landscape care: water buffers, nesting windows and pollinator strips. The percentage is fixed at award and paid with each milestone release."
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 8

                        Text {
                            text: "Reserve"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: page.app ? (Logic.formatNumber(page.app.wallets.conservation) + " DHN") : ""
                            color: Theme.forestMid
                            font.family: Theme.displayFont
                            font.pixelSize: 18
                        }
                    }
                }
            }
        }
    }
}
