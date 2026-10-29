import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../assistant.js" as Assistant
import "../components"

SideSheet {
    id: drawer

    property var app: null
    property bool backendReady: false
    property var backend: null

    property var ideas: []
    property var status: ({})
    property bool statusChecked: false
    property bool busy: false
    property var history: []
    property string draft: ""

    signal navigate(string page)
    signal openProfile()
    signal openAllocate(string projectId)

    panelWidth: 600
    eyebrow: "Dhun assistant"
    title: "A field hand that knows the rules."
    subtitle: "Ask about earning DHN, planning a low-waste meal or matching your background to a programme. Amounts and balances come from this device's rehearsal state; a payout still needs two of three signatures."

    readonly property bool configured: status && status.configured === true
    readonly property string modelLabel: status && status.model ? String(status.model) : "openai/gpt-4o"

    onOpenChanged: {
        if (!open) return;
        ideas = Assistant.rewardIdeas(app);
        history = [];
        chatModel.clear();
        chatModel.append({
            text: "Ask about today's DHN actions, a dish or mood for the kitchen, or your background. " +
                  "Built-in guidance works without a key; model answers need OpenRouter configured.",
            mine: false,
            source: "built-in",
            meta: "Local guidance · no model called"
        });
        refreshStatus();
        inputArea.forceActiveFocus();
    }

    function refreshStatus() {
        statusChecked = false;
        if (!backendReady) {
            status = { configured: false, note: "The module backend is not ready inside Basecamp." };
            statusChecked = true;
            return;
        }
        logos.watch(backend.aiStatus(), function (value) {
            var reply = {};
            try { reply = JSON.parse(String(value)); } catch (error) { reply = {}; }
            drawer.status = reply;
            drawer.statusChecked = true;
        }, function (error) {
            drawer.status = { configured: false, note: "The module backend could not read the assistant status: " + error };
            drawer.statusChecked = true;
        });
    }

    function appendMessage(text, mine, source, meta) {
        chatModel.append({ text: String(text || ""), mine: !!mine, source: String(source || ""), meta: String(meta || "") });
        chatView.positionViewAtEnd();
    }

    function send() {
        var text = String(draft || "").trim();
        if (!text || busy) return;
        draft = "";
        appendMessage(text, true, "you", "You");
        var reply = {};
        if (!backendReady || (statusChecked && !configured)) {
            appendMessage(Assistant.localAnswer(app, text), false, "built-in",
                          "Built-in guidance · no model called");
            history = history.concat([{ mine: true, text: text, source: "you" }]);
            return;
        }

        busy = true;
        var payload = {
            messages: Assistant.chatMessages(app, history, text),
            maxTokens: 700,
            temperature: 0.2
        };
        history = history.concat([{ mine: true, text: text, source: "you" }]);
        logos.watch(backend.aiChat(JSON.stringify(payload)), function (value) {
            drawer.busy = false;
            var snapshot = {};
            try { snapshot = JSON.parse(String(value)); } catch (error) { snapshot = {}; }
            if (!snapshot.success) {
                var fallback = Assistant.localAnswer(app, text);
                drawer.appendMessage((snapshot.error || "The model request failed.") +
                                     "\n\n" + fallback, false, "built-in",
                                     "Model unavailable · built-in guidance shown");
                return;
            }
            var seconds = Math.max(0.1, Number(snapshot.seconds) || 0);
            drawer.appendMessage(snapshot.content, false, "openrouter",
                "OpenRouter · " + String(snapshot.model || drawer.modelLabel) +
                " · " + seconds.toFixed(1) + " s");
            drawer.history = drawer.history.concat([
                { mine: false, text: snapshot.content, source: "openrouter" }
            ]);
        }, function (error) {
            drawer.busy = false;
            drawer.appendMessage("The module backend could not reach OpenRouter: " + error +
                                 "\n\n" + Assistant.localAnswer(app, text), false, "built-in",
                                 "Model unavailable · built-in guidance shown");
        });
    }

    function usePrompt(prompt) {
        draft = prompt;
        inputArea.forceActiveFocus();
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 12
        color: drawer.configured ? Theme.sageLight : Theme.goldLight

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                width: 30
                height: 30
                radius: 9
                color: drawer.configured ? Theme.forest : Theme.gold

                Icon {
                    anchors.centerIn: parent
                    name: drawer.configured ? "leaf" : "info"
                    color: drawer.configured ? Theme.lime : "#3E2A0B"
                    width: 14
                    height: 14
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: drawer.configured
                          ? "OpenRouter · " + drawer.modelLabel
                          : (drawer.statusChecked ? "No OpenRouter key configured" : "Checking the assistant backend…")
                    color: Theme.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: drawer.configured
                          ? "Remote inference · prompts leave this device · key read at runtime"
                          : "Built-in guidance still works. Set OPENROUTER_API_KEY or a private config file to call a model."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: drawer.statusChecked && !drawer.configured
        text: "Configuration is read from the environment or " +
              (drawer.status && drawer.status.configPath ? drawer.status.configPath : "~/.config/dhun-commons/openrouter.json") +
              ". The module never writes the key to the repository or the rehearsal state." +
              (drawer.status && drawer.status.warning ? " " + drawer.status.warning : "")
        color: Theme.muted
        font.family: Theme.uiFont
        font.pixelSize: 8
        lineHeight: 1.4
        wrapMode: Text.WordWrap
    }

    Eyebrow { text: "EARN DHN TODAY" }

    Repeater {
        model: drawer.ideas

        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: ideaColumn.implicitHeight + 20
            radius: 11
            color: Theme.paperWarm
            border.width: 1
            border.color: Theme.lineSoft

            RowLayout {
                id: ideaColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 9

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title + (modelData.amount > 0 ? "  ·  +" + modelData.amount + " DHN" : "")
                        color: Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.detail
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }

                ActionButton {
                    compact: true
                    variant: "secondary"
                    fontSize: 8
                    text: modelData.action
                    onClicked: {
                        if (modelData.page === "profile") drawer.openProfile();
                        else drawer.navigate(modelData.page);
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "Queued rewards are not spendable until a treasury proposal is executed. The app never claims a payment that has not been signed."
        color: Theme.mutedLight
        font.family: Theme.uiFont
        font.pixelSize: 7
        lineHeight: 1.35
        wrapMode: Text.WordWrap
    }

    Eyebrow { text: "ASK" }

    Repeater {
        model: Assistant.starterPrompts()

        delegate: Rectangle {
            required property string modelData
            Layout.fillWidth: true
            implicitHeight: promptText.implicitHeight + 16
            radius: 9
            color: Theme.white
            border.width: 1
            border.color: Theme.line

            Text {
                id: promptText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                text: modelData
                color: Theme.inkSoft
                font.family: Theme.uiFont
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: drawer.usePrompt(modelData)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        radius: 11
        color: Theme.paperWarm
        border.width: 1
        border.color: Theme.line

        ListView {
            id: chatView
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            clip: true
            model: ListModel { id: chatModel }

            delegate: Rectangle {
                id: bubbleRoot
                required property string text
                required property bool mine
                required property string source
                required property string meta

                width: chatView.width
                height: bubble.implicitHeight + 18
                radius: 10
                color: bubbleRoot.mine ? Theme.forest : (bubbleRoot.source === "openrouter" ? Theme.white : Theme.sageLight)

                ColumnLayout {
                    id: bubble
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 9
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: bubbleRoot.text
                        color: bubbleRoot.mine ? "#F4F7E9" : Theme.ink
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        text: bubbleRoot.meta
                        color: bubbleRoot.mine ? "#C7D6BC" : Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 7
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 92
        radius: 10
        color: Theme.white
        border.width: 1
        border.color: inputArea.activeFocus ? "#A8BE9B" : Theme.line

        TextArea {
            id: inputArea
            anchors.fill: parent
            anchors.margins: 9
            padding: 0
            placeholderText: "Ask about a dish, a mood, DHN actions or your background…"
            placeholderTextColor: Theme.mutedLight
            color: Theme.ink
            font.family: Theme.uiFont
            font.pixelSize: 10
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            background: null
            onTextChanged: if (drawer.draft !== text) drawer.draft = text
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Return && (event.modifiers & Qt.ControlModifier)) {
                    drawer.send();
                    event.accepted = true;
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ActionButton {
            variant: "lime"
            text: drawer.busy ? "Thinking…" : "Send"
            enabled: drawer.draft.trim().length > 0 && !drawer.busy
            onClicked: drawer.send()
        }

        Text {
            Layout.fillWidth: true
            text: "Ctrl+Enter sends. With a key, the conversation and the context JSON go to openrouter.ai."
            color: Theme.mutedLight
            font.family: Theme.uiFont
            font.pixelSize: 7
            wrapMode: Text.WordWrap
        }

        ActionButton {
            compact: true
            variant: "ghost"
            text: "Clear"
            onClicked: {
                drawer.history = [];
                chatModel.clear();
                drawer.appendMessage("Thread cleared. No model was called.", false, "built-in", "Local guidance");
            }
        }
    }
}
