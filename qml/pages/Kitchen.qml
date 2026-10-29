import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../data.js" as Data
import "../kitchen.js" as Kitchen
import "../assistant.js" as Assistant
import "../components"

Item {
    id: page

    property var app: null
    property var host: null
    property var plan: null
    property int guests: 24
    property int month: 12
    property string menuText: Kitchen.sampleMenus[0].text
    property string promptText: ""
    property var promptInfo: null
    property var modelTips: []
    property string photoPath: ""
    property string modelEndpoint: "http://127.0.0.1:11434/v1"
    property string modelName: "qwen2.5vl:3b"
    property bool modelBusy: false
    property string modelStatus: "Checking local menu suggestions…"
    property string modelProvenance: "Local AI · checking availability"
    property bool cooledWithin2h: false
    property bool refrigerated: false
    property bool untouched: false
    property bool dehydrator: false

    readonly property string samplePhotoUrl: Qt.resolvedUrl("../assets/menu-sample.jpg")
    readonly property string photoUrl: photoPath.length > 0 ? photoPath : samplePhotoUrl
    readonly property bool samplePhoto: photoPath.length === 0
    readonly property var season: plan && plan.season ? plan.season : Kitchen.seasonForMonth(month)
    readonly property string monthLabel: Data.monthNames[Math.max(0, month - 1)] + " · " + season.name

    function localPath(url) {
        var value = String(url === undefined || url === null ? "" : url);
        if (value.indexOf("file://") === 0) value = value.substring(7);
        try { value = decodeURIComponent(value); } catch (error) {}
        return value;
    }

    function setMenuText(text) {
        menuText = String(text === undefined || text === null ? "" : text);
        menuArea.text = menuText;
    }

    function useSample(index) {
        var sample = Kitchen.sampleMenus[Math.max(0, Math.min(Kitchen.sampleMenus.length - 1, index))];
        guests = sample.guests;
        month = sample.month;
        photoPath = "";
        promptText = "";
        promptInfo = null;
        modelTips = [];
        setMenuText(sample.text);
        modelProvenance = "Built-in planner · sample menu";
        modelStatus = "Sample menu loaded. Change guests to recalculate quantities and costs.";
        rebuild();
    }

    function rebuild() {
        plan = Kitchen.buildPlan(app, {
            guests: guests,
            month: month,
            menuText: menuText,
            safety: {
                cooledWithin2h: cooledWithin2h,
                refrigerated: refrigerated,
                untouched: untouched,
                dehydrator: dehydrator
            },
            now: Date.now()
        });
        if (plan && plan.ok && promptInfo) plan.prompt = promptInfo;
    }

    function planFromPrompt() {
        if (!String(promptText || "").trim().length) {
            modelStatus = "Type a dish, a mood or anything you want to cook.";
            return;
        }
        var interpreted = Kitchen.interpretPrompt(promptText, month);
        if (!interpreted.ok) {
            modelStatus = interpreted.error;
            return;
        }
        if (interpreted.guests > 0) {
            guests = interpreted.guests;
            guestsField.text = String(guests);
        }
        modelTips = [];
        promptInfo = {
            text: promptText,
            kind: interpreted.kind,
            note: interpreted.note,
            dishes: interpreted.dishes.map(function (item) { return item.name; })
        };
        setMenuText(interpreted.text);
        modelProvenance = "Built-in planner · " +
            (interpreted.kind === "mood" ? "mood match" :
             (interpreted.kind === "dish" ? "dish match" : "seasonal fallback"));
        modelStatus = interpreted.note + " Sourcing and costs are calculated from local app data.";
        rebuild();
    }

    function fallbackFromPrompt(reason) {
        planFromPrompt();
        if (plan && plan.ok)
            modelStatus = reason + " The built-in local planner made a fallback plan; review its menu and estimates.";
        else
            modelStatus = reason + " " + modelStatus;
    }

    function suggestMenuWithLocalAi() {
        if (modelBusy) return;
        if (!backendReady()) {
            fallbackFromPrompt("Basecamp's local AI connection is not ready. No remote provider was used.");
            return;
        }
        var request = String(promptText || "").trim();
        if (!request.length) {
            modelStatus = "Describe the meal, cuisine, preferences or constraints first.";
            return;
        }
        var interpreted = Kitchen.interpretPrompt(request, month);
        if (interpreted.ok && interpreted.guests > 0) {
            guests = interpreted.guests;
            guestsField.text = String(guests);
        }
        var state = app && app.state ? app.state : app;
        var offers = Logic.produceOffers(state).map(function (offer) {
            return {
                ingredientId: String(offer.ingredientId || ""),
                title: String(offer.title || offer.ingredientId || ""),
                stock: Number(offer.stock) || 0,
                unit: String(offer.unit || ""),
                pricePerUnit: Number(offer.price) || 0,
                supplier: String(offer.supplier || "")
            };
        });
        modelBusy = true;
        modelStatus = "Asking the local model for a menu. Guest-scaled quantities, stock coverage and costs will be computed by the planner.";
        var payload = {
            messages: Assistant.kitchenMessages(request, guests, month, Kitchen.dishChoices(), offers),
            maxTokens: 900,
            temperature: 0.2,
            localOnly: true
        };
        logos.watch(host.relayBackend.aiChat(JSON.stringify(payload)), function (value) {
            page.modelBusy = false;
            var snapshot = {};
            try { snapshot = JSON.parse(String(value)); } catch (error) { snapshot = {}; }
            if (!snapshot.success || snapshot.provider !== "ollama") {
                page.fallbackFromPrompt(snapshot.error || "The local model did not return a local response. No remote provider was used.");
                return;
            }
            var reply = Kitchen.parseModelReply(snapshot.content || "", { allowExtras: false });
            if (!reply.ok || !reply.matched) {
                page.fallbackFromPrompt(reply.error || "The local model did not choose a recognized dish.");
                return;
            }
            var data = Assistant.parseJsonObject(snapshot.content || "");
            var tips = [];
            if (data && Array.isArray(data.wasteTips)) {
                for (var i = 0; i < data.wasteTips.length && tips.length < 6; ++i) {
                    var tip = String(data.wasteTips[i] || "").trim();
                    if (tip) tips.push(tip);
                }
            }
            page.modelTips = tips;
            page.setMenuText(Kitchen.modelReplyToText(reply));
            page.promptInfo = {
                text: request,
                kind: "model",
                note: "Local AI menu suggestion · review dishes and verify dietary constraints before cooking.",
                dishes: reply.dishes.map(function (item) { return item.name; })
            };
            page.modelProvenance = "Local AI · review";
            page.modelStatus = "Local suggestion received in " + Math.max(1, Math.round(Number(snapshot.seconds) || 0)) +
                " s. Quantities and all itemized estimates were recalculated for " + page.guests + " guests.";
            page.rebuild();
        }, function (error) {
            page.modelBusy = false;
            page.fallbackFromPrompt("Local AI could not be reached: " + error + ". No remote provider was used.");
        });
    }

    function statusLabel(line) {
        if (line.status === "covered") return "Market lot";
        if (line.status === "partial") return "Short " + line.shortfallLabel;
        if (line.status === "plot") return "Field plot";
        return "No offer";
    }

    function statusColor(line) {
        if (line.status === "covered") return Theme.limeDeep;
        if (line.status === "partial") return Theme.gold;
        if (line.status === "plot") return Theme.blue;
        return Theme.clay;
    }

    function statusSoft(line) {
        if (line.status === "covered") return Theme.sageLight;
        if (line.status === "partial") return Theme.goldLight;
        if (line.status === "plot") return Theme.blueLight;
        return Theme.clayLight;
    }

    function backendReady() {
        return host && host.relayBackend && typeof logos !== "undefined" && logos !== null;
    }

    function checkServer() {
        if (!backendReady()) {
            modelStatus = "Connecting to the local AI backend. The built-in planner is available; Kitchen will not call a remote provider.";
            modelProvenance = "Local AI · connecting";
            return;
        }
        logos.watch(host.relayBackend.probeModelServer(modelEndpoint), function (value) {
            var reply = {};
            try { reply = JSON.parse(String(value)); } catch (error) { reply = {}; }
            page.modelStatus = reply.success && reply.models && reply.models.length
                ? "Local AI is ready. Menu suggestions stay on this Mac."
                : "Local AI is unavailable. Kitchen will use its built-in planner and will not call a remote provider.";
            page.modelProvenance = reply.success && reply.models && reply.models.length
                ? "Local AI · ready"
                : "Built-in planner · available";
        }, function () {
            page.modelStatus = "Local AI is unavailable. Kitchen will not call a remote provider; the built-in planner still works.";
            page.modelProvenance = "Built-in planner · available";
        });
    }

    function readPhotoWithModel() {
        if (modelBusy) return;
        if (!Kitchen.localEndpointAllowed(modelEndpoint)) {
            modelStatus = "Only a loopback endpoint is allowed. The photo is not sent to a remote host.";
            return;
        }
        if (!backendReady()) {
            modelStatus = "The module backend is not ready. Open Dhun Commons inside Basecamp to read a local photo.";
            return;
        }
        var path = localPath(photoUrl);
        modelBusy = true;
        modelStatus = "Reading the photo with local AI. The image stays on this Mac.";
        logos.watch(host.relayBackend.startMenuPhoto(path, modelEndpoint, modelName, Kitchen.MODEL_PROMPT), function (value) {
            page.modelBusy = false;
            var snapshot = {};
            try { snapshot = JSON.parse(String(value)); } catch (error) { snapshot = {}; }
            if (!snapshot.success) {
                page.modelStatus = snapshot.error || "The local model request failed.";
                return;
            }
            var reply = Kitchen.parseModelReply(snapshot.content || "");
            if (!reply.ok) {
                page.modelStatus = reply.error;
                return;
            }
            if (!reply.matched) {
                page.modelStatus = "The model returned " + reply.dishes.length + " dish names, but none matched the kitchen library. Edit the lines by hand.";
                return;
            }
            page.setMenuText(Kitchen.modelReplyToText(reply));
            if (reply.servings > 0) page.guests = reply.servings;
            page.modelTips = [];
            page.promptInfo = {
                kind: "photo",
                note: "Dish names read from the menu photo locally; review before using.",
                dishes: reply.dishes.map(function (item) { return item.name; })
            };
            page.modelProvenance = "Local photo read · review";
            page.modelStatus = "Reply received in " + Math.max(1, Math.round(Number(snapshot.seconds) || 0)) + " s." +
                (reply.notes.length ? " " + reply.notes.join(" · ") : "");
            page.rebuild();
        }, function (error) {
            page.modelBusy = false;
            page.modelStatus = "The module backend could not reach the local model: " + error;
        });
    }

    Connections {
        target: page.host
        ignoreUnknownSignals: true
        function onRelayBackendChanged() {
            if (page.backendReady()) page.checkServer();
        }
    }

    Component.onCompleted: {
        menuArea.text = menuText;
        rebuild();
        checkServer();
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

                Text {
                    text: "Menu → farm → pantry"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 26
                }

                Text {
                    Layout.leftMargin: 8
                    Layout.fillWidth: true
                    text: "A photo or typed menu becomes a sourcing plan, a waste-use plan and a >20-day pantry route."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                }

                Pill {
                    text: page.modelProvenance
                    fg: Theme.forest
                    bg: Theme.sageLight
                    dotColor: Theme.limeDeep
                    fontSize: 8
                }

                ActionButton {
                    compact: true
                    variant: "lime"
                    text: "File plan · +5 DHN"
                    enabled: page.plan !== null && page.plan.ok && page.host !== null
                    onClicked: page.host.fileKitchenPlan(page.plan)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Card {
                    Layout.preferredWidth: 350
                    Layout.alignment: Qt.AlignTop
                    padding: 14
                    gap: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 230
                        radius: 14
                        color: Theme.forest
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: page.photoUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 10
                            visible: page.samplePhoto
                            implicitWidth: sampleLabel.implicitWidth + 16
                            implicitHeight: 22
                            radius: 11
                            color: "#12241ACC"
                            border.width: 1
                            border.color: "#3C5943"

                            Text {
                                id: sampleLabel
                                anchors.centerIn: parent
                                text: "SAMPLE CARD · ILLUSTRATION"
                                color: "#E8F0DC"
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.letterSpacing: 1
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            text: "Choose photo"
                            compact: true
                            fontSize: 9
                            onClicked: photoDialog.open()
                        }

                        ActionButton {
                            text: "Use sample"
                            variant: "secondary"
                            compact: true
                            fontSize: 9
                            onClicked: page.useSample(0)
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.samplePhoto
                            ? "The sample card is illustrative. The built-in planner reads the typed lines below; a local vision model can read your own photo."
                            : "Photo selected locally. Nothing is uploaded unless you press Read photo, and then only to a loopback model."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.lineSoft
                    }

                    Eyebrow { text: "OPTIONAL LOCAL PHOTO READ" }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            text: page.modelBusy ? "Working…" : "Read photo locally"
                            compact: true
                            fontSize: 9
                            enabled: !page.modelBusy
                            onClicked: page.readPhotoWithModel()
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.modelStatus
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Typed menu suggestions and photo reading use local Ollama only. No OpenRouter key or cloud provider is used by Kitchen."
                        color: Theme.mutedLight
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 18
                    gap: 9

                    Eyebrow { text: "WHAT DO YOU WANT TO COOK?" }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        radius: 10
                        color: Theme.white
                        border.width: 1
                        border.color: promptArea.activeFocus ? "#A8BE9B" : Theme.line

                        TextArea {
                            id: promptArea
                            anchors.fill: parent
                            anchors.margins: 9
                            padding: 0
                            placeholderText: "e.g. A warming vegetarian lunch for 20; no peanuts. Prefer produce already listed locally."
                            placeholderTextColor: Theme.mutedLight
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            wrapMode: TextEdit.Wrap
                            background: null
                            selectByMouse: true
                            onTextChanged: if (page.promptText !== text) page.promptText = text
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            compact: true
                            variant: "lime"
                            fontSize: 9
                            text: page.modelBusy ? "Suggesting…" : "Suggest menu locally"
                            enabled: !page.modelBusy
                            onClicked: page.suggestMenuWithLocalAi()
                        }

                        ActionButton {
                            compact: true
                            variant: "secondary"
                            fontSize: 9
                            text: "Use built-in planner"
                            enabled: !page.modelBusy
                            onClicked: page.planFromPrompt()
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Local AI suggests dishes from Dhun's built-in menu library; the planner calculates quantities, local sourcing and estimates. Add dietary needs here and verify ingredients before cooking. Unsupported cuisines need recipes added to the library first."
                            color: Theme.mutedLight
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            wrapMode: Text.WordWrap
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.lineSoft
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Eyebrow { text: "MENU AND GUESTS" }

                        Item { Layout.fillWidth: true }

                        Pill {
                            text: page.monthLabel
                            fg: Theme.goldDeep
                            bg: Theme.goldLight
                            fontSize: 8
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 156
                        radius: 10
                        color: Theme.paperWarm
                        border.width: 1
                        border.color: Theme.line

                        TextArea {
                            id: menuArea
                            anchors.fill: parent
                            anchors.margins: 10
                            padding: 0
                            placeholderText: "Suggested menu appears here. You can edit it; use one dish per line."
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            wrapMode: TextArea.Wrap
                            background: null
                            selectByMouse: true
                            onTextChanged: if (page.menuText !== text) {
                                page.menuText = text;
                                page.promptInfo = null;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "GUESTS"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.1
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            implicitWidth: 64
                            implicitHeight: 32
                            radius: 8
                            color: Theme.white
                            border.width: 1
                            border.color: guestsField.activeFocus ? "#A8BE9B" : Theme.line

                            TextField {
                                id: guestsField
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                text: String(page.guests)
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                horizontalAlignment: TextInput.AlignRight
                                background: null
                                validator: IntValidator { bottom: 1; top: 500 }
                                onEditingFinished: {
                                    page.guests = Math.max(1, Math.min(500, parseInt(text, 10) || 1));
                                    text = String(page.guests);
                                    page.rebuild();
                                }
                            }
                        }

                        Repeater {
                            model: [12, 24, 50, 100]

                            delegate: Rectangle {
                                required property int modelData
                                implicitWidth: guestChip.implicitWidth + 18
                                implicitHeight: 28
                                radius: 14
                                color: page.guests === modelData ? Theme.forest : "transparent"
                                border.width: page.guests === modelData ? 0 : 1
                                border.color: Theme.line

                                Text {
                                    id: guestChip
                                    anchors.centerIn: parent
                                    text: String(modelData)
                                    color: page.guests === modelData ? "#F4F7E9" : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        page.guests = modelData;
                                        guestsField.text = String(page.guests);
                                        page.rebuild();
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "PLANNING MONTH"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.1
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: Data.seasons

                            delegate: Rectangle {
                                required property var modelData
                                readonly property int seasonMonth: modelData.id === "rabi" ? 12 : (modelData.id === "kharif" ? 9 : 5)
                                readonly property bool active: page.season && page.season.id === modelData.id

                                implicitWidth: seasonChip.implicitWidth + 18
                                implicitHeight: 28
                                radius: 14
                                color: active ? Theme.sageLight : "transparent"
                                border.width: active ? 1 : 1
                                border.color: active ? Theme.limeDeep : Theme.line

                                Text {
                                    id: seasonChip
                                    anchors.centerIn: parent
                                    text: modelData.name + " · " + modelData.window
                                    color: active ? Theme.forest : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: active ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        page.month = seasonMonth;
                                        page.rebuild();
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: Kitchen.sampleMenus

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                implicitWidth: sampleChip.implicitWidth + 18
                                implicitHeight: 27
                                radius: 13.5
                                color: sampleMouse.containsMouse ? Theme.sageLight : Theme.white
                                border.width: 1
                                border.color: Theme.line

                                Text {
                                    id: sampleChip
                                    anchors.centerIn: parent
                                    text: modelData.title
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                MouseArea {
                                    id: sampleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.useSample(index)
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ActionButton {
                            text: "Recalculate sourcing"
                            compact: true
                            fontSize: 9
                            onClicked: page.rebuild()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.modelProvenance + ". Quantities scale with guests. Listed Market lots are rehearsal data; unlisted needs and lot shortfalls are estimates to confirm locally, not live inventory."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                }
            }

            Card {
                visible: page.plan && !page.plan.ok
                Layout.fillWidth: true
                padding: 18

                Text {
                    Layout.fillWidth: true
                    text: "No plan yet"
                    color: Theme.ink
                    font.family: Theme.displayFont
                    font.pixelSize: 16
                }

                Text {
                    Layout.fillWidth: true
                    text: page.plan ? page.plan.reason : "Type a menu to begin."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                visible: page.plan && page.plan.ok
                Layout.fillWidth: true
                spacing: 10

                StatTile {
                    Layout.fillWidth: true
                    label: "GUESTS"
                    value: page.plan ? String(page.plan.guests) : "0"
                    caption: page.plan && page.plan.season ? page.plan.season.name + " · " + page.monthLabel : ""
                    accent: Theme.gold
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "DISHES"
                    value: page.plan ? String(page.plan.dishes.length + page.plan.extras.length) : "0"
                    caption: "Recognised menu lines"
                    accent: Theme.limeDeep
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "FARM LINES"
                    value: page.plan ? String(page.plan.totals.lines) : "0"
                    caption: page.plan ? page.plan.totals.requiredKg + " kg planning weight" : ""
                    accent: Theme.forestMid
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "MARKET COVER"
                    value: page.plan ? page.plan.totals.coverage + "%" : "0%"
                    caption: page.plan ? page.plan.totals.covered + " covered · " + page.plan.totals.plotLines + " field plots" : ""
                    accent: Theme.blue
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "ESTIMATED TOTAL"
                    value: page.plan ? page.plan.totals.costInr : "₹0"
                    caption: page.plan ? page.plan.totals.perPersonCostInr + "/person · " + page.plan.totals.marketCostInr + " listed · " + page.plan.totals.plotCostInr + " est." : ""
                    accent: Theme.clay
                }

                StatTile {
                    Layout.fillWidth: true
                    label: ">20-DAY OPTIONS"
                    value: page.plan ? String(page.plan.longLifePreserves.length) : "0"
                    caption: "Allowed by the safety gate"
                    accent: Theme.limeDeep
                }
            }

            Card {
                visible: page.plan && page.plan.ok
                Layout.fillWidth: true
                padding: 18
                gap: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Cook without waste"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 16
                    }

                    Item { Layout.fillWidth: true }

                    Pill {
                        text: page.promptInfo
                              ? (page.promptInfo.kind === "model" ? "Model-assisted menu" :
                                 (page.promptInfo.kind === "mood" ? "Built-in mood plan" :
                                  (page.promptInfo.kind === "dish" ? "Built-in dish plan" : "Built-in seasonal plan")))
                              : "Built-in plan"
                        fg: Theme.forest
                        bg: Theme.sageLight
                        fontSize: 8
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.promptInfo && page.promptInfo.note
                    text: page.promptInfo ? page.promptInfo.note : ""
                    color: Theme.inkSoft
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }

                Repeater {
                    model: page.plan && page.plan.ok && page.plan.zeroWaste ? page.plan.zeroWaste : []

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.sageLight

                            Icon {
                                anchors.centerIn: parent
                                name: "leaf"
                                color: Theme.forest
                                width: 10
                                height: 10
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.detail
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                wrapMode: Text.WordWrap
                                lineHeight: 1.35
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: page.modelTips.length > 0
                    spacing: 4

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.lineSoft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "MODEL TIPS · " + page.modelProvenance
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        font.letterSpacing: 1.1
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: page.modelTips

                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: "· " + modelData
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            wrapMode: Text.WordWrap
                            lineHeight: 1.35
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Model tips are advisory. The waste list, pantry gate and safety blockers above are computed locally and are not replaced by the model."
                        color: Theme.mutedLight
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Card {
                visible: page.plan && page.plan.ok
                Layout.fillWidth: true
                padding: 18
                gap: 12

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Source from the farm map"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 16
                    }

                    Item { Layout.fillWidth: true }

                    Pill {
                        text: page.plan ? page.plan.totals.costInr + " estimated" : ""
                        fg: Theme.forest
                        bg: Theme.sageLight
                        fontSize: 8
                        strong: true
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Each item shows local listed stock and the farm-map source. Listed lots are seeded rehearsal data; quantities beyond a lot and unlisted ingredients use a clearly marked estimate to confirm with the grower before sourcing."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }

                Repeater {
                    model: page.plan && page.plan.ok ? page.plan.groups : []

                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 7

                            Rectangle {
                                width: 7
                                height: 7
                                radius: 4
                                color: modelData.color
                            }

                            Text {
                                text: modelData.zoneName
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Text {
                                text: modelData.lines.length + (modelData.lines.length === 1 ? " ingredient" : " ingredients")
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: Logic.formatINR(modelData.cost) + " est."
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Repeater {
                            model: modelData.lines

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: lineRow.implicitHeight + 16
                                radius: 10
                                color: Theme.paperWarm
                                border.width: 1
                                border.color: Theme.lineSoft

                                RowLayout {
                                    id: lineRow
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 9

                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 8
                                        color: Theme.forest

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: "../assets/produce/" + modelData.photo + ".jpg"
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            spacing: 6

                                            Text {
                                                text: modelData.name
                                                color: Theme.ink
                                                font.family: Theme.uiFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                            }

                                            Text {
                                                text: modelData.local
                                                color: Theme.muted
                                                font.family: Theme.uiFont
                                                font.pixelSize: 8
                                            }

                                            Pill {
                                                visible: !modelData.inSeason
                                                text: "off-season"
                                                fg: Theme.clayDeep
                                                bg: Theme.clayLight
                                                fontSize: 7
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Needs " + modelData.needLabel + " · " + modelData.supplier +
                                                (modelData.offerId ? " · " + modelData.offerId : " · confirm plot") +
                                                " · " + modelData.usedBy.join(" / ")
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: modelData.shortfall > 0
                                            text: "Short " + modelData.shortfallLabel + " against the listed lot."
                                            color: Theme.clayDeep
                                            font.family: Theme.uiFont
                                            font.pixelSize: 7
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Layout.alignment: Qt.AlignRight

                                        Pill {
                                            text: page.statusLabel(modelData)
                                            fg: page.statusColor(modelData)
                                            bg: page.statusSoft(modelData)
                                            fontSize: 7
                                            strong: true
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignRight
                                            text: modelData.marketCost > 0 && modelData.estimatedCost > 0
                                                  ? Logic.formatINR(modelData.marketCost) + " lot + " + Logic.formatINR(modelData.estimatedCost) + " est."
                                                  : (modelData.estimated ? "est. " : "") + Logic.formatINR(modelData.cost)
                                            color: Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Unmatched menu lines: " + (page.plan && page.plan.unmatched.length ? page.plan.unmatched.join(" · ") : "none") +
                        ". A line is only planned when it maps to the farm catalogue."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                visible: page.plan && page.plan.ok
                Layout.fillWidth: true
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    gap: 9

                    Text {
                        text: "Waste parts → kitchen use"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 15
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Stalks, leaves, peels, roots and seeds are used only where the part is edible and clean. Anything doubtful goes to compost."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    Repeater {
                        model: page.plan && page.plan.ok ? page.plan.waste : []

                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: modelData.name
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: modelData.parts

                                delegate: Text {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: "• " + modelData.part + " — " + modelData.use + " " + modelData.caution
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    gap: 9

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Native additions"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 15
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: "FORAGE + GARDEN"
                            fg: Theme.goldDeep
                            bg: Theme.goldLight
                            fontSize: 7
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Lesser-known dryland foods that fit the menu. These are culinary suggestions only, not nutrition or medical claims. Introduce small portions and check allergies."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    Repeater {
                        model: page.plan && page.plan.ok ? page.plan.natives : []

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: nativeColumn.implicitHeight + 16
                            radius: 10
                            color: Theme.sageLight
                            border.width: 1
                            border.color: Theme.lineSoft

                            ColumnLayout {
                                id: nativeColumn
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.name
                                        color: Theme.forest
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: modelData.local
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                    Item { Layout.fillWidth: true }
                                    Pill {
                                        text: modelData.inSeason ? "in season" : "confirm"
                                        fg: modelData.inSeason ? Theme.forest : Theme.clayDeep
                                        bg: modelData.inSeason ? Theme.lime : Theme.clayLight
                                        fontSize: 7
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "With " + modelData.pairing + ": " + modelData.action
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.source
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.caution
                                    color: Theme.clayDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                visible: page.plan && page.plan.ok
                Layout.fillWidth: true
                spacing: 14

                Card {
                    Layout.preferredWidth: 360
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    gap: 8

                    Text {
                        text: "Safety gate for excess food"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 15
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "A long shelf life does not make unsafe food safe. Tick each assurance before a cooked-food preserve is offered. Plate waste is never preserved."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    ToggleRow {
                        Layout.fillWidth: true
                        label: "Cooled within two hours"
                        detail: "From cooking to refrigeration, not left warm."
                        checked: page.cooledWithin2h
                        onToggled: { page.cooledWithin2h = !page.cooledWithin2h; page.rebuild(); }
                    }

                    ToggleRow {
                        Layout.fillWidth: true
                        label: "Kept refrigerated"
                        detail: "Below 5 °C until the preserve is made."
                        checked: page.refrigerated
                        onToggled: { page.refrigerated = !page.refrigerated; page.rebuild(); }
                    }

                    ToggleRow {
                        Layout.fillWidth: true
                        label: "Never served"
                        detail: "Kept out of service; no guest plate returned to the kitchen."
                        checked: page.untouched
                        onToggled: { page.untouched = !page.untouched; page.rebuild(); }
                    }

                    ToggleRow {
                        Layout.fillWidth: true
                        label: "Dehydrator available"
                        detail: "Needed only for the dried dal papad route."
                        checked: page.dehydrator
                        onToggled: { page.dehydrator = !page.dehydrator; page.rebuild(); }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.lineSoft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.cooledWithin2h && page.refrigerated && page.untouched
                            ? "The cooked-food gate is open. Only the methods marked Allowed below are offered."
                            : "The cooked-food gate is closed. Cooked-food preserves show why they are blocked; raw-fruit, trim and dairy routes may still be available."
                        color: page.cooledWithin2h && page.refrigerated && page.untouched ? Theme.forest : Theme.clayDeep
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    padding: 16
                    gap: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Pantry routes over 20 days"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 15
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: page.plan ? page.plan.longLifePreserves.length + " allowed" : "0 allowed"
                            fg: Theme.forest
                            bg: Theme.lime
                            fontSize: 7
                            strong: true
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Shelf lives are conservative kitchen guidance, not a guarantee. Storage conditions and a clean jar matter more than the number on the label."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.35
                    }

                    Repeater {
                        model: page.plan && page.plan.ok ? page.plan.preserves : []

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: preserveColumn.implicitHeight + 14
                            radius: 10
                            color: modelData.allowed ? Theme.paperWarm : Theme.paperDeep
                            border.width: 1
                            border.color: modelData.allowed ? Theme.lineSoft : Theme.line
                            opacity: modelData.allowed ? 1 : 0.78

                            ColumnLayout {
                                id: preserveColumn
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.name
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: modelData.input
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                    Item { Layout.fillWidth: true }
                                    Pill {
                                        text: modelData.days >= 21 ? modelData.daysLabel : modelData.daysLabel
                                        fg: modelData.days >= 21 ? Theme.forest : Theme.muted
                                        bg: modelData.days >= 21 ? Theme.lime : Theme.sage
                                        fontSize: 7
                                        strong: true
                                    }
                                    Pill {
                                        text: modelData.allowed ? "ALLOWED" : "BLOCKED"
                                        fg: modelData.allowed ? Theme.forest : Theme.clayDeep
                                        bg: modelData.allowed ? Theme.sageLight : Theme.clayLight
                                        fontSize: 7
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: modelData.allowed
                                    text: "1. " + modelData.steps[0] + "  2. " + modelData.steps[1] + "  3. " + modelData.steps[2]
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: !modelData.allowed && modelData.blockers.length > 0
                                    text: "Blocked: " + modelData.blockers.join(" ")
                                    color: Theme.clayDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.caveat
                                    color: modelData.allowed ? Theme.muted : Theme.mutedLight
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.3
                                }
                            }
                        }
                    }
                }
            }

            Card {
                visible: page.plan && page.plan.ok && page.plan.memorabilia !== null
                Layout.fillWidth: true
                padding: 18
                gap: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "Guest memorabilia label"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.plan && page.plan.memorabilia
                                ? page.plan.memorabilia.note
                                : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            wrapMode: Text.WordWrap
                        }
                    }

                    Pill {
                        text: "NOT FOR SALE"
                        fg: Theme.clayDeep
                        bg: Theme.clayLight
                        fontSize: 8
                        strong: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 380
                    Layout.alignment: Qt.AlignLeft
                    implicitHeight: labelColumn.implicitHeight + 30
                    radius: 12
                    color: Theme.paperWarm
                    border.width: 1
                    border.color: Theme.gold

                    ColumnLayout {
                        id: labelColumn
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 4

                        Repeater {
                            model: page.plan && page.plan.memorabilia ? page.plan.memorabilia.labelLines : []

                            delegate: Text {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                text: modelData
                                color: index === 0 ? Theme.goldDeep : Theme.ink
                                font.family: index === 0 ? Theme.uiFont : Theme.displayFont
                                font.pixelSize: index === 0 ? 8 : (index === 1 ? 17 : 10)
                                font.letterSpacing: index === 0 ? 1.2 : 0
                                font.weight: index === 0 || index === 5 ? Font.DemiBold : Font.Normal
                                wrapMode: Text.WordWrap
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6

                            Pill {
                                text: page.plan && page.plan.memorabilia ? page.plan.memorabilia.batchCode : ""
                                fg: Theme.forest
                                bg: Theme.lime
                                fontSize: 8
                                mono: true
                                strong: true
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: page.plan && page.plan.memorabilia
                                    ? page.plan.memorabilia.jars + " × " + page.plan.memorabilia.method
                                    : ""
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Give a jar only from a checked batch. Label allergens, storage and the batch code. Guest memorabilia is not a commercial product and is not for sale."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }
            }

            Text {
                Layout.fillWidth: true
                text: "The planner is deterministic and offline. It does not call a model unless you press Read photo, and it never sends a photo to a remote host. Market lots and field plots are seeded rehearsal data, not live farmer inventory."
                color: Theme.mutedLight
                font.family: Theme.uiFont
                font.pixelSize: 7
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
        }
    }

    FileDialog {
        id: photoDialog
        title: "Choose a menu photo"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: {
            page.photoPath = page.localPath(selectedFile);
            page.modelProvenance = "Photo chosen locally · no model called";
            page.modelStatus = "Photo chosen. Press Read photo to use a loopback vision model.";
        }
    }

    component ToggleRow: Item {
        id: toggle

        property string label: ""
        property string detail: ""
        property bool checked: false
        signal toggled()

        implicitHeight: toggleRow.implicitHeight

        RowLayout {
            id: toggleRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                width: 18
                height: 18
                radius: 5
                color: toggle.checked ? Theme.forest : Theme.white
                border.width: 1
                border.color: toggle.checked ? Theme.forest : Theme.line

                Icon {
                    anchors.centerIn: parent
                    visible: toggle.checked
                    name: "check"
                    color: Theme.lime
                    width: 11
                    height: 11
                    strokeWidth: 2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: toggle.label
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: toggle.detail
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    wrapMode: Text.WordWrap
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }
}
