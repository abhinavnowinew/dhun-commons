import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../agro.js" as Agro
import "../components"

Item {
    id: page

    property var host: null
    property var app: null
    property var now: Date.now()
    property string activeRole: "funder"

    property string activeLocation: "farms"
    property string activeLayer: "rain-3h"
    property bool loading: false
    property string errorText: ""
    property var forecast: ({ success: false, days: [], current: {}, label: "" })

    readonly property bool backendReady: host !== null && host.relayBackend !== null && host.relayReady === true
    readonly property var location: Agro.locationById(activeLocation)
    readonly property var days: forecast.days ? forecast.days : []
    readonly property var today: days.length > 0 ? days[0] : ({})
    readonly property var current: forecast.current ? forecast.current : ({})
    readonly property var agronomy: Agro.dayAdvisories(today)
    readonly property var conservation: Agro.conservationAdvisories(days, current)
    readonly property var summary: Agro.summarise(days)
    readonly property var windows: Agro.windowsFor(days)

    function toneEdge(tone) {
        if (tone === "red") return Theme.danger;
        if (tone === "amber") return Theme.goldDeep;
        if (tone === "blue") return "#5A7684";
        return "#5C7A3F";
    }

    function toneFill(tone) {
        if (tone === "red") return Theme.clayLight;
        if (tone === "amber") return Theme.goldLight;
        if (tone === "blue") return Theme.blueLight;
        return Theme.sageLight;
    }

    function toneInk(tone) {
        if (tone === "red") return Theme.danger;
        if (tone === "amber") return Theme.goldDeep;
        if (tone === "blue") return "#3F5C6B";
        return "#3F5A26";
    }

    function openExternal(url) {
        Qt.openUrlExternally(url);
    }

    function reload() {
        if (!backendReady) {
            errorText = "Weather needs the Dhun Commons backend. Open this page inside Basecamp with the module running.";
            return;
        }
        if (loading) return;
        var place = Agro.locationById(activeLocation);
        loading = true;
        errorText = "";
        var request = JSON.stringify({
            location: place.id,
            label: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            days: 7
        });
        logos.watch(host.relayBackend.agroForecast(request), function (value) {
            page.loading = false;
            var parsed = host.relayParse ? host.relayParse(value) : null;
            var mapped = Agro.mapForecast(parsed);
            if (mapped.success) {
                page.forecast = mapped;
                page.errorText = "";
            } else {
                page.errorText = mapped.error;
            }
        }, function (error) {
            page.loading = false;
            page.errorText = "The advisory could not reach the forecast service.";
        });
    }

    function windowText(dates) {
        if (!dates || !dates.length) return "—";
        var labels = [];
        for (var i = 0; i < dates.length; ++i) labels.push(Agro.dayLabel(dates[i], -1));
        return labels.join(" · ");
    }

    onActiveLocationChanged: reload()
    onBackendReadyChanged: if (backendReady && !forecast.success) reload()
    Component.onCompleted: if (backendReady) reload()

    Timer {
        interval: 30 * 60 * 1000
        running: page.backendReady
        repeat: true
        onTriggered: page.reload()
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
                spacing: 10

                ColumnLayout {
                    spacing: 3

                    Text {
                        text: "Agro & conservation advisory"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 24
                    }

                    Text {
                        text: "Open-Meteo forecast for the five zones · Ventusky atlas · rules are advisory only"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                    }
                }

                Item { Layout.fillWidth: true }

                Pill {
                    visible: page.forecast.success
                    text: page.forecast.cached ? "cached · 30 min" : "live fetch"
                    fg: page.forecast.cached ? Theme.goldDeep : "#3F5C6B"
                    bg: page.forecast.cached ? Theme.goldLight : Theme.blueLight
                    dotColor: page.forecast.cached ? Theme.gold : Theme.blue
                }

                ActionButton {
                    text: "Ventusky atlas"
                    variant: "primary"
                    compact: true
                    onClicked: page.openExternal(Agro.webUrl(page.activeLocation, page.activeLayer))
                }

                ActionButton {
                    text: page.loading ? "Reading…" : "Refresh"
                    variant: "secondary"
                    compact: true
                    enabled: !page.loading && page.backendReady
                    onClicked: page.reload()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Agro.LOCATIONS

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: page.activeLocation === modelData.id

                        implicitWidth: chipLabel.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: active ? Theme.forest : (chipMouse.containsMouse ? Theme.sageLight : "transparent")
                        border.width: active ? 0 : 1
                        border.color: Theme.line

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData.short
                            color: active ? "#F4F7E9" : Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            font.weight: active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.activeLocation = modelData.id
                        }
                    }
                }
            }

            Rectangle {
                visible: page.errorText.length > 0
                Layout.fillWidth: true
                implicitHeight: errorLabel.implicitHeight + 20
                radius: Theme.radiusMedium
                color: Theme.clayLight
                border.width: 1
                border.color: Theme.danger

                Text {
                    id: errorLabel
                    anchors.fill: parent
                    anchors.margins: 10
                    text: page.errorText
                    color: Theme.danger
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                visible: page.loading && !page.forecast.success
                text: "Reading the forecast for " + page.location.name + "…"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 10
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatTile {
                    Layout.fillWidth: true
                    label: "Now · " + page.location.short.toUpperCase()
                    value: Agro.num(page.current.temp, 1) + "°"
                    caption: Agro.conditionLabel(page.current.code) + " · feels like "
                             + Agro.num(page.today.apparentMax, 0) + "° max today"
                    accent: Theme.clay
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "TOP 10 CM MOISTURE"
                    value: Agro.percent(page.current.soil)
                    caption: "Soil at 6 cm " + Agro.num(page.current.soilTemp, 1) + " °C · "
                             + Agro.num(page.today.soil, 2) + " m³/m³ daily mean"
                    accent: "#5A7684"
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "RAIN NEXT 72 H"
                    value: Agro.num(page.summary.rain72, 1) + " mm"
                    caption: "Week total " + Agro.num(page.summary.rainWeek, 1) + " mm · peak chance "
                             + Agro.num(page.summary.peakChance) + "%"
                    accent: Theme.blue
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "WIND NOW"
                    value: Agro.num(page.current.wind) + " km/h"
                    caption: "From " + Agro.directionLabel(page.current.direction) + " · week gust max "
                             + Agro.num(page.summary.maxGust) + " km/h"
                    accent: Theme.gold
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "REFERENCE ET0 · WEEK"
                    value: Agro.num(page.summary.et0Week, 1) + " mm"
                    caption: "Water balance " + (page.summary.rainWeek - page.summary.et0Week >= 0 ? "+" : "")
                             + Agro.num(page.summary.rainWeek - page.summary.et0Week, 1) + " mm"
                    accent: Theme.limeDeep
                }
            }

            Text {
                text: "TODAY · AGRONOMY"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: page.agronomy

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: advisoryBody.implicitHeight + 26
                        radius: Theme.radiusMedium
                        color: page.toneFill(modelData.tone)
                        border.width: 1
                        border.color: page.toneEdge(modelData.tone)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 10

                            Rectangle {
                                Layout.fillHeight: true
                                width: 3
                                radius: 1.5
                                color: page.toneEdge(modelData.tone)
                            }

                            ColumnLayout {
                                id: advisoryBody
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: page.toneInk(modelData.tone)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.detail
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    lineHeight: 1.25
                                    wrapMode: Text.WordWrap
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Repeater {
                                        model: modelData.measures

                                        delegate: Text {
                                            required property var modelData

                                            Layout.fillWidth: true
                                            text: "· " + modelData
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            lineHeight: 1.2
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "CONSERVATION · SOIL, WATER, HABITAT AND FIRE"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.letterSpacing: 1.6
                font.weight: Font.DemiBold
                Layout.topMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: page.conservation

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: conservationBody.implicitHeight + 26
                        radius: Theme.radiusMedium
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 10

                            Rectangle {
                                Layout.fillHeight: true
                                width: 3
                                radius: 1.5
                                color: page.toneEdge(modelData.tone)
                            }

                            ColumnLayout {
                                id: conservationBody
                                Layout.fillWidth: true
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Pill {
                                        text: "CONSERVATION"
                                        fg: page.toneInk(modelData.tone)
                                        bg: page.toneFill(modelData.tone)
                                        fontSize: 7
                                        horizontalPadding: 7
                                        strong: true
                                    }

                                    Item { Layout.fillWidth: true }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: page.toneInk(modelData.tone)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.detail
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    lineHeight: 1.25
                                    wrapMode: Text.WordWrap
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Repeater {
                                        model: modelData.measures

                                        delegate: Text {
                                            required property var modelData

                                            Layout.fillWidth: true
                                            text: "· " + modelData
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            lineHeight: 1.2
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: tableBody.implicitHeight + 28
                radius: Theme.radiusLarge
                color: Theme.white
                border.width: 1
                border.color: Theme.line

                ColumnLayout {
                    id: tableBody
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    Text {
                        text: "SEVEN-DAY FORECAST · " + page.location.name.toUpperCase()
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.4
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text { Layout.preferredWidth: 74; text: "DAY"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.fillWidth: true; text: "CONDITIONS"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.preferredWidth: 92; text: "RAIN · CHANCE"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.preferredWidth: 78; text: "MAX / MIN"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.preferredWidth: 92; text: "WIND · GUST"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.preferredWidth: 62; text: "ET0"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                        Text { Layout.preferredWidth: 64; text: "TOPSOIL"; color: Theme.mutedLight; font.family: Theme.uiFont; font.pixelSize: 7; font.letterSpacing: 1 }
                    }

                    Repeater {
                        model: page.days

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: 6
                            color: index % 2 === 0 ? Theme.paperWarm : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 74
                                    text: Agro.dayLabel(modelData.date, index)
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: index === 0 ? Font.DemiBold : Font.Normal
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: Agro.conditionLabel(modelData.code)
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.preferredWidth: 92
                                    text: Agro.num(modelData.rain, 1) + " mm · " + Agro.num(modelData.chance) + "%"
                                    color: (modelData.rain || 0) >= 8 ? "#3F5C6B" : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.preferredWidth: 78
                                    text: Agro.num(modelData.tMax, 0) + "° / " + Agro.num(modelData.tMin, 0) + "°"
                                    color: modelData.tMax >= 38 ? Theme.danger : Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.preferredWidth: 92
                                    text: Agro.num(modelData.wind) + " · " + Agro.num(modelData.gust) + " km/h"
                                    color: modelData.gust >= 50 ? Theme.danger : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.preferredWidth: 62
                                    text: Agro.num(modelData.et0, 1) + " mm"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.preferredWidth: 64
                                    text: Agro.percent(modelData.soil)
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }
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
                    implicitHeight: windowBody.implicitHeight + 32
                    radius: Theme.radiusLarge
                    color: Theme.forest

                    ColumnLayout {
                        id: windowBody
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 9

                        Text {
                            text: "FIELD WINDOWS"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.4
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: [
                                { label: "Sow / transplant", dates: page.windows.sow },
                                { label: "Spray or foliar feed", dates: page.windows.spray },
                                { label: "Harvest and dry", dates: page.windows.harvest },
                                { label: "Hold field work", dates: page.windows.hold }
                            ]

                            delegate: RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 116
                                    text: modelData.label
                                    color: "#C7D6C4"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: page.windowText(modelData.dates)
                                    color: modelData.dates.length > 0 ? "#F2F6E7" : "#6E8577"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Windows are inferred from the same gridded forecast. Confirm against the bed and the crew."
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 360
                    implicitHeight: layerBody.implicitHeight + 28
                    radius: Theme.radiusLarge
                    color: Theme.white
                    border.width: 1
                    border.color: Theme.line

                    ColumnLayout {
                        id: layerBody
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 9

                        Text {
                            text: "VENTUSKY LAYER"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.letterSpacing: 1.4
                            font.weight: Font.DemiBold
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: Agro.LAYERS

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active: page.activeLayer === modelData.id

                                    implicitWidth: layerLabel.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 12
                                    color: active ? Theme.forest : (layerMouse.containsMouse ? Theme.sageLight : "transparent")
                                    border.width: active ? 0 : 1
                                    border.color: Theme.line

                                    Text {
                                        id: layerLabel
                                        anchors.centerIn: parent
                                        text: modelData.short
                                        color: active ? "#F4F7E9" : Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        id: layerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.activeLayer = modelData.id
                                    }
                                }
                            }
                        }

                        ActionButton {
                            Layout.fillWidth: true
                            text: "Open " + Agro.layerById(page.activeLayer).label
                            variant: "secondary"
                            compact: true
                            onClicked: page.openExternal(Agro.webUrl(page.activeLocation, page.activeLayer))
                        }

                        ActionButton {
                            Layout.fillWidth: true
                            text: "Satellite plot · Google Maps"
                            variant: "ghost"
                            compact: true
                            onClicked: page.openExternal(Agro.googleMapsUrl(page.activeLocation))
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: Agro.LIMIT_NOTE + " " + Agro.ATTRIBUTION
                color: Theme.mutedLight
                font.family: Theme.uiFont
                font.pixelSize: 8
                lineHeight: 1.35
                wrapMode: Text.WordWrap
            }
        }
    }
}
