import QtQuick
import QtQuick.Layouts
import "../theme.js" as Theme

Rectangle {
    id: sidebar

    property string currentPage: "overview"
    property string activeRole: "funder"
    property int pendingCount: 0
    property int openChallengeCount: 0
    property int fieldTodayCount: 0
    property int roomUnread: 0
    property real vaultBalance: 0
    property real walletBalance: 0
    property bool rehearsal: true

    signal navigate(string page)
    signal openAbout()

    color: Theme.forest
    implicitWidth: Theme.sidebarWidth

    readonly property var navItems: [
        { key: "overview", label: "Overview", icon: "grid", badge: "" },
        { key: "field", label: "Field map", icon: "map", badge: "" },
        { key: "kitchen", label: "Kitchen", icon: "kitchen", badge: "" },
        { key: "market", label: "Market", icon: "market", badge: "" },
        { key: "projects", label: "Projects", icon: "projects", badge: "" },
        { key: "challenges", label: "Challenges", icon: "challenges", badge: "" },
        { key: "wallet", label: "Wallet", icon: "wallet", badge: "" },
        { key: "room", label: "Coordination room", icon: "room", badge: "" },
        { key: "landscape", label: "Landscape", icon: "landscape", badge: "" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 26
        anchors.bottomMargin: 20
        anchors.leftMargin: 18
        anchors.rightMargin: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 11

            Rectangle {
                width: 34
                height: 34
                radius: 10
                color: Theme.lime

                Icon {
                    anchors.centerIn: parent
                    name: "leaf"
                    color: Theme.forest
                    width: 17
                    height: 17
                    strokeWidth: 1.7
                }
            }

            ColumnLayout {
                spacing: 0
                Text {
                    text: "Dhun"
                    color: "#F7F4E8"
                    font.family: Theme.displayFont
                    font.pixelSize: 23
                    font.weight: Font.Normal
                }
                Text {
                    text: "C O M M O N S"
                    color: "#8FA795"
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    font.letterSpacing: 1.6
                }
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.leftMargin: 10
            Layout.topMargin: 24
            text: "TREASURY"
            color: "#7C9483"
            font.family: Theme.uiFont
            font.pixelSize: 8
            font.letterSpacing: 1.8
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 9
            Layout.preferredHeight: 84
            radius: 12
            color: "#18301F"
            border.width: 1
            border.color: "#27452F"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                Text {
                    text: "Multisig vault"
                    color: "#8FA795"
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }

                RowLayout {
                    spacing: 5
                    Text {
                        text: format.number(sidebar.vaultBalance)
                        color: "#F2F6E7"
                        font.family: Theme.displayFont
                        font.pixelSize: 22
                    }
                    Text {
                        text: "DHN"
                        color: Theme.limeDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                    }
                }

                RowLayout {
                    spacing: 6
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: sidebar.pendingCount > 0 ? Theme.gold : Theme.limeDeep
                    }
                    Text {
                        text: sidebar.pendingCount > 0
                              ? sidebar.pendingCount + " proposals need a signature"
                              : "Quorum clear · nothing waiting"
                        color: "#A7BCA9"
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }
            }
        }

        Text {
            Layout.leftMargin: 10
            Layout.topMargin: 22
            text: "WORKSPACE"
            color: "#7C9483"
            font.family: Theme.uiFont
            font.pixelSize: 8
            font.letterSpacing: 1.8
            font.weight: Font.DemiBold
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 7
            spacing: 2

            Repeater {
                model: sidebar.navItems

                delegate: Rectangle {
                    id: navRow
                    required property var modelData
                    readonly property bool active: sidebar.currentPage === modelData.key
                    readonly property string badgeText: {
                        if (modelData.key === "wallet" || modelData.key === "overview") return sidebar.pendingCount > 0 ? String(sidebar.pendingCount) : "";
                        if (modelData.key === "challenges") return sidebar.openChallengeCount > 0 ? String(sidebar.openChallengeCount) : "";
                        if (modelData.key === "field") return sidebar.fieldTodayCount > 0 ? String(sidebar.fieldTodayCount) : "";
                        if (modelData.key === "room") return sidebar.roomUnread > 0 ? String(sidebar.roomUnread) : "";
                        return "";
                    }

                    Layout.fillWidth: true
                    height: 38
                    radius: 9
                    color: active ? "#23402C" : (navMouse.containsMouse ? "#1B3425" : "transparent")

                    Rectangle {
                        visible: navRow.active
                        width: 3
                        height: 18
                        radius: 1.5
                        color: Theme.lime
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 13
                        anchors.rightMargin: 10
                        spacing: 10

                        Icon {
                            name: navRow.modelData.icon
                            color: navRow.active ? Theme.lime : "#93A997"
                            width: 16
                            height: 16
                            opacity: navRow.active ? 1 : 0.85
                        }

                        Text {
                            Layout.fillWidth: true
                            text: navRow.modelData.label
                            color: navRow.active ? "#F4F7E9" : "#B9C9B9"
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.weight: navRow.active ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: navRow.badgeText.length > 0
                            implicitWidth: badgeLabel.implicitWidth + 12
                            implicitHeight: 17
                            radius: 8.5
                            color: navRow.active ? Theme.lime : (sidebar.currentPage === "wallet" ? "#3A5238" : "#2A4632")

                            Text {
                                id: badgeLabel
                                anchors.centerIn: parent
                                text: navRow.badgeText
                                color: navRow.active ? Theme.forest : "#DCE6CE"
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    MouseArea {
                        id: navMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sidebar.navigate(navRow.modelData.key)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#26402F"
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            Layout.leftMargin: 4
            Layout.rightMargin: 2
            spacing: 8

            Rectangle {
                width: 26
                height: 26
                radius: 13
                color: Theme.roleSoft(sidebar.activeRole)

                Text {
                    anchors.centerIn: parent
                    text: sidebar.activeRole === "dhun" ? "M" : (sidebar.activeRole === "steward" ? "K" : "A")
                    color: Theme.roleText(sidebar.activeRole)
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: format.roleName(sidebar.activeRole)
                    color: "#E8EFDC"
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Text {
                    text: format.number(sidebar.walletBalance) + " DHN available"
                    color: "#8FA795"
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }
            }

            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: aboutMouse.containsMouse ? "#284433" : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: "info"
                    color: "#8FA795"
                    width: 14
                    height: 14
                }

                MouseArea {
                    id: aboutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sidebar.openAbout()
                }
            }
        }

        Text {
            Layout.topMargin: 10
            Layout.leftMargin: 4
            text: "Rehearsal · local state, no chain"
            color: "#6E8577"
            font.family: Theme.uiFont
            font.pixelSize: 8
            font.letterSpacing: 0.3
        }
    }

    // Format helpers kept in the view layer so the sidebar never depends on seed data.
    QtObject {
        id: format
        function roleName(role) {
            if (role === "dhun") return "Dhun Field Unit";
            if (role === "steward") return "Khejri Mandal";
            return "Dhun Capital Circle";
        }
        function number(value) {
            var n = Number(value) || 0;
            return n.toLocaleString(Qt.locale("en-IN"), "f", 0);
        }
    }
}
