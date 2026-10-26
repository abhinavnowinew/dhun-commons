import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Item {
    id: topBar

    property string title: ""
    property string subtitle: ""
    property string section: ""
    property string activeRole: "funder"
    property real walletBalance: 0
    property int pendingCount: 0

    signal roleSelected(string role)

    implicitHeight: Theme.topBarHeight

    Rectangle {
        anchors.fill: parent
        color: Theme.paper
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.lineSoft
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pagePadding
        anchors.rightMargin: Theme.pagePadding
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 620
            spacing: 2

            RowLayout {
                spacing: 7
                visible: topBar.section.length > 0
                Text {
                    text: topBar.section.toUpperCase()
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.letterSpacing: 1.6
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: 14
                    height: 1
                    color: Theme.line
                }
                Text {
                    text: "seasonal commons"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                }
            }

            Text {
                text: topBar.title
                color: Theme.ink
                font.family: Theme.displayFont
                font.pixelSize: 24
                font.weight: Font.Normal
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: topBar.subtitle
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 10
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: rehearsalRow.implicitWidth + 20
            implicitHeight: 26
            radius: 13
            color: Theme.goldLight
            border.width: 1
            border.color: "#E4CE9E"

            RowLayout {
                id: rehearsalRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Theme.goldDeep
                }

                Text {
                    text: "REHEARSAL · NO FUNDS"
                    color: Theme.goldDeep
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.letterSpacing: 0.7
                }
            }
        }

        Rectangle {
            width: 1
            height: 30
            color: Theme.line
        }

        ColumnLayout {
            spacing: 5

            Text {
                text: "SIGNING AS"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                font.letterSpacing: 1.4
                font.weight: Font.DemiBold
            }

            Rectangle {
                implicitWidth: roleRow.implicitWidth + 8
                implicitHeight: 32
                radius: 10
                color: Theme.paperDeep

                RowLayout {
                    id: roleRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: [
                            { key: "funder", label: "Funder", initial: "A" },
                            { key: "dhun", label: "Dhun", initial: "M" },
                            { key: "steward", label: "Steward", initial: "K" }
                        ]

                        delegate: Rectangle {
                            id: roleButton
                            required property var modelData
                            readonly property bool active: topBar.activeRole === modelData.key

                            width: roleContent.implicitWidth + 16
                            height: 26
                            radius: 8
                            color: active ? Theme.white : (roleMouse.containsMouse ? "#E2DECD" : "transparent")
                            border.width: active ? 1 : 0
                            border.color: Theme.line

                            RowLayout {
                                id: roleContent
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 15
                                    height: 15
                                    radius: 7.5
                                    color: Theme.roleSoft(roleButton.modelData.key)

                                    Text {
                                        anchors.centerIn: parent
                                        text: roleButton.modelData.initial
                                        color: Theme.roleText(roleButton.modelData.key)
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: roleButton.modelData.label
                                    color: roleButton.active ? Theme.ink : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: roleButton.active ? Font.DemiBold : Font.Normal
                                }
                            }

                            MouseArea {
                                id: roleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: topBar.roleSelected(roleButton.modelData.key)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: 30
            color: Theme.line
        }

        ColumnLayout {
            spacing: 3

            Text {
                text: "AVAILABLE"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                font.letterSpacing: 1.4
                font.weight: Font.DemiBold
            }

            RowLayout {
                spacing: 6

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: Theme.sage
                    Icon {
                        anchors.centerIn: parent
                        name: "wallet"
                        color: Theme.forestMid
                        width: 9
                        height: 9
                        strokeWidth: 1.6
                    }
                }

                Text {
                    text: format.number(topBar.walletBalance) + " DHN"
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: topBar.pendingCount > 0
                    implicitWidth: pendingText.implicitWidth + 12
                    implicitHeight: 17
                    radius: 8.5
                    color: Theme.clayLight

                    Text {
                        id: pendingText
                        anchors.centerIn: parent
                        text: topBar.pendingCount + " to sign"
                        color: Theme.clayDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    QtObject {
        id: format
        function number(value) {
            var n = Number(value) || 0;
            return n.toLocaleString(Qt.locale("en-IN"), "f", 0);
        }
    }
}
