import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../data.js" as Data
import "../components"

Item {
    id: page

    property var app: null
    property var now: Date.now()
    property string activeRole: "funder"
    property string activeSeasonId: "rabi"
    property string activeZone: ""

    signal navigate(string pageKey)
    signal openProject(var project)

    readonly property var season: Data.seasonById(activeSeasonId)
    readonly property var visibleIngredients: {
        var result = [];
        for (var i = 0; i < Data.ingredients.length; ++i) {
            var ingredient = Data.ingredients[i];
            if (activeZone !== "" && ingredient.zone !== activeZone) continue;
            if (Data.matchesFilter(ingredient, "season", 11, activeSeasonId)) result.push(ingredient);
        }
        return result;
    }
    readonly property var zonePositions: ({
        farms: { x: 0.2, y: 0.63 },
        orchard: { x: 0.52, y: 0.42 },
        kitchen: { x: 0.7, y: 0.24 },
        dairy: { x: 0.85, y: 0.67 }
    })

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
                    text: "Landscape ledger"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 19
                }

                Text {
                    Layout.leftMargin: 8
                    text: "500 acres · four working zones · three covenants"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4

                    Repeater {
                        model: Data.seasons

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: page.activeSeasonId === modelData.id

                            implicitWidth: seasonLabel.implicitWidth + 20
                            implicitHeight: 27
                            radius: 13.5
                            color: active ? Theme.forest : (seasonMouse.containsMouse ? Theme.sageLight : "transparent")
                            border.width: active ? 0 : 1
                            border.color: Theme.line

                            Text {
                                id: seasonLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                color: active ? "#F4F7E9" : Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: active ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: seasonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.activeSeasonId = modelData.id
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 438
                    radius: Theme.radiusXL
                    color: Theme.forest
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "../assets/dhun-satellite.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#0E1E1666" }
                            GradientStop { position: 0.55; color: "#0E1E1600" }
                            GradientStop { position: 1.0; color: "#0E1E16CC" }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16

                        Rectangle {
                            implicitWidth: satRow.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: "#12241ACC"
                            border.width: 1
                            border.color: "#3C5943"

                            RowLayout {
                                id: satRow
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.lime }
                                Text {
                                    text: "SATELLITE · CHAK GULABPURA"
                                    color: "#C7D6C4"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: coordRow.implicitWidth + 16
                            implicitHeight: 24
                            radius: 12
                            color: "#12241ACC"
                            border.width: 1
                            border.color: "#3C5943"

                            RowLayout {
                                id: coordRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "26.7113° N"
                                    color: "#C7D6C4"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                }
                                Rectangle { width: 1; height: 9; color: "#3C5943" }
                                Text {
                                    text: "75.5901° E"
                                    color: "#C7D6C4"
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                }
                            }
                        }
                    }

                    Repeater {
                        model: Data.zones

                        delegate: Item {
                            id: zonePin
                            required property var modelData
                            readonly property var pos: page.zonePositions[modelData.id]
                            readonly property bool active: page.activeZone === modelData.id

                            x: (parent.width - 120) * pos.x
                            y: parent.height * pos.y - 64
                            width: 120
                            height: 64

                            Rectangle {
                                x: zonePin.width / 2 - 8
                                y: (zonePin.height - 44) / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: zonePin.modelData.color
                                border.width: 3
                                border.color: zonePin.active ? "#F6F4E8" : "#F6F4E888"

                                SequentialAnimation on scale {
                                    running: zonePin.active
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.15; duration: 700; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                }
                            }

                            Rectangle {
                                x: zonePin.width / 2 - label.implicitWidth / 2 - 8
                                y: 52
                                implicitWidth: label.implicitWidth + 16
                                implicitHeight: 21
                                radius: 10.5
                                color: zonePin.active ? zonePin.modelData.color : "#12241ACC"
                                border.width: 1
                                border.color: zonePin.active ? zonePin.modelData.color : "#4C6552"

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: zonePin.modelData.short
                                    color: zonePin.active ? "#2A2410" : "#DDE8D8"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.activeZone = zonePin.active ? "" : zonePin.modelData.id
                            }
                        }
                    }

                    Repeater {
                        model: [
                            { x: 0.62, y: 0.33, label: "nesting" },
                            { x: 0.28, y: 0.52, label: "water" },
                            { x: 0.76, y: 0.15, label: "hedge" }
                        ]

                        delegate: RowLayout {
                            required property var modelData
                            x: parent.width * modelData.x
                            y: parent.height * modelData.y
                            spacing: 4

                            Rectangle {
                                width: 17
                                height: 17
                                radius: 8.5
                                color: "#E8F0D6DD"
                                Icon {
                                    anchors.centerIn: parent
                                    name: "leaf"
                                    color: Theme.forestMid
                                    width: 9
                                    height: 9
                                    strokeWidth: 1.6
                                }
                            }

                            Text {
                                text: modelData.label
                                color: "#E9F0DD"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 230
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: "#5511251B" }
                            GradientStop { position: 1.0; color: "#E611251B" }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 18
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: page.season ? (page.season.name.toUpperCase() + " · " + page.season.window) : ""
                                    color: Theme.limeDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 1.3
                                    font.weight: Font.Bold
                                }
                                Text {
                                    text: page.activeZone === ""
                                          ? "All zones · tap a pin to filter"
                                          : Data.zoneById(page.activeZone).name
                                    color: "#F2F5E8"
                                    font.family: Theme.displayFont
                                    font.pixelSize: 21
                                }
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: String(page.visibleIngredients.length)
                                    color: "#F2F5E8"
                                    font.family: Theme.displayFont
                                    font.pixelSize: 26
                                    horizontalAlignment: Text.AlignRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "foods & materials in season"
                                    color: "#A7BCA9"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: Data.zones

                                delegate: RowLayout {
                                    required property var modelData
                                    spacing: 4
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: modelData.color
                                    }
                                    Text {
                                        text: modelData.short
                                        color: "#B8C9B6"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Natural colour composite · Esri World Imagery"
                                color: "#8FA795"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 356
                    Layout.preferredHeight: 438
                    radius: Theme.radiusXL
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: "In season now"
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: page.season
                                          ? (page.season.tagline + " · " + page.season.window)
                                          : ""
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: page.activeZone !== ""
                                implicitWidth: clearLabel.implicitWidth + 16
                                implicitHeight: 23
                                radius: 11.5
                                color: Theme.paperDeep

                                Text {
                                    id: clearLabel
                                    anchors.centerIn: parent
                                    text: "Clear zone ×"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.activeZone = ""
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            height: 1
                            color: Theme.lineSoft
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 6
                            clip: true
                            spacing: 0
                            model: page.visibleIngredients
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Item {
                                id: ingredientRow
                                required property var modelData
                                width: ListView.view.width
                                height: 52

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.rightMargin: 4
                                    spacing: 8

                                    Rectangle {
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: Data.zoneById(ingredientRow.modelData.zone).color
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            text: ingredientRow.modelData.name
                                            color: Theme.ink
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: ingredientRow.modelData.local + " · " + ingredientRow.modelData.category
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 7
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: ingredientRow.modelData.harvestLabel
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                    }

                                    Text {
                                        text: "₹" + ingredientRow.modelData.price
                                        color: Theme.inkSoft
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 1
                                    color: Theme.lineSoft
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.topMargin: 4
                            radius: 9
                            color: Theme.sageLight

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 6

                                Icon {
                                    name: "leaf"
                                    color: Theme.forestMid
                                    width: 11
                                    height: 11
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Buying this produce pays the grower; covenant offers also fund the reserve."
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    wrapMode: Text.WordWrap
                                }

                                ActionButton {
                                    compact: true
                                    variant: "secondary"
                                    text: "Market"
                                    onClicked: page.navigate("market")
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 12

                Repeater {
                    model: page.app ? page.app.covenants : []

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168
                        radius: Theme.radiusLarge
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 7
                                    color: Theme.sageLight
                                    Icon {
                                        anchors.centerIn: parent
                                        name: "leaf"
                                        color: Theme.forestMid
                                        width: 11
                                        height: 11
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Pill {
                                    text: modelData.status === "active" ? "Active" : "Draft"
                                    fg: modelData.status === "active" ? Theme.forestMid : Theme.muted
                                    bg: modelData.status === "active" ? Theme.sageLight : Theme.paperDeep
                                    fontSize: 7
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.rule
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                Layout.fillHeight: true
                            }

                            ProgressBar {
                                Layout.fillWidth: true
                                value: modelData.progress
                                fill: Theme.forestMid
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.metric
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: Data.zoneById(modelData.zone).short
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "The map is a discovery surface, not a title deed. Conservation covenants are enforced by the token program: a share of every milestone release is routed to the reserve before the grower is paid."
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
