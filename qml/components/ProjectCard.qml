import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic

Rectangle {
    id: card

    property var project: null
    property var app: null
    property real now: Date.now()
    property string activeRole: "funder"

    signal openProject(var project)

    readonly property real progress: project ? Logic.projectProgress(project) : 0
    readonly property int bidCount: project ? project.bids.length : 0

    implicitHeight: 266
    radius: Theme.radiusLarge
    color: projectMouse.containsMouse ? Theme.paperWarm : Theme.white
    border.width: 1
    border.color: Theme.line

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Text {
                text: card.project ? card.project.code : ""
                color: Theme.muted
                font.family: Theme.monoFont
                font.pixelSize: 8
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: 3
                height: 3
                radius: 1.5
                color: Theme.mutedLight
            }

            Text {
                text: card.project ? card.project.season : ""
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
            }

            Item { Layout.fillWidth: true }

            Pill {
                text: {
                    if (!card.project) return "";
                    if (card.project.status === "bidding") return "Bidding · " + card.bidCount;
                    if (card.project.status === "draft") return "Draft";
                    if (card.project.status === "complete") return "Complete";
                    return "Active";
                }
                fg: card.project && card.project.status === "bidding" ? Theme.goldDeep
                    : (card.project && card.project.status === "draft" ? Theme.muted : Theme.forestMid)
                bg: card.project && card.project.status === "bidding" ? Theme.goldLight
                    : (card.project && card.project.status === "draft" ? Theme.paperDeep : Theme.sageLight)
                dotColor: card.project && card.project.status === "bidding" ? Theme.gold
                    : (card.project && card.project.status === "draft" ? Theme.mutedLight : Theme.limeDeep)
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            text: card.project ? card.project.title : ""
            color: Theme.ink
            font.family: Theme.displayFont
            font.pixelSize: 17
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: card.project ? card.project.summary : ""
            color: Theme.inkSoft
            font.family: Theme.uiFont
            font.pixelSize: 9
            lineHeight: 1.4
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 6

            Text {
                text: card.project ? card.project.window : ""
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
            }

            Item { Layout.fillWidth: true }

            Text {
                text: card.project && card.project.awardedName.length > 0
                      ? card.project.awardedName
                      : (card.bidCount > 0 ? card.bidCount + " bids open" : "No bids yet")
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                elide: Text.ElideRight
            }
        }

        ProgressBar {
            Layout.fillWidth: true
            Layout.topMargin: 8
            value: card.progress
            fill: card.project && card.project.status === "bidding" ? Theme.gold : Theme.limeDeep
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 8

            ColumnLayout {
                spacing: 1
                Text {
                    text: "ESCROW"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    font.letterSpacing: 1
                    font.weight: Font.DemiBold
                }
                Text {
                    text: card.project ? Logic.formatNumber(Logic.projectEscrow(card.project)) + " DHN" : ""
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.lineSoft
            }

            ColumnLayout {
                spacing: 1
                Text {
                    text: "COVENANT"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    font.letterSpacing: 1
                    font.weight: Font.DemiBold
                }
                Text {
                    text: card.project ? card.project.conservationPct + "%" : ""
                    color: Theme.forestMid
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 28
                height: 28
                radius: 8
                color: openMouse.containsMouse ? Theme.sage : Theme.paperDeep

                Icon {
                    anchors.centerIn: parent
                    name: "arrow"
                    color: Theme.forestMid
                    width: 13
                    height: 13
                }

                MouseArea {
                    id: openMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.openProject(card.project)
                }
            }
        }
    }

    MouseArea {
        id: projectMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.openProject(card.project)
    }
}
