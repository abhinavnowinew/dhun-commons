import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    id: sheet

    property bool open: false
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    property int panelWidth: 560
    default property alias bodyData: contentColumn.data

    signal close()

    anchors.fill: parent
    visible: open
    z: 100

    Rectangle {
        anchors.fill: parent
        color: "#0C1911"
        opacity: sheet.open ? 0.42 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.close()
        }
    }

    Rectangle {
        id: panel
        width: Math.min(sheet.panelWidth, sheet.width - 80)
        height: sheet.height
        anchors.top: parent.top
        x: sheet.open ? sheet.width - width : sheet.width
        color: Theme.paper
        border.width: 0

        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Rectangle {
            width: 1
            height: parent.height
            anchors.left: parent.left
            color: "#2A3B2E"
            opacity: 0.18
        }

        Rectangle {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: headerColumn.implicitHeight + 46
            color: Theme.paper
            z: 2

            ColumnLayout {
                id: headerColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 28
                anchors.rightMargin: 24
                anchors.topMargin: 26
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: sheet.eyebrow.toUpperCase()
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.6
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 9
                        color: closeMouse.containsMouse ? Theme.paperDeep : "transparent"

                        Icon {
                            anchors.centerIn: parent
                            name: "close"
                            color: Theme.inkSoft
                            width: 13
                            height: 13
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sheet.close()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: sheet.title
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 25
                    wrapMode: Text.WordWrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: sheet.subtitle.length > 0
                    text: sheet.subtitle
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.line
            }
        }

        Flickable {
            id: scroller
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: contentColumn.implicitHeight + 56
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                id: contentColumn
                x: 28
                y: 24
                width: scroller.width - 56
                spacing: 12
            }
        }
    }
}
