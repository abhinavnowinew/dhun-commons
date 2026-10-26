import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic

Rectangle {
    id: row

    property var proposal: null
    property var app: null
    property real now: Date.now()
    property string activeRole: "funder"
    property bool showAmount: true

    signal open(var proposal)

    readonly property string stateValue: proposal ? Logic.proposalState(app, proposal, now) : "unknown"
    readonly property int approvals: proposal ? Logic.approvalCount(proposal) : 0
    readonly property int threshold: proposal ? Logic.approvalThreshold(app, proposal) : 2
    readonly property bool signedByActive: proposal ? Logic.approvedBy(proposal, activeRole) : false
    readonly property bool actionable: stateValue === "pending" && !signedByActive && !Logic.rejectedBy(proposal, activeRole)

    implicitHeight: 82
    radius: Theme.radiusMedium
    color: rowMouse.containsMouse ? Theme.paperWarm : Theme.white
    border.width: 1
    border.color: stateValue === "ready" ? "#DFC78A" : Theme.line

    Rectangle {
        width: 4
        height: parent.height - 24
        radius: 2
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: {
            if (row.stateValue === "ready") return Theme.gold;
            if (row.stateValue === "executed") return Theme.limeDeep;
            if (row.stateValue === "rejected" || row.stateValue === "expired") return Theme.line;
            if (row.stateValue === "timelocked") return Theme.blue;
            return Theme.forestMid;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 25
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 220
            spacing: 4

            RowLayout {
                spacing: 6

                Text {
                    text: row.proposal ? (Logic.proposalKindLabel(row.proposal.kind) || "").toUpperCase() : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    font.letterSpacing: 1.1
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Theme.mutedLight
                }

                Text {
                    text: row.proposal ? row.proposal.id : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.4
                }

                Rectangle {
                    visible: row.signedByActive
                    implicitWidth: signedLabel.implicitWidth + 12
                    implicitHeight: 16
                    radius: 8
                    color: Theme.sageLight

                    Text {
                        id: signedLabel
                        anchors.centerIn: parent
                        text: "your signature"
                        color: Theme.forestMid
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: row.proposal ? row.proposal.title : ""
                color: Theme.ink
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: row.proposal
                      ? "by " + Logic.roleOrg(row.app, row.proposal.createdBy) + " · " + Logic.countdown(row.proposal.expiresAt, row.now) + " left"
                      : ""
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 78
            spacing: 5

            Text {
                text: row.approvals + " / " + row.threshold + " signed"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
            }

            RowLayout {
                spacing: 4
                Repeater {
                    model: row.app ? Object.keys(row.app.roles) : []

                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool hasSigned: row.proposal ? Logic.approvedBy(row.proposal, modelData) : false
                        readonly property bool hasRejected: row.proposal ? Logic.rejectedBy(row.proposal, modelData) : false

                        width: 16
                        height: 16
                        radius: 8
                        color: hasSigned ? Theme.roleColor(modelData) : (hasRejected ? Theme.clayLight : Theme.paperDeep)
                        border.width: 1
                        border.color: hasSigned ? "transparent" : (hasRejected ? "#D8A18E" : Theme.line)

                        Text {
                            anchors.centerIn: parent
                            text: hasRejected ? "×" : (parent.hasSigned ? "✓" : "")
                            color: parent.hasRejected ? Theme.danger : Theme.forest
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: row.showAmount
            Layout.preferredWidth: 96
            spacing: 1
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: row.proposal ? Logic.formatNumber(row.proposal.amount) : ""
                color: Theme.ink
                font.family: Theme.displayFont
                font.pixelSize: 17
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }

            Text {
                text: "DHN"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }

        Pill {
            Layout.preferredWidth: 116
            Layout.alignment: Qt.AlignVCenter
            text: Logic.stateLabel(row.stateValue)
            fg: {
                if (row.stateValue === "ready") return Theme.goldDeep;
                if (row.stateValue === "executed") return Theme.forestMid;
                if (row.stateValue === "rejected" || row.stateValue === "expired") return Theme.muted;
                if (row.stateValue === "timelocked") return "#41616E";
                return Theme.inkSoft;
            }
            bg: {
                if (row.stateValue === "ready") return Theme.goldLight;
                if (row.stateValue === "executed") return Theme.sageLight;
                if (row.stateValue === "rejected" || row.stateValue === "expired") return Theme.paperDeep;
                if (row.stateValue === "timelocked") return Theme.blueLight;
                return Theme.sage;
            }
            dotColor: {
                if (row.stateValue === "ready") return Theme.gold;
                if (row.stateValue === "executed") return Theme.limeDeep;
                if (row.stateValue === "rejected" || row.stateValue === "expired") return Theme.mutedLight;
                return Theme.forestMid;
            }
        }

        Icon {
            Layout.alignment: Qt.AlignVCenter
            name: "arrow"
            color: row.actionable ? Theme.forestMid : Theme.mutedLight
            width: 14
            height: 14
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.open(row.proposal)
    }
}
