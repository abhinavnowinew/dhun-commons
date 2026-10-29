import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme.js" as Theme
import "../rewards.js" as Rewards
import "../assistant.js" as Assistant
import "../components"

SideSheet {
    id: drawer

    property var app: null
    property var assistantHost: null
    property string activePersonId: ""
    property string backgroundDraft: ""
    property var assessment: null
    property bool assessBusy: false
    property string assessStatus: "No model called. Paste a background or load a text file, then save it."

    signal createProfile(string name, string place, string note)
    signal selectProfile(string id)
    signal openRewards()
    signal saveBackground(string personId, string background, string assessmentJson)
    signal startAllocation(string projectId)
    signal openProjects()

    panelWidth: 540

    readonly property var activePerson: {
        var list = app && app.people ? app.people : [];
        for (var i = 0; i < list.length; ++i)
            if (list[i].id === activePersonId) return list[i];
        return null;
    }
    readonly property bool backendReady: assistantHost && assistantHost.relayBackend &&
                                         assistantHost.relayReady && typeof logos !== "undefined" && logos !== null

    onOpenChanged: if (open) loadPerson()
    onActivePersonIdChanged: if (open) loadPerson()

    function loadPerson() {
        var person = activePerson;
        backgroundDraft = person && person.background ? String(person.background) : "";
        assessment = person && person.capability ? person.capability : null;
        assessStatus = person && person.capability
            ? "Saved model assessment from " + (person.capability.model || "OpenRouter") + ". Review it before relying on it."
            : "No model called. Paste a background or load a text file, then save it.";
        backgroundArea.text = backgroundDraft;
    }

    function storeBackground() {
        if (!activePerson) {
            drawer.assessStatus = "Select or create a profile first.";
            return;
        }
        var text = String(backgroundDraft || "").trim();
        if (text.length < 20) {
            drawer.assessStatus = "Write at least a couple of sentences before saving.";
            return;
        }
        drawer.saveBackground(activePersonId, text, "");
        drawer.assessStatus = "Background saved on this device. No model was called.";
    }

    function checkCapability() {
        if (assessBusy) return;
        if (!activePerson) {
            assessStatus = "Select or create a profile first.";
            return;
        }
        var text = String(backgroundDraft || "").trim();
        if (text.length < 40) {
            assessStatus = "Add a fuller background (at least a few sentences) before the model check.";
            return;
        }
        if (!backendReady) {
            assessStatus = "The module backend is not ready inside Basecamp, so no model was called.";
            return;
        }
        assessBusy = true;
        assessStatus = "Sending the background to OpenRouter. Nothing else from this device is included.";
        var payload = {
            messages: Assistant.profileMessages(activePerson, text, app && app.projects ? app.projects : []),
            maxTokens: 600,
            temperature: 0.1
        };
        logos.watch(assistantHost.relayBackend.aiChat(JSON.stringify(payload)), function (value) {
            drawer.assessBusy = false;
            var snapshot = {};
            try { snapshot = JSON.parse(String(value)); } catch (error) { snapshot = {}; }
            if (!snapshot.success) {
                drawer.assessStatus = snapshot.error || "The model request failed.";
                return;
            }
            var parsed = Assistant.parseAssessment(snapshot.content,
                                                   drawer.app && drawer.app.projects ? drawer.app.projects : []);
            if (!parsed) {
                drawer.assessStatus = "The model reply was not the expected JSON, so nothing was saved.";
                return;
            }
            parsed.model = String(snapshot.model || "OpenRouter");
            parsed.checkedAt = Date.now();
            drawer.assessment = parsed;
            drawer.saveBackground(drawer.activePersonId, text, JSON.stringify(parsed));
            drawer.assessStatus = "Assessment saved on this device · " + parsed.model +
                " · " + Math.max(0.1, Number(snapshot.seconds) || 0).toFixed(1) + " s. It is a suggestion, not an award.";
        }, function (error) {
            drawer.assessBusy = false;
            drawer.assessStatus = "The module backend could not reach OpenRouter: " + error;
        });
    }

    function projectById(id) {
        var list = app && app.projects ? app.projects : [];
        for (var i = 0; i < list.length; ++i)
            if (list[i].id === id) return list[i];
        return null;
    }

    eyebrow: "Steward signup"
    title: "Your name is the whole account."
    subtitle: "Anyone can join as a steward. Pick a name, say where you work, and the profile is saved on this device — the funder and Dhun parties stay seeded rehearsal roles."

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 78
        radius: 12
        color: Theme.sageLight

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 10

            Rectangle {
                width: 34
                height: 34
                radius: 10
                color: Theme.forest

                Icon {
                    anchors.centerIn: parent
                    name: "user"
                    color: Theme.lime
                    width: 16
                    height: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "You get the steward role"
                    color: Theme.forest
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Stewards file field work, evidence and kitchen plans. Treasury payouts still need two of three signatures."
                    color: Theme.forestMid
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    LabeledField {
        id: nameField
        Layout.fillWidth: true
        label: "Your name"
        placeholder: "e.g. Meera Rathore"
        hint: "Shown on the field calendar and in the coordination room. Two characters minimum."
        maximumLength: 60
    }

    LabeledField {
        id: placeField
        Layout.fillWidth: true
        label: "Place"
        placeholder: "e.g. Khejri Mandal, Barmer"
        maximumLength: 80
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "What do you work on?"
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 7
        font.letterSpacing: 1.1
        font.weight: Font.DemiBold
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        radius: 9
        color: Theme.white
        border.width: 1
        border.color: noteField.activeFocus ? "#A8BE9B" : Theme.line

        TextArea {
            id: noteField
            anchors.fill: parent
            anchors.margins: 9
            placeholderText: "Beds, orchard, seed bank, nursery…"
            placeholderTextColor: Theme.mutedLight
            color: Theme.ink
            font.family: Theme.uiFont
            font.pixelSize: 10
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: null
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        ActionButton {
            Layout.fillWidth: true
            variant: "lime"
            text: "Create my steward profile"
            onClicked: drawer.createProfile(nameField.text, placeField.text, noteField.text)
        }

        ActionButton {
            compact: true
            variant: "secondary"
            text: "How DHN is earned"
            onClicked: drawer.openRewards()
        }
    }

    Text {
        Layout.fillWidth: true
        text: "The profile is stored in Basecamp's local settings for this module. It is not a chain account, it does not have its own key, and clearing the app state removes it. Rewards accrue to the profile; payment still moves DHN into the shared steward wallet."
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 8
        lineHeight: 1.45
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.line
    }

    Eyebrow { text: "BACKGROUND & CAPABILITY" }

    Text {
        Layout.fillWidth: true
        text: drawer.activePerson
              ? "Signed profile · " + drawer.activePerson.name +
                (drawer.activePerson.place ? " · " + drawer.activePerson.place : "")
              : "Select a profile above, or create one, to attach a background."
        color: Theme.inkSoft
        font.family: Theme.uiFont
        font.pixelSize: 9
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 132
        radius: 9
        color: Theme.white
        border.width: 1
        border.color: backgroundArea.activeFocus ? "#A8BE9B" : Theme.line

        TextArea {
            id: backgroundArea
            anchors.fill: parent
            anchors.margins: 9
            padding: 0
            placeholderText: "Experience, training, tools, crops or trades you know, languages, availability. Paste a CV here or load a .txt/.md file."
            placeholderTextColor: Theme.mutedLight
            color: Theme.ink
            font.family: Theme.uiFont
            font.pixelSize: 10
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: null
            onTextChanged: if (drawer.backgroundDraft !== text) drawer.backgroundDraft = text
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        ActionButton {
            compact: true
            variant: "secondary"
            fontSize: 8
            text: "Load .txt / .md"
            onClicked: backgroundFileDialog.open()
        }

        ActionButton {
            compact: true
            variant: "secondary"
            fontSize: 8
            text: "Save background"
            onClicked: drawer.storeBackground()
        }

        ActionButton {
            compact: true
            variant: "lime"
            fontSize: 8
            text: drawer.assessBusy ? "Checking…" : "Check capability"
            enabled: !drawer.assessBusy
            onClicked: drawer.checkCapability()
        }

        Item { Layout.fillWidth: true }
    }

    Text {
        Layout.fillWidth: true
        text: drawer.assessStatus
        color: Theme.inkSoft
        font.family: Theme.uiFont
        font.pixelSize: 8
        lineHeight: 1.4
        wrapMode: Text.WordWrap
    }

    Rectangle {
        Layout.fillWidth: true
        visible: drawer.assessment !== null && drawer.assessment !== undefined
        Layout.preferredHeight: assessmentColumn.implicitHeight + 22
        radius: 11
        color: Theme.sageLight

        ColumnLayout {
            id: assessmentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 11
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: "MODEL ASSESSMENT · " + (drawer.assessment && drawer.assessment.model
                                               ? drawer.assessment.model : "OpenRouter")
                color: Theme.forestMid
                font.family: Theme.uiFont
                font.pixelSize: 7
                font.letterSpacing: 1.1
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: drawer.assessment && drawer.assessment.summary ? drawer.assessment.summary : ""
                color: Theme.ink
                font.family: Theme.uiFont
                font.pixelSize: 9
                lineHeight: 1.4
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: drawer.assessment && drawer.assessment.strengths ? drawer.assessment.strengths : []

                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    text: "· " + modelData
                    color: Theme.forest
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: drawer.assessment && drawer.assessment.fitNotes ? "Fit: " + drawer.assessment.fitNotes : ""
                color: Theme.inkSoft
                font.family: Theme.uiFont
                font.pixelSize: 8
                wrapMode: Text.WordWrap
                lineHeight: 1.35
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: drawer.assessment && drawer.assessment.gaps ? "Not proven: " + drawer.assessment.gaps : ""
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 8
                wrapMode: Text.WordWrap
                lineHeight: 1.35
            }

            Repeater {
                model: drawer.assessment && drawer.assessment.projectIds ? drawer.assessment.projectIds : []

                delegate: RowLayout {
                    id: matchRow
                    required property string modelData
                    readonly property var project: drawer.projectById(modelData)
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: matchRow.project ? matchRow.project.title : modelData
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    ActionButton {
                        compact: true
                        variant: "secondary"
                        fontSize: 8
                        text: "Start allocation"
                        onClicked: drawer.startAllocation(matchRow.project ? matchRow.project.id : modelData)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "The model only sees the background text, your name and place, and the project list above. It cannot award a project; you still submit a proposal and collect two of three signatures."
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 7
            lineHeight: 1.35
            wrapMode: Text.WordWrap
        }

        ActionButton {
            compact: true
            variant: "ghost"
            fontSize: 8
            text: "Browse projects"
            onClicked: drawer.openProjects()
        }
    }

    FileDialog {
        id: backgroundFileDialog
        title: "Choose a background or CV text file"
        nameFilters: ["Plain text (*.txt *.md *.markdown *.csv *.json)"]
        onAccepted: {
            if (!drawer.backendReady) {
                drawer.assessStatus = "The module backend is not ready, so the file was not read.";
                return;
            }
            drawer.assessStatus = "Reading the chosen file locally…";
            logos.watch(assistantHost.relayBackend.readTextFile(selectedFile), function (value) {
                var reply = {};
                try { reply = JSON.parse(String(value)); } catch (error) { reply = {}; }
                if (!reply.success) {
                    drawer.assessStatus = reply.error || "The file could not be read.";
                    return;
                }
                drawer.backgroundDraft = String(reply.text || "");
                backgroundArea.text = drawer.backgroundDraft;
                drawer.assessStatus = "Loaded " + reply.name + " · " + reply.characters + " characters" +
                    (reply.truncated ? " (trimmed to 120,000 characters)" : "") + ". Nothing was uploaded.";
            }, function (error) {
                drawer.assessStatus = "The module backend could not read the file: " + error;
            });
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.line
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: "PROFILES ON THIS DEVICE"
            color: Theme.muted
            font.family: Theme.uiFont
            font.pixelSize: 7
            font.letterSpacing: 1.3
            font.weight: Font.DemiBold
        }

        Pill {
            text: drawer.app && drawer.app.people ? (drawer.app.people.length + " total") : "0"
            fg: Theme.forestMid
            bg: Theme.sageLight
            fontSize: 8
        }
    }

    Repeater {
        model: drawer.app && drawer.app.people ? drawer.app.people : []

        delegate: Rectangle {
            required property var modelData
            readonly property bool active: modelData.id === drawer.activePersonId
            readonly property var totals: Rewards.profileTotals(drawer.app, modelData.id)

            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 10
            color: active ? Theme.white : Theme.paperWarm
            border.width: 1
            border.color: active ? "#A8BE9B" : Theme.lineSoft

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                spacing: 10

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.roleSoft(modelData.role)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name.substring(0, 1).toUpperCase()
                        color: Theme.roleText(modelData.role)
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (modelData.role === "steward" ? "Steward" : (modelData.role === "dhun" ? "Dhun field unit" : "Funder"))
                              + (modelData.place ? " · " + modelData.place : "")
                              + " · " + totals.pending + " DHN queued"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                ActionButton {
                    compact: true
                    variant: active ? "secondary" : "ghost"
                    text: active ? "Signing" : "Sign as"
                    enabled: !active
                    onClicked: drawer.selectProfile(modelData.id)
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "The funder and Dhun profiles are seeded for the rehearsal. New profiles always receive the steward role."
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 8
        wrapMode: Text.WordWrap
        lineHeight: 1.4
    }
}
