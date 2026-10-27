import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../data.js" as Data
import "../kitchen.js" as Kitchen
import "../components"

Item {
    id: page

    property var app: null
    property var host: null
    property var plan: null
    property int guests: 24
    property int month: 12
    property string menuText: Kitchen.sampleMenus[0].text
    property string photoPath: ""
    property string modelEndpoint: "http://127.0.0.1:11434/v1"
    property string modelName: "qwen2.5vl:7b"
    property bool modelBusy: false
    property string modelStatus: "No model called. The built-in planner reads the typed lines offline."
    property string modelProvenance: "Built-in planner · offline"
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
        setMenuText(sample.text);
        modelProvenance = "Built-in planner · offline";
        modelStatus = "Sample menu loaded. No model called.";
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

    function checkServer() {
        if (!Kitchen.localEndpointAllowed(modelEndpoint)) {
            modelStatus = "Only a loopback endpoint is allowed. Use http://127.0.0.1:11434/v1 or another local port.";
            return;
        }
        modelBusy = true;
        modelStatus = "Checking " + Kitchen.modelsUrl(modelEndpoint) + " …";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", Kitchen.modelsUrl(modelEndpoint), true);
        xhr.timeout = 8000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            page.modelBusy = false;
            if (xhr.status < 200 || xhr.status >= 300) {
                page.modelStatus = "No local model server replied (HTTP " + xhr.status + "). Start Ollama or llama.cpp and try again.";
                return;
            }
            try {
                var data = JSON.parse(xhr.responseText);
                var items = data.data || data.models || [];
                var names = [];
                for (var i = 0; i < items.length && names.length < 6; ++i) {
                    var name = items[i].id || items[i].name || items[i].model;
                    if (name) names.push(name);
                }
                page.modelStatus = names.length
                    ? "Local server reachable · " + names.join(" · ")
                    : "Local server reachable, but it listed no models.";
            } catch (error) {
                page.modelStatus = "The local server replied, but the model list was not readable.";
            }
        };
        xhr.onerror = function () {
            page.modelBusy = false;
            page.modelStatus = "No local model server replied. Start Ollama or llama.cpp on loopback.";
        };
        xhr.ontimeout = function () {
            page.modelBusy = false;
            page.modelStatus = "The local model server did not reply in time.";
        };
        xhr.send();
    }

    function readPhotoWithModel() {
        if (modelBusy) return;
        if (!Kitchen.localEndpointAllowed(modelEndpoint)) {
            modelStatus = "Only a loopback endpoint is allowed. The photo is not sent to a remote host.";
            return;
        }
        if (!modelName.trim().length) {
            modelStatus = "Name the local vision model first (for example qwen2.5vl:7b).";
            return;
        }
        if (!host || !host.relayBackend || typeof logos === "undefined" || logos === null) {
            modelStatus = "The module backend is not ready. Open Dhun Commons inside Basecamp to read a local photo.";
            return;
        }
        var path = localPath(photoUrl);
        modelBusy = true;
        modelStatus = "Reading the image locally …";
        logos.watch(host.relayBackend.readPhotoBase64(path), function (value) {
            page.sendPhotoToModel(value, path);
        }, function (error) {
            page.modelBusy = false;
            page.modelStatus = "Could not read the photo: " + error;
        });
    }

    function sendPhotoToModel(value, path) {
        var result;
        try {
            result = JSON.parse(String(value));
        } catch (error) {
            modelBusy = false;
            modelStatus = "The backend returned an unreadable photo payload.";
            return;
        }
        if (!result || !result.success) {
            modelBusy = false;
            modelStatus = "The photo was not read: " + (result && result.error ? result.error : "unknown error");
            return;
        }
        var payload = {
            model: modelName,
            temperature: 0,
            max_tokens: 500,
            messages: [{
                role: "user",
                content: [
                    { type: "text", text: Kitchen.MODEL_PROMPT },
                    { type: "image_url", image_url: { url: "data:" + result.mime + ";base64," + result.base64 } }
                ]
            }]
        };
        modelStatus = "Asking " + modelName + " on loopback. Local inference can take a while …";
        var started = Date.now();
        var xhr = new XMLHttpRequest();
        xhr.open("POST", Kitchen.chatCompletionsUrl(modelEndpoint), true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 180000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            page.modelBusy = false;
            if (xhr.status < 200 || xhr.status >= 300) {
                page.modelStatus = "The local model returned HTTP " + xhr.status + ". Check the model name and server.";
                return;
            }
            var content = "";
            try {
                var data = JSON.parse(xhr.responseText);
                var message = data.choices && data.choices[0] ? data.choices[0].message : null;
                content = message ? message.content : "";
                if (Object.prototype.toString.call(content) === "[object Array]") {
                    var parts = [];
                    for (var i = 0; i < content.length; ++i)
                        if (content[i] && content[i].text) parts.push(content[i].text);
                    content = parts.join(" ");
                }
            } catch (error) {
                page.modelStatus = "The local model replied, but the response was not readable JSON.";
                return;
            }
            var reply = Kitchen.parseModelReply(content);
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
            page.modelProvenance = "Extracted by " + page.modelName + " on loopback · review the lines and the safety gate.";
            page.modelStatus = "Reply received in " + Math.max(1, Math.round((Date.now() - started) / 1000)) + " s." +
                (reply.notes.length ? " " + reply.notes.join(" · ") : "");
            page.rebuild();
        };
        xhr.onerror = function () {
            page.modelBusy = false;
            page.modelStatus = "The local model did not accept the request. Is the server running on loopback?";
        };
        xhr.ontimeout = function () {
            page.modelBusy = false;
            page.modelStatus = "The local model timed out after 180 seconds.";
        };
        xhr.send(JSON.stringify(payload));
    }

    Component.onCompleted: {
        menuArea.text = menuText;
        rebuild();
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
                    font.pixelSize: 19
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

                    Eyebrow { text: "LOCAL VISION MODEL" }

                    LabeledField {
                        Layout.fillWidth: true
                        label: "Loopback endpoint"
                        text: page.modelEndpoint
                        maximumLength: 200
                        onTextChanged: if (page.modelEndpoint !== text) page.modelEndpoint = text
                        hint: "Only 127.0.0.1 / localhost are accepted. Remote endpoints are refused."
                    }

                    LabeledField {
                        Layout.fillWidth: true
                        label: "Model name"
                        text: page.modelName
                        maximumLength: 80
                        onTextChanged: if (page.modelName !== text) page.modelName = text
                        hint: "For example qwen2.5vl:7b with Ollama, or a llama.cpp server model."
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            text: page.modelBusy ? "Working…" : "Check server"
                            variant: "secondary"
                            compact: true
                            fontSize: 9
                            enabled: !page.modelBusy
                            onClicked: page.checkServer()
                        }

                        ActionButton {
                            text: page.modelBusy ? "Working…" : "Read photo"
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
                        text: "Free local vision options: Qwen2.5-VL-7B-Instruct (Apache-2.0), LLaVA-OneVision-7B (Apache-2.0), moondream2 (Apache-2.0), Florence-2-large (MIT). See docs/KITCHEN.md. None is bundled or claimed to be running."
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
                            placeholderText: "One dish per line, for example:\nBajra Roti\nMoth Dal\nSarson Saag"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            wrapMode: TextArea.Wrap
                            background: null
                            selectByMouse: true
                            onTextChanged: if (page.menuText !== text) page.menuText = text
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
                            text: "Plan the menu"
                            compact: true
                            fontSize: 9
                            onClicked: page.rebuild()
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.modelProvenance + ". Quantities, stock and prices are planning estimates from the seeded Market; they are not live farmer inventory."
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
                    label: "ESTIMATED COST"
                    value: page.plan ? page.plan.totals.costInr : "₹0"
                    caption: page.plan ? page.plan.totals.marketCostInr + " Market · " + page.plan.totals.plotCostInr + " plot estimate" : ""
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
                    text: "Each line is tied to the ingredient's plot on the field map. A Market lot uses the seeded offer stock; a field-plot line is an estimate to confirm with the grower, not a live inventory promise."
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
                                            text: (modelData.estimated ? "est. " : "") + Logic.formatINR(modelData.cost)
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
