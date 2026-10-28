import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import "theme.js" as Theme
import "logic.js" as Logic
import "seed.js" as Seed
import "rewards.js" as Rewards
import "components"
import "pages"
import "drawers"

Item {
    id: app

    width: 1440
    height: 900

    property bool restoreState: true
    property bool persistState: true

    property var state: Seed.build(Date.now())
    property real now: Date.now()
    property string activePage: "overview"
    property string activeRole: "funder"
    property string activePersonId: "person-funder"
    property bool profileOpen: false
    property string roomChannel: "room-msig"

    property var activeProposal: null
    property var activeOffer: null
    property bool treasuryOpen: false
    property string treasuryMode: "sale"
    property bool allocateOpen: false
    property string allocateProjectId: "PRJ-01"
    property var activeProject: null
    property var activeChallenge: null
    property bool aboutOpen: false
    property bool webStudioEnabled: true
    property int purchaseInitialQty: 1
    property var seenStudioUpdates: ({})

    // Any QML sheet or drawer sits below QtWebView's native macOS view, so the
    // Field map unloads its web view while one is open.
    readonly property bool overlayOpen: profileOpen || aboutOpen || treasuryOpen || allocateOpen ||
                                        activeProposal !== null || activeOffer !== null ||
                                        activeProject !== null || activeChallenge !== null

    readonly property bool relayHosted: typeof logos !== "undefined" && logos !== null
    property var relayBackend: null
    property bool relayReady: false
    property bool relayBusy: false
    property var relayInbox: []
    property var relayBridge: ({})
    property double relayPublishedAt: 0
    property string relayNotice: ""
    property var relaySeen: ({})

    property string toastText: ""
    property string toastTone: "ok"

    readonly property var activePerson: personById(activePersonId)
    readonly property var people: state && state.people ? state.people : []
    readonly property int profileCount: people.length
    readonly property int stewardProfileCount: people.filter(function (person) { return person.role === "steward"; }).length
    readonly property int pendingRewardCount: state ? Rewards.pendingCount(state) : 0
    readonly property var catalog: state && state.catalog ? state.catalog : null

    readonly property var pageOrder: ["overview", "field", "kitchen", "market", "projects", "challenges", "wallet", "node", "room", "landscape"]
    readonly property var pageMeta: ({
        overview: {
            title: "Overview",
            subtitle: "Treasury, pending signatures and the next closing window",
            section: "Commons"
        },
        field: {
            title: "Field map",
            subtitle: "Produce plots, field work and the calendar the three parties share",
            section: "Field"
        },
        kitchen: {
            title: "Kitchen",
            subtitle: "Menu photo to farm sourcing, waste-part uses and a guarded >20-day pantry",
            section: "Kitchen"
        },
        market: {
            title: "Market",
            subtitle: "Verified resources priced in DHN, plus external placement",
            section: "Market"
        },
        projects: {
            title: "Projects",
            subtitle: "Programmes, competing bids and milestone releases",
            section: "Programmes"
        },
        challenges: {
            title: "Challenges",
            subtitle: "Short cultivation windows, claimed and evidenced in the field",
            section: "Field"
        },
        wallet: {
            title: "Wallet",
            subtitle: "Your role, the multisig queue, token backing and the ledger",
            section: "Treasury"
        },
        node: {
            title: "Node & rewards",
            subtitle: "The node that is actually running, the accounts on this device and how DHN is earned",
            section: "Treasury"
        },
        room: {
            title: "Coordination room",
            subtitle: "Encrypted coordination bound to proposals and programmes",
            section: "Rooms"
        },
        landscape: {
            title: "Landscape",
            subtitle: "Seasonal food, materials and the covenants that conserve them",
            section: "Land"
        }
    })
    readonly property var meta: pageMeta[activePage] ? pageMeta[activePage] : pageMeta.overview
    readonly property int pendingCount: state ? Logic.proposalsForRole(state, activeRole, now).length : 0
    readonly property int openChallengeCount: {
        if (!state) return 0;
        var total = 0;
        for (var i = 0; i < state.challenges.length; ++i)
            if (Logic.challengeState(state.challenges[i], now) === "open") total += 1;
        return total;
    }
    readonly property int roomUnread: {
        if (!state) return 0;
        var total = 0;
        for (var i = 0; i < state.channels.length; ++i) total += Number(state.channels[i].unread || 0);
        return total;
    }
    readonly property int fieldTodayCount: {
        if (!state || !state.fieldActivities) return 0;
        var today = Logic.fieldActivitiesOnDay(state, activeRole, Date.now());
        var total = 0;
        for (var i = 0; i < today.length; ++i) if (today[i].status !== "done") total += 1;
        return total;
    }

    Settings {
        id: settings
        category: "dhun-commons"
        property string stateJson: ""
        property string page: "overview"
        property string role: "funder"
        property string person: "person-funder"
        property string room: "room-msig"
    }

    Component.onCompleted: {
        if (restoreState) {
            try {
                var saved = JSON.parse(settings.stateJson);
                if (saved && saved.schema === Seed.SCHEMA && saved.roles && saved.proposals) state = saved;
            } catch (error) {
                state = Seed.build(Date.now());
            }
            if (state.roles[settings.role]) activeRole = settings.role;
            if (personById(settings.person)) activePersonId = settings.person;
            else if (personForRole(activeRole)) activePersonId = personForRole(activeRole).id;
            if (pageOrder.indexOf(settings.page) !== -1) activePage = settings.page;
            if (state.messages[settings.room]) roomChannel = settings.room;
        }
        now = Date.now();
        if (relayHosted) Qt.callLater(app.attachRelayBackend);
    }

    onActivePageChanged: if (persistState) settings.page = activePage
    onActiveRoleChanged: {
        if (persistState) settings.role = activeRole;
        fieldPage.setStudioRole(activeRole);
    }
    onActivePersonIdChanged: if (persistState) settings.person = activePersonId
    onRoomChannelChanged: if (persistState) settings.room = roomChannel

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: app.now = Date.now()
    }

    Timer {
        id: relayAttachTimer
        interval: 600
        repeat: false
        onTriggered: app.attachRelayBackend()
    }

    Timer {
        interval: 5000
        repeat: true
        running: app.relayReady
        onTriggered: app.publishRelaySnapshot()
    }

    Timer {
        interval: 4000
        repeat: true
        running: app.relayReady
        onTriggered: app.pollRelayInbox()
    }

    // A node day is only recorded while the Logos Messaging node reports
    // ready inside Basecamp. Without a node there is nothing to reward.
    Timer {
        interval: 60000
        repeat: true
        running: app.relayHosted && roomPage !== null && roomPage.chatReady
        onTriggered: app.noteNodeDay()
    }

    Connections {
        target: roomPage
        function onChatReadyChanged() {
            if (roomPage.chatReady) app.noteNodeDay();
        }
    }

    Connections {
        target: app.relayHosted ? logos : null
        function onViewModuleReadyChanged(moduleName, isReady) {
            if (moduleName !== "dhun_commons") return;
            app.relayReady = isReady;
            if (isReady) {
                app.publishRelaySnapshot();
                app.pollRelayInbox();
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 3600
        onTriggered: app.toastText = ""
    }

    function showToast(text, tone) {
        toastTone = tone === undefined ? "ok" : tone;
        toastText = text;
        toastTimer.restart();
    }

    function saveState(next) {
        if (persistState) settings.stateJson = JSON.stringify(next);
    }

    function mutate(work) {
        var next = JSON.parse(JSON.stringify(state));
        work(next);
        state = next;
        saveState(next);
        refreshSelection();
    }

    function refreshSelection() {
        if (activeProposal) activeProposal = proposalById(activeProposal.id);
        if (activeProject) activeProject = Logic.findProject(state, activeProject.id);
        if (activeChallenge) activeChallenge = Logic.findChallenge(state, activeChallenge.id);
    }

    function proposalById(id) {
        for (var i = 0; i < state.proposals.length; ++i)
            if (state.proposals[i].id === id) return state.proposals[i];
        return null;
    }

    function nextProposalId(next) {
        var max = 100;
        for (var i = 0; i < next.proposals.length; ++i) {
            var value = parseInt(String(next.proposals[i].id).replace("PROP-", ""), 10);
            if (!isNaN(value) && value > max) max = value;
        }
        return "PROP-" + (max + 1);
    }

    function newMessageId(next) {
        var stamp = Date.now();
        return "MSG-" + stamp + "-" + (next.ledger.length + next.proposals.length + 1);
    }

    function systemMessage(next, roomId, text) {
        if (!next.messages[roomId]) next.messages[roomId] = [];
        next.messages[roomId].push({
            id: newMessageId(next),
            role: "system",
            kind: "system",
            text: text,
            at: Date.now()
        });
    }

    function pushLedger(next, kind, title, detail, amount, from, to, txid, proposalId) {
        var max = 0;
        for (var i = 0; i < next.ledger.length; ++i) {
            var value = parseInt(String(next.ledger[i].id).replace("LED-", ""), 10);
            if (!isNaN(value) && value > max) max = value;
        }
        next.ledger.push({
            id: "LED-" + ("000" + (max + 1)).slice(-3),
            kind: kind,
            title: title,
            detail: detail,
            amount: amount,
            from: from,
            to: to,
            at: Date.now(),
            txid: txid,
            proposalId: proposalId
        });
    }

    function addProposal(next, spec) {
        var id = nextProposalId(next);
        var createdAt = Date.now();
        var expiresAt = spec.expiresAt || (createdAt + 72 * 3600000);
        var proposal = {
            id: id,
            kind: spec.kind,
            title: spec.title,
            summary: spec.summary,
            amount: spec.amount,
            from: spec.from,
            to: spec.to || "",
            target: spec.target,
            room: spec.room || "room-msig",
            status: "pending",
            createdBy: activeRole,
            createdAt: createdAt,
            expiresAt: expiresAt,
            timelock: spec.timelock || 0,
            quorum: next.token.quorum,
            approvals: [],
            rejections: [],
            meta: spec.meta || {}
        };
        if (spec.conservationPct !== undefined) proposal.conservationPct = spec.conservationPct;
        proposal.digest = Logic.digest(proposal);
        proposal.approvals.push({
            role: activeRole,
            at: createdAt,
            sig: Logic.demoSignature(proposal, activeRole)
        });
        next.proposals.push(proposal);
        systemMessage(next, "room-msig",
            "Proposal " + id + " opened by " + next.roles[activeRole].org + " · " +
            proposal.title + " · 1 of " + next.token.quorum + " signatures.");
        return proposal;
    }

    function createProposal(spec) {
        var createdId = "";
        mutate(function (next) {
            createdId = addProposal(next, spec).id;
        });
        now = Date.now();
        activeProposal = proposalById(createdId);
        return createdId;
    }

    function personById(id) {
        if (!state || !state.people) return null;
        for (var i = 0; i < state.people.length; ++i)
            if (state.people[i].id === id) return state.people[i];
        return null;
    }

    function personForRole(roleId) {
        if (!state || !state.people) return null;
        var current = personById(activePersonId);
        if (current && current.role === roleId) return current;
        for (var i = state.people.length - 1; i >= 0; --i)
            if (state.people[i].role === roleId) return state.people[i];
        return null;
    }

    function profileIdForRole(roleId) {
        var person = personForRole(roleId);
        return person ? person.id : "";
    }

    function selectPerson(id) {
        var person = personById(id);
        if (!person) return;
        activePersonId = person.id;
        if (activeRole !== person.role) activeRole = person.role;
        profileOpen = false;
        showToast("Signing as " + person.name + " · " + state.roles[person.role].short);
    }

    function addPerson(spec) {
        var name = String(spec && spec.name ? spec.name : "").trim();
        if (name.length < 2) {
            showToast("Add a name of at least two characters.", "error");
            return null;
        }
        var created = null;
        mutate(function (next) {
            var id = "person-" + Date.now().toString(36);
            var existing = {};
            for (var i = 0; i < next.people.length; ++i) existing[next.people[i].id] = true;
            while (existing[id]) id += "x";
            var person = {
                id: id,
                name: name,
                role: "steward",
                org: "Khejri Mandal · steward",
                place: String(spec.place || "").trim(),
                note: String(spec.note || "").trim(),
                joinedAt: Date.now(),
                seeded: false
            };
            next.people.push(person);
            addReward(next, "steward-onboarding", "steward", id, "profile|" + id,
                name + " joined as a steward");
            systemMessage(next, "room-msig",
                "Steward signup · " + name + " created a profile on this device · steward role only.");
            created = person;
        });
        if (!created) return null;
        activePersonId = created.id;
        if (activeRole !== "steward") activeRole = "steward";
        now = Date.now();
        showToast("Welcome, " + created.name + " · steward profile saved on this device");
        return created;
    }

    function setRole(roleId) {
        if (!state.roles[roleId] || roleId === activeRole) return;
        activeRole = roleId;
        var person = personForRole(roleId);
        if (person) activePersonId = person.id;
        showToast("Signing as " + state.roles[roleId].org);
    }

    function navigate(pageKey) {
        if (pageOrder.indexOf(pageKey) === -1) return;
        activePage = pageKey;
        closeDrawers();
    }

    function goRoom(roomId) {
        closeDrawers();
        activePage = "room";
        selectRoom(roomId);
    }

    function closeDrawers() {
        activeProposal = null;
        activeOffer = null;
        treasuryOpen = false;
        allocateOpen = false;
        activeProject = null;
        activeChallenge = null;
        aboutOpen = false;
        profileOpen = false;
    }

    function closeTop() {
        if (activeProposal) activeProposal = null;
        else if (activeOffer) activeOffer = null;
        else if (treasuryOpen) treasuryOpen = false;
        else if (allocateOpen) allocateOpen = false;
        else if (activeChallenge) activeChallenge = null;
        else if (activeProject) activeProject = null;
        else if (profileOpen) profileOpen = false;
        else if (aboutOpen) aboutOpen = false;
    }

    function openOffer(offer) {
        purchaseInitialQty = 1;
        activeOffer = offer;
    }
    function openProject(project) { activeProject = project; }
    function openChallenge(challenge) { activeChallenge = challenge; }
    function openSale() { treasuryMode = "sale"; treasuryOpen = true; }
    function openMint() { treasuryMode = "mint"; treasuryOpen = true; }
    function openAllocate(projectId) {
        allocateProjectId = projectId || "PRJ-01";
        allocateOpen = true;
    }

    function nextFieldActivityId(next) {
        var max = 0;
        for (var i = 0; i < next.fieldActivities.length; ++i) {
            var value = parseInt(String(next.fieldActivities[i].id).replace("FLD-", ""), 10);
            if (!isNaN(value) && value > max) max = value;
        }
        return "FLD-" + ("000" + (max + 1)).slice(-3);
    }

    function nextRewardId(next) {
        var max = 0;
        for (var i = 0; i < next.rewards.length; ++i) {
            var value = parseInt(String(next.rewards[i].id).replace("RWD-", ""), 10);
            if (!isNaN(value) && value > max) max = value;
        }
        return "RWD-" + ("0000" + (max + 1)).slice(-4);
    }

    function addReward(next, ruleId, roleId, profileId, ref, note) {
        if (!next.rewards) next.rewards = [];
        if (Rewards.hasRef(next, ref)) return null;
        var rule = Rewards.rule(ruleId);
        if (!rule) return null;
        if (!profileId) {
            var fallback = personForRole(roleId);
            profileId = fallback ? fallback.id : "";
        }
        var entry = {
            id: nextRewardId(next),
            rule: rule.id,
            label: rule.label,
            amount: Number(rule.amount),
            role: roleId,
            profileId: profileId,
            ref: ref,
            note: note || "",
            earnedAt: Date.now(),
            status: "earned"
        };
        next.rewards.push(entry);
        return entry;
    }

    function revokeReward(next, ref) {
        if (!next.rewards) return;
        for (var i = 0; i < next.rewards.length; ++i) {
            if (next.rewards[i].ref !== ref) continue;
            if (next.rewards[i].status === "earned") next.rewards[i].status = "cancelled";
        }
    }

    function noteNodeDay() {
        if (!roomPage || !roomPage.chatReady) return;
        var person = activePerson;
        if (!person) return;
        var key = "node|" + Rewards.dateKey(Date.now());
        if (Rewards.hasRef(state, key)) return;
        mutate(function (next) {
            addReward(next, "node-day", person.role, person.id, key,
                "Logos Messaging node ready on " + Rewards.dateKey(Date.now()));
        });
        showToast("Node day logged · " + Rewards.amountFor("node-day") + " DHN queued for " + person.name);
    }

    function fileKitchenPlan(plan) {
        if (!plan || !plan.ok) {
            showToast("Build a valid kitchen plan before filing it.", "error");
            return false;
        }
        var person = activePerson;
        if (!person) return false;
        var key = "kitchen|" + Rewards.dateKey(Date.now());
        if (Rewards.hasRef(state, key)) {
            showToast("A kitchen plan is already filed today.", "error");
            return false;
        }
        mutate(function (next) {
            addReward(next, "kitchen-plan", person.role, person.id, key,
                plan.totals.lines + " sourced lines · " + plan.totals.coverage + "% covered");
        });
        showToast("Kitchen plan filed · " + Rewards.amountFor("kitchen-plan") + " DHN queued");
        return true;
    }

    function proposeRewardPayout(profileId) {
        var person = personById(profileId);
        if (!person) return;
        var list = Rewards.earnedForProfile(state, profileId);
        if (!list.length) {
            showToast(person.name + " has no unclaimed rewards.", "error");
            return;
        }
        var amount = Rewards.total(list);
        var ids = [];
        for (var i = 0; i < list.length; ++i) ids.push(list[i].id);
        var rows = Rewards.byRule(list);
        var parts = [];
        for (var r = 0; r < rows.length; ++r) parts.push(rows[r].label + " ×" + rows[r].count);
        createProposal({
            kind: "reward",
            title: "Pay " + person.name + " · " + amount + " DHN",
            summary: "Earned rewards: " + parts.join(", ") +
                     ". Paid from the treasury to the " + state.roles[person.role].short.toLowerCase() +
                     " wallet. The profile record is local to this device; 2-of-3 signatures are still required.",
            amount: amount,
            from: "vault",
            to: person.role,
            target: "dhun_multisig::reward",
            meta: {
                profileId: person.id,
                profileName: person.name,
                rewardIds: ids,
                rules: rows
            }
        });
        showToast("Reward payout proposed · needs a second signature");
    }

    function fieldUpdateText(activity, next, verb) {
        var org = next.roles[activity.role] ? next.roles[activity.role].org : activity.role;
        var parts = [verb, activity.title, org];
        parts.push(Qt.formatDate(new Date(Number(activity.date)), "d MMM") + " " +
                   Qt.formatTime(new Date(Number(activity.date)), "HH:mm"));
        return "Field calendar · " + parts.join(" · ") + ".";
    }

    function addFieldActivity(spec) {
        if (!spec || String(spec.title || "").trim().length === 0) return null;
        var created = null;
        mutate(function (next) {
            var activity = {
                id: nextFieldActivityId(next),
                role: spec.role || activeRole,
                type: spec.type || "sowing",
                title: String(spec.title).trim(),
                produceId: spec.produceId || "",
                zone: spec.zone || "farms",
                date: Number(spec.date) || Date.now(),
                status: "planned",
                notes: String(spec.notes || ""),
                visibility: spec.visibility || "room",
                source: spec.source || "wallet",
                plot: spec.plot || null,
                media: spec.media || []
            };
            next.fieldActivities.push(activity);
            systemMessage(next, "room-msig", fieldUpdateText(activity, next, "Planned"));
            created = activity;
        });
        if (!created) return null;
        now = Date.now();
        fieldPage.pushActivity(created);
        showToast("Field work added · " + created.title);
        return created;
    }

    function ingestStudioActivity(raw) {
        if (!raw || String(raw.title || "").trim().length === 0) return;
        var normalized = {
            id: String(raw.id || ""),
            role: state.roles[raw.role] ? raw.role : activeRole,
            type: String(raw.type || "sowing"),
            title: String(raw.title).trim(),
            produceId: String(raw.produceId || ""),
            zone: String(raw.zone || "farms"),
            date: Number(raw.date) || Date.now(),
            status: raw.status === "done" ? "done" : "planned",
            notes: String(raw.notes || ""),
            visibility: String(raw.visibility || "room"),
            source: String(raw.source || "studio"),
            plot: raw.plot || null,
            media: raw.media || []
        };
        var mode = "";
        mutate(function (next) {
            var existing = null;
            for (var i = 0; i < next.fieldActivities.length; ++i)
                if (next.fieldActivities[i].id === normalized.id) existing = next.fieldActivities[i];
            if (existing) {
                existing.title = normalized.title;
                existing.type = normalized.type;
                existing.role = normalized.role;
                existing.produceId = normalized.produceId;
                existing.zone = normalized.zone;
                existing.date = normalized.date;
                existing.status = normalized.status;
                existing.notes = normalized.notes;
                existing.visibility = normalized.visibility;
                existing.source = normalized.source;
                existing.plot = normalized.plot;
                existing.media = normalized.media;
                mode = "updated";
                systemMessage(next, "room-msig", fieldUpdateText(normalized, next, "Field note updated"));
            } else {
                normalized.id = normalized.id.length > 0 ? normalized.id : nextFieldActivityId(next);
                next.fieldActivities.push(JSON.parse(JSON.stringify(normalized)));
                mode = "added";
                systemMessage(next, "room-msig", fieldUpdateText(normalized, next, "Marked in the studio"));
            }
        });
        if (mode.length === 0) return;
        now = Date.now();
        showToast(mode === "added" ? "Studio field work added to the wallet calendar" : "Field work updated from the studio");
    }

    function setFieldActivityStatus(id, status) {
        if (!id) return;
        var label = "";
        var wanted = status === "done" ? "done" : "planned";
        var rewardNote = "";
        mutate(function (next) {
            for (var i = 0; i < next.fieldActivities.length; ++i) {
                var activity = next.fieldActivities[i];
                if (activity.id !== id || activity.status === wanted) continue;
                activity.status = wanted;
                activity.completedAt = wanted === "done" ? Date.now() : 0;
                label = activity.title;
                if (wanted === "done") {
                    var earned = addReward(next, "field-task", activity.role, profileIdForRole(activity.role),
                        "field|" + activity.id, activity.title);
                    if (earned) rewardNote = " · " + earned.amount + " DHN queued";
                } else {
                    revokeReward(next, "field|" + activity.id);
                }
                systemMessage(next, "room-msig",
                    "Field calendar · " + (wanted === "done" ? "Completed" : "Reopened") +
                    " · " + activity.title + " · " + (next.roles[activity.role] ? next.roles[activity.role].org : activity.role) + ".");
            }
        });
        if (label.length === 0) return;
        now = Date.now();
        fieldPage.pushStatus(id, wanted);
        showToast((wanted === "done" ? "Marked done · " + label + rewardNote : "Reopened · " + label));
    }

    function openFieldOffer(offer) {
        purchaseInitialQty = 1;
        activeOffer = offer;
    }

    function openStudioOffer(produceId, offerId, qty) {
        var offer = offerId ? Logic.findOffer(state, offerId) : null;
        if (!offer || offer.kind !== "produce") offer = Logic.findProduceOffer(state, produceId);
        if (!offer) {
            showToast("That produce lot is not in the wallet market", "error");
            return;
        }
        purchaseInitialQty = Math.max(1, Math.min(Number(qty) || 1, Number(offer.stock) || 1));
        activeOffer = offer;
        showToast("Wallet lot " + offer.id + " · " + offer.title);
    }

    function ingestFieldUpdate(update) {
        if (!update || !update.id || seenStudioUpdates[update.id]) return;
        seenStudioUpdates[update.id] = true;
        var org = state.roles[update.role] ? state.roles[update.role].org : (update.role || "Field studio");
        var text = "Field clip · " + (update.title || "Field update") + " · " + org +
                   (update.text ? " · " + update.text : "") +
                   " · the clip stays in the field studio.";
        mutate(function (next) {
            if (!next.messages["room-msig"]) next.messages["room-msig"] = [];
            next.messages["room-msig"].push({
                id: "MSG-STUDIO-" + update.id,
                role: "system",
                kind: "field-update",
                text: text,
                at: Number(update.at) || Date.now()
            });
        });
        now = Date.now();
        showToast("Field update posted to the coordination room");
    }

    function fieldOrderFor(next, offer, qty, amount, tx, path) {
        var max = 0;
        for (var i = 0; i < next.fieldOrders.length; ++i) {
            var value = parseInt(String(next.fieldOrders[i].id).replace("ORD-", ""), 10);
            if (!isNaN(value) && value > max) max = value;
        }
        next.fieldOrders.push({
            id: "ORD-" + ("000" + (max + 1)).slice(-3),
            offerId: offer.id,
            produceId: offer.ingredientId || "",
            title: offer.title,
            qty: Number(qty),
            unit: offer.unit,
            amount: Number(amount),
            role: activeRole,
            at: Date.now(),
            txid: tx,
            path: path
        });
    }

    function approveActive() {
        var proposal = proposalById(activeProposal ? activeProposal.id : "");
        if (!proposal) return;
        var value = Logic.proposalState(state, proposal, now);
        if (value !== "pending") {
            showToast("Cannot sign · " + Logic.stateLabel(value).toLowerCase(), "error");
            return;
        }
        if (Logic.approvedBy(proposal, activeRole)) {
            showToast("Your role has already signed this proposal", "error");
            return;
        }
        if (Logic.rejectedBy(proposal, activeRole)) {
            showToast("Your role rejected this proposal", "error");
            return;
        }
        mutate(function (next) {
            var target = null;
            for (var i = 0; i < next.proposals.length; ++i)
                if (next.proposals[i].id === proposal.id) target = next.proposals[i];
            if (!target) return;
            target.approvals.push({
                role: activeRole,
                at: Date.now(),
                sig: Logic.demoSignature(target, activeRole)
            });
            if (target.approvals.length >= target.quorum && !target.readyAt) target.readyAt = Date.now();
            systemMessage(next, "room-msig",
                target.id + " approved by " + next.roles[activeRole].org + " · " +
                target.approvals.length + " of " + target.quorum + " signatures.");
        });
        now = Date.now();
        activeProposal = proposalById(proposal.id);
        showToast("Signature recorded · " + state.roles[activeRole].org);
    }

    function rejectActive() {
        var proposal = proposalById(activeProposal ? activeProposal.id : "");
        if (!proposal) return;
        if (Logic.proposalState(state, proposal, now) !== "pending") {
            showToast("This proposal can no longer be rejected", "error");
            return;
        }
        mutate(function (next) {
            var target = null;
            for (var i = 0; i < next.proposals.length; ++i)
                if (next.proposals[i].id === proposal.id) target = next.proposals[i];
            if (!target) return;
            target.rejections.push({ role: activeRole, at: Date.now() });
            if (target.rejections.length >= target.quorum) target.status = "rejected";
            systemMessage(next, "room-msig",
                target.id + " rejected by " + next.roles[activeRole].org + " · " +
                target.rejections.length + " of " + target.quorum + " rejections.");
        });
        activeProposal = proposalById(proposal.id);
        showToast("Proposal rejected by " + state.roles[activeRole].org, "error");
    }

    function executionProblem(proposal) {
        if (!proposal) return "No proposal selected";
        var value = Logic.proposalState(state, proposal, now);
        if (value !== "ready") return "Not executable · " + Logic.stateLabel(value).toLowerCase();
        var amount = Number(proposal.amount);
        var movesFunds = proposal.kind !== "mint" && proposal.kind !== "award";
        if (movesFunds && Number(state.wallets[proposal.from] || 0) < amount)
            return "Source wallet cannot cover the amount";
        if (proposal.kind === "release") {
            var project = Logic.findProject(state, proposal.meta.projectId);
            var milestone = project ? Logic.findMilestone(project, proposal.meta.milestoneId) : null;
            if (!project || !milestone) return "Linked milestone not found";
            if (milestone.status === "released") return "Milestone is already released";
        }
        if (proposal.kind === "challenge_release") {
            var challenge = Logic.findChallenge(state, proposal.meta.challengeId);
            if (!challenge) return "Linked challenge not found";
            if (challenge.status === "released") return "Challenge is already released";
        }
        if (proposal.kind === "award") {
            var awardProject = Logic.findProject(state, proposal.meta.projectId);
            if (!awardProject || awardProject.status !== "bidding") return "Project is no longer open for award";
        }
        if (proposal.kind === "purchase") {
            var offer = Logic.findOffer(state, proposal.meta.offerId);
            if (!offer) return "Market offer not found";
            if (Number(offer.stock) < Number(proposal.meta.qty || 1)) return "Offer stock no longer covers the order";
        }
        if (proposal.kind === "reward") {
            var rewardIds = proposal.meta.rewardIds || [];
            var remaining = 0;
            for (var r = 0; r < rewardIds.length; ++r)
                for (var q = 0; q < state.rewards.length; ++q)
                    if (state.rewards[q].id === rewardIds[r] && state.rewards[q].status === "earned") remaining += 1;
            if (remaining === 0) return "These reward entries were already paid";
        }
        return "";
    }

    function executeActive() {
        var proposal = proposalById(activeProposal ? activeProposal.id : "");
        var problem = executionProblem(proposal);
        if (problem.length > 0) {
            showToast(problem, "error");
            return;
        }

        var executedTx = "";
        var amount = Number(proposal.amount);
        var studioOrder = null;
        mutate(function (next) {
            var target = null;
            for (var i = 0; i < next.proposals.length; ++i)
                if (next.proposals[i].id === proposal.id) target = next.proposals[i];
            if (!target) return;

            var tx = Logic.txid(target.id + "|" + next.ledger.length + "|" + Date.now());
            executedTx = tx;
            var conservationPct = Logic.conservationPctFor(next, target);
            var conservationAmount = Math.round(amount * conservationPct) / 100;
            var net = amount - conservationAmount;

            if (target.kind === "mint") {
                next.wallets.vault += amount;
                next.token.issued += amount;
                next.token.fiatReserve += Number(target.meta.collateral || amount * next.token.floorINR);
                pushLedger(next, "issue", "Issued " + (target.meta.tranche || "tranche"),
                    "Collateral locked · supply now " + Logic.formatNumber(next.token.issued) + " DHN",
                    amount, "issuance", "vault", tx, target.id);
            } else if (target.kind === "sale") {
                next.wallets.vault -= amount;
                next.wallets.external += amount;
                var proceeds = Number(target.meta.proceeds || 0);
                next.token.fiatRaised += proceeds;
                next.token.fiatReserve += proceeds;
                pushLedger(next, "sale", "External placement",
                    (target.meta.buyer || "External buyer") + " · ₹" + Number(target.meta.price || 0).toFixed(2) + " per DHN",
                    amount, "vault", "external", tx, target.id);
            } else if (target.kind === "fund") {
                var fundProject = Logic.findProject(next, target.meta.projectId);
                if (fundProject) {
                    fundProject.funded = true;
                    fundProject.status = "bidding";
                }
                next.wallets.vault -= amount;
                next.wallets.projectEscrow += amount;
                pushLedger(next, "fund", "Funded " + (fundProject ? fundProject.title : "programme"),
                    "Moved to project escrow · open for bids", amount, "vault", "projectEscrow", tx, target.id);
            } else if (target.kind === "award") {
                var awardProject = Logic.findProject(next, target.meta.projectId);
                if (awardProject) {
                    for (var b = 0; b < awardProject.bids.length; ++b) {
                        awardProject.bids[b].status = awardProject.bids[b].id === target.meta.bidId ? "selected" : "not selected";
                    }
                    var winningBid = Logic.findBid(awardProject, target.meta.bidId);
                    awardProject.awardedTo = winningBid ? winningBid.bidder : "";
                    awardProject.awardedName = winningBid ? winningBid.team : "";
                    awardProject.status = "active";
                    pushLedger(next, "award", "Awarded " + awardProject.title,
                        (winningBid ? winningBid.team : "") + " · " + Logic.formatNumber(amount) + " DHN reserved in escrow",
                        amount, "projectEscrow", awardProject.awardedTo, tx, target.id);
                    systemMessage(next, awardProject.room,
                        awardProject.title + " awarded to " + (winningBid ? winningBid.team : "") + " · " + target.id + " executed.");
                }
            } else if (target.kind === "release") {
                var releaseProject = Logic.findProject(next, target.meta.projectId);
                var milestone = releaseProject ? Logic.findMilestone(releaseProject, target.meta.milestoneId) : null;
                if (releaseProject && milestone) {
                    milestone.status = "released";
                    milestone.releasedAt = Date.now();
                    next.wallets.projectEscrow -= amount;
                    next.wallets[releaseProject.awardedTo] += net;
                    next.wallets.conservation += conservationAmount;
                    var allReleased = true;
                    for (var m = 0; m < releaseProject.milestones.length; ++m)
                        if (releaseProject.milestones[m].status !== "released") allReleased = false;
                    if (allReleased) releaseProject.status = "complete";
                    pushLedger(next, "release", "Released " + milestone.title,
                        releaseProject.id + " · " + Logic.formatNumber(net) + " to " + releaseProject.awardedName +
                        (conservationAmount > 0 ? " · " + Logic.formatNumber(conservationAmount) + " covenant" : ""),
                        amount, "projectEscrow", releaseProject.awardedTo, tx, target.id);
                    systemMessage(next, releaseProject.room,
                        milestone.id + " " + milestone.title + " released · " + Logic.formatNumber(net) + " DHN to " +
                        releaseProject.awardedName + " · tx " + Logic.shortHash(tx) + ".");
                }
            } else if (target.kind === "challenge_release") {
                var releaseChallenge = Logic.findChallenge(next, target.meta.challengeId);
                if (releaseChallenge) {
                    releaseChallenge.status = "released";
                    releaseChallenge.releasedAt = Date.now();
                    next.wallets.challengeEscrow -= amount;
                    next.wallets[releaseChallenge.claimedBy || "dhun"] += net;
                    next.wallets.conservation += conservationAmount;
                    pushLedger(next, "challenge_release", "Challenge bounty paid",
                        releaseChallenge.id + " · " + releaseChallenge.title +
                        (conservationAmount > 0 ? " · " + Logic.formatNumber(conservationAmount) + " covenant" : ""),
                        amount, "challengeEscrow", releaseChallenge.claimedBy, tx, target.id);
                    systemMessage(next, releaseChallenge.room,
                        releaseChallenge.title + " bounty released · " + Logic.formatNumber(net) + " DHN · tx " + Logic.shortHash(tx) + ".");
                }
            } else if (target.kind === "purchase") {
                var purchased = Logic.findOffer(next, target.meta.offerId);
                var qty = Number(target.meta.qty || 1);
                var purchaseCovenant = purchased && purchased.covenant ? Math.round(amount * 0.05) : 0;
                next.wallets[target.from] -= amount;
                next.wallets.suppliers += amount - purchaseCovenant;
                next.wallets.conservation += purchaseCovenant;
                if (purchased) purchased.stock = Math.max(0, Number(purchased.stock) - qty);
                if (purchased && purchased.kind === "produce") {
                    fieldOrderFor(next, purchased, qty, amount, tx, "proposal");
                    studioOrder = { produceId: purchased.ingredientId, offerId: purchased.id, qty: qty };
                }
                pushLedger(next, "purchase", "Purchased " + (purchased ? purchased.title : "resource"),
                    (purchased ? (qty + " × " + purchased.unit + " · " + purchased.supplier) : "Market settlement") +
                    (purchaseCovenant > 0 ? " · " + Logic.formatNumber(purchaseCovenant) + " covenant" : ""),
                    amount, target.from, "suppliers", tx, target.id);
            } else if (target.kind === "reward") {
                next.wallets.vault -= amount;
                next.wallets[target.to] += amount;
                var rewardIds = target.meta.rewardIds || [];
                var paidCount = 0;
                for (var ri = 0; ri < next.rewards.length; ++ri) {
                    for (var rj = 0; rj < rewardIds.length; ++rj) {
                        if (next.rewards[ri].id !== rewardIds[rj] || next.rewards[ri].status !== "earned") continue;
                        next.rewards[ri].status = "paid";
                        next.rewards[ri].paidAt = Date.now();
                        next.rewards[ri].proposalId = target.id;
                        paidCount += 1;
                    }
                }
                pushLedger(next, "reward", "Reward payout",
                    (target.meta.profileName || target.to) + " · " + paidCount + " entries · treasury funded, not minted",
                    amount, "vault", target.to, tx, target.id);
                systemMessage(next, "room-msig",
                    (target.meta.profileName || target.to) + " paid " + Logic.formatNumber(amount) +
                    " DHN in rewards · " + target.id + " executed · tx " + Logic.shortHash(tx) + ".");
            } else if (target.kind === "allocate") {
                var allocateProject = Logic.findProject(next, target.meta.projectId);
                var maxChallenge = 0;
                for (var c = 0; c < next.challenges.length; ++c) {
                    var cn = parseInt(String(next.challenges[c].id).replace("CH-", ""), 10);
                    if (!isNaN(cn) && cn > maxChallenge) maxChallenge = cn;
                }
                next.wallets.vault -= amount;
                next.wallets.challengeEscrow += amount;
                next.challenges.push({
                    id: "CH-" + ("00" + (maxChallenge + 1)).slice(-2),
                    code: (allocateProject ? allocateProject.code.split(" ")[0] : "FIELD") + " / NEW",
                    title: target.meta.title,
                    summary: target.meta.summary,
                    projectId: target.meta.projectId,
                    zone: target.meta.zone,
                    bounty: amount,
                    conservationPct: allocateProject ? allocateProject.conservationPct : 5,
                    windowEnd: Date.now() + Number(target.meta.windowHours || 72) * 3600000,
                    evidenceSpec: target.meta.evidenceSpec,
                    status: "open",
                    claimedBy: "",
                    claimedName: "",
                    claimedAt: 0,
                    evidence: "",
                    createdBy: target.createdBy,
                    room: allocateProject ? allocateProject.room : "room-msig"
                });
                pushLedger(next, "allocate", "Opened challenge",
                    target.meta.title + " · " + target.meta.zone + " · " + target.meta.windowHours + "h window",
                    amount, "vault", "challengeEscrow", tx, target.id);
                if (allocateProject) {
                    systemMessage(next, allocateProject.room,
                        "New challenge · " + target.meta.title + " · " + Logic.formatNumber(amount) +
                        " DHN · closes in " + target.meta.windowHours + "h.");
                }
            }

            target.status = "executed";
            target.executedAt = Date.now();
            target.txid = tx;
            systemMessage(next, "room-msig",
                target.id + " executed · " + Logic.formatNumber(amount) + " DHN · tx " + Logic.shortHash(tx) + ".");
        });

        now = Date.now();
        activeProposal = proposalById(proposal.id);
        if (studioOrder) {
            fieldPage.recordOrder(studioOrder.produceId, studioOrder.qty, executedTx, studioOrder.offerId);
            fieldPage.refreshStudio();
        }
        showToast("Executed · tx " + Logic.shortHash(executedTx));
    }

    function confirmPurchase(offer, qty) {
        if (!offer) return;
        var amount = Number(offer.price) * Number(qty);
        if (Number(qty) > Number(offer.stock)) {
            showToast("Quantity exceeds stock", "error");
            return;
        }
        if (amount > Number(state.wallets[activeRole])) {
            showToast("Operating wallet cannot cover this purchase", "error");
            return;
        }
        var roleAllowance = state.roles[activeRole] && state.roles[activeRole].allowance !== undefined
                ? Number(state.roles[activeRole].allowance) : Number(state.token.allowance);
        if (activeRole !== "funder" && amount <= roleAllowance) {
            var tx = "";
            var covenant = offer.covenant ? Math.round(amount * 0.05) : 0;
            var fieldOrder = null;
            mutate(function (next) {
                var target = Logic.findOffer(next, offer.id);
                next.wallets[activeRole] -= amount;
                next.wallets.suppliers += amount - covenant;
                next.wallets.conservation += covenant;
                if (target) target.stock = Math.max(0, Number(target.stock) - Number(qty));
                tx = Logic.txid("allowance|" + offer.id + "|" + qty + "|" + Date.now());
                if (target && target.kind === "produce") {
                    fieldOrderFor(next, target, qty, amount, tx, "allowance");
                    fieldOrder = { produceId: target.ingredientId, offerId: target.id, qty: Number(qty) };
                }
                pushLedger(next, "purchase", "Purchased " + offer.title,
                    qty + " × " + offer.unit + " · allowance payment · " + offer.supplier +
                    (covenant > 0 ? " · " + Logic.formatNumber(covenant) + " covenant" : ""),
                    amount, activeRole, "suppliers", tx, "");
                systemMessage(next, "room-msig",
                    "Allowance purchase · " + offer.title + " · " + Logic.formatDHN(amount) + " paid by " +
                    next.roles[activeRole].org + " · tx " + Logic.shortHash(tx) + ".");
            });
            activeOffer = null;
            if (fieldOrder) {
                fieldPage.recordOrder(fieldOrder.produceId, fieldOrder.qty, tx, fieldOrder.offerId);
                fieldPage.refreshStudio();
            }
            showToast("Paid " + Logic.formatDHN(amount) + " within allowance");
        } else {
            activeOffer = null;
            createProposal({
                kind: "purchase",
                title: "Buy " + offer.title,
                summary: Number(qty) + " × " + offer.unit + " from " + offer.supplier +
                         ". Above the " + roleAllowance + " DHN single-signer allowance." +
                         (offer.covenant ? " Covenant supplier: 5% is routed to the habitat reserve." : ""),
                amount: amount,
                from: activeRole,
                to: "suppliers",
                target: "dhun_commons.market::purchase",
                meta: { offerId: offer.id, qty: Number(qty) }
            });
            showToast("Purchase proposed · needs a second signature");
        }
    }

    function proposeSale(buyer, amount, price) {
        if (amount <= 0 || amount > Number(state.wallets.vault)) {
            showToast("Vault cannot cover that placement", "error");
            return;
        }
        if (price < Number(state.token.floorINR)) {
            showToast("Price is below the ₹" + state.token.floorINR + " floor", "error");
            return;
        }
        treasuryOpen = false;
        createProposal({
            kind: "sale",
            title: "Sell " + Logic.formatNumber(amount) + " DHN externally",
            summary: "Place a tranche with " + buyer + " at ₹" + Number(price).toFixed(2) +
                     ". Proceeds go to the settlement reserve.",
            amount: amount,
            from: "vault",
            to: "external",
            target: "dhun_multisig::external_sale",
            meta: { buyer: buyer, price: price, proceeds: Math.round(amount * price) }
        });
        showToast("External sale proposed · 2-of-3 required");
    }

    function proposeMint(amount, collateral, purpose) {
        if (amount <= 0 || collateral < amount * Number(state.token.floorINR)) {
            showToast("Collateral must cover the floor backing", "error");
            return;
        }
        treasuryOpen = false;
        createProposal({
            kind: "mint",
            title: "Issue tranche · " + Logic.formatNumber(amount) + " DHN",
            summary: purpose,
            amount: amount,
            from: "funder",
            to: "vault",
            target: "dhun_multisig::mint",
            meta: {
                tranche: "Tranche " + String.fromCharCode(65 + Math.min(25, Math.floor(state.token.issued / 50000))) + " · " + new Date().getFullYear(),
                collateral: collateral,
                purpose: purpose
            }
        });
        showToast("Issuance proposed · collateral noted · 2-of-3 required");
    }

    function proposeAllocation(title, summary, zone, bounty, hours, evidenceSpec, projectId) {
        if (bounty <= 0 || bounty > Logic.unallocatedChallengePool(state)) {
            showToast("Bounty exceeds the free challenge pool", "error");
            return;
        }
        allocateOpen = false;
        var project = Logic.findProject(state, projectId);
        createProposal({
            kind: "allocate",
            title: "Allocate challenge · " + title,
            summary: summary,
            amount: bounty,
            from: "vault",
            to: "challengeEscrow",
            target: "dhun_commons.challenge::allocate",
            room: project ? project.room : "room-msig",
            meta: {
                title: title,
                summary: summary,
                zone: zone,
                windowHours: hours,
                evidenceSpec: evidenceSpec,
                projectId: projectId
            }
        });
        showToast("Challenge proposed · execution reserves the bounty");
    }

    function claimChallenge(challenge) {
        if (!challenge) return;
        if (activeRole === "funder") {
            showToast("Field windows are claimed by Dhun and stewards", "error");
            return;
        }
        if (Logic.challengeState(challenge, now) !== "open") {
            showToast("This window is no longer open", "error");
            return;
        }
        mutate(function (next) {
            var target = Logic.findChallenge(next, challenge.id);
            if (!target) return;
            target.claimedBy = activeRole;
            target.claimedName = next.roles[activeRole].org;
            target.claimedAt = Date.now();
            systemMessage(next, target.room,
                target.title + " claimed by " + next.roles[activeRole].org +
                " · evidence due " + Logic.countdown(target.windowEnd, Date.now()) + ".");
        });
        activeChallenge = Logic.findChallenge(state, challenge.id);
        showToast("Window claimed · evidence due before expiry");
    }

    function submitChallengeEvidence(challenge, text) {
        if (!challenge || text.length < 10) return;
        mutate(function (next) {
            var target = Logic.findChallenge(next, challenge.id);
            if (!target) return;
            target.evidence = text;
            addReward(next, "challenge-evidence", activeRole, activePersonId,
                "challenge|" + target.id, target.title);
            systemMessage(next, target.room,
                target.title + " evidence filed by " + next.roles[activeRole].org + " · release now needs 2 signatures.");
        });
        activeChallenge = Logic.findChallenge(state, challenge.id);
        showToast("Evidence filed · " + Rewards.amountFor("challenge-evidence") + " DHN queued · propose the release next");
    }

    function proposeChallengeRelease(challenge) {
        if (!challenge) return;
        for (var i = 0; i < state.proposals.length; ++i) {
            var existing = state.proposals[i];
            if (existing.kind === "challenge_release" && existing.meta.challengeId === challenge.id &&
                Logic.isOpen(existing, state, now)) {
                activeProposal = existing;
                showToast("A release proposal is already open");
                return;
            }
        }
        createProposal({
            kind: "challenge_release",
            title: "Release challenge · " + challenge.title,
            summary: "Evidence accepted for " + challenge.id + ". Pay the bounty and route the conservation covenant.",
            amount: Number(challenge.bounty),
            from: "challengeEscrow",
            to: challenge.claimedBy,
            target: "dhun_commons.challenge::release",
            room: challenge.room,
            conservationPct: challenge.conservationPct,
            meta: { challengeId: challenge.id }
        });
        showToast("Challenge release proposed · 2-of-3 required");
    }

    function proposeMilestoneRelease(project, milestone) {
        if (!project || !milestone) return;
        for (var i = 0; i < state.proposals.length; ++i) {
            var existing = state.proposals[i];
            if (existing.kind === "release" && existing.meta.milestoneId === milestone.id &&
                existing.meta.projectId === project.id && Logic.isOpen(existing, state, now)) {
                activeProposal = existing;
                showToast("A release proposal for this milestone is already open");
                return;
            }
        }
        createProposal({
            kind: "release",
            title: "Release " + project.code.split(" ")[0].toLowerCase() + " milestone " + milestone.id,
            summary: milestone.title + ". Evidence accepted; the conservation covenant is paid with the release.",
            amount: Number(milestone.amount),
            from: "projectEscrow",
            to: project.awardedTo,
            target: "dhun_multisig::release",
            room: project.room,
            conservationPct: project.conservationPct,
            meta: { projectId: project.id, milestoneId: milestone.id }
        });
        showToast("Milestone release proposed · 2-of-3 required");
    }

    function submitMilestoneEvidence(project, milestone, text) {
        if (!project || !milestone || text.length < 10) return;
        mutate(function (next) {
            var targetProject = Logic.findProject(next, project.id);
            var targetMilestone = Logic.findMilestone(targetProject, milestone.id);
            if (!targetMilestone) return;
            targetMilestone.status = "evidence";
            targetMilestone.evidence = text;
            targetMilestone.submittedAt = Date.now();
            systemMessage(next, targetProject.room,
                targetProject.id + " " + targetMilestone.id + " evidence filed by " + next.roles[activeRole].org +
                " · " + Logic.formatNumber(targetMilestone.amount) + " DHN awaiting a release proposal.");
        });
        activeProject = Logic.findProject(state, project.id);
        showToast("Evidence filed · release is now available");
    }

    function awardBid(project, bid) {
        if (!project || !bid) return;
        if (project.status !== "bidding") {
            showToast("This programme is no longer open for award", "error");
            return;
        }
        activeProject = null;
        createProposal({
            kind: "award",
            title: "Award " + project.code.split(" ")[0].toLowerCase() + " to " + bid.team,
            summary: Logic.formatNumber(bid.amount) + " DHN over " + bid.days + " days. " + bid.plan,
            amount: Number(bid.amount),
            from: "projectEscrow",
            to: bid.bidder,
            target: "dhun_multisig::award",
            room: project.room,
            conservationPct: project.conservationPct,
            meta: { projectId: project.id, bidId: bid.id }
        });
        showToast("Award proposed · 2-of-3 required");
    }

    function submitBid(project, amount, days, plan) {
        if (!project || amount <= 0 || days <= 0 || plan.length < 10) return;
        mutate(function (next) {
            var target = Logic.findProject(next, project.id);
            if (!target) return;
            var max = 200;
            for (var i = 0; i < target.bids.length; ++i) {
                var value = parseInt(String(target.bids[i].id).replace("BID-", ""), 10);
                if (!isNaN(value) && value > max) max = value;
            }
            target.bids.push({
                id: "BID-" + (max + 1),
                bidder: activeRole,
                team: next.roles[activeRole].org,
                amount: amount,
                days: days,
                plan: plan,
                reputation: next.roles[activeRole].reputation,
                score: 80 + Math.round((next.roles[activeRole].reputation - 80) * 0.5),
                status: "open"
            });
            systemMessage(next, target.room,
                next.roles[activeRole].org + " submitted a competing bid · " + Logic.formatNumber(amount) +
                " DHN · " + days + " days.");
        });
        activeProject = Logic.findProject(state, project.id);
        showToast("Bid submitted · the award is still a multisig decision");
    }

    function fundProject(project) {
        if (!project || project.funded) return;
        if (Number(state.wallets.vault) < Number(project.budget)) {
            showToast("Vault cannot cover the programme budget", "error");
            return;
        }
        createProposal({
            kind: "fund",
            title: "Fund " + project.title,
            summary: "Move the programme budget into project escrow and open it for bids.",
            amount: Number(project.budget),
            from: "vault",
            to: "projectEscrow",
            target: "dhun_multisig::fund",
            room: project.room,
            conservationPct: project.conservationPct,
            meta: { projectId: project.id }
        });
        showToast("Funding proposed · 2-of-3 required");
    }

    function selectRoom(channelId) {
        if (!state.messages[channelId]) return;
        roomChannel = channelId;
        mutate(function (next) {
            for (var i = 0; i < next.channels.length; ++i)
                if (next.channels[i].id === channelId) next.channels[i].unread = 0;
        });
    }

    function sendMessage(text) {
        var value = String(text).trim();
        if (value.length === 0) return;
        mutate(function (next) {
            if (!next.messages[roomChannel]) next.messages[roomChannel] = [];
            next.messages[roomChannel].push({
                id: newMessageId(next),
                role: activeRole,
                kind: "text",
                text: value,
                at: Date.now()
            });
        });
    }

    function appendLogosMessage(sender, text) {
        var value = String(text);
        if (value.length === 0) return;
        var who = String(sender || "");
        var label = who.length > 22
                  ? who.substring(0, 12) + "…" + who.substring(who.length - 6)
                  : (who.length ? who : "unknown sender");
        mutate(function (next) {
            systemMessage(next, "room-msig", "Logos Messaging · " + label + ": " + value);
            if (roomChannel !== "room-msig") {
                for (var i = 0; i < next.channels.length; ++i)
                    if (next.channels[i].id === "room-msig")
                        next.channels[i].unread = (next.channels[i].unread || 0) + 1;
            }
        });
        showToast("Message received over Logos delivery");
    }

    function relayParse(value) {
        if (value === null || value === undefined) return null;
        if (typeof value === "object") return value;
        try { return JSON.parse(String(value)); } catch (error) { return null; }
    }

    function attachRelayBackend() {
        if (!relayHosted) return;
        if (!relayBackend) {
            try { relayBackend = logos.module("dhun_commons"); }
            catch (error) { relayBackend = null; }
        }
        if (!relayBackend) {
            relayAttachTimer.restart();
            return;
        }
        try { relayReady = logos.isViewModuleReady("dhun_commons"); }
        catch (error) { relayReady = false; }
        if (relayReady) {
            publishRelaySnapshot();
            pollRelayInbox();
        } else {
            relayAttachTimer.restart();
        }
    }

    function relaySnapshot() {
        var pending = [];
        try {
            var queue = Logic.pendingProposals(state, now);
            for (var i = 0; i < queue.length; ++i) {
                var proposal = queue[i];
                pending.push({
                    id: proposal.id,
                    title: proposal.title,
                    amount: proposal.amount,
                    status: Logic.proposalState(state, proposal, now),
                    approvals: proposal.approvals ? proposal.approvals.length : 0,
                    quorum: proposal.quorum,
                    room: proposal.room,
                    createdAt: proposal.createdAt,
                    expiresAt: proposal.expiresAt
                });
            }
        } catch (error) { pending = []; }

        var offers = [];
        try {
            for (var j = 0; j < state.offers.length && j < 24; ++j) {
                var offer = state.offers[j];
                offers.push({
                    id: offer.id, title: offer.title, supplier: offer.supplier,
                    price: offer.price, unit: offer.unit, stock: offer.stock,
                    season: offer.season, zone: offer.zone
                });
            }
        } catch (error) { offers = []; }

        var activities = [];
        try {
            var today = Logic.fieldActivitiesOnDay(state, activeRole, now);
            for (var k = 0; k < today.length; ++k) {
                activities.push({
                    id: today[k].id, title: today[k].title, status: today[k].status,
                    type: today[k].type, at: today[k].date, zone: today[k].zone
                });
            }
        } catch (error) { activities = []; }

        var messages = [];
        var thread = state.messages["room-msig"] || [];
        for (var m = Math.max(0, thread.length - 8); m < thread.length; ++m) {
            messages.push({ role: thread[m].role, text: thread[m].text, at: thread[m].at });
        }

        var accounts = [];
        var lastTx = ({});
        var chain = ({ status: "uninitialized", height: 0, network: "", sequencer: "", accounts: [], lastTx: ({}) });
        if (relayBackend) {
            try { accounts = JSON.parse(relayBackend.chainAccounts || "[]"); } catch (error) { accounts = []; }
            try { lastTx = JSON.parse(relayBackend.chainLastTx || "{}"); } catch (error) { lastTx = ({}); }
            chain = {
                status: relayBackend.chainStatus,
                height: relayBackend.chainHeight,
                network: relayBackend.chainNetwork,
                sequencer: relayBackend.chainSequencer,
                accounts: accounts,
                lastTx: lastTx
            };
        }

        return {
            app: "dhun_commons",
            version: "0.4.2",
            page: activePage,
            role: activeRole,
            room: "room-msig",
            proposals: pending,
            offers: offers,
            activities: activities,
            messages: messages,
            chain: chain,
            queued: relayInbox.length
        };
    }

    function publishRelaySnapshot() {
        if (!relayBackend || !relayReady || relayBusy) return;
        relayBusy = true;
        logos.watch(relayBackend.publishTelegramState(JSON.stringify(relaySnapshot())), function (value) {
            app.relayBusy = false;
            var parsed = app.relayParse(value);
            if (parsed && parsed.success) {
                app.relayPublishedAt = Date.now();
                app.relayNotice = "";
            } else {
                app.relayNotice = parsed && parsed.error ? parsed.error : "The relay snapshot was not written.";
            }
        }, function (error) {
            app.relayBusy = false;
            app.relayNotice = "The relay snapshot was not written.";
        });
    }

    function pollRelayInbox() {
        if (!relayBackend || !relayReady) return;
        logos.watch(relayBackend.telegramInbox(), function (value) {
            var parsed = app.relayParse(value);
            if (!parsed || !parsed.success) return;
            app.relayBridge = parsed.bridge && typeof parsed.bridge === "object" ? parsed.bridge : ({});
            var list = Array.isArray(parsed.messages) ? parsed.messages : [];
            var fresh = 0;
            for (var i = 0; i < list.length; ++i) {
                var id = String(list[i].id || "");
                if (id.length && !app.relaySeen[id]) {
                    app.relaySeen[id] = true;
                    fresh += 1;
                }
            }
            app.relayInbox = list;
            if (fresh > 0)
                app.showToast("Telegram · " + fresh + (fresh === 1 ? " message queued" : " messages queued"));
        }, function (error) {});
    }

    function relayAck(id) {
        var key = String(id || "");
        var next = [];
        for (var i = 0; i < relayInbox.length; ++i)
            if (String(relayInbox[i].id) !== key) next.push(relayInbox[i]);
        relayInbox = next;
        if (!relayBackend || !relayReady) return;
        logos.watch(relayBackend.ackTelegramMessage(key), function () {}, function () {});
    }

    function relayPost(id) {
        var key = String(id || "");
        var entry = null;
        for (var i = 0; i < relayInbox.length; ++i)
            if (String(relayInbox[i].id) === key) entry = relayInbox[i];
        if (!entry) return false;
        var text = String(entry.text || "");
        var who = String(entry.author || "Telegram");
        mutate(function (next) {
            systemMessage(next, "room-msig", "Telegram · " + who + ": " + text);
            if (roomChannel !== "room-msig") {
                for (var i = 0; i < next.channels.length; ++i)
                    if (next.channels[i].id === "room-msig")
                        next.channels[i].unread = (next.channels[i].unread || 0) + 1;
            }
        });
        if (roomPage && typeof roomPage.mirrorToLogos === "function")
            roomPage.mirrorToLogos("Telegram · " + who + ": " + text);
        relayAck(key);
        showToast("Telegram message posted to the room");
        return true;
    }

    function relayDismiss(id) {
        relayAck(String(id || ""));
        showToast("Telegram message dismissed");
    }

    function resetRehearsal() {
        state = Seed.build(Date.now());
        now = Date.now();
        activeProposal = null;
        activeOffer = null;
        treasuryOpen = false;
        allocateOpen = false;
        activeProject = null;
        activeChallenge = null;
        aboutOpen = false;
        profileOpen = false;
        purchaseInitialQty = 1;
        seenStudioUpdates = ({});
        activePersonId = "person-funder";
        activeRole = "funder";
        fieldPage.resetStudio();
        roomChannel = "room-msig";
        if (persistState) settings.stateJson = "";
        showToast("Rehearsal state reset · seeded balances restored");
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.paper
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth
            currentPage: app.activePage
            activeRole: app.activeRole
            activePerson: app.activePerson
            profileCount: app.profileCount
            pendingRewards: app.pendingRewardCount
            pendingCount: app.pendingCount
            openChallengeCount: app.openChallengeCount
            fieldTodayCount: app.fieldTodayCount
            roomUnread: app.roomUnread
            vaultBalance: app.state.wallets.vault
            walletBalance: app.state.wallets[app.activeRole]
            onNavigate: function (page) { app.navigate(page) }
            onOpenAbout: app.aboutOpen = true
            onOpenProfile: app.profileOpen = true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TopBar {
                Layout.fillWidth: true
                title: app.meta.title
                subtitle: app.meta.subtitle
                section: app.meta.section
                activeRole: app.activeRole
                activePerson: app.activePerson
                walletBalance: app.state.wallets[app.activeRole]
                pendingCount: app.pendingCount
                onRoleSelected: function (role) { app.setRole(role) }
                onProfileRequested: app.profileOpen = true
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: app.pageOrder.indexOf(app.activePage)

                Overview {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    activePerson: app.activePerson
                    catalog: app.catalog
                    profileCount: app.profileCount
                    stewardProfileCount: app.stewardProfileCount
                    pendingRewardCount: app.pendingRewardCount
                    nodeReady: roomPage.chatReady
                    nodeState: roomPage.chatState
                    onOpenProposal: function (proposal) { app.activeProposal = proposal }
                    onOpenOffer: function (offer) { app.openOffer(offer) }
                    onOpenChallenge: function (challenge) { app.openChallenge(challenge) }
                    onOpenProject: function (project) { app.openProject(project) }
                    onNavigate: function (page) { app.navigate(page) }
                    onJoinAsSteward: app.profileOpen = true
                }

                FieldMap {
                    id: fieldPage
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    webEnabled: app.webStudioEnabled
                    hostOverlay: app.overlayOpen
                    onPurchase: function (offer) { app.openFieldOffer(offer) }
                    onAddActivity: function (spec) { app.addFieldActivity(spec) }
                    onSetActivityStatus: function (id, status) { app.setFieldActivityStatus(id, status) }
                    onStudioRole: function (role) { app.setRole(role) }
                    onStudioActivity: function (activity) { app.ingestStudioActivity(activity) }
                    onStudioStatus: function (id, status) { app.setFieldActivityStatus(id, status) }
                    onStudioOffer: function (produceId, offerId, qty) { app.openStudioOffer(produceId, offerId, qty) }
                    onStudioUpdate: function (update) { app.ingestFieldUpdate(update) }
                    onStudioReady: function (info) { app.now = Date.now() }
                    onToast: function (text, tone) { app.showToast(text, tone) }
                }

                Kitchen {
                    host: app
                    app: app.state
                }

                Market {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    onPurchase: function (offer) { app.openOffer(offer) }
                    onOpenSale: app.openSale()
                    onOpenMint: app.openMint()
                    onOpenProposal: function (proposal) { app.activeProposal = proposal }
                }

                Projects {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    onOpenProject: function (project) { app.openProject(project) }
                    onAwardBid: function (project, bid) { app.awardBid(project, bid) }
                }

                Challenges {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    onOpenChallenge: function (challenge) { app.openChallenge(challenge) }
                    onAllocate: app.openAllocate("PRJ-01")
                    onOpenProposal: function (proposal) { app.activeProposal = proposal }
                }

                Wallet {
                    id: walletPage
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    onOpenProposal: function (proposal) { app.activeProposal = proposal }
                    onOpenSale: app.openSale()
                    onOpenMint: app.openMint()
                    onAllocate: app.openAllocate("PRJ-01")
                    onNavigate: function (page) { app.navigate(page) }
                }

                Node {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    activePerson: app.activePerson
                    catalog: app.catalog
                    profileCount: app.profileCount
                    stewardProfileCount: app.stewardProfileCount
                    pendingRewardCount: app.pendingRewardCount
                    nodeHosted: roomPage.logosHosted
                    nodeReady: roomPage.chatReady
                    nodeState: roomPage.chatState
                    nodeDelivery: roomPage.chatDelivery
                    nodeAddress: roomPage.chatAddress
                    nodeError: roomPage.chatError
                    nodeLine: roomPage.chatLine
                    nodePeers: roomPage.chatPeers
                    nodeInbound: roomPage.chatInbound
                    nodeMirrored: roomPage.chatMirrored
                    nodeConvos: roomPage.chatConvos
                    chainHosted: walletPage.chainHosted
                    chainReady: walletPage.chainReady
                    chainStatus: walletPage.chainStatus
                    chainHeight: walletPage.chainHeight
                    chainNetwork: walletPage.chainNetwork
                    chainSequencer: walletPage.chainSequencer
                    chainAccounts: walletPage.chainAccounts
                    onNavigate: function (pageKey) { app.navigate(pageKey) }
                    onOpenProfile: app.profileOpen = true
                    onProposePayout: function (profileId) { app.proposeRewardPayout(profileId) }
                }

                Room {
                    id: roomPage
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    activeChannel: app.roomChannel
                    relayReady: app.relayReady
                    relayInbox: app.relayInbox
                    relayBridge: app.relayBridge
                    relayPublishedAt: app.relayPublishedAt
                    relayNotice: app.relayNotice
                    onSelectChannel: function (channelId) { app.selectRoom(channelId) }
                    onSendMessage: function (text) { app.sendMessage(text) }
                    onLogosMessage: function (sender, text) { app.appendLogosMessage(sender, text) }
                    onOpenProposal: function (proposal) { app.activeProposal = proposal }
                    onRelayPost: function (id) { app.relayPost(id) }
                    onRelayDismiss: function (id) { app.relayDismiss(id) }
                    onRelayPublish: app.publishRelaySnapshot()
                }

                Landscape {
                    app: app.state
                    now: app.now
                    activeRole: app.activeRole
                    onNavigate: function (page) { app.navigate(page) }
                    onOpenProject: function (project) { app.openProject(project) }
                }
            }
        }
    }

    ProjectDrawer {
        id: projectDrawer
        anchors.fill: parent
        z: 110
        app: app.state
        project: app.activeProject
        now: app.now
        activeRole: app.activeRole
        onClose: app.activeProject = null
        onProposeRelease: function (project, milestone) { app.proposeMilestoneRelease(project, milestone) }
        onSubmitEvidence: function (project, milestone, text) { app.submitMilestoneEvidence(project, milestone, text) }
        onAwardBid: function (project, bid) { app.awardBid(project, bid) }
        onSubmitBid: function (project, amount, days, plan) { app.submitBid(project, amount, days, plan) }
        onFundProject: function (project) { app.fundProject(project) }
        onOpenProposal: function (proposal) { app.activeProposal = proposal }
    }

    ChallengeDrawer {
        id: challengeDrawer
        anchors.fill: parent
        z: 110
        app: app.state
        challenge: app.activeChallenge
        now: app.now
        activeRole: app.activeRole
        onClose: app.activeChallenge = null
        onClaim: function (challenge) { app.claimChallenge(challenge) }
        onSubmitEvidence: function (challenge, text) { app.submitChallengeEvidence(challenge, text) }
        onProposeRelease: function (challenge) { app.proposeChallengeRelease(challenge) }
        onOpenProposal: function (proposal) { app.activeProposal = proposal }
    }

    PurchaseDrawer {
        id: purchaseDrawer
        anchors.fill: parent
        z: 120
        app: app.state
        offer: app.activeOffer
        now: app.now
        activeRole: app.activeRole
        initialQty: app.purchaseInitialQty
        onClose: app.activeOffer = null
        onConfirm: app.confirmPurchase(app.activeOffer, purchaseDrawer.qty)
    }

    TreasuryDrawer {
        id: treasuryDrawer
        anchors.fill: parent
        z: 120
        app: app.state
        open: app.treasuryOpen
        mode: app.treasuryMode
        now: app.now
        onClose: app.treasuryOpen = false
        onProposeSale: function (buyer, amount, price) { app.proposeSale(buyer, amount, price) }
        onProposeMint: function (amount, collateral, purpose) { app.proposeMint(amount, collateral, purpose) }
    }

    AllocateDrawer {
        id: allocateDrawer
        anchors.fill: parent
        z: 120
        app: app.state
        now: app.now
        activeRole: app.activeRole
        open: app.allocateOpen
        projectId: app.allocateProjectId
        onClose: app.allocateOpen = false
        onPropose: function (title, summary, zone, bounty, hours, evidenceSpec, projectId) {
            app.proposeAllocation(title, summary, zone, bounty, hours, evidenceSpec, projectId);
        }
    }

    ProposalDrawer {
        id: proposalDrawer
        anchors.fill: parent
        z: 130
        app: app.state
        proposal: app.activeProposal
        now: app.now
        activeRole: app.activeRole
        onClose: app.activeProposal = null
        onApprove: app.approveActive()
        onReject: app.rejectActive()
        onExecute: app.executeActive()
        onOpenRoom: function (roomId) { app.goRoom(roomId) }
    }

    ProfileDrawer {
        id: profileDrawer
        anchors.fill: parent
        z: 135
        app: app.state
        open: app.profileOpen
        activePersonId: app.activePersonId
        onClose: app.profileOpen = false
        onCreateProfile: function (name, place, note) {
            if (app.addPerson({ name: name, place: place, note: note })) app.profileOpen = false;
        }
        onSelectProfile: function (id) { app.selectPerson(id) }
        onOpenRewards: {
            app.profileOpen = false;
            app.navigate("node");
        }
    }

    AboutDrawer {
        anchors.fill: parent
        z: 140
        app: app.state
        open: app.aboutOpen
        onClose: app.aboutOpen = false
        onReset: app.resetRehearsal()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: app.closeTop()
    }

    Rectangle {
        id: toast
        z: 200
        visible: app.toastText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 92
        width: Math.min(560, toastRow.implicitWidth + 36)
        height: 42
        radius: 21
        color: app.toastTone === "error" ? "#8F452A" : "#173023"
        border.width: 1
        border.color: app.toastTone === "error" ? "#A95C3D" : "#33513A"

        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 16
                height: 16
                radius: 8
                color: app.toastTone === "error" ? "#A95C3D" : Theme.limeDeep

                Icon {
                    anchors.centerIn: parent
                    name: app.toastTone === "error" ? "close" : "check"
                    color: app.toastTone === "error" ? "#FBEDE6" : Theme.forest
                    width: 8
                    height: 8
                    strokeWidth: 2
                }
            }

            Text {
                text: app.toastText
                color: "#F4F7E9"
                font.family: Theme.uiFont
                font.pixelSize: 9
                font.weight: Font.Medium
            }
        }
    }
}
