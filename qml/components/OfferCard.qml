import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic

Rectangle {
    id: card

    property var offer: null
    property var app: null
    property string activeRole: "funder"
    property real now: Date.now()

    signal purchase(var offer)

    implicitHeight: 252
    radius: Theme.radiusLarge
    color: offerMouse.containsMouse ? Theme.paperWarm : Theme.white
    border.width: 1
    border.color: Theme.line

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                implicitWidth: categoryText.implicitWidth + 14
                implicitHeight: 19
                radius: 9.5
                color: Theme.paperDeep

                Text {
                    id: categoryText
                    anchors.centerIn: parent
                    text: card.offer ? card.offer.category : ""
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: card.offer ? card.offer.covenant === true : false
                implicitWidth: covenantRow.implicitWidth + 12
                implicitHeight: 19
                radius: 9.5
                color: Theme.sageLight

                RowLayout {
                    id: covenantRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        name: "leaf"
                        color: Theme.forestMid
                        width: 9
                        height: 9
                        strokeWidth: 1.6
                    }
                    Text {
                        text: "covenant"
                        color: Theme.forestMid
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                visible: card.offer ? card.offer.verified === true : false
                width: 19
                height: 19
                radius: 9.5
                color: Theme.sage

                Icon {
                    anchors.centerIn: parent
                    name: "check"
                    color: Theme.forestMid
                    width: 9
                    height: 9
                    strokeWidth: 2
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: card.offer ? card.offer.title : ""
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
            Layout.topMargin: 4
            text: card.offer ? card.offer.supplier : ""
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 9
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: card.offer ? card.offer.description : ""
            color: Theme.inkSoft
            font.family: Theme.uiFont
            font.pixelSize: 9
            lineHeight: 1.35
            wrapMode: Text.WordWrap
            maximumLineCount: 3
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
            spacing: 8

            ColumnLayout {
                spacing: 1

                RowLayout {
                    spacing: 4
                    Text {
                        text: card.offer ? Logic.formatINR(card.offer.price * 10) : ""
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 19
                    }
                    Text {
                        text: card.offer ? (card.offer.price + " DHN") : ""
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 2
                    }
                }

                Text {
                    text: card.offer ? (card.offer.unit + " · " + card.offer.stock + " available · " + card.offer.lead) : ""
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillWidth: true }

            ActionButton {
                text: "Buy"
                compact: true
                variant: "primary"
                onClicked: card.purchase(card.offer)
            }
        }
    }

    MouseArea {
        id: offerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.purchase(card.offer)
    }
}
