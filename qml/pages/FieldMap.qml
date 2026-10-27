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
    property real now: Date.now()
    property string activeRole: "funder"
    property bool webEnabled: true

    property bool studioRequested: false
    property string sourceMode: "bundled"
    property bool polling: false
    property string pendingComposer: ""
    property int weekOffset: 0
    property real selectedDay: startOfDay(Date.now())
    property string selectedProduceId: ""
    property string selectedActivityId: ""
    property bool composerOpen: false
    property string composerType: "sowing"
    property string composerZone: "farms"
    property string composerError: ""

    signal purchase(var offer)
    signal addActivity(var spec)
    signal setActivityStatus(string id, string status)
    signal studioRole(string role)
    signal studioActivity(var activity)
    signal studioStatus(string id, string status)
    signal studioOffer(string produceId, string offerId, int qty)
    signal studioUpdate(var update)
    signal studioReady(var info)
    signal toast(string text, string tone)

    readonly property real dayMilliseconds: 86400000
    readonly property var produceOffers: app ? Logic.produceOffers(app) : []
    readonly property var produceInStock: produceOffers.filter(function (offer) { return Number(offer.stock) > 0; })
    readonly property var orders: app && app.fieldOrders ? app.fieldOrders : []
    readonly property var allActivities: app && app.fieldActivities ? app.fieldActivities : []
    readonly property var selectedDayActivities: app ? Logic.fieldActivitiesOnDay(app, activeRole, selectedDay) : []
    readonly property var selectedIngredient: selectedProduceId.length > 0 ? Data.ingredientById(selectedProduceId) : null
    readonly property var selectedOffer: selectedProduceId.length > 0 && app ? Logic.findProduceOffer(app, selectedProduceId) : null
    readonly property var selectedActivity: {
        if (!app || selectedActivityId.length === 0 || !app.fieldActivities) return null;
        for (var i = 0; i < app.fieldActivities.length; ++i)
            if (app.fieldActivities[i].id === selectedActivityId) return app.fieldActivities[i];
        return null;
    }
    readonly property var weekDays: buildWeek()
    readonly property string weekLabel: {
        var base = startOfDay(Date.now()) + weekOffset * 7 * dayMilliseconds;
        return Qt.formatDate(new Date(base), "d MMM") + " \u2014 " + Qt.formatDate(new Date(base + 6 * dayMilliseconds), "d MMM");
    }
    readonly property bool wide: width >= 1120
    readonly property string statusText: {
        if (!webEnabled) return "NATIVE FIELD DESK";
        if (studioWebView.failed) return "STUDIO OFFLINE";
        if (studioWebView.loaded) return "LIVE GOOGLE STUDIO";
        if (studioRequested) return "OPENING STUDIO";
        return "FIELD DESK READY";
    }
    readonly property color statusColor: {
        if (!webEnabled) return Theme.muted;
        if (studioWebView.failed) return Theme.clay;
        if (studioWebView.loaded) return Theme.limeDeep;
        return Theme.gold;
    }
    readonly property string statusHint: {
        if (!webEnabled) return "The embedded studio is disabled in this test build. The native plan view and wallet procurement are active.";
        if (studioWebView.failed) return studioWebView.failureText;
        if (studioWebView.loaded) return "Search places, mark field work, record clips and procure inside the studio.";
        return "The studio is starting. The local plan view and wallet actions remain available.";
    }
    readonly property string bundledUrl: Qt.resolvedUrl("../web/index.html")

    function startOfDay(value) {
        var date = new Date(Number(value) || Date.now());
        date.setHours(0, 0, 0, 0);
        return date.getTime();
    }

    function buildWeek() {
        var base = startOfDay(Date.now()) + weekOffset * 7 * dayMilliseconds;
        var today = startOfDay(Date.now());
        var result = [];
        for (var i = 0; i < 7; ++i) {
            var stamp = base + i * dayMilliseconds;
            var items = app ? Logic.fieldActivitiesOnDay(app, activeRole, stamp) : [];
            var done = 0;
            for (var j = 0; j < items.length; ++j) if (items[j].status === "done") done += 1;
            result.push({
                timestamp: stamp,
                weekday: Qt.formatDate(new Date(stamp), "ddd"),
                day: new Date(stamp).getDate(),
                count: items.length,
                done: done,
                today: stamp === today,
                selected: stamp === selectedDay
            });
        }
        return result;
    }

    function dayLabel(value) {
        var stamp = startOfDay(value);
        var today = startOfDay(Date.now());
        if (stamp === today) return "Today";
        if (stamp === today + dayMilliseconds) return "Tomorrow";
        if (stamp === today - dayMilliseconds) return "Yesterday";
        return Qt.formatDate(new Date(stamp), "ddd d MMM");
    }

    function timeLabel(value) {
        return Qt.formatTime(new Date(Number(value)), "HH:mm");
    }

    function roleName(role) {
        if (role === "dhun") return "Dhun Field Unit";
        if (role === "steward") return "Khejri Mandal";
        return "Dhun Capital Circle";
    }

    function photoSource(ingredient) {
        return ingredient
            ? "../assets/produce/" + Data.photoFor(ingredient) + ".jpg"
            : "../assets/produce/grains.jpg";
    }

    function activityType(activity) {
        return Data.activityTypeById(activity ? activity.type : "sowing");
    }

    function activityMeta(activity) {
        if (!activity) return "";
        var type = activityType(activity);
        var zone = Data.zoneById(activity.zone);
        var produce = activity.produceId ? Data.ingredientById(activity.produceId) : null;
        var parts = [type.label];
        if (zone) parts.push(zone.short);
        if (produce) parts.push(produce.name);
        return parts.join(" \u00B7 ");
    }

    function activityPlot(activity) {
        if (!activity) return { latitude: Data.site.latitude, longitude: Data.site.longitude };
        if (activity.plot && isFinite(Number(activity.plot.latitude)) && isFinite(Number(activity.plot.longitude)))
            return activity.plot;
        var ingredient = activity.produceId ? Data.ingredientById(activity.produceId) : null;
        if (ingredient) return Data.plotFor(ingredient);
        var zone = Data.zoneById(activity.zone) || Data.zones[0];
        var h = Data.hash32(activity.id || activity.title || "field");
        var angle = ((h % 360) / 180) * Math.PI;
        var radius = 0.0018 + ((h >> 9) % 80) / 100000;
        return {
            latitude: zone.latitude + Math.sin(angle) * radius * 0.82,
            longitude: zone.longitude + Math.cos(angle) * radius
        };
    }

    function xPercent(longitude) {
        return Math.max(0.035, Math.min(0.965, 0.5 + (Number(longitude) - Data.site.longitude) / 0.0142));
    }

    function yPercent(latitude) {
        return Math.max(0.04, Math.min(0.96, 0.5 - (Number(latitude) - Data.site.latitude) / 0.0125));
    }

    function offerFor(produceId) {
        return app ? Logic.findProduceOffer(app, produceId) : null;
    }

    function bundledAddress() {
        return bundledUrl.toString() + "?embedded=1&role=" + encodeURIComponent(activeRole);
    }

    function serverAddress() {
        return "http://127.0.0.1:8788/qml/web/index.html?embedded=1&role=" + encodeURIComponent(activeRole);
    }

    function studioAddress() {
        return sourceMode === "server" ? serverAddress() : bundledAddress();
    }

    function startStudio() {
        if (!webEnabled) return;
        if (!studioRequested) {
            studioRequested = true;
            studioWebView.studioUrl = studioAddress();
        } else if (studioWebView.failed || !studioWebView.loaded) {
            studioWebView.loadUrl(studioAddress());
        }
    }

    function reconnectStudio() {
        if (!webEnabled) {
            toast("The native field desk is active. The embedded studio is disabled in this build.", "error");
            return;
        }
        if (!studioRequested) {
            startStudio();
            return;
        }
        studioWebView.loadUrl(studioAddress());
        toast("Reconnecting the field studio\u2026");
    }

    function switchSource() {
        sourceMode = sourceMode === "server" ? "bundled" : "server";
        if (studioRequested) studioWebView.loadUrl(studioAddress());
        toast(sourceMode === "server"
              ? "Switching to the local studio server. Run scripts/serve-map.sh if the page stays blank."
              : "Switching to the bundled studio, which works without a server.");
    }

    function setStudioRole(role) {
        if (!studioWebView.loaded) return;
        callStudio("setRole", [role]);
    }

    function callStudio(name, args, callback) {
        if (!studioWebView.loaded) return;
        var payload = JSON.stringify(args === undefined ? [] : args);
        studioWebView.runJavaScript("window.dhunStudio && window.dhunStudio." + name + " ? window.dhunStudio." + name + "(" + payload + ") : false", callback);
    }

    function pushSync() {
        if (!studioWebView.loaded) return;
        callStudio("setRole", [activeRole]);
        var inventory = [];
        for (var i = 0; i < produceOffers.length; ++i) {
            var offer = produceOffers[i];
            inventory.push({
                produceId: offer.ingredientId,
                stock: Number(offer.stock),
                updatedAt: Number(offer.updatedAt || offer.harvestedAt || Date.now())
            });
        }
        callStudio("syncInventory", [inventory]);
        var activities = [];
        for (var j = 0; j < allActivities.length; ++j) {
            var activity = allActivities[j];
            activities.push({
                id: activity.id,
                role: activity.role,
                type: activity.type,
                title: activity.title,
                produceId: activity.produceId,
                zone: activity.zone,
                date: Number(activity.date),
                status: activity.status,
                notes: activity.notes,
                visibility: activity.visibility,
                source: activity.source,
                media: activity.media || [],
                plot: activity.plot || null
            });
        }
        callStudio("syncActivities", [activities]);
    }

    function pushActivity(activity) {
        if (!activity) return;
        callStudio("importActivity", [activity]);
    }

    function pushStatus(id, status) {
        callStudio("setActivityStatus", [id, status]);
    }

    function recordOrder(produceId, qty, reference, offerId) {
        callStudio("recordOrder", [produceId, qty, reference, offerId]);
    }

    function resetStudio() {
        if (studioWebView.loaded) callStudio("resetSchedule", []);
    }

    function refreshStudio() {
        pushSync();
    }

    function handleBridgeEvent(event) {
        if (!event || !event.type) return;
        if (event.type === "ready") {
            pushSync();
            if (pendingComposer.length > 0) {
                callStudio("openComposer", [pendingComposer]);
                pendingComposer = "";
            }
            studioReady(event);
        } else if (event.type === "role" && event.role && event.role !== activeRole) {
            studioRole(event.role);
        } else if (event.type === "activity" && event.activity) {
            studioActivity(event.activity);
        } else if (event.type === "activity-status" && event.id) {
            studioStatus(event.id, event.status === "done" ? "done" : "planned");
        } else if (event.type === "open-offer" && event.produceId) {
            studioOffer(event.produceId, event.offerId || "", Math.max(1, Number(event.qty) || 1));
        } else if (event.type === "update" && event.update) {
            studioUpdate(event.update);
        }
    }

    function pollBridge() {
        if (!studioWebView.loaded || polling) return;
        polling = true;
        studioWebView.runJavaScript("window.dhunBridge && window.dhunBridge.drainJSON ? window.dhunBridge.drainJSON() : '[]'", function (result) {
            page.polling = false;
            if (!result || result === "[]") return;
            var events = [];
            try { events = JSON.parse(result); } catch (error) { return; }
            if (!events || !events.length) return;
            for (var i = 0; i < events.length; ++i) page.handleBridgeEvent(events[i]);
        });
    }

    function openStudioComposer(kind) {
        if (webEnabled && studioWebView.loaded) {
            callStudio("openComposer", [kind]);
            return true;
        }
        if (webEnabled) {
            pendingComposer = kind;
            startStudio();
            toast(kind === "video" ? "Opening the studio to record a clip\u2026" : "Opening the studio work composer\u2026");
            return true;
        }
        return false;
    }

    function openActivityComposer() {
        if (webEnabled && openStudioComposer("activity")) return;
        composerType = "sowing";
        composerZone = "farms";
        composerError = "";
        activityTitle.text = "";
        activityProduce.text = "";
        activityNotes.text = "";
        composerOpen = true;
    }

    function openActivityFromMap(activity) {
        if (!activity) return;
        selectedActivityId = activity.id;
        selectedProduceId = "";
        selectedDay = startOfDay(activity.date);
        weekOffset = Math.floor((selectedDay - startOfDay(Date.now())) / (7 * dayMilliseconds));
    }

    function selectProduce(id) {
        selectedProduceId = id;
        selectedActivityId = "";
    }

    function matchProduce(text) {
        var value = String(text || "").trim().toLowerCase();
        if (value.length === 0) return null;
        for (var i = 0; i < Data.ingredients.length; ++i) {
            var item = Data.ingredients[i];
            if (item.id === value || item.name.toLowerCase() === value || item.local.toLowerCase() === value)
                return item;
        }
        for (var j = 0; j < Data.ingredients.length; ++j) {
            var entry = Data.ingredients[j];
            if ((entry.name + " " + entry.local + " " + entry.botanical).toLowerCase().indexOf(value) !== -1)
                return entry;
        }
        return null;
    }

    function saveActivity() {
        var title = String(activityTitle.text || "").trim();
        if (title.length === 0) {
            composerError = "Give the field work a short title.";
            return;
        }
        var produce = matchProduce(activityProduce.text);
        if (String(activityProduce.text || "").trim().length > 0 && !produce) {
            composerError = "No produce matches that name. Clear it to record general field work.";
            return;
        }
        var date = new Date(selectedDay);
        date.setHours(9, 0, 0, 0);
        var spec = {
            role: activeRole,
            type: composerType,
            title: title,
            produceId: produce ? produce.id : "",
            zone: produce ? produce.zone : composerZone,
            date: date.getTime(),
            status: "planned",
            notes: String(activityNotes.text || "").trim(),
            visibility: "room",
            source: "wallet",
            plot: produce ? Data.plotFor(produce) : null
        };
        composerError = "";
        composerOpen = false;
        addActivity(spec);
    }

    Component.onCompleted: selectedDay = startOfDay(Date.now())

    onVisibleChanged: if (visible) startStudio()

    Timer {
        interval: 1100
        running: studioWebView.loaded && !studioWebView.failed
        repeat: true
        onTriggered: page.pollBridge()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pagePadding
        anchors.rightMargin: Theme.pagePadding
        anchors.topMargin: 16
        anchors.bottomMargin: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                implicitWidth: statusRow.implicitWidth + 22
                implicitHeight: 24

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: page.statusColor
                    opacity: 0.16
                }

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: page.statusColor
                    }
                    Text {
                        id: statusLabel
                        text: page.statusText
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                Layout.leftMargin: 6
                Layout.fillWidth: true
                visible: page.width > 1180
                text: page.statusHint
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: !visible }

            ActionButton {
                text: "Mark work"
                variant: "secondary"
                compact: true
                onClicked: page.openActivityComposer()
            }

            ActionButton {
                text: "Record clip"
                variant: "primary"
                compact: true
                onClicked: {
                    if (!page.openStudioComposer("video"))
                        page.toast("Clip capture needs the embedded studio. Reconnect it or use a browser.", "error");
                }
            }

            ActionButton {
                visible: page.webEnabled
                text: "Reconnect"
                variant: "ghost"
                compact: true
                onClicked: page.reconnectStudio()
            }

            ActionButton {
                visible: page.webEnabled
                text: page.sourceMode === "server" ? "Bundled" : "Local server"
                variant: "ghost"
                compact: true
                onClicked: page.switchSource()
            }

            ActionButton {
                text: "Browser"
                variant: "ghost"
                compact: true
                onClicked: {
                    Qt.openUrlExternally("http://127.0.0.1:8788/qml/web/");
                    page.toast("If the browser page is blank, run scripts/serve-map.sh first.");
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 12
            color: Theme.white
            border.width: 1
            border.color: Theme.line

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                anchors.topMargin: 8
                anchors.bottomMargin: 8
                spacing: 10

                ColumnLayout {
                    Layout.preferredWidth: 148
                    spacing: 1

                    Text {
                        text: "Native & foraged"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 13
                    }
                    Text {
                        text: Data.nativeSpecies.length + " reference species \u00B7 not stock"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    model: Data.nativeSpecies
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: nativeCard
                        required property var modelData
                        width: 172
                        height: ListView.view.height
                        radius: 8
                        clip: true
                        color: Theme.paper
                        border.width: 1
                        border.color: nativeHover.containsMouse ? Theme.sage : Theme.lineSoft

                        Image {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 58
                            source: "../assets/produce/" + nativeCard.modelData.photo + ".jpg"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        ColumnLayout {
                            anchors.left: parent.left
                            anchors.leftMargin: 66
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: nativeCard.modelData.name
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: nativeCard.modelData.kind
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: nativeCard.modelData.credit.split(" / ")[1] || "Wikimedia Commons"
                                color: Theme.mutedLight
                                font.family: Theme.uiFont
                                font.pixelSize: 5
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: nativeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }

                        ToolTip.visible: nativeHover.containsMouse
                        ToolTip.delay: 250
                        ToolTip.text: nativeCard.modelData.local + "\n" + nativeCard.modelData.note
                                      + "\nPhoto: " + nativeCard.modelData.credit + " (Wikimedia Commons)"
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 420
                radius: Theme.radiusXL
                color: Theme.forest
                clip: true

                StudioWebView {
                    id: studioWebView
                    anchors.fill: parent
                    started: page.studioRequested && page.webEnabled
                    pageActive: page.visible
                    visible: page.webEnabled && !studioWebView.failed
                    onPageLoaded: page.callStudio("snapshot", [])
                }

                Item {
                    id: nativeDesk
                    anchors.fill: parent
                    visible: !page.webEnabled || studioWebView.failed

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
                            GradientStop { position: 1.0; color: "#0E1E16B8" }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14

                        Rectangle {
                            implicitWidth: planPill.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: "#12241AD9"
                            border.width: 1
                            border.color: "#3C5943"

                            RowLayout {
                                id: planPill
                                anchors.centerIn: parent
                                spacing: 5
                                Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.lime }
                                Text {
                                    text: "LOCAL PLAN VIEW \u00B7 CHAK GULABPURA"
                                    color: "#C7D6C4"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.9
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: countPill.implicitWidth + 18
                            implicitHeight: 24
                            radius: 12
                            color: "#12241AD9"
                            border.width: 1
                            border.color: "#3C5943"

                            Text {
                                id: countPill
                                anchors.centerIn: parent
                                text: Data.ingredients.length + " plots \u00B7 " + page.produceOffers.length + " wallet lots"
                                color: "#C7D6C4"
                                font.family: Theme.monoFont
                                font.pixelSize: 7
                            }
                        }
                    }

                    Repeater {
                        model: Data.zones

                        delegate: Item {
                            required property var modelData
                            x: nativeDesk.width * page.xPercent(modelData.longitude) - width / 2
                            y: nativeDesk.height * page.yPercent(modelData.latitude) - height / 2
                            width: zoneTag.implicitWidth + 14
                            height: 22
                            z: 2

                            Rectangle {
                                anchors.fill: parent
                                radius: 11
                                color: "#12241AB8"
                                border.width: 1
                                border.color: "#36503E"
                            }

                            RowLayout {
                                id: zoneTag
                                anchors.centerIn: parent
                                spacing: 4
                                Rectangle { width: 5; height: 5; radius: 2.5; color: modelData.color }
                                Text {
                                    text: modelData.short
                                    color: "#BDD0BC"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    Repeater {
                        model: Data.ingredients

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var plot: Data.plotFor(modelData)
                            width: 6
                            height: 6
                            radius: 3
                            color: Data.zoneById(modelData.zone).color
                            opacity: 0.72
                            z: 1
                            x: nativeDesk.width * page.xPercent(plot.longitude) - width / 2
                            y: nativeDesk.height * page.yPercent(plot.latitude) - height / 2

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectProduce(modelData.id)
                            }
                        }
                    }

                    Repeater {
                        model: page.produceOffers

                        delegate: Item {
                            id: producePin
                            required property var modelData
                            readonly property var ingredient: Data.ingredientById(modelData.ingredientId)
                            readonly property var plot: ingredient ? Data.plotFor(ingredient) : null
                            width: 58
                            height: 62
                            z: page.selectedProduceId === modelData.ingredientId ? 20 : 8
                            x: plot ? nativeDesk.width * page.xPercent(plot.longitude) - width / 2 : 0
                            y: plot ? nativeDesk.height * page.yPercent(plot.latitude) - height / 2 : 0
                            visible: ingredient !== null

                            Rectangle {
                                id: photoFrame
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 38
                                height: 38
                                radius: 11
                                color: "#12241A"
                                border.width: page.selectedProduceId === modelData.ingredientId ? 2 : 1.5
                                border.color: page.selectedProduceId === modelData.ingredientId ? Theme.lime : "#F4F1E7"

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: page.photoSource(producePin.ingredient)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    opacity: Number(modelData.stock) > 0 ? 1 : 0.55
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 40
                                width: Math.min(82, labelText.implicitWidth + 10)
                                height: 18
                                radius: 9
                                color: "#12241AE6"

                                Text {
                                    id: labelText
                                    anchors.centerIn: parent
                                    text: producePin.ingredient ? producePin.ingredient.name : ""
                                    color: "#F0F4E6"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectProduce(modelData.ingredientId)
                            }
                        }
                    }

                    Repeater {
                        model: page.allActivities

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var plot: page.activityPlot(modelData)
                            readonly property var type: page.activityType(modelData)
                            width: modelData.status === "done" ? 13 : 16
                            height: width
                            radius: width / 2
                            color: type.color
                            border.width: 1.5
                            border.color: modelData.status === "done" ? "#B7C8B7" : "#F8F5EA"
                            opacity: modelData.role === page.activeRole ? 1 : 0.58
                            z: 10
                            x: nativeDesk.width * page.xPercent(plot.longitude) - width / 2
                            y: nativeDesk.height * page.yPercent(plot.latitude) - height / 2

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.openActivityFromMap(modelData)
                            }
                        }
                    }

                    Item {
                        width: 34
                        height: 34
                        z: 15
                        x: nativeDesk.width * page.xPercent(Data.site.longitude) - width / 2
                        y: nativeDesk.height * page.yPercent(Data.site.latitude) - height / 2

                        Rectangle {
                            anchors.fill: parent
                            radius: 17
                            color: Theme.lime
                            border.width: 2
                            border.color: "#F8F5EA"

                            Icon {
                                anchors.centerIn: parent
                                name: "leaf"
                                color: Theme.forest
                                width: 16
                                height: 16
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 38
                            text: "Dhun"
                            color: "#F4F7E9"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        visible: studioWebView.failed && page.webEnabled
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        height: noticeText.implicitHeight + 22
                        radius: 12
                        color: "#2C1A12F0"
                        border.width: 1
                        border.color: "#6D3B28"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Icon {
                                name: "info"
                                color: "#E8B79D"
                                width: 14
                                height: 14
                            }

                            Text {
                                id: noticeText
                                Layout.fillWidth: true
                                text: studioWebView.failureText
                                color: "#F0D9C9"
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                wrapMode: Text.WordWrap
                                lineHeight: 1.3
                            }

                            ActionButton {
                                text: "Reconnect"
                                variant: "gold"
                                compact: true
                                onClicked: page.reconnectStudio()
                            }
                        }
                    }

                    Rectangle {
                        id: selectionCard
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        width: Math.min(370, nativeDesk.width - 28)
                        height: selectionColumn.implicitHeight + 26
                        radius: 15
                        color: "#FBF9F1"
                        border.width: 1
                        border.color: "#D3D9C9"
                        z: 30
                        visible: (page.selectedIngredient !== null || page.selectedActivity !== null) && !(studioWebView.failed && page.webEnabled)

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {}
                        }

                        ColumnLayout {
                            id: selectionColumn
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9
                                visible: page.selectedIngredient !== null

                                Rectangle {
                                    width: 52
                                    height: 52
                                    radius: 12
                                    clip: true
                                    color: Theme.paperDeep

                                    Image {
                                        anchors.fill: parent
                                        source: page.photoSource(page.selectedIngredient)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: page.selectedIngredient ? page.selectedIngredient.name : ""
                                        color: Theme.ink
                                        font.family: Theme.displayFont
                                        font.pixelSize: 17
                                    }
                                    Text {
                                        text: page.selectedIngredient
                                              ? (page.selectedIngredient.local + " \u00B7 " + page.selectedIngredient.zoneName)
                                              : ""
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: page.selectedOffer
                                              ? ("\u20B9" + page.selectedOffer.price + " / " + page.selectedOffer.unit + " \u00B7 " + page.selectedOffer.stock + " in stock")
                                              : "Growing at Dhun \u00B7 not listed in the wallet tonight"
                                        color: page.selectedOffer ? Theme.forestMid : Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                    }
                                }

                                ActionButton {
                                    visible: page.selectedOffer !== null
                                    text: "Procure"
                                    variant: "primary"
                                    compact: true
                                    enabled: page.selectedOffer !== null && Number(page.selectedOffer.stock) > 0
                                    onClicked: if (page.selectedOffer) page.purchase(page.selectedOffer)
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: closeProduce.containsMouse ? Theme.paperDeep : "transparent"

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        color: Theme.muted
                                        width: 10
                                        height: 10
                                    }

                                    MouseArea {
                                        id: closeProduce
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selectedProduceId = ""
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9
                                visible: page.selectedActivity !== null

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 10
                                    color: page.activityType(page.selectedActivity).color
                                    opacity: 0.9

                                    Text {
                                        anchors.centerIn: parent
                                        text: page.selectedActivity && page.selectedActivity.status === "done" ? "\u2713" : "\u2022"
                                        color: "#FFFFFF"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: page.selectedActivity ? page.selectedActivity.title : ""
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: page.selectedActivity
                                              ? (page.dayLabel(page.selectedActivity.date) + " \u00B7 " + page.timeLabel(page.selectedActivity.date) + " \u00B7 " + page.activityMeta(page.selectedActivity))
                                              : ""
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                ActionButton {
                                    text: page.selectedActivity && page.selectedActivity.status === "done" ? "Reopen" : "Mark done"
                                    variant: "secondary"
                                    compact: true
                                    onClicked: {
                                        if (!page.selectedActivity) return;
                                        page.setActivityStatus(page.selectedActivity.id,
                                                              page.selectedActivity.status === "done" ? "planned" : "done");
                                    }
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: closeActivity.containsMouse ? Theme.paperDeep : "transparent"

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "close"
                                        color: Theme.muted
                                        width: 10
                                        height: 10
                                    }

                                    MouseArea {
                                        id: closeActivity
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.selectedActivityId = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: page.wide
                // Without the cap this rail claims the whole row at Basecamp's
                // window width, collapsing the studio to a sliver.
                Layout.preferredWidth: page.wide ? 330 : 0
                Layout.minimumWidth: page.wide ? 300 : 0
                Layout.maximumWidth: page.wide ? 330 : 0
                Layout.fillHeight: true
                spacing: 12

                Card {
                    Layout.fillWidth: true
                    padding: 14
                    gap: 9

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Field calendar"
                                color: Theme.ink
                                font.family: Theme.displayFont
                                font.pixelSize: 16
                            }
                            Text {
                                text: page.roleName(page.activeRole) + " \u00B7 " + page.weekLabel
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 6
                            color: previousWeek.containsMouse ? Theme.paperDeep : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                name: "arrow"
                                color: Theme.muted
                                width: 11
                                height: 11
                                rotation: 180
                            }

                            MouseArea {
                                id: previousWeek
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.weekOffset -= 1;
                                    page.selectedDay = page.startOfDay(Date.now()) + page.weekOffset * 7 * page.dayMilliseconds;
                                }
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 6
                            color: nextWeek.containsMouse ? Theme.paperDeep : "transparent"

                            Icon {
                                anchors.centerIn: parent
                                name: "arrow"
                                color: Theme.muted
                                width: 11
                                height: 11
                            }

                            MouseArea {
                                id: nextWeek
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    page.weekOffset += 1;
                                    page.selectedDay = page.startOfDay(Date.now()) + page.weekOffset * 7 * page.dayMilliseconds;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Repeater {
                            model: page.weekDays

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 48
                                radius: 9
                                color: modelData.selected ? Theme.forest : (dayMouse.containsMouse ? Theme.sageLight : Theme.paper)
                                border.width: modelData.today && !modelData.selected ? 1 : 0
                                border.color: Theme.limeDeep

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.weekday.toUpperCase()
                                        color: modelData.selected ? "#AFC4AF" : Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 6
                                        font.letterSpacing: 0.5
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(modelData.day)
                                        color: modelData.selected ? "#F6F8EC" : Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 12
                                        font.weight: modelData.today ? Font.Bold : Font.Medium
                                    }
                                    Row {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 2
                                        Repeater {
                                            model: Math.min(3, modelData.count)
                                            delegate: Rectangle {
                                                width: 3
                                                height: 3
                                                radius: 1.5
                                                color: modelData.selected ? Theme.lime : Theme.limeDeep
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        page.selectedDay = modelData.timestamp;
                                        page.selectedActivityId = "";
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.lineSoft
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: page.dayLabel(page.selectedDay).toUpperCase()
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.1
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.selectedDayActivities.length + " item" + (page.selectedDayActivities.length === 1 ? "" : "s")
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150

                        Text {
                            anchors.centerIn: parent
                            visible: page.selectedDayActivities.length === 0
                            text: "No field work on this day.\nMark work to add it to the calendar."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.4
                        }

                        ListView {
                            anchors.fill: parent
                            visible: page.selectedDayActivities.length > 0
                            clip: true
                            spacing: 4
                            model: page.selectedDayActivities
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width
                                height: 44
                                radius: 8
                                color: activityMouse.containsMouse ? Theme.paperDeep : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: 30
                                    radius: 1.5
                                    color: page.activityType(modelData).color
                                }

                                Text {
                                    x: 11
                                    y: 5
                                    text: page.timeLabel(modelData.date)
                                    color: Theme.muted
                                    font.family: Theme.monoFont
                                    font.pixelSize: 7
                                }

                                Text {
                                    x: 46
                                    y: 4
                                    width: parent.width - 108
                                    text: modelData.title
                                    color: modelData.status === "done" ? Theme.muted : Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    x: 46
                                    y: 20
                                    width: parent.width - 108
                                    text: page.activityMeta(modelData) + (modelData.status === "done" ? " \u00B7 done" : "")
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 42
                                    height: 24
                                    radius: 7
                                    color: doneMouse.containsMouse ? Theme.sageLight : Theme.paper
                                    border.width: 1
                                    border.color: Theme.line

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.status === "done" ? "Reopen" : "Done"
                                        color: Theme.inkSoft
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: doneMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.setActivityStatus(modelData.id, modelData.status === "done" ? "planned" : "done")
                                    }
                                }

                                MouseArea {
                                    id: activityMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: 46
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.openActivityFromMap(modelData)
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 14
                    gap: 9

                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: "Produce in the wallet"
                                color: Theme.ink
                                font.family: Theme.displayFont
                                font.pixelSize: 16
                            }
                            Text {
                                text: page.produceInStock.length + " lots in stock \u00B7 " + page.orders.length + " field orders"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Pill {
                            text: "LIVE STOCK"
                            fg: Theme.forest
                            bg: Theme.sageLight
                            dotColor: Theme.limeDeep
                            fontSize: 6
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 260
                        clip: true
                        spacing: 6
                        model: page.produceOffers
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 58
                            radius: 10
                            color: page.selectedOffer && page.selectedOffer.id === modelData.id ? Theme.sageLight : Theme.paper
                            border.width: 1
                            border.color: page.selectedOffer && page.selectedOffer.id === modelData.id ? "#AFC39E" : Theme.lineSoft

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectProduce(modelData.ingredientId)
                            }

                            Rectangle {
                                x: 7
                                anchors.verticalCenter: parent.verticalCenter
                                width: 42
                                height: 42
                                radius: 9
                                clip: true
                                color: Theme.paperDeep

                                Image {
                                    anchors.fill: parent
                                    source: page.photoSource(Data.ingredientById(modelData.ingredientId))
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                }
                            }

                            ColumnLayout {
                                x: 56
                                y: 8
                                width: parent.width - 126
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.supplier + " \u00B7 " + modelData.stock + " " + modelData.unit + " left"
                                    color: Number(modelData.stock) > 0 ? Theme.muted : Theme.danger
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "\u20B9" + modelData.price + " / " + modelData.unit
                                    color: Theme.forestMid
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                            }

                            ActionButton {
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Procure"
                                variant: "primary"
                                compact: true
                                enabled: Number(modelData.stock) > 0
                                onClicked: page.purchase(modelData)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Field inventory is rehearsal data held in the wallet. Orders above a role's allowance become a 2-of-3 proposal. Species photos are Wikimedia Commons references; credits are in docs/NATIVE-SPECIES.md."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }
            }
        }
    }

    SideSheet {
        id: activitySheet
        open: page.composerOpen
        eyebrow: "Field calendar \u00B7 " + page.roleName(page.activeRole)
        title: "Mark field work"
        subtitle: "Add the work to your calendar and the field map. It shares a room note with the other parties."
        panelWidth: 530
        onClose: page.composerOpen = false

        LabeledField {
            id: activityTitle
            Layout.fillWidth: true
            label: "What happens"
            placeholder: "e.g. Scout the bajra drying yard"
            maximumLength: 100
        }

        Text {
            text: "ACTIVITY TYPE"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 7
            font.letterSpacing: 1.1
            font.weight: Font.DemiBold
        }

        Flow {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: Data.activityTypes

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: page.composerType === modelData.id
                    width: typeChip.implicitWidth + 18
                    height: 27
                    radius: 8
                    color: active ? Theme.sageLight : Theme.white
                    border.width: 1
                    border.color: active ? modelData.color : Theme.line

                    RowLayout {
                        id: typeChip
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: modelData.color
                        }

                        Text {
                            text: modelData.label
                            color: active ? Theme.ink : Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: active ? Font.DemiBold : Font.Normal
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.composerType = modelData.id
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            LabeledField {
                id: activityProduce
                Layout.fillWidth: true
                label: "Produce (optional)"
                placeholder: "Bajra, sarson, amla\u2026"
                hint: "A matching produce moves the pin to its plot. Leave blank for general work."
                maximumLength: 40
            }

            ColumnLayout {
                Layout.preferredWidth: 190
                spacing: 4

                Text {
                    text: "ZONE"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    font.letterSpacing: 1.1
                    font.weight: Font.DemiBold
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: Data.zones

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: page.composerZone === modelData.id
                            width: zoneChip.implicitWidth + 14
                            height: 25
                            radius: 7
                            color: active ? Theme.forest : Theme.white
                            border.width: 1
                            border.color: active ? Theme.forest : Theme.line

                            Text {
                                id: zoneChip
                                anchors.centerIn: parent
                                text: modelData.short
                                color: active ? "#F4F7E9" : Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.composerZone = modelData.id
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "NOTES"
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 7
                font.letterSpacing: 1.1
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                radius: 9
                color: Theme.white
                border.width: 1
                border.color: activityNotes.activeFocus ? "#A8BE9B" : Theme.line

                TextArea {
                    id: activityNotes
                    anchors.fill: parent
                    anchors.margins: 9
                    padding: 0
                    placeholderText: "Covenant points, moisture reading, what to check next\u2026"
                    placeholderTextColor: Theme.mutedLight
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    wrapMode: TextArea.Wrap
                    selectByMouse: true
                    background: null
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: 9
            color: Theme.sageLight

            RowLayout {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 7

                Icon {
                    name: "clock"
                    color: Theme.forestMid
                    width: 13
                    height: 13
                }

                Text {
                    Layout.fillWidth: true
                    text: "Scheduled for " + page.dayLabel(page.selectedDay) + " at 09:00 \u00B7 " + page.roleName(page.activeRole)
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: page.composerError.length > 0
            text: page.composerError
            color: Theme.danger
            font.family: Theme.uiFont
            font.pixelSize: 8
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ActionButton {
                Layout.fillWidth: true
                text: "Add to calendar"
                variant: "primary"
                onClicked: page.saveActivity()
            }

            ActionButton {
                text: "Cancel"
                variant: "ghost"
                onClicked: page.composerOpen = false
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Rehearsal field log \u00B7 saved on this device, not on chain."
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 7
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
