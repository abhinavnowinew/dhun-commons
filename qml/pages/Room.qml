import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../components"

Item {
    id: page

    property var app: null
    property var now: Date.now()
    property string activeRole: "funder"
    property string activeChannel: "room-msig"

    signal selectChannel(string channelId)
    signal sendMessage(string text)
    signal openProposal(var proposal)
    signal logosMessage(string sender, string text)
    signal relayPost(string id)
    signal relayDismiss(string id)
    signal relayPublish()

    property bool relayReady: false
    property var relayInbox: []
    property var relayBridge: ({})
    property double relayPublishedAt: 0
    property string relayNotice: ""
    property bool relayOpen: false
    readonly property int relayQueued: relayInbox ? relayInbox.length : 0
    readonly property bool relayBridgeOnline: {
        if (!relayReady || !relayBridge) return false;
        var at = Number(relayBridge.at || 0);
        return at > 0 && (Date.now() - at) < 45000;
    }
    readonly property string relayState: {
        if (!relayReady) return "BACKEND OFFLINE";
        return relayBridgeOnline ? "BRIDGE ONLINE" : "NO BRIDGE";
    }
    readonly property string relaySummary: {
        if (!relayReady) return "The Dhun Commons backend is not connected in this host.";
        var text = relayBridgeOnline
                 ? (String(relayBridge.bot || "Telegram bridge") + " · ")
                 : "Start telegram/bridge.mjs · ";
        text += relayQueued + " queued";
        if (relayPublishedAt > 0) {
            var age = Math.round((Date.now() - relayPublishedAt) / 1000);
            text += " · snapshot " + (age < 60 ? age + "s ago" : Math.round(age / 60) + "m ago");
        }
        return text;
    }

    // ── Logos Messaging: chat_module over delivery_module ──────────────────
    readonly property bool logosHosted: typeof logos !== "undefined" && logos !== null
    property bool chatStarted: false
    property bool chatReady: false
    property bool chatBusy: false
    property bool chatSubscribed: false
    property bool chatCallFailed: false
    property bool chatCreating: false
    property bool chatInviteOpen: false
    property int chatAttempts: 0
    property string chatAddress: ""
    property string chatDelivery: ""
    property string chatDetail: ""
    property string chatError: ""
    property string chatNotice: ""
    property string chatConvoId: ""
    property int chatConvos: 0
    property int chatMembers: 0
    property int chatPeers: 0
    property int chatPending: 0
    property int chatMirrored: 0
    property int chatEchoes: 0
    property int chatInbound: 0

    readonly property string chatState: {
        if (!logosHosted) return "UNAVAILABLE";
        if (chatError.length) return "ERROR";
        if (!chatStarted || !chatReady) return chatBusy ? "STARTING" : "OFFLINE";
        return chatDelivery.length ? chatDelivery.toUpperCase() : "CONNECTED";
    }
    readonly property string chatAddressShort: chatAddress.length > 26
        ? chatAddress.substring(0, 14) + "…" + chatAddress.substring(chatAddress.length - 8)
        : chatAddress
    readonly property string chatLine: {
        if (!logosHosted) return "Logos Messaging is available only inside Basecamp.";
        if (chatError.length) return chatError;
        if (!chatStarted) return "The Logos delivery node has not started.";
        if (!chatReady) return "Starting the Logos delivery node…";
        var line = "node " + (chatDelivery.length ? chatDelivery.toLowerCase() : "starting");
        line += " · " + chatPeers + (chatPeers === 1 ? " peer" : " peers");
        if (chatPending > 0) line += " · " + chatPending + " invited";
        if (chatMirrored > 0) line += " · " + chatMirrored + " submitted";
        if (chatInbound > 0) line += " · " + chatInbound + " received";
        return line;
    }

    readonly property var channel: {
        if (!app) return null;
        for (var i = 0; i < app.channels.length; ++i)
            if (app.channels[i].id === activeChannel) return app.channels[i];
        return app.channels.length ? app.channels[0] : null;
    }
    readonly property var thread: app && app.messages[activeChannel] ? app.messages[activeChannel] : []
    readonly property var linkedProposal: {
        if (!app) return null;
        var queue = Logic.pendingProposals(app, now);
        for (var i = 0; i < queue.length; ++i) {
            var proposal = queue[i];
            if (activeChannel === "room-msig") return proposal;
            if (proposal.meta && proposal.meta.projectId && Logic.findProject(app, proposal.meta.projectId) &&
                Logic.findProject(app, proposal.meta.projectId).room === activeChannel)
                return proposal;
        }
        return null;
    }

    Component.onCompleted: {
        if (page.logosHosted) {
            page.subscribeLogosEvents();
            Qt.callLater(page.startLogosChat);
        }
    }

    Timer {
        id: chatRetryTimer
        interval: 1800
        repeat: false
        onTriggered: page.startLogosChat()
    }

    Timer {
        id: chatPollTimer
        interval: 6000
        repeat: true
        running: page.logosHosted && page.chatStarted && page.chatReady
        onTriggered: page.refreshLogosChat()
    }

    Connections {
        target: typeof logos !== "undefined" ? logos : null
        function onModuleEventReceived(moduleName, eventName, data) {
            if (moduleName === "chat_module")
                page.handleChatEvent(eventName, data || []);
        }
    }

    function chatParse(value) {
        if (value === null || value === undefined) return null;
        if (typeof value === "object") return value;
        var text = String(value).trim();
        if (!text.length) return null;
        try { return JSON.parse(text); } catch (error) { return null; }
    }

    function chatBool(value) {
        return value === true || String(value).toLowerCase() === "true";
    }

    function chatList(value) {
        var parsed = page.chatParse(value);
        if (Array.isArray(parsed)) return parsed;
        if (parsed && typeof parsed === "object") {
            if (Array.isArray(parsed.items)) return parsed.items;
            if (Array.isArray(parsed.value)) return parsed.value;
        }
        return [];
    }

    function chatResultId(value) {
        var parsed = page.chatParse(value);
        if (typeof parsed === "string") return parsed;
        if (parsed && typeof parsed === "object") {
            if (parsed.convo_id) return String(parsed.convo_id);
            if (parsed.id) return String(parsed.id);
            if (typeof parsed.value === "string") return parsed.value;
        }
        var raw = value === null || value === undefined ? "" : String(value).trim();
        if (raw.charAt(0) === '"') {
            var unquoted = page.chatParse(raw);
            return typeof unquoted === "string" ? unquoted : "";
        }
        if (raw.length && raw !== "null" && raw.toLowerCase() !== "true" && raw.charAt(0) !== "{") return raw;
        return "";
    }

    function chatCall(method, args) {
        page.chatCallFailed = false;
        if (!page.logosHosted) return null;
        try {
            var value = logos.callModule("chat_module", method, args || []);
            if (typeof value === "string" && /^error[:\s]/i.test(value)) {
                page.chatCallFailed = true;
                page.chatError = "chat_module." + method + ": " + value;
                return null;
            }
            return value;
        } catch (error) {
            page.chatCallFailed = true;
            page.chatError = "chat_module." + method + ": " + String(error);
            return null;
        }
    }

    function subscribeLogosEvents() {
        if (!page.logosHosted || page.chatSubscribed || !logos.onModuleEvent) return;
        var events = ["message_received", "message_sent", "delivery_state_changed",
                      "conversation_created", "conversation_updated", "members_changed"];
        for (var i = 0; i < events.length; ++i)
            logos.onModuleEvent("chat_module", events[i]);
        page.chatSubscribed = true;
    }

    function connectChat() {
        page.chatAttempts = 0;
        page.chatError = "";
        page.chatNotice = "";
        page.startLogosChat();
    }

    function startLogosChat() {
        if (!page.logosHosted || page.chatBusy) return;
        if (page.chatStarted && page.chatReady) {
            page.refreshLogosChat();
            return;
        }
        page.chatBusy = true;
        page.chatError = "";
        if (!page.chatStarted) {
            page.chatCall("init", [{ delivery_preset: "logos.test", log_level: "info" }]);
            if (page.chatCallFailed) {
                page.chatBusy = false;
                page.retryChat();
                return;
            }
            page.chatStarted = true;
        }
        page.chatReady = page.chatBool(page.chatCall("health", []));
        if (!page.chatReady) {
            page.chatBusy = false;
            page.retryChat();
            return;
        }
        var address = page.chatCall("get_address", []);
        page.chatAddress = address === null || address === undefined ? "" : String(address).replace(/^"|"$/g, "");
        page.chatAttempts = 0;
        page.chatBusy = false;
        page.refreshLogosChat();
        page.ensureChatConversation();
    }

    function retryChat() {
        if (!page.logosHosted) return;
        if (page.chatAttempts >= 20) {
            if (!page.chatError.length)
                page.chatError = "The Logos delivery node did not become ready. Check Basecamp’s log and network access.";
            page.chatBusy = false;
            return;
        }
        page.chatAttempts += 1;
        chatRetryTimer.restart();
    }

    function refreshLogosChat() {
        if (!page.logosHosted || !page.chatStarted) return;
        var status = page.chatParse(page.chatCall("status", []));
        if (status && typeof status === "object" && !Array.isArray(status)) {
            page.chatConvos = parseInt(status.convo_count, 10) || 0;
            var state = status.delivery_state === null || status.delivery_state === undefined
                      ? "" : String(status.delivery_state);
            if (state.length) page.chatDelivery = state;
            page.chatDetail = status.detail === null || status.detail === undefined
                      ? "" : String(status.detail);
            if (state.toLowerCase() === "online") {
                page.chatReady = true;
                if (!page.chatCallFailed && page.chatError.indexOf("did not become ready") !== -1)
                    page.chatError = "";
            } else if (state.toLowerCase() === "error" && page.chatDetail.length) {
                page.chatError = page.chatDetail;
            }
        }
        if (!page.chatConvoId.length && page.chatReady) page.ensureChatConversation();
        else page.refreshChatRoster();
    }

    function refreshChatRoster() {
        if (!page.chatConvoId.length) return;
        var members = page.chatList(page.chatCall("list_group_members", [page.chatConvoId]));
        var peers = 0;
        var pending = 0;
        for (var i = 0; i < members.length; ++i) {
            var entry = members[i] || {};
            var address = entry.address === null || entry.address === undefined
                        ? "" : String(entry.address);
            if (page.chatBool(entry.pending)) {
                pending += 1;
                continue;
            }
            if (address.length && address !== page.chatAddress) peers += 1;
        }
        page.chatMembers = members.length;
        page.chatPeers = peers;
        page.chatPending = pending;
    }

    function ensureChatConversation() {
        if (!page.chatReady || page.chatCreating) return;
        if (page.chatConvoId.length) {
            page.refreshChatRoster();
            return;
        }
        page.chatCreating = true;
        var convos = page.chatList(page.chatCall("list_conversations", []));
        var found = null;
        for (var i = 0; i < convos.length; ++i) {
            var convo = convos[i] || {};
            if (String(convo.kind) === "group" && String(convo.name) === "Dhun Commons" &&
                !page.chatBool(convo.history_only)) {
                found = convo;
                break;
            }
        }
        if (found) {
            page.chatConvoId = String(found.convo_id);
            page.chatNotice = "Using the live “Dhun Commons” Logos group.";
        } else {
            var created = page.chatCall("create_group_conversation",
                ["Dhun Commons", "Dhun.life commons over Logos Messaging. Posts are mirrored from the room; chat carries no custody or signatures."]);
            var convoId = page.chatResultId(created);
            if (convoId.length) {
                page.chatConvoId = convoId;
                page.chatNotice = "Created the Logos group “Dhun Commons”.";
            } else {
                var after = page.chatList(page.chatCall("list_conversations", []));
                for (var j = 0; j < after.length; ++j) {
                    if (String(after[j].kind) === "group" && String(after[j].name) === "Dhun Commons" &&
                        !page.chatBool(after[j].history_only)) {
                        page.chatConvoId = String(after[j].convo_id);
                        page.chatNotice = "Created the Logos group “Dhun Commons”.";
                        break;
                    }
                }
            }
            if (!page.chatConvoId.length)
                page.chatNotice = "Logos Messaging is online but the group could not be created.";
        }
        page.chatCreating = false;
        page.refreshChatRoster();
    }

    function submitMessage(value) {
        var text = String(value).trim();
        if (!text.length) return;
        page.sendMessage(text);
        page.mirrorToLogos(text);
    }

    function mirrorToLogos(text) {
        if (!page.logosHosted) return false;
        if (!page.chatReady) {
            page.chatNotice = "Posted locally. Logos Messaging is " + page.chatState.toLowerCase() + ".";
            return false;
        }
        if (!page.chatConvoId.length) page.ensureChatConversation();
        if (!page.chatConvoId.length) {
            page.chatNotice = "Posted locally. No Logos group is open yet.";
            return false;
        }
        page.chatCall("send_message", [page.chatConvoId, text]);
        if (page.chatCallFailed) {
            page.chatNotice = "Posted locally. chat_module could not submit this message.";
            return false;
        }
        page.chatMirrored += 1;
        page.chatNotice = "Handed to chat_module. Peer delivery is not acknowledged here.";
        return true;
    }

    function inviteChatPeer(value) {
        var peer = String(value).trim();
        if (!page.chatConvoId.length) {
            page.chatNotice = "Connect Logos Messaging before inviting a peer.";
            return false;
        }
        if (peer.length < 16) {
            page.chatNotice = "Paste the peer’s Logos chat address from their Rooms panel.";
            return false;
        }
        page.chatCall("add_group_member", [page.chatConvoId, peer]);
        if (page.chatCallFailed) {
            page.chatNotice = "The invite could not be submitted.";
            return false;
        }
        page.chatNotice = "Invite submitted. Joining is asynchronous; a peer appears only after its installation joins.";
        page.refreshChatRoster();
        return true;
    }

    function handleChatEvent(eventName, data) {
        var args = data || [];
        if (eventName === "delivery_state_changed") {
            if (args.length > 0) page.chatDelivery = String(args[0]);
            if (args.length > 1) page.chatDetail = String(args[1]);
            if (page.chatDelivery.toLowerCase() === "online") {
                page.chatReady = true;
                page.chatError = "";
                if (!page.chatConvoId.length) page.ensureChatConversation();
            } else if (page.chatDelivery.toLowerCase() === "error") {
                page.chatError = page.chatDetail.length ? page.chatDetail
                              : "Logos delivery reported an error.";
            }
            return;
        }
        if (eventName === "message_sent") {
            if (args.length > 0 && String(args[0]) === page.chatConvoId) page.chatEchoes += 1;
            return;
        }
        if (eventName === "message_received") {
            var content = args.length > 1 ? String(args[1]) : "";
            var sender = args.length > 3 ? String(args[3]) : "";
            if (!content.length) return;
            page.chatInbound += 1;
            page.chatNotice = "Inbound message received over Logos delivery.";
            page.logosMessage(sender, content);
            return;
        }
        if (eventName === "conversation_created") {
            var createdId = args.length > 0 ? String(args[0]) : "";
            var outgoing = args.length > 1 ? page.chatBool(args[1]) : true;
            var kind = args.length > 3 ? String(args[3]) : "";
            var name = args.length > 4 ? String(args[4]) : "";
            if (!outgoing && kind === "group" && name === "Dhun Commons" && !page.chatConvoId.length) {
                page.chatConvoId = createdId;
                page.chatNotice = "Added to the “Dhun Commons” Logos group.";
                page.refreshChatRoster();
            }
            return;
        }
        if (eventName === "members_changed" || eventName === "conversation_updated") {
            var changedId = args.length > 0 ? String(args[0]) : "";
            if (!page.chatConvoId.length || changedId === page.chatConvoId) page.refreshChatRoster();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.pagePadding
        anchors.rightMargin: Theme.pagePadding
        anchors.topMargin: 22
        anchors.bottomMargin: 24
        spacing: 18

        Rectangle {
            Layout.preferredWidth: 262
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Theme.white
            border.width: 1
            border.color: Theme.line

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 7

                Text {
                    text: "ROOMS"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 7
                    font.letterSpacing: 1.4
                    font.weight: Font.DemiBold
                    Layout.leftMargin: 4
                }

                Repeater {
                    model: page.app ? page.app.channels : []

                    delegate: Rectangle {
                        id: channelRow
                        required property var modelData
                        readonly property bool active: page.activeChannel === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 10
                        color: active ? Theme.sageLight : (channelMouse.containsMouse ? Theme.paperWarm : "transparent")

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Icon {
                                    name: channelRow.modelData.kind === "multisig" ? "shield" : "room"
                                    color: channelRow.active ? Theme.forestMid : Theme.muted
                                    width: 12
                                    height: 12
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: channelRow.modelData.name
                                    color: channelRow.active ? Theme.ink : Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: channelRow.active ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: channelRow.modelData.unread > 0
                                    width: 15
                                    height: 15
                                    radius: 7.5
                                    color: Theme.clay
                                    Text {
                                        anchors.centerIn: parent
                                        text: String(channelRow.modelData.unread)
                                        color: "#FBF3EC"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 7
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: channelRow.modelData.subtitle
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: channelMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selectChannel(channelRow.modelData.id)
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: logosCard.implicitHeight + 20
                    radius: 10
                    color: page.chatReady ? Theme.sageLight : Theme.paper
                    border.width: 1
                    border.color: page.chatError.length ? "#E3B7A9"
                                : (page.chatReady ? Theme.sage : Theme.lineSoft)

                    ColumnLayout {
                        id: logosCard
                        x: 10
                        y: 10
                        width: parent.width - 20
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                color: page.chatError.length ? Theme.clay
                                     : (page.chatReady ? Theme.forestMid
                                     : (page.chatBusy ? Theme.gold : Theme.mutedLight))
                            }

                            Text {
                                text: "LOGOS MESSAGING"
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.letterSpacing: 1
                                font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: page.chatState
                                color: page.chatError.length ? Theme.danger
                                     : (page.chatReady ? Theme.forestMid : Theme.muted)
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.chatLine
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            visible: page.chatAddress.length > 0
                            Layout.fillWidth: true
                            spacing: 5

                            Text {
                                Layout.fillWidth: true
                                text: page.chatAddressShort
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                elide: Text.ElideMiddle
                            }

                            ActionButton {
                                compact: true
                                variant: "ghost"
                                fontSize: 7
                                hPadding: 6
                                text: "Copy"
                                onClicked: {
                                    chatAddressClip.selectAll();
                                    chatAddressClip.copy();
                                    page.chatNotice = "Chat address copied.";
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            ActionButton {
                                compact: true
                                variant: "secondary"
                                fontSize: 7
                                hPadding: 8
                                text: page.chatReady ? "Sync"
                                    : (page.chatBusy ? "Starting…" : (page.chatError.length ? "Retry" : "Connect"))
                                onClicked: page.chatReady ? page.refreshLogosChat() : page.connectChat()
                            }

                            ActionButton {
                                compact: true
                                variant: "ghost"
                                fontSize: 7
                                hPadding: 8
                                visible: page.chatReady
                                text: page.chatInviteOpen ? "Close" : "Invite"
                                onClicked: page.chatInviteOpen = !page.chatInviteOpen
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: page.chatPeers > 0
                                text: page.chatPeers + (page.chatPeers === 1 ? " peer" : " peers")
                                color: Theme.forestMid
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                font.weight: Font.Bold
                            }
                        }

                        RowLayout {
                            visible: page.chatInviteOpen && page.chatReady
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 7
                                color: Theme.white
                                border.width: 1
                                border.color: Theme.line

                                TextField {
                                    id: inviteField
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 7
                                    placeholderText: "peer address"
                                    placeholderTextColor: Theme.mutedLight
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    background: null
                                    selectByMouse: true
                                    onAccepted: if (page.inviteChatPeer(text)) text = "";
                                }
                            }

                            ActionButton {
                                compact: true
                                variant: "primary"
                                fontSize: 7
                                hPadding: 7
                                text: "Add"
                                onClicked: if (page.inviteChatPeer(inviteField.text)) inviteField.text = ""
                            }
                        }

                        Text {
                            visible: page.chatNotice.length > 0
                            Layout.fillWidth: true
                            text: page.chatNotice
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 6
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                        }
                    }

                    TextEdit {
                        id: chatAddressClip
                        visible: false
                        text: page.chatAddress
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusLarge
            color: Theme.white
            border.width: 1
            border.color: Theme.line

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 10

                        ColumnLayout {
                            spacing: 2
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: page.channel ? page.channel.name : ""
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Pill {
                                    visible: page.chatReady
                                    text: "LOGOS MSG"
                                    fg: Theme.forestMid
                                    bg: Theme.sageLight
                                    fontSize: 7
                                }
                                Pill {
                                    visible: !page.chatReady
                                    text: "LOCAL"
                                    fg: Theme.goldDeep
                                    bg: Theme.goldLight
                                    fontSize: 7
                                }
                            }
                            Text {
                                text: page.channel ? page.channel.subtitle : ""
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: -5
                            Repeater {
                                model: page.app ? Object.keys(page.app.roles) : []
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: Theme.roleColor(modelData)
                                    border.width: 2
                                    border.color: Theme.white
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData === "funder" ? "A" : (modelData === "dhun" ? "M" : "K")
                                        color: Theme.roleText(modelData)
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                    }
                                }
                            }
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

                Rectangle {
                    visible: page.linkedProposal !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: linked.implicitHeight + 22
                    Layout.margins: 14
                    Layout.bottomMargin: 0
                    radius: 10
                    color: Theme.paper
                    border.width: 1
                    border.color: Theme.lineSoft

                    RowLayout {
                        id: linked
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 9

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 8
                            color: Theme.goldLight
                            Icon {
                                anchors.centerIn: parent
                                name: "shield"
                                color: Theme.goldDeep
                                width: 12
                                height: 12
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: page.linkedProposal ? ("Bound proposal · " + page.linkedProposal.id) : ""
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                            }
                            Text {
                                Layout.fillWidth: true
                                text: page.linkedProposal
                                      ? (page.linkedProposal.title + " · " + Logic.formatNumber(page.linkedProposal.amount) + " DHN")
                                      : ""
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: page.linkedProposal ? Logic.stateLabel(Logic.proposalState(page.app, page.linkedProposal, page.now)) : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }

                        ActionButton {
                            compact: true
                            variant: "secondary"
                            text: "Open"
                            onClicked: if (page.linkedProposal) page.openProposal(page.linkedProposal)
                        }
                    }
                }

                ListView {
                    id: messageList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 18
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 8
                    clip: true
                    spacing: 14
                    model: page.thread
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    Connections {
                        target: page
                        function onActiveChannelChanged() { Qt.callLater(messageList.positionViewAtEnd); }
                    }

                    delegate: Item {
                        id: messageItem
                        required property var modelData
                        readonly property bool system: modelData.role === "system"
                        readonly property bool own: modelData.role === page.activeRole

                        width: messageList.width
                        height: messageBody.implicitHeight + 4

                        ColumnLayout {
                            id: messageBody
                            visible: !messageItem.system
                            x: 0
                            width: messageItem.width - 8
                            spacing: 5

                            RowLayout {
                                spacing: 7

                                Avatar {
                                    role: messageItem.modelData.role
                                    size: 26
                                }

                                Text {
                                    text: {
                                        if (!page.app) return "";
                                        var role = page.app.roles[messageItem.modelData.role];
                                        return role ? role.org : messageItem.modelData.role;
                                    }
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: page.app && page.app.roles[messageItem.modelData.role]
                                          ? page.app.roles[messageItem.modelData.role].signer.split("·")[0].trim()
                                          : ""
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: Logic.timeLabel(messageItem.modelData.at)
                                    color: Theme.mutedLight
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.leftMargin: 33
                                Layout.preferredHeight: messageText.implicitHeight + 18
                                radius: 10
                                color: messageItem.own ? Theme.sageLight : Theme.paper
                                border.width: messageItem.own ? 0 : 1
                                border.color: Theme.lineSoft

                                Text {
                                    id: messageText
                                    x: 12
                                    y: 9
                                    width: parent.width - 24
                                    text: messageItem.modelData.text
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    lineHeight: 1.4
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            visible: messageItem.system
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: messageItem.width - 60
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.lineSoft
                            }

                            Icon {
                                name: "shield"
                                color: Theme.mutedLight
                                width: 10
                                height: 10
                            }

                            Text {
                                Layout.fillWidth: true
                                text: messageItem.modelData.text
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Theme.lineSoft
                            }
                        }
                    }
                }

                Rectangle {
                    id: relayBar
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.preferredHeight: relayColumn.implicitHeight + 18
                    radius: 10
                    color: page.relayQueued > 0 ? Theme.goldLight : Theme.paper
                    border.width: 1
                    border.color: page.relayNotice.length ? "#E3B7A9" : Theme.lineSoft

                    ColumnLayout {
                        id: relayColumn
                        x: 12
                        y: 8
                        width: parent.width - 24
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                spacing: 5

                                Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: page.relayNotice.length ? Theme.clay
                                         : (page.relayBridgeOnline ? Theme.forestMid : Theme.mutedLight)
                                }

                                Text {
                                    text: "TELEGRAM RELAY"
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.letterSpacing: 1
                                    font.weight: Font.Bold
                                }

                                Text {
                                    visible: page.relayQueued > 0
                                    text: page.relayQueued + " queued"
                                    color: Theme.goldDeep
                                    font.family: Theme.uiFont
                                    font.pixelSize: 7
                                    font.weight: Font.DemiBold
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: page.relayState
                                    color: page.relayBridgeOnline ? Theme.forestMid : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: page.relayOpen ? "▾" : "▸"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.relayOpen = !page.relayOpen
                            }
                        }

                        Text {
                            visible: !page.relayOpen
                            Layout.fillWidth: true
                            text: page.relayNotice.length ? page.relayNotice : page.relaySummary
                            color: page.relayNotice.length ? Theme.danger : Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            elide: Text.ElideRight
                        }

                        ColumnLayout {
                            visible: page.relayOpen
                            Layout.fillWidth: true
                            spacing: 5

                            Repeater {
                                model: page.relayInbox.slice(0, 2)

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: queuedColumn.implicitHeight + 12
                                    radius: 8
                                    color: Theme.white
                                    border.width: 1
                                    border.color: Theme.lineSoft

                                    ColumnLayout {
                                        id: queuedColumn
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        spacing: 3

                                        Text {
                                            Layout.fillWidth: true
                                            text: String(modelData.author || "Telegram") + " · "
                                                  + Logic.timeLabel(modelData.at || 0)
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 7
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: String(modelData.text || "")
                                            color: Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            spacing: 5

                                            ActionButton {
                                                compact: true
                                                variant: "primary"
                                                fontSize: 7
                                                hPadding: 8
                                                text: "Post to room"
                                                onClicked: page.relayPost(modelData.id)
                                            }

                                            ActionButton {
                                                compact: true
                                                variant: "ghost"
                                                fontSize: 7
                                                hPadding: 8
                                                text: "Dismiss"
                                                onClicked: page.relayDismiss(modelData.id)
                                            }

                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: page.relayQueued === 0
                                Layout.fillWidth: true
                                text: "No Telegram messages queued."
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                ActionButton {
                                    compact: true
                                    variant: "secondary"
                                    fontSize: 7
                                    hPadding: 8
                                    text: "Publish snapshot"
                                    onClicked: page.relayPublish()
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    visible: page.relayQueued > 2
                                    text: "+" + (page.relayQueued - 2) + " more"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                }
                            }

                            Text {
                                visible: page.relayNotice.length > 0
                                Layout.fillWidth: true
                                text: page.relayNotice
                                color: Theme.danger
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Relay runs beside Basecamp. Telegram posts are not signed and do not travel over Logos Messaging unless you post them to the room."
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 6
                                lineHeight: 1.3
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: composerColumn.implicitHeight + 24
                    color: "transparent"

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Theme.lineSoft
                    }

                    ColumnLayout {
                        id: composerColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.topMargin: 11
                        spacing: 5

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Theme.paper
                                border.width: 1
                                border.color: composer.activeFocus ? "#A8BE9B" : Theme.line

                                TextField {
                                    id: composer
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    placeholderText: "Message " + (page.channel ? page.channel.name : "")
                                                     + (page.chatReady ? " · mirrored over Logos" : " · local rehearsal only")
                                    placeholderTextColor: Theme.mutedLight
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    background: null
                                    selectByMouse: true
                                    onAccepted: {
                                        if (text.trim().length > 0) {
                                            page.submitMessage(text);
                                            text = "";
                                        }
                                    }
                                }
                            }

                            ActionButton {
                                text: "Send"
                                variant: "primary"
                                onClicked: {
                                    if (composer.text.trim().length > 0) {
                                        page.submitMessage(composer.text);
                                        composer.text = "";
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: page.chatReady
                                  ? "Posts are also handed to the Logos “Dhun Commons” group. A peer’s messages appear only after its installation joins; chat never signs."
                                  : "Local rehearsal only — Logos Messaging is " + page.chatState.toLowerCase() + ". Chat never signs; approvals happen in the wallet."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
