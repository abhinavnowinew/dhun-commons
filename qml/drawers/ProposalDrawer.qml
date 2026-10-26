import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: drawer

    property var app: null
    property var proposal: null
    property real now: Date.now()
    property string activeRole: "funder"

    signal approve()
    signal reject()
    signal execute()
    signal openRoom(string roomId)
    signal close()

    readonly property string stateValue: proposal ? Logic.proposalState(app, proposal, now) : "unknown"
    readonly property bool activeSigned: proposal ? Logic.approvedBy(proposal, activeRole) : false
    readonly property bool activeRejected: proposal ? Logic.rejectedBy(proposal, activeRole) : false
    readonly property bool canApprove: stateValue === "pending" && !activeSigned && !activeRejected

    anchors.fill: parent

    SideSheet {
        open: drawer.proposal !== null
        eyebrow: proposal ? (Logic.proposalKindLabel(proposal.kind) + " · " + proposal.id) : ""
        title: proposal ? proposal.title : ""
        subtitle: proposal ? proposal.summary : ""
        onClose: drawer.close()

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: Theme.radiusLarge
                color: Theme.forest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "AMOUNT"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: stateChip.implicitWidth + 18
                            implicitHeight: 22
                            radius: 11
                            color: drawer.stateValue === "ready" ? "#4A3D1D"
                                : (drawer.stateValue === "executed" ? "#27452F" : "#223A2A")

                            RowLayout {
                                id: stateChip
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: drawer.stateValue === "ready" ? Theme.gold : Theme.lime
                                }
                                Text {
                                    text: Logic.stateLabel(drawer.stateValue)
                                    color: drawer.stateValue === "ready" ? "#F1D9A6" : "#CFE3BE"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: proposal ? Logic.formatNumber(proposal.amount) : "—"
                            color: "#F6F4E8"
                            font.family: Theme.displayFont
                            font.pixelSize: 34
                        }
                        Text {
                            text: "DHN"
                            color: Theme.limeDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 7
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Text {
                            text: proposal ? Logic.sourceLabel(drawer.app, proposal.from) : ""
                            color: "#C3D3C0"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }

                        Icon {
                            name: "arrow"
                            color: "#78907C"
                            width: 11
                            height: 11
                        }

                        Text {
                            text: proposal && proposal.to ? Logic.recipientLabel(drawer.app, proposal.to) : ""
                            color: "#C3D3C0"
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: proposal ? Logic.conservationPctFor(drawer.app, proposal) > 0 : false
                            text: proposal
                                  ? Logic.conservationPctFor(drawer.app, proposal) + "% to covenant"
                                  : ""
                            color: Theme.limeDeep
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { label: "Created", value: drawer.proposal ? Logic.dateTimeLabel(drawer.proposal.createdAt) : "" },
                        { label: "Expires", value: drawer.proposal ? Logic.dateTimeLabel(drawer.proposal.expiresAt) : "" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 2

                            Text {
                                text: modelData.label.toUpperCase()
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.value
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4

                Text {
                    text: "Signatures"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: proposal ? (Logic.approvalCount(proposal) + " of " + Logic.approvalThreshold(drawer.app, proposal) + " required") : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: drawer.app ? Object.keys(drawer.app.roles) : []

                    delegate: Rectangle {
                        id: signerRow
                        required property string modelData
                        readonly property var role: drawer.app ? drawer.app.roles[modelData] : null
                        readonly property bool signed: drawer.proposal ? Logic.approvedBy(drawer.proposal, modelData) : false
                        readonly property bool rejected: drawer.proposal ? Logic.rejectedBy(drawer.proposal, modelData) : false
                        readonly property string sig: {
                            if (!signed || !drawer.proposal) return "";
                            for (var i = 0; i < drawer.proposal.approvals.length; ++i) {
                                if (drawer.proposal.approvals[i].role === modelData)
                                    return drawer.proposal.approvals[i].sig || "";
                            }
                            return "";
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: signerRow.modelData === drawer.activeRole ? "#C9D4B9" : Theme.line

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Avatar {
                                role: signerRow.modelData
                                size: 28
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: signerRow.role ? signerRow.role.org : ""
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        visible: signerRow.modelData === drawer.activeRole
                                        text: "you"
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.letterSpacing: 0.4
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: signerRow.signed
                                          ? "sig " + Logic.shortHash(signerRow.sig) + " · " + signerRow.role.keyFingerprint
                                          : (signerRow.rejected ? "rejected · no signature recorded" : signerRow.role.signer)
                                    color: signerRow.signed ? Theme.muted : Theme.muted
                                    font.family: signerRow.signed ? Theme.monoFont : Theme.uiFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            Pill {
                                text: signerRow.signed ? "Signed" : (signerRow.rejected ? "Rejected" : "Waiting")
                                fg: signerRow.signed ? Theme.forestMid : (signerRow.rejected ? Theme.danger : Theme.muted)
                                bg: signerRow.signed ? Theme.sageLight : (signerRow.rejected ? Theme.clayLight : Theme.paperDeep)
                                dotColor: signerRow.signed ? Theme.limeDeep : (signerRow.rejected ? Theme.clay : Theme.mutedLight)
                            }
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.topMargin: 4
                padding: 16
                gap: 0
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Decode before you sign"
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Pill {
                        text: "registry v1"
                        fg: Theme.muted
                        bg: Theme.paperDeep
                        fontSize: 7
                        mono: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.preferredHeight: decodeColumn.implicitHeight + 20
                    radius: 10
                    color: Theme.paper
                    border.width: 1
                    border.color: Theme.lineSoft

                    ColumnLayout {
                        id: decodeColumn
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 7

                        Repeater {
                            model: drawer.proposal ? Logic.decodeRows(drawer.app, drawer.proposal) : []

                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 132
                                    text: modelData.label
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: modelData.strong ? Theme.ink : Theme.inkSoft
                                    font.family: modelData.mono ? Theme.monoFont : Theme.uiFont
                                    font.pixelSize: modelData.mono ? 8 : 9
                                    font.weight: modelData.strong ? Font.DemiBold : Font.Normal
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    text: "Rehearsal signature · derived locally from the payload digest. Production uses BIP-340 approvals verified by the LEZ program at execution."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }
            }

            Card {
                Layout.fillWidth: true
                padding: 16
                gap: 0
                fill: Theme.white

                Text {
                    text: "Program checks"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 5

                    Repeater {
                        model: drawer.proposal ? Logic.policyChecks(drawer.app, drawer.proposal) : []

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 7

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: modelData.ok ? Theme.sageLight : Theme.clayLight

                                Icon {
                                    anchors.centerIn: parent
                                    name: modelData.ok ? "check" : "close"
                                    color: modelData.ok ? Theme.forestMid : Theme.danger
                                    width: 8
                                    height: 8
                                    strokeWidth: 2
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                text: modelData.ok ? "pass" : "blocked"
                                color: modelData.ok ? Theme.muted : Theme.danger
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.preferredHeight: 1
                color: Theme.line
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    text: drawer.activeSigned ? "Signed by you" : "Approve as " + Logic.roleName(drawer.app, drawer.activeRole)
                    variant: "lime"
                    iconText: "✓"
                    enabled: drawer.canApprove
                    onClicked: drawer.approve()
                }

                ActionButton {
                    visible: drawer.stateValue === "ready"
                    text: "Execute " + Logic.formatNumber(drawer.proposal ? drawer.proposal.amount : 0) + " DHN"
                    variant: "primary"
                    iconText: "→"
                    onClicked: drawer.execute()
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    text: "Reject"
                    variant: "danger"
                    visible: drawer.canApprove
                    onClicked: drawer.reject()
                }

                ActionButton {
                    visible: drawer.stateValue === "executed"
                    text: "View in room"
                    variant: "secondary"
                    onClicked: drawer.openRoom(drawer.proposal && drawer.proposal.room ? drawer.proposal.room : "room-msig")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: proposal && proposal.room
                          ? "Coordination discussion is bound to " + proposal.id + " in the room."
                          : "Execution is recorded in the multisig room and the treasury ledger."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    implicitWidth: roomLink.implicitWidth + 16
                    implicitHeight: 24
                    radius: 8
                    color: roomLinkMouse.containsMouse ? Theme.sage : "transparent"

                    RowLayout {
                        id: roomLink
                        anchors.centerIn: parent
                        spacing: 4
                        Icon {
                            name: "room"
                            color: Theme.forestMid
                            width: 10
                            height: 10
                        }
                        Text {
                            text: "Open room"
                            color: Theme.forestMid
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: roomLinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawer.openRoom("room-msig")
                    }
                }
            }
        }
    }
}
