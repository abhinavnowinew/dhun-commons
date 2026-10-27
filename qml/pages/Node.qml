import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "../theme.js" as Theme
import "../logic.js" as Logic
import "../rewards.js" as Rewards
import "../components"

Item {
    id: page

    property var app: null
    property var now: Date.now()
    property string activeRole: "funder"
    property var activePerson: null
    property var catalog: null
    property int profileCount: 0
    property int stewardProfileCount: 0
    property int pendingRewardCount: 0

    // Reported by the Logos Messaging node in Room.qml.
    property bool nodeHosted: false
    property bool nodeReady: false
    property string nodeState: "UNAVAILABLE"
    property string nodeDelivery: ""
    property string nodeAddress: ""
    property string nodeError: ""
    property string nodeLine: ""
    property int nodePeers: 0
    property int nodeInbound: 0
    property int nodeMirrored: 0
    property int nodeConvos: 0

    // Reported by the LEZ backend attached in Wallet.qml.
    property bool chainHosted: false
    property bool chainReady: false
    property string chainStatus: "uninitialized"
    property int chainHeight: 0
    property string chainNetwork: "LEZ public testnet"
    property string chainSequencer: "https://testnet.lez.logos.co"
    property var chainAccounts: []

    signal navigate(string pageKey)
    signal openProfile()
    signal proposePayout(string profileId)

    readonly property var people: app && app.people ? app.people : []
    readonly property var rewards: app && app.rewards ? app.rewards : []

    readonly property int knownAccounts: {
        var total = 0;
        for (var i = 0; i < chainAccounts.length; ++i)
            if (chainAccounts[i] && chainAccounts[i].hasAccount) total += 1;
        return total;
    }
    readonly property int fundedAccounts: {
        var total = 0;
        for (var i = 0; i < chainAccounts.length; ++i) {
            var entry = chainAccounts[i];
            if (!entry || !entry.hasAccount) continue;
            if (String(entry.balanceLepta || "") !== "" && String(entry.balanceLepta) !== "0") total += 1;
        }
        return total;
    }
    readonly property int nodeDays: countRule("node-day")
    readonly property int queuedTotal: Rewards.total(Rewards.entries(app).filter(function (entry) {
        return entry.status === "earned";
    }))
    readonly property int paidTotal: Rewards.total(Rewards.entries(app).filter(function (entry) {
        return entry.status === "paid";
    }))
    readonly property string checkedLabel: {
        if (!catalog || !catalog.checkedAt) return "not checked";
        return String(catalog.checkedAt).replace("T", " · ").replace("Z", " UTC");
    }

    function countRule(ruleId) {
        var total = 0;
        for (var i = 0; i < rewards.length; ++i)
            if (rewards[i].rule === ruleId && rewards[i].status !== "cancelled") total += 1;
        return total;
    }

    function ruleCountFor(profileId, ruleId) {
        var list = Rewards.forProfile(app, profileId);
        var total = 0;
        for (var i = 0; i < list.length; ++i)
            if (list[i].rule === ruleId) total += 1;
        return total;
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

            // ── Node hero ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 252
                radius: Theme.radiusXL
                color: Theme.forest
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 26

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 640
                        spacing: 9

                        RowLayout {
                            spacing: 8

                            Pill {
                                text: nodeReady ? "LOGOS NODE READY" : (nodeHosted ? "NODE NOT READY" : "NOT HOSTED")
                                fg: nodeReady ? Theme.forest : "#3B2A12"
                                bg: nodeReady ? Theme.lime : Theme.gold
                                dotColor: nodeReady ? Theme.forest : "#7A5215"
                                fontSize: 8
                                strong: true
                            }
                            Pill {
                                text: chainStatus === "ready" ? "LEZ SEQUENCER READY" : "LEZ " + chainStatus.toUpperCase()
                                fg: chainStatus === "ready" ? "#CFE3BE" : "#E7C79B"
                                bg: chainStatus === "ready" ? "#25432F" : "#3E2F18"
                                fontSize: 8
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "The node earns\nthe commons its keep."
                            color: "#F6F4E8"
                            font.family: Theme.displayFont
                            font.pixelSize: 32
                            lineHeight: 1.02
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "DHN is not minted for clicks. Treasury payouts queue up for work you can verify — a ready Logos node, filed field tasks, evidence on a challenge, a built kitchen plan. A profile earns the entries; two of three signatures move the money."
                            color: "#B7C8B7"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            lineHeight: 1.45
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 8

                            ActionButton {
                                compact: true
                                variant: "lime"
                                text: activePerson ? "Earn as " + activePerson.name : "Create your profile"
                                onClicked: page.openProfile()
                            }
                            ActionButton {
                                compact: true
                                variant: "secondary"
                                text: "Open coordination room"
                                onClicked: page.navigate("room")
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.preferredWidth: 272
                        spacing: 8

                        Text {
                            text: "THIS DEVICE"
                            color: "#8FA795"
                            font.family: Theme.uiFont
                            font.pixelSize: 7
                            font.letterSpacing: 1.5
                            font.weight: Font.DemiBold
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { label: "Node days", value: String(page.nodeDays) },
                                    { label: "Queued", value: page.queuedTotal + " DHN" },
                                    { label: "Paid", value: page.paidTotal + " DHN" }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.value
                                        color: "#F4F7E9"
                                        font.family: Theme.displayFont
                                        font.pixelSize: 21
                                    }
                                    Text {
                                        text: modelData.label
                                        color: "#8FA795"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#2C4634"
                        }

                        Text {
                            Layout.fillWidth: true
                            text: nodeLine.length > 0 ? nodeLine : "The Logos Messaging node reports its own state inside Basecamp."
                            color: "#A5B9A7"
                            font.family: Theme.monoFont
                            font.pixelSize: 8
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ── Node day meter ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StatTile {
                    Layout.fillWidth: true
                    label: "NODE UPTIME"
                    value: page.nodeDays + (page.nodeDays === 1 ? " day" : " days")
                    caption: "Logged once per device per calendar day while the node is ready"
                    accent: Theme.limeDeep
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "TREASURY QUEUE"
                    value: page.pendingRewardCount + (page.pendingRewardCount === 1 ? " entry" : " entries")
                    caption: "Unclaimed rewards waiting for a 2-of-3 payout"
                    accent: Theme.gold
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "PROFILES ON DEVICE"
                    value: String(page.profileCount)
                    caption: page.stewardProfileCount + " steward · profiles are local identities"
                    accent: Theme.clay
                }

                StatTile {
                    Layout.fillWidth: true
                    label: "LEZ ACCOUNTS"
                    value: page.knownAccounts > 0 ? (page.fundedAccounts + " / " + page.knownAccounts) : "—"
                    caption: chainHosted
                             ? "Funded of created party accounts in the local wallet"
                             : "Open in Basecamp to read the LEZ wallet"
                    accent: Theme.forestMid
                }
            }

            // ── The two things that are actually running ────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Card {
                    Layout.fillWidth: true
                    padding: 18
                    gap: 10
                    fill: Theme.white

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Logos Messaging node"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 22
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: page.nodeState
                            fg: page.nodeReady ? Theme.forest : Theme.goldDeep
                            bg: page.nodeReady ? Theme.lime : Theme.goldLight
                            dotColor: page.nodeReady ? Theme.forest : Theme.goldDeep
                            fontSize: 8
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.nodeHosted
                              ? (page.nodeError.length ? page.nodeError : page.nodeLine)
                              : "Logos Messaging is available only inside Basecamp. This page is not claiming a node here."
                        color: page.nodeError.length ? Theme.danger : Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10

                        Repeater {
                            model: [
                                { label: "Delivery", value: page.nodeDelivery.length ? page.nodeDelivery : "—" },
                                { label: "Peers", value: String(page.nodePeers) },
                                { label: "Route address", value: page.nodeAddress.length ? page.nodeAddress : "not issued" },
                                { label: "Conversations", value: String(page.nodeConvos) },
                                { label: "Submitted", value: String(page.nodeMirrored) },
                                { label: "Received", value: String(page.nodeInbound) }
                            ]

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.label.toUpperCase()
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Theme.ink
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.lineSoft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.nodePeers <= 1
                              ? "One peer is this device. NODE UPTIME rewards the local node being ready; it is not proof that a second person received a message. Delivery to another peer has not been observed."
                              : "A second peer is visible. Delivery is sequencer- and node-reported, not independently verified finality."
                        color: Theme.inkSoft
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }
                }

                Card {
                    Layout.fillWidth: true
                    padding: 18
                    gap: 10
                    fill: Theme.white

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "LEZ sequencer"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 22
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: page.chainStatus.toUpperCase()
                            fg: page.chainStatus === "ready" ? Theme.forest : Theme.goldDeep
                            bg: page.chainStatus === "ready" ? Theme.lime : Theme.goldLight
                            fontSize: 8
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.chainHosted
                              ? (page.chainReady
                                 ? "The local LEZ wallet talks to the public testnet sequencer. Heights and balances are reported by the sequencer; a submitted transfer is not finality."
                                 : "The Dhun Commons backend is not ready yet. Open Basecamp and wait for the module to attach.")
                              : "This page is running outside Logos Basecamp, so the LEZ backend is not available. No chain state is claimed."
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 9
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 10

                        Repeater {
                            model: [
                                { label: "Network", value: page.chainNetwork },
                                { label: "Height", value: page.chainHeight > 0 ? Logic.formatNumber(page.chainHeight) : "—" },
                                { label: "Sequencer", value: page.chainSequencer },
                                { label: "Accounts", value: page.knownAccounts > 0 ? (page.knownAccounts + " created · " + page.fundedAccounts + " funded") : "not opened" }
                            ]

                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.label.toUpperCase()
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Theme.ink
                                    font.family: Theme.monoFont
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
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
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: "Wallet accounts belong to the three parties, not to each profile. Steward profiles share the steward wallet until a payout is executed."
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                        }

                        ActionButton {
                            compact: true
                            variant: "secondary"
                            text: "Open wallet"
                            onClicked: page.navigate("wallet")
                        }
                    }
                }
            }

            // ── Who is actually here ────────────────────────────────────
            Card {
                Layout.fillWidth: true
                padding: 18
                gap: 12
                fill: Theme.paperWarm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Who is actually here"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 21
                    }
                    Pill {
                        text: "NO INVENTED NUMBERS"
                        fg: Theme.clayDeep
                        bg: Theme.clayLight
                        fontSize: 7
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "checked " + page.checkedLabel
                        color: Theme.muted
                        font.family: Theme.monoFont
                        font.pixelSize: 8
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 26

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: page.catalog ? String(page.catalog.uniqueVisitors) : "—"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "unique visitors"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.catalog ? (page.catalog.pageViews + " page views in " + page.catalog.windowDays + " days") : "no analytics snapshot"
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle { width: 1; height: 54; color: Theme.line }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: String(page.knownAccounts)
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "LEZ wallet accounts on this device"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.chainHosted
                                  ? (page.knownAccounts > 0 ? page.fundedAccounts + " funded with testnet tokens" : "create the wallet from the Wallet page")
                                  : "available inside Basecamp only"
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle { width: 1; height: 54; color: Theme.line }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: String(page.profileCount)
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 30
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "profiles saved on this device"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.stewardProfileCount + " steward · local identities, not chain accounts"
                            color: Theme.inkSoft
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: (page.catalog ? ("Catalog host " + page.catalog.host + " reports " + page.catalog.source + " for the public Basecamp listing. Downloads are " + (page.catalog.downloadsReported ? "reported" : "not reported") + " by the host, so no install count is shown. " + (page.catalog.coverageNote || "") + " ") : "No catalog snapshot is stored on this device. ")
                          + "Wallet holders are the party accounts this device actually holds; profiles are names on this device, not separate wallets."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                }
            }

            // ── How to earn ──────────────────────────────────────────────
            Card {
                Layout.fillWidth: true
                padding: 20
                gap: 14
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "How to earn DHN"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 23
                        }
                        Text {
                            text: "Five verifiable actions. Each entry is recorded with evidence, then a 2-of-3 payout moves treasury money — nothing is minted silently."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Pill {
                        text: page.activePerson ? ("EARNING AS " + page.activePerson.name.toUpperCase()) : "NO PROFILE"
                        fg: Theme.forest
                        bg: Theme.sageLight
                        dotColor: Theme.limeDeep
                        fontSize: 7
                    }
                }

                Repeater {
                    model: Rewards.RULES

                    delegate: Rectangle {
                        required property var modelData
                        readonly property int done: page.ruleCountFor(page.activePerson ? page.activePerson.id : "", modelData.id)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        radius: 12
                        color: Theme.paperWarm
                        border.width: 1
                        border.color: Theme.lineSoft

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 14

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 12
                                color: Theme.forest

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: String(modelData.amount)
                                        color: Theme.lime
                                        font.family: Theme.displayFont
                                        font.pixelSize: 17
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "DHN"
                                        color: "#9DB29F"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 6
                                        font.letterSpacing: 0.8
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: modelData.label
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Pill {
                                        text: "per " + modelData.unit
                                        fg: Theme.forestMid
                                        bg: Theme.sageLight
                                        fontSize: 7
                                    }
                                    Pill {
                                        visible: done > 0
                                        text: done + " for you"
                                        fg: Theme.clayDeep
                                        bg: Theme.clayLight
                                        fontSize: 7
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.evidence
                                    color: Theme.inkSoft
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    lineHeight: 1.35
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: "ROUTE"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: modelData.route
                                    color: Theme.forestMid
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }
                            }

                            ActionButton {
                                compact: true
                                variant: "ghost"
                                text: "Go"
                                onClicked: {
                                    if (modelData.id === "node-day") page.navigate("room");
                                    else if (modelData.id === "field-task") page.navigate("field");
                                    else if (modelData.id === "challenge-evidence") page.navigate("challenges");
                                    else if (modelData.id === "kitchen-plan") page.navigate("kitchen");
                                    else page.openProfile();
                                }
                            }
                        }
                    }
                }
            }

            // ── Profiles and unclaimed rewards ──────────────────────────
            Card {
                Layout.fillWidth: true
                padding: 20
                gap: 12
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Earned on this device"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 21
                    }
                    Item { Layout.fillWidth: true }
                    ActionButton {
                        compact: true
                        variant: "lime"
                        text: "Create a steward profile"
                        onClicked: page.openProfile()
                    }
                }

                Repeater {
                    model: page.people

                    delegate: Rectangle {
                        required property var modelData
                        readonly property var totals: Rewards.profileTotals(page.app, modelData.id)
                        readonly property bool active: page.activePerson && page.activePerson.id === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        radius: 11
                        color: active ? Theme.sageLight : Theme.paperWarm
                        border.width: 1
                        border.color: active ? "#C9D8B9" : Theme.lineSoft

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 11

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Theme.roleSoft(modelData.role)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name.substring(0, 1).toUpperCase()
                                    color: Theme.roleText(modelData.role)
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        text: modelData.name
                                        color: Theme.ink
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Pill {
                                        text: modelData.role === "steward" ? "STEWARD" : modelData.role.toUpperCase()
                                        fg: Theme.roleText(modelData.role)
                                        bg: Theme.roleSoft(modelData.role)
                                        fontSize: 7
                                    }
                                    Pill {
                                        visible: active
                                        text: "SIGNING"
                                        fg: Theme.forest
                                        bg: Theme.lime
                                        fontSize: 7
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: ((modelData.place || "").length ? modelData.place + " · " : "")
                                          + (modelData.seeded ? "seeded profile" : "joined " + Qt.formatDate(new Date(modelData.joinedAt), "d MMM yyyy"))
                                          + " · saved on this device"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: totals.pending + " DHN queued"
                                    color: totals.pending > 0 ? Theme.forestMid : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: totals.paid + " DHN paid"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                }
                            }

                            ActionButton {
                                compact: true
                                variant: totals.pending > 0 ? "primary" : "secondary"
                                text: "Propose payout"
                                enabled: totals.pending > 0
                                onClicked: page.proposePayout(modelData.id)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "A payout is a normal multisig proposal: treasury → " + (page.activePerson ? page.activePerson.role : "party") +
                          " wallet, signed by two of three. It moves existing DHN; supply does not change. Profiles are local to this device — clearing app state removes them."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 8
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
