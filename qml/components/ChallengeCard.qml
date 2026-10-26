import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic

Rectangle {
    id: card

    property var challenge: null
    property var app: null
    property real now: Date.now()
    property string activeRole: "funder"

    signal openChallenge(var challenge)

    readonly property string stateValue: challenge ? Logic.challengeState(challenge, now) : "unknown"
    readonly property bool urgent: challenge ? (Number(challenge.windowEnd) - now) < 48 * 3600000 && stateValue !== "released" && stateValue !== "expired" : false
    readonly property var project: challenge ? Logic.findProject(app, challenge.projectId) : null

    implicitHeight: 232
    radius: Theme.radiusLarge
    color: challengeMouse.containsMouse ? Theme.paperWarm : Theme.white
    border.width: 1
    border.color: urgent ? "#E3C9A6" : Theme.line

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: card.challenge ? card.challenge.code : ""
                color: Theme.muted
                font.family: Theme.monoFont
                font.pixelSize: 8
                font.letterSpacing: 1
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 4
                visible: card.urgent
                Icon {
                    name: "clock"
                    color: Theme.clayDeep
                    width: 10
                    height: 10
                    strokeWidth: 1.7
                }
                Text {
                    text: card.challenge ? Logic.countdown(card.challenge.windowEnd, card.now) : ""
                    color: Theme.clayDeep
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }

            Pill {
                text: Logic.challengeLabel(card.stateValue)
                fg: {
                    if (card.stateValue === "open") return Theme.forestMid;
                    if (card.stateValue === "claimed") return "#41616E";
                    if (card.stateValue === "evidence") return Theme.goldDeep;
                    if (card.stateValue === "released") return Theme.forestMid;
                    return Theme.muted;
                }
                bg: {
                    if (card.stateValue === "open") return Theme.sageLight;
                    if (card.stateValue === "claimed") return Theme.blueLight;
                    if (card.stateValue === "evidence") return Theme.goldLight;
                    if (card.stateValue === "released") return Theme.sage;
                    return Theme.paperDeep;
                }
                dotColor: card.stateValue === "open" ? Theme.limeDeep : (card.stateValue === "evidence" ? Theme.gold : Theme.blue)
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 9
            text: card.challenge ? card.challenge.title : ""
            color: Theme.ink
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 5
            text: card.challenge ? card.challenge.summary : ""
            color: Theme.inkSoft
            font.family: Theme.uiFont
            font.pixelSize: 9
            lineHeight: 1.38
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
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
            spacing: 10

            ColumnLayout {
                spacing: 1

                RowLayout {
                    spacing: 4
                    Text {
                        text: card.challenge ? Logic.formatNumber(card.challenge.bounty) : ""
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 18
                    }
                    Text {
                        text: "DHN bounty"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 2
                    }
                }

                Text {
                    text: {
                        if (!card.challenge) return "";
                        var owner = card.challenge.claimedName ? card.challenge.claimedName : "unclaimed";
                        return (card.project ? card.project.id : "—") + " · " + owner;
                    }
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            ActionButton {
                compact: true
                variant: card.stateValue === "evidence" ? "gold" : (card.stateValue === "open" ? "primary" : "secondary")
                text: {
                    if (card.stateValue === "open") return "Claim";
                    if (card.stateValue === "claimed") return card.challenge && card.challenge.claimedBy === card.activeRole ? "Evidence" : "View";
                    if (card.stateValue === "evidence") return card.challenge && card.challenge.createdBy === card.activeRole ? "Review" : "View";
                    return "Open";
                }
                onClicked: card.openChallenge(card.challenge)
            }
        }
    }

    MouseArea {
        id: challengeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.openChallenge(card.challenge)
    }
}
