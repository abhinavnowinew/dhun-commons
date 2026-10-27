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

    signal openProposal(var proposal)
    signal openSale()
    signal openMint()
    signal allocate()
    signal navigate(string pageKey)

    // ── LEZ testnet backend ────────────────────────────────────────────────
    // The universal C++ backend is reachable only inside Logos Basecamp. In
    // the standalone harness `logos` does not exist, so the chain card shows
    // an explicit "not connected" state instead of inventing one.
    readonly property bool chainHosted: typeof logos !== "undefined" && logos !== null
    property var chainBackend: null
    property bool chainReady: false
    property string chainAction: ""
    property string chainActionError: ""
    property string recoveryPhrase: ""
    property string recoveryError: ""
    property bool recoveryOpen: false
    property string sendFrom: "funder"
    property string sendTo: "dhun"

    readonly property string chainStatus: chainBackend ? chainBackend.chainStatus : "uninitialized"
    readonly property string chainNotice: chainBackend ? chainBackend.chainNotice : ""
    readonly property string chainNetwork: chainBackend ? chainBackend.chainNetwork : "LEZ public testnet"
    readonly property string chainSequencer: chainBackend ? chainBackend.chainSequencer : "https://testnet.lez.logos.co"
    readonly property string chainWalletPath: chainBackend ? chainBackend.chainWalletPath : ""
    readonly property int chainHeight: chainBackend ? chainBackend.chainHeight : 0
    readonly property bool chainBusy: chainBackend ? chainBackend.chainBusy : false
    readonly property var chainAccounts: {
        try { return JSON.parse(chainBackend ? chainBackend.chainAccounts : "[]"); }
        catch (error) { return []; }
    }
    readonly property var chainLastTx: {
        try { return JSON.parse(chainBackend ? chainBackend.chainLastTx : "{}"); }
        catch (error) { return ({}); }
    }
    readonly property bool chainHasTx: !!(chainLastTx && chainLastTx.txHash)
    readonly property bool chainTxSuccess: !!(chainLastTx && chainLastTx.success)
    readonly property bool chainTxConfirmed: !!(chainLastTx && chainLastTx.confirmed)
    readonly property string chainTxHash: chainHasTx ? String(chainLastTx.txHash) : ""
    readonly property string chainTxError: (chainLastTx && chainLastTx.error) ? String(chainLastTx.error) : ""
    readonly property var chainAccountByRole: {
        var map = ({});
        for (var i = 0; i < chainAccounts.length; ++i) {
            var entry = chainAccounts[i];
            if (entry && entry.hasAccount) map[entry.role] = entry;
        }
        return map;
    }
    readonly property bool chainUnfunded: {
        if (!chainAccountByRole.funder) return false;
        for (var key in chainAccountByRole) {
            var lepta = String(chainAccountByRole[key].balanceLepta || "");
            if (lepta !== "" && lepta !== "0") return false;
        }
        return true;
    }
    readonly property string chainStatusLabel: {
        if (!chainHosted) return "NOT HOSTED";
        if (!chainReady) return "CONNECTING";
        if (chainStatus === "no-wallet") return "NO WALLET";
        if (chainStatus === "ready") return "CONNECTED";
        if (chainStatus === "error") return "ERROR";
        return "CONNECTING";
    }
    readonly property color chainStatusColor: {
        if (chainStatus === "ready") return Theme.forestMid;
        if (chainStatus === "error") return Theme.danger;
        if (chainStatus === "no-wallet") return Theme.goldDeep;
        return Theme.muted;
    }

    function parseChainReply(value) {
        if (value === undefined || value === null) return ({});
        if (typeof value === "object") return value;
        try { return JSON.parse(String(value)); }
        catch (error) { return ({ error: String(value), success: false }); }
    }

    function callChain(method, args, done) {
        if (!chainBackend || !chainReady) {
            chainActionError = "The Dhun Commons backend is not connected in this host.";
            return;
        }
        var pending;
        args = args || [];
        try {
            if (method === "refreshChain") pending = chainBackend.refreshChain();
            else if (method === "createWallet") pending = chainBackend.createWallet(String(args[0]));
            else if (method === "openWallet") pending = chainBackend.openWallet();
            else if (method === "sendSettlement") pending = chainBackend.sendSettlement(String(args[0]), String(args[1]), String(args[2]));
            else if (method === "checkTransaction") pending = chainBackend.checkTransaction(String(args[0]));
            else if (method === "chainDetails") pending = chainBackend.chainDetails();
            else throw new Error("Unknown chain method: " + method);
        } catch (error) {
            chainActionError = String(error);
            return;
        }
        logos.watch(pending, function (value) {
            chainActionError = "";
            if (done) done(parseChainReply(value));
        }, function (error) {
            chainActionError = String(error);
            if (done) done({ success: false, error: String(error) });
        });
    }

    function attachChainBackend() {
        if (!chainHosted) return false;
        if (!chainBackend) {
            try { chainBackend = logos.module("dhun_commons"); }
            catch (error) { chainBackend = null; }
        }
        if (!chainBackend) return false;
        try { page.chainReady = logos.isViewModuleReady("dhun_commons"); }
        catch (error) { page.chainReady = false; }
        if (page.chainReady && page.chainStatus === "ready" && page.chainHeight === 0
                && page.chainAction === "") page.refreshChain();
        return true;
    }

    function refreshChain() {
        chainAction = "refresh";
        callChain("refreshChain", [], function () { chainAction = ""; });
    }

    function createChainWallet(password) {
        if (password.length < 8) {
            chainActionError = "Choose a password of at least 8 characters.";
            return;
        }
        chainAction = "create";
        callChain("createWallet", [password], function (reply) {
            chainAction = "";
            if (reply && reply.mnemonic) {
                recoveryPhrase = reply.mnemonic;
                recoveryError = "";
                recoveryOpen = true;
            }
            if (!reply || !reply.success) {
                chainActionError = (reply && reply.error) ? reply.error : "The wallet could not be created.";
                return;
            }
            refreshChain();
        });
    }

    function openChainWallet() {
        chainAction = "open";
        callChain("openWallet", [], function (reply) {
            chainAction = "";
            if (!reply || !reply.success) {
                chainActionError = (reply && reply.error) ? reply.error : "The wallet could not be opened.";
                return;
            }
            refreshChain();
        });
    }

    function sendChainSettlement() {
        var from = chainAccountByRole[sendFrom];
        var to = chainAccountByRole[sendTo];
        if (!from || !to) {
            chainActionError = "Both party accounts must exist on this device.";
            return;
        }
        if (sendFrom === sendTo) {
            chainActionError = "Choose two different party accounts.";
            return;
        }
        chainAction = "send";
        chainActionError = "";
        callChain("sendSettlement", [from.idHex, to.idHex, settlementAmount.text], function (reply) {
            chainAction = "";
            if (reply && reply.success) {
                settlementAmount.text = "";
                chainActionError = "";
            } else {
                chainActionError = (reply && reply.error) ? reply.error : "The transfer was not submitted.";
            }
        });
    }

    function verifyChainSettlement() {
        var hash = chainLastTx && chainLastTx.txHash ? chainLastTx.txHash : "";
        if (hash.length === 0) return;
        chainAction = "verify";
        callChain("checkTransaction", [hash], function () { chainAction = ""; });
    }

    Connections {
        target: page.chainHosted ? logos : null
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName !== "dhun_commons") return;
            page.attachChainBackend();
        }
    }

    Connections {
        target: page.chainBackend
        ignoreUnknownSignals: true
        function onChainStatusChanged() {
            if (!page.chainReady || page.chainStatus !== "ready") return;
            if (page.chainHeight > 0 || page.chainAccounts.length > 0) return;
            if (page.chainAction !== "" || page.chainBusy) return;
            page.refreshChain();
        }
    }

    // The host's viewModuleReadyChanged signal is not guaranteed to fire for
    // in-process UI modules, so poll until the backend is attached.
    Timer {
        interval: 300
        repeat: true
        running: page.chainHosted && (!page.chainBackend || !page.chainReady)
        onTriggered: page.attachChainBackend()
    }

    Component.onCompleted: page.attachChainBackend()

    readonly property var role: app ? app.roles[activeRole] : null
    readonly property var roleProposals: app ? Logic.pendingProposals(app, now) : []
    readonly property var walletOrder: ["vault", "external", "projectEscrow", "challengeEscrow", "conservation", "funder", "dhun", "steward", "suppliers"]
    readonly property var ledgerNewest: {
        if (!app) return [];
        return app.ledger.slice().reverse();
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
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 184
                    radius: Theme.radiusXL
                    color: Theme.forest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 8

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: Theme.roleSoft(page.activeRole)

                                    Text {
                                        anchors.centerIn: parent
                                        text: page.activeRole === "funder" ? "A" : (page.activeRole === "dhun" ? "M" : "K")
                                        color: Theme.roleText(page.activeRole)
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }
                                }

                                ColumnLayout {
                                    spacing: 0
                                    Text {
                                        text: page.role ? page.role.org : ""
                                        color: "#F4F7E9"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: page.role ? page.role.signer : ""
                                        color: "#8FA795"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Pill {
                                text: "OPERATING WALLET"
                                fg: "#CFE3BE"
                                bg: "#25432F"
                                fontSize: 7
                            }
                        }

                        RowLayout {
                            spacing: 8

                            Text {
                                text: page.app ? Logic.formatNumber(page.app.wallets[page.activeRole]) : ""
                                color: "#F6F4E8"
                                font.family: Theme.displayFont
                                font.pixelSize: 46
                            }
                            Text {
                                text: "DHN"
                                color: Theme.limeDeep
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 8
                            }

                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignRight
                                Text {
                                    text: "SINGLE-SIGNER ALLOWANCE"
                                    color: "#829887"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    horizontalAlignment: Text.AlignRight
                                    Layout.fillWidth: true
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: page.role ? (page.role.allowance > 0 ? page.role.allowance + " DHN" : "none") : ""
                                    color: "#E7EFD9"
                                    font.family: Theme.uiFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Repeater {
                                model: [
                                    { label: "Address", value: page.role ? page.role.address : "" },
                                    { label: "Key fingerprint", value: page.role ? page.role.keyFingerprint : "" },
                                    { label: "Reputation", value: page.role ? (page.role.reputation + " · " + page.role.onTime + "% on time") : "" }
                                ]

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.label.toUpperCase()
                                        color: "#829887"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 6
                                        font.letterSpacing: 1
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: "#C8D7C5"
                                        font.family: Theme.monoFont
                                        font.pixelSize: 8
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            ActionButton {
                                compact: true
                                variant: "lime"
                                text: page.activeRole === "funder" ? "Sell externally" : "Buy resources"
                                onClicked: {
                                    if (page.activeRole === "funder") page.openSale();
                                    else page.navigate("market");
                                }
                            }

                            ActionButton {
                                compact: true
                                variant: "ghost"
                                text: page.activeRole === "funder" ? "Issue tranche" : "Allocate challenge"
                                onClicked: {
                                    if (page.activeRole === "funder") page.openMint();
                                    else page.allocate();
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: page.activeRole === "funder"
                                      ? "Funder cannot spend unilaterally"
                                      : "Above allowance, a co-signature is required"
                                color: "#7E9583"
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                Card {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    padding: 18
                    gap: 0
                    fill: Theme.white

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Token backing"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Pill {
                            text: "₹" + (page.app ? page.app.token.floorINR : "") + " floor"
                            fg: Theme.forestMid
                            bg: Theme.sageLight
                            fontSize: 8
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        text: page.app ? ("₹" + Logic.formatNumber(page.app.token.fiatReserve)) : ""
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 29
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "settlement reserve"
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 8
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        value: 1
                        fill: Theme.limeDeep
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Text {
                            text: "100% backed"
                            color: Theme.forestMid
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.app ? (Logic.formatNumber(page.app.token.issued) + " issued") : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        height: 1
                        color: Theme.lineSoft
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 9

                        Repeater {
                            model: [
                                { label: "Raised", value: page.app ? ("₹" + Logic.compact(page.app.token.fiatRaised)) : "" },
                                { label: "External", value: page.app ? Logic.formatNumber(page.app.wallets.external) : "" },
                                { label: "Quorum", value: page.app ? (page.app.token.quorum + " of " + page.app.token.members) : "" },
                                { label: "Program", value: "v" + (page.app ? page.app.token.version : "") }
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
                                    text: modelData.value
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }

            Card {
                id: chainCard
                Layout.fillWidth: true
                padding: 18
                gap: 12
                fill: Theme.white

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "On-chain accounts"
                        color: Theme.ink
                        font.family: Theme.displayFont
                        font.pixelSize: 22
                    }
                    Pill {
                        text: "LEZ PUBLIC TESTNET"
                        fg: Theme.forestMid
                        bg: Theme.sageLight
                        fontSize: 7
                    }
                    Pill {
                        text: page.chainStatusLabel
                        fg: Theme.white
                        bg: page.chainStatusColor
                        dotColor: Theme.white
                        fontSize: 7
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: page.chainHeight > 0
                        text: "BLOCK " + Logic.formatNumber(page.chainHeight)
                        color: Theme.muted
                        font.family: Theme.monoFont
                        font.pixelSize: 8
                    }
                    ActionButton {
                        compact: true
                        variant: "secondary"
                        text: page.chainBusy ? "Reading…" : "Refresh"
                        enabled: page.chainReady && !page.chainBusy
                        onClicked: page.refreshChain()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: page.chainNotice.length > 0
                          ? page.chainNotice
                          : (page.chainHosted
                             ? "Connecting to the Dhun Commons backend…"
                             : "This page is running outside Logos Basecamp, so the on-chain backend is not available. Open Dhun Commons in Basecamp to read the LEZ testnet.")
                    color: page.chainStatus === "error" ? Theme.danger : Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 9
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.lineSoft
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        // ── No wallet yet: creation / opening ──────────────────
                        ColumnLayout {
                            visible: page.chainReady && page.chainStatus === "no-wallet"
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "Create a local LEZ wallet to place the three party accounts on the public testnet. The seed is generated on this device. lez_core 0.5.1 does not encrypt its wallet file and ignores the password, so protect this OS account; the field below only gates creation."
                                color: Theme.inkSoft
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                lineHeight: 1.35
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: chainPassword
                                    Layout.preferredWidth: 240
                                    placeholderText: "Local password (8+ characters)"
                                    placeholderTextColor: Theme.mutedLight
                                    echoMode: TextInput.Password
                                    color: Theme.ink
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    selectByMouse: true
                                    background: Rectangle {
                                        implicitHeight: 34
                                        radius: 8
                                        color: Theme.paperWarm
                                        border.width: 1
                                        border.color: chainPassword.activeFocus ? Theme.forestMid : Theme.line
                                    }
                                }

                                ActionButton {
                                    compact: true
                                    variant: "primary"
                                    text: "Create wallet"
                                    enabled: page.chainReady && !page.chainBusy && page.chainAction !== "create"
                                    onClicked: page.createChainWallet(chainPassword.text)
                                }

                                ActionButton {
                                    compact: true
                                    variant: "ghost"
                                    text: "Open saved wallet"
                                    enabled: page.chainReady && !page.chainBusy
                                    onClicked: page.openChainWallet()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "The recovery phrase is shown once after creation. Dhun Commons never stores it. The LEZ wallet folder is plain JSON in this version; treat it as a secret."
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                            }
                        }

                        // ── Accounts ───────────────────────────────────────────
                        ColumnLayout {
                            visible: page.chainReady && page.chainStatus !== "no-wallet"
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: page.chainAccounts

                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 9
                                        color: Theme.roleSoft(modelData.role)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name ? modelData.name.substring(0, 1) : "?"
                                            color: Theme.roleText(modelData.role)
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: 1
                                        Text {
                                            text: modelData.name + " · " + modelData.role
                                            color: Theme.ink
                                            font.family: Theme.uiFont
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            Layout.preferredWidth: 0
                                            text: modelData.hasAccount ? modelData.address : "No account on this device"
                                            color: Theme.muted
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: modelData.hasAccount ? (modelData.balance + " LEZ") : "—"
                                            color: Theme.ink
                                            font.family: Theme.displayFont
                                            font.pixelSize: 15
                                            horizontalAlignment: Text.AlignRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: modelData.hasAccount && modelData.idHex
                                                  ? ("id " + String(modelData.idHex).substring(0, 8) + "…")
                                                  : ""
                                            color: Theme.mutedLight
                                            font.family: Theme.monoFont
                                            font.pixelSize: 6
                                            horizontalAlignment: Text.AlignRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                spacing: 8

                                Pill {
                                    visible: page.chainUnfunded
                                    text: "UNFUNDED"
                                    fg: Theme.goldDeep
                                    bg: Theme.goldLight
                                    fontSize: 7
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: page.chainUnfunded
                                          ? "Every account reads 0 LEZ. The testnet has no in-app faucet in this build; a transfer can only succeed once an account is funded externally."
                                          : "Balances are read straight from the LEZ sequencer. Public transfers are signed on this device."
                                    color: page.chainUnfunded ? Theme.goldDeep : Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 8
                                    lineHeight: 1.35
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                text: page.chainWalletPath.length > 0
                                      ? ("Wallet files · " + page.chainWalletPath)
                                      : ""
                                color: Theme.mutedLight
                                font.family: Theme.monoFont
                                font.pixelSize: 7
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                text: "Sequencer · " + page.chainSequencer
                                color: Theme.mutedLight
                                font.family: Theme.monoFont
                                font.pixelSize: 7
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.lineSoft
                    }

                    // ── Public settlement form ─────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Public transfer"
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Pill {
                                text: "SUBMITTED ≠ SETTLED"
                                fg: Theme.goldDeep
                                bg: Theme.goldLight
                                fontSize: 6
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: "From"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                Layout.preferredWidth: 30
                            }
                            Repeater {
                                model: ["funder", "dhun", "steward"]
                                delegate: ActionButton {
                                    required property string modelData
                                    compact: true
                                    fontSize: 9
                                    hPadding: 9
                                    variant: page.sendFrom === modelData ? "lime" : "ghost"
                                    text: page.chainAccountByRole[modelData] ? page.chainAccountByRole[modelData].name : modelData
                                    enabled: page.chainStatus === "ready"
                                    onClicked: page.sendFrom = modelData
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: "To"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                Layout.preferredWidth: 30
                            }
                            Repeater {
                                model: ["funder", "dhun", "steward"]
                                delegate: ActionButton {
                                    required property string modelData
                                    compact: true
                                    fontSize: 9
                                    hPadding: 9
                                    variant: page.sendTo === modelData ? "lime" : "ghost"
                                    text: page.chainAccountByRole[modelData] ? page.chainAccountByRole[modelData].name : modelData
                                    enabled: page.chainStatus === "ready"
                                    onClicked: page.sendTo = modelData
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: settlementAmount
                                Layout.fillWidth: true
                                placeholderText: "Amount in LEZ"
                                placeholderTextColor: Theme.mutedLight
                                color: Theme.ink
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                selectByMouse: true
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                background: Rectangle {
                                    implicitHeight: 34
                                    radius: 8
                                    color: Theme.paperWarm
                                    border.width: 1
                                    border.color: settlementAmount.activeFocus ? Theme.forestMid : Theme.line
                                }
                            }

                            ActionButton {
                                compact: true
                                variant: "primary"
                                text: page.chainAction === "send" ? "Submitting…" : "Submit"
                                enabled: page.chainStatus === "ready" && !page.chainBusy && page.chainAction === ""
                                onClicked: page.sendChainSettlement()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: page.chainActionError.length > 0
                            text: page.chainActionError
                            color: Theme.danger
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.lineSoft
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            visible: page.chainHasTx
                            Text {
                                text: page.chainTxConfirmed
                                      ? "Sequencer reported · still verify finality"
                                      : (page.chainTxSuccess ? "Submitted · awaiting verification" : "Not submitted")
                                color: page.chainTxSuccess ? Theme.forestMid : Theme.danger
                                font.family: Theme.uiFont
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: page.chainTxHash
                                color: Theme.inkSoft
                                font.family: Theme.monoFont
                                font.pixelSize: 7
                                wrapMode: Text.WrapAnywhere
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: page.chainTxError.length > 0
                                text: page.chainTxError
                                color: Theme.danger
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                wrapMode: Text.WordWrap
                            }
                            ActionButton {
                                compact: true
                                variant: "secondary"
                                text: page.chainAction === "verify" ? "Checking…" : "Verify with sequencer"
                                enabled: page.chainTxSuccess && page.chainAction === ""
                                onClicked: page.verifyChainSettlement()
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !page.chainHasTx
                            text: "The transaction hash appears here after submission. Nothing is called settled until the sequencer reports it and the explorer shows it."
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Open proposals"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 22
                        }
                        Text {
                            Layout.leftMargin: 7
                            text: page.app ? (Logic.pendingProposals(page.app, page.now).length + " in the queue") : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Distinct signatures are verified at execution"
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Repeater {
                        model: page.roleProposals

                        delegate: ProposalRow {
                            required property var modelData
                            Layout.fillWidth: true
                            app: page.app
                            proposal: modelData
                            now: page.now
                            activeRole: page.activeRole
                            onOpen: function (proposal) { page.openProposal(proposal) }
                        }
                    }

                    Card {
                        visible: page.roleProposals.length === 0
                        Layout.fillWidth: true
                        padding: 18
                        EmptyState {
                            Layout.fillWidth: true
                            glyph: "✓"
                            title: "The queue is clear"
                            body: "No proposal is waiting. Issue a tranche, sell externally or allocate a challenge to start the next round."
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Text {
                            text: "Treasury ledger"
                            color: Theme.ink
                            font.family: Theme.displayFont
                            font.pixelSize: 22
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.app ? (page.app.ledger.length + " entries · all wallets sum to " + Logic.formatNumber(Logic.totalSupply(page.app)) + " DHN") : ""
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: ledgerColumn.implicitHeight + 24
                        radius: Theme.radiusLarge
                        color: Theme.white
                        border.width: 1
                        border.color: Theme.line

                        ColumnLayout {
                            id: ledgerColumn
                            x: 16
                            y: 12
                            width: parent.width - 32
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.bottomMargin: 6
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 62
                                    text: "DATE"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "ENTRY"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.preferredWidth: 70
                                    text: "AMOUNT"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    Layout.preferredWidth: 84
                                    text: "TXID"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 6
                                    font.letterSpacing: 1
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Repeater {
                                model: page.ledgerNewest

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 1
                                        color: Theme.lineSoft
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 6
                                        Layout.bottomMargin: 6
                                        spacing: 8

                                        Text {
                                            Layout.preferredWidth: 62
                                            text: Logic.dateLabel(modelData.at).replace(" 2026", "")
                                            color: Theme.muted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
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
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.detail
                                                color: Theme.muted
                                                font.family: Theme.uiFont
                                                font.pixelSize: 7
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: 70
                                            text: (modelData.kind === "issue" ? "+" : "") + Logic.formatNumber(modelData.amount)
                                            color: modelData.kind === "issue" ? Theme.forestMid : Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 84
                                            text: Logic.shortHash(modelData.txid)
                                            color: Theme.muted
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 310
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    Card {
                        Layout.fillWidth: true
                        padding: 17
                        gap: 0
                        fill: Theme.white

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Where the DHN sits"
                                color: Theme.ink
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: page.app ? Logic.formatNumber(Logic.totalSupply(page.app)) : ""
                                color: Theme.muted
                                font.family: Theme.monoFont
                                font.pixelSize: 8
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 11
                            spacing: 7

                            Repeater {
                                model: page.walletOrder

                                delegate: ColumnLayout {
                                    required property string modelData
                                    readonly property real amount: page.app ? Number(page.app.wallets[modelData] || 0) : 0
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            text: Logic.walletLabel(modelData)
                                            color: modelData === page.activeRole ? Theme.forestMid : Theme.inkSoft
                                            font.family: Theme.uiFont
                                            font.pixelSize: 8
                                            font.weight: modelData === page.activeRole ? Font.DemiBold : Font.Normal
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: Logic.formatNumber(amount)
                                            color: Theme.muted
                                            font.family: Theme.monoFont
                                            font.pixelSize: 7
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 3
                                        radius: 1.5
                                        color: Theme.paperDeep

                                        Rectangle {
                                            width: parent.width * amount / Math.max(1, page.app ? Logic.totalSupply(page.app) : 1)
                                            height: 3
                                            radius: 1.5
                                            color: modelData === page.activeRole ? Theme.forestMid : Theme.limeDeep
                                            opacity: modelData === page.activeRole ? 1 : 0.6
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        padding: 17
                        gap: 0
                        fill: Theme.white

                        Text {
                            text: "Program policy"
                            color: Theme.ink
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 9
                            spacing: 6

                            Repeater {
                                model: page.app ? [
                                    { label: "Posture", value: page.app.policy.posture },
                                    { label: "Approve", value: page.app.policy.approve },
                                    { label: "Propose", value: page.app.policy.propose },
                                    { label: "Time lock", value: page.app.policy.timelockCurrent > 0 ? page.app.policy.timelockCurrent + " seconds" : "none on this rehearsal" },
                                    { label: "Disclosure", value: page.app.policy.disclosure },
                                    { label: "Licence", value: page.app.policy.licence }
                                ] : []

                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Text {
                                        Layout.preferredWidth: 62
                                        text: modelData.label
                                        color: Theme.muted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        color: Theme.inkSoft
                                        font.family: Theme.uiFont
                                        font.pixelSize: 8
                                        wrapMode: Text.WordWrap
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        Layout.fillWidth: true
                        padding: 15
                        gap: 0
                        fill: Theme.goldLight
                        stroke: "#E4CE9E"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            Icon {
                                name: "info"
                                color: Theme.goldDeep
                                width: 13
                                height: 13
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Rehearsal wallet"
                                color: Theme.goldDeep
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 5
                            text: "DHN balances, signatures and txids in this treasury view are locally generated demo data. They are separate from the LEZ testnet accounts above, which are real public accounts on the sequencer."
                            color: "#7C5A20"
                            font.family: Theme.uiFont
                            font.pixelSize: 8
                            lineHeight: 1.35
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: recoveryDialog
        parent: Overlay.overlay
        modal: true
        closePolicy: Popup.NoAutoClose
        width: Math.min(560, page.width - 80)
        x: (page.width - width) / 2
        y: Math.max(40, (page.height - height) / 2)
        padding: 22
        background: Rectangle {
            color: Theme.white
            radius: Theme.radiusLarge
            border.width: 1
            border.color: Theme.line
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "Save your recovery phrase"
                color: Theme.ink
                font.family: Theme.displayFont
                font.pixelSize: 21
            }
            Text {
                Layout.fillWidth: true
                text: "This phrase restores the three party accounts. It is shown once and is never stored by Dhun Commons. Write it down offline before closing this window."
                color: Theme.danger
                font.family: Theme.uiFont
                font.pixelSize: 9
                lineHeight: 1.35
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                radius: 10
                color: Theme.paperWarm
                border.width: 1
                border.color: Theme.line
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 10
                    TextArea {
                        id: recoveryText
                        text: page.recoveryPhrase
                        readOnly: true
                        selectByMouse: true
                        color: Theme.ink
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                        background: Rectangle { color: "transparent" }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionButton {
                    compact: true
                    variant: "secondary"
                    text: "Copy phrase"
                    onClicked: {
                        recoveryText.selectAll();
                        recoveryText.copy();
                    }
                }
                Item { Layout.fillWidth: true }
                ActionButton {
                    compact: true
                    variant: "primary"
                    text: "I have written it down"
                    onClicked: recoveryDialog.close()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: page.recoveryError.length > 0
                text: page.recoveryError
                color: Theme.danger
                font.family: Theme.uiFont
                font.pixelSize: 8
                wrapMode: Text.WordWrap
            }
        }
        visible: page.recoveryOpen
        onClosed: {
            page.recoveryOpen = false;
            page.recoveryPhrase = "";
        }
    }
}
