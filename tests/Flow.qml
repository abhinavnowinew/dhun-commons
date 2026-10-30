import QtQuick
import QtQuick.Window
import "../qml/kitchen.js" as Kitchen
import "../qml/assistant.js" as Assistant
import "../qml/agro.js" as Agro
import "../qml/civic.js" as Civic

Window {
    id: win
    width: 1440
    height: 900
    visible: true

    property int checks: 0
    property int failures: 0

    Loader {
        id: loader
        anchors.fill: parent
        asynchronous: false
        source: "../qml/Main.qml"

        onLoaded: {
            item.width = win.width;
            item.height = win.height;
            item.restoreState = false;
            item.persistState = false;
            item.webStudioEnabled = false;
            runTimer.start();
        }
    }

    function check(label, condition, detail) {
        win.checks += 1;
        if (condition) {
            console.log("PASS  " + label);
        } else {
            win.failures += 1;
            console.log("FAIL  " + label + (detail !== undefined ? "  [" + detail + "]" : ""));
        }
    }

    function walletSum(app) {
        var total = 0;
        var keys = Object.keys(app.state.wallets);
        for (var i = 0; i < keys.length; ++i) total += Number(app.state.wallets[keys[i]]);
        return total;
    }

    function proposal(app, id) {
        return app.proposalById(id);
    }

    function fieldActivity(app, id) {
        for (var i = 0; i < app.state.fieldActivities.length; ++i)
            if (app.state.fieldActivities[i].id === id) return app.state.fieldActivities[i];
        return null;
    }

    function offerById(app, id) {
        for (var i = 0; i < app.state.offers.length; ++i)
            if (app.state.offers[i].id === id) return app.state.offers[i];
        return null;
    }

    function signWith(app, role, proposalId) {
        app.setRole(role);
        app.activeProposal = app.proposalById(proposalId);
        app.approveActive();
    }

    function run() {
        var app = loader.item;
        if (!app) return;

        check("seeded supply equals 150,000", walletSum(app) === 150000, walletSum(app));
        check("issued equals wallet sum", app.state.token.issued === walletSum(app));

        var conserve0 = app.state.wallets.conservation;
        var suppliers0 = app.state.wallets.suppliers;
        var dhun0 = app.state.wallets.dhun;

        // 1. Single-signer allowance purchase as Dhun (380 <= 500)
        app.setRole("dhun");
        app.confirmPurchase(app.state.offers[0], 1);
        check("allowance purchase debited 380", app.state.wallets.dhun === dhun0 - 380, app.state.wallets.dhun);
        check("allowance purchase paid supplier", app.state.wallets.suppliers === suppliers0 + 380, app.state.wallets.suppliers);
        check("allowance purchase preserved supply", walletSum(app) === 150000, walletSum(app));
        check("allowance purchase reduced stock", app.state.offers[0].stock === 5, app.state.offers[0].stock);

        // 2. Covenant purchase as Dhun (native saplings 1100 > allowance -> proposal)
        app.confirmPurchase(app.state.offers[6], 1);
        var covenantProposal = app.activeProposal;
        check("covenant purchase proposed", covenantProposal !== null && covenantProposal.kind === "purchase");
        app.setRole("steward");
        app.approveActive();
        app.setRole("funder");
        app.activeProposal = covenantProposal;
        app.executeActive();
        check("covenant purchase paid 1,045 to supplier", app.state.wallets.suppliers === suppliers0 + 380 + 1045, app.state.wallets.suppliers);
        check("covenant purchase moved 55 to reserve", app.state.wallets.conservation === conserve0 + 55, app.state.wallets.conservation);
        check("covenant purchase preserved supply", walletSum(app) === 150000, walletSum(app));

        // 3. Challenge claim + evidence + release
        app.setRole("dhun");
        var ch = app.state.challenges[0];
        app.claimChallenge(ch);
        check("challenge claimed by dhun", app.state.challenges[0].claimedBy === "dhun");
        app.submitChallengeEvidence(app.state.challenges[0], "Seed lot photo, drill calibration sheet and geotagged points filed for CH-01.");
        check("challenge evidence recorded", !!app.state.challenges[0].evidence);
        app.proposeChallengeRelease(app.state.challenges[0]);
        var releaseId = app.activeProposal.id;
        var conserveBeforeRelease = app.state.wallets.conservation;
        signWith(app, "funder", releaseId);
        app.setRole("funder");
        app.activeProposal = app.proposalById(releaseId);
        app.executeActive();
        check("challenge released", app.state.challenges[0].status === "released", app.state.challenges[0].status);
        check("challenge covenant paid", app.state.wallets.conservation > conserveBeforeRelease, app.state.wallets.conservation - conserveBeforeRelease);
        check("challenge release preserved supply", walletSum(app) === 150000, walletSum(app));

        // 4. Execute the ready amla milestone PROP-108
        var prop108 = app.proposalById("PROP-108");
        app.setRole("steward");
        app.activeProposal = prop108;
        app.approveActive();
        app.setRole("funder");
        app.activeProposal = app.proposalById("PROP-108");
        app.executeActive();
        check("PROP-108 executed", app.proposalById("PROP-108").status === "executed");
        check("amla milestone released", app.state.projects[1].milestones[0].status === "released");
        check("milestone release preserved supply", walletSum(app) === 150000, walletSum(app));

        // 5. External sale PROP-106
        var external0 = app.state.wallets.external;
        signWith(app, "dhun", "PROP-106");
        app.setRole("funder");
        app.activeProposal = app.proposalById("PROP-106");
        app.executeActive();
        check("sale executed", app.proposalById("PROP-106").status === "executed");
        check("sale moved 6,000 to external", app.state.wallets.external === external0 + 6000, app.state.wallets.external);
        check("sale preserved supply", walletSum(app) === 150000, walletSum(app));

        // 6. Mint tranche PROP-105
        var issued0 = app.state.token.issued;
        signWith(app, "steward", "PROP-105");
        app.setRole("funder");
        app.activeProposal = app.proposalById("PROP-105");
        app.executeActive();
        check("mint executed", app.proposalById("PROP-105").status === "executed");
        check("mint raised issued supply", app.state.token.issued === issued0 + 20000, app.state.token.issued);
        check("mint wallet sum matches issued", walletSum(app) === app.state.token.issued, walletSum(app) + " vs " + app.state.token.issued);

        // 7. Award seed bank PROP-107
        signWith(app, "dhun", "PROP-107");
        app.setRole("funder");
        app.activeProposal = app.proposalById("PROP-107");
        app.executeActive();
        check("award executed", app.proposalById("PROP-107").status === "executed");
        check("seed bank awarded to Khejri", app.state.projects[2].awardedTo === "steward", app.state.projects[2].awardedTo);
        check("award preserved supply", walletSum(app) === app.state.token.issued, walletSum(app));

        // 8. Milestone release on PRJ-01
        app.setRole("dhun");
        var prj = app.state.projects[0];
        app.openProject(prj);
        app.proposeMilestoneRelease(prj, prj.milestones[0]);
        var mId = app.activeProposal.id;
        signWith(app, "funder", mId);
        app.setRole("dhun");
        app.activeProposal = app.proposalById(mId);
        app.executeActive();
        check("PRJ-01 M1 released", app.state.projects[0].milestones[0].status === "released", app.state.projects[0].milestones[0].status);
        check("release preserved supply", walletSum(app) === app.state.token.issued, walletSum(app));

        // 9. Fund the hedge project
        app.fundProject(app.state.projects[3]);
        var fundId = app.activeProposal.id;
        signWith(app, "steward", fundId);
        app.setRole("funder");
        app.activeProposal = app.proposalById(fundId);
        app.executeActive();
        check("hedge project funded", app.state.projects[3].funded === true);
        check("hedge project open for bids", app.state.projects[3].status === "bidding", app.state.projects[3].status);
        check("fund preserved supply", walletSum(app) === app.state.token.issued, walletSum(app));

        // 10. Allocate a new challenge
        var escrow0 = app.state.wallets.challengeEscrow;
        var vault0 = app.state.wallets.vault;
        app.proposeAllocation("Mulch the nursery beds", "Mulch before the dry spell to hold moisture in the nursery beds.", "kitchen", 1200, 48, "Mulch depth photo and nursery bed moisture readings.", "PRJ-01");
        var allocId = app.activeProposal.id;
        signWith(app, "steward", allocId);
        app.setRole("dhun");
        app.activeProposal = app.proposalById(allocId);
        app.executeActive();
        check("allocation executed", app.proposalById(allocId).status === "executed");
        check("new challenge exists", app.state.challenges.length === 5, app.state.challenges.length);
        check("challenge escrow funded", app.state.wallets.challengeEscrow === escrow0 + 1200, app.state.wallets.challengeEscrow);
        check("vault paid allocation", app.state.wallets.vault === vault0 - 1200, app.state.wallets.vault);
        check("allocation preserved supply", walletSum(app) === app.state.token.issued, walletSum(app));

        // 11. Roles, navigation, persistence-safe breadth
        app.setRole("steward");
        app.navigate("projects");
        app.openProject(app.state.projects[2]);
        check("project drawer opens", app.activeProject !== null);
        app.closeTop();
        check("escape closes drawer", app.activeProject === null);
        app.navigate("landscape");
        check("landscape navigable", app.activePage === "landscape");

        // 11b. Agro and conservation advisory
        app.navigate("agro");
        check("agro tab is registered", app.pageOrder.indexOf("agro") !== -1 && app.activePage === "agro", app.activePage);
        check("agro tab has page metadata",
              app.pageMeta.agro && app.pageMeta.agro.section === "Field" && app.pageMeta.agro.title.length > 4,
              app.pageMeta.agro ? app.pageMeta.agro.title : "missing");
        var orchard = Agro.locationById("orchard");
        check("agro knows the orchard zone", orchard.id === "orchard" && orchard.latitude > 26, orchard.id);
        check("agro builds a Ventusky atlas url",
              Agro.webUrl("farms", "rain-3h").indexOf("ventusky.com/?p=26.7088;75.5868;11&l=rain-3h") !== -1,
              Agro.webUrl("farms", "rain-3h"));
        var stormDay = { date: "2026-07-02", code: 95, tMax: 43, tMin: 4, rain: 60, chance: 90, wind: 22, gust: 70,
                         rh: 90, soil: 0.36, et0: 7, uv: 10, dew: 26 };
        var stormItems = Agro.dayAdvisories(stormDay);
        var stormTitles = stormItems.map(function (item) { return item.title; }).join(" | ");
        check("agro flags heavy rain and heat",
              stormItems.some(function (item) { return item.tone === "red" && item.title.indexOf("Heavy rain") !== -1; }),
              stormTitles);
        check("agro caps today's agronomy cards at six", stormItems.length <= 6, stormItems.length);
        var calmDay = { date: "2026-02-10", code: 2, tMax: 27, tMin: 12, rain: 0, chance: 5, wind: 8, gust: 12,
                        rh: 55, soil: 0.2, et0: 3, uv: 5, dew: 12 };
        check("agro returns a workable-day fallback",
              Agro.dayAdvisories(calmDay)[0].title === "Workable field day",
              Agro.dayAdvisories(calmDay)[0].title);
        var wetWeek = [
            { date: "2026-07-02", rain: 30, et0: 4, rh: 90, gust: 20, tMax: 30, tMin: 25, soil: 0.36 },
            { date: "2026-07-03", rain: 18, et0: 4, rh: 88, gust: 20, tMax: 30, tMin: 25, soil: 0.34 }
        ];
        var wetItems = Agro.conservationAdvisories(wetWeek, { soil: 0.36 });
        var wetTitles = wetItems.map(function (item) { return item.title; }).join(" | ");
        check("agro flags runoff in a wet 72 h", wetTitles.indexOf("Runoff watch") !== -1, wetTitles);
        check("agro reports a surplus water budget", wetTitles.indexOf("Surplus water") !== -1, wetTitles);
        check("agro keeps advisory-only copy in view", Agro.LIMIT_NOTE.indexOf("Advisory only") === 0, Agro.LIMIT_NOTE);
        var dryWeek = [
            { date: "2026-05-20", rain: 0, et0: 10, rh: 20, gust: 40, tMax: 41, tMin: 29, soil: 0.05 },
            { date: "2026-05-21", rain: 0, et0: 10, rh: 20, gust: 38, tMax: 42, tMin: 30, soil: 0.05 }
        ];
        var dryItems = Agro.conservationAdvisories(dryWeek, { soil: 0.05 });
        var dryTitles = dryItems.map(function (item) { return item.title; }).join(" | ");
        check("agro flags fire weather and wildlife water",
              dryTitles.indexOf("Fire weather") !== -1 && dryTitles.indexOf("Wildlife water stress") !== -1,
              dryTitles);
        check("agro notices the irrigation deficit", dryTitles.indexOf("Irrigation deficit") !== -1, dryTitles);
        var windowDays = [
            { date: "2026-06-15", rain: 0, wind: 10, tMax: 28, tMin: 18, rh: 60, gust: 18, chance: 10 },
            { date: "2026-06-16", rain: 12, wind: 12, tMax: 29, tMin: 20, rh: 70, gust: 22, chance: 80 }
        ];
        var windows = Agro.windowsFor(windowDays);
        check("agro marks sow, spray, harvest and hold windows",
              windows.sow.length === 1 && windows.spray.length === 1 &&
              windows.harvest.length === 1 && windows.hold.length === 1,
              JSON.stringify(windows));
        var drySummary = Agro.summarise(dryWeek);
        check("agro summarises the dry week",
              drySummary.rainWeek === 0 && drySummary.maxTemp === 42 && drySummary.dryDays === 2,
              JSON.stringify(drySummary));
        check("agro maps a backend payload",
              Agro.mapForecast({ success: true, days: [{ date: "2026-10-30", tMax: 31, soil: 0.21 }], current: { temp: 29 } }).success === true);
        check("agro rejects a failed payload",
              Agro.mapForecast({ success: false, error: "nope" }).success === false);
        app.navigate("overview");

        // 11b. Civic simulation
        check("civic registers six domains and eight personas",
              Civic.DOMAINS.length === 6 && Civic.PERSONAS.length === 8);
        var civicCauseIds = [];
        for (var cc = 0; cc < Civic.DOMAINS.length; ++cc) civicCauseIds.push(Civic.DOMAINS[cc].id);
        check("civic covers water, roads, agri and safety",
              civicCauseIds.indexOf("water") !== -1 && civicCauseIds.indexOf("roads") !== -1 &&
              civicCauseIds.indexOf("agri") !== -1 && civicCauseIds.indexOf("safety") !== -1,
              civicCauseIds.join(","));

        var civicRun = Civic.create(77, 10);
        Civic.advance(civicRun);
        check("civic opens reports at dawn",
              civicRun.issues.length >= 2 && civicRun.issues[0].status === "backlog",
              civicRun.issues.length);
        Civic.advance(civicRun);
        var civicCapable = true;
        var civicUnattended = 0;
        var civicLoads = {};
        for (var ci = 0; ci < civicRun.issues.length; ++ci) {
            var civicIssue = civicRun.issues[ci];
            if (!civicIssue.owner) { civicUnattended += 1; continue; }
            var civicPersona = Civic.personaById(civicIssue.owner);
            if (!civicPersona || civicPersona.capability[civicIssue.domain] < 2) civicCapable = false;
            if (civicIssue.status === "assigned" || civicIssue.status === "actioned" || civicIssue.status === "awaiting")
                civicLoads[civicIssue.owner] = (civicLoads[civicIssue.owner] || 0) + 1;
        }
        check("civic assigns only capable agents", civicCapable);
        var civicLoadOk = true;
        for (var civicOwner in civicLoads) if (civicLoads[civicOwner] > 2) civicLoadOk = false;
        check("civic caps each agent at two active tasks", civicLoadOk, JSON.stringify(civicLoads));

        var civicGuard = 0;
        while (!civicRun.done && civicRun.escalations.length === 0 && civicGuard < 24) {
            Civic.advance(civicRun);
            civicGuard += 1;
        }
        check("civic escalates high-risk work to a human", civicRun.escalations.length > 0, civicGuard);

        var civicSign = Civic.create(5, 10);
        civicSign.dayStats[1] = { opened: 1, closed: 0, actions: 0, asks: 0, humanMinutes: 0, zoneActions: {}, domainActions: {}, assigned: {}, reopened: 0 };
        var civicWell = Civic.addIssue(civicSign, "s-well");
        civicWell.status = "assigned";
        civicWell.owner = "kabir";
        var civicAsk = Civic.escalate(civicSign, civicWell, "safety-critical");
        var civicSpentBefore = civicSign.budget.spent;
        Civic.sign(civicSign, civicAsk.id);
        check("civic signing clears the ask and commits budget",
              civicAsk.status === "signed" && civicWell.status === "actioned" &&
              civicSign.budget.spent === civicSpentBefore + civicWell.cost,
              civicAsk.status + " " + civicWell.status + " " + civicSign.budget.spent);

        var civicDecline = Civic.create(6, 10);
        civicDecline.dayStats[1] = { opened: 1, closed: 0, actions: 0, asks: 0, humanMinutes: 0, zoneActions: {}, domainActions: {}, assigned: {}, reopened: 0 };
        var civicLane = Civic.addIssue(civicDecline, "r-school");
        civicLane.status = "assigned";
        civicLane.owner = "arjun";
        var civicPermit = Civic.escalate(civicDecline, civicLane, "permit");
        Civic.decline(civicDecline, civicPermit.id);
        check("civic declining returns work to the backlog",
              civicPermit.status === "declined" && civicLane.status === "backlog" && civicLane.declines === 1,
              civicPermit.status + " " + civicLane.status);

        var civicBatch = Civic.create(7, 10);
        civicBatch.dayStats[1] = { opened: 3, closed: 0, actions: 0, asks: 0, humanMinutes: 0, zoneActions: {}, domainActions: {}, assigned: {}, reopened: 0 };
        var civicBatchTemplates = ["s-well", "s-snake", "s-night"];
        var civicBatchAsks = [];
        for (var cb = 0; cb < civicBatchTemplates.length; ++cb) {
            var civicRisk = Civic.addIssue(civicBatch, civicBatchTemplates[cb]);
            civicRisk.status = "assigned";
            civicRisk.owner = "kabir";
            civicBatchAsks.push(Civic.escalate(civicBatch, civicRisk, "safety-critical"));
        }
        var civicBatched = 0;
        for (var cba = 0; cba < civicBatchAsks.length; ++cba) if (civicBatchAsks[cba].status === "batched") civicBatched += 1;
        check("civic batches extra asks for one human", civicBatched >= 1, civicBatched);

        var civicFair = Civic.create(8, 10);
        civicFair.dayStats[1] = { opened: 2, closed: 0, actions: 6, asks: 0, humanMinutes: 0, zoneActions: { farms: 6 }, domainActions: { water: 6 }, assigned: {}, reopened: 0 };
        var civicOrch1 = Civic.addIssue(civicFair, "a-drip");
        civicOrch1.status = "backlog";
        var civicOrch2 = Civic.addIssue(civicFair, "r-bend");
        civicOrch2.status = "backlog";
        var civicFocus = Civic.facilitatorCheck(civicFair);
        check("civic facilitator rebalances a lopsided day",
              civicFocus === "orchard" && civicFair.fairness.posts === 1, String(civicFocus));

        var civicNight = Civic.create(91, 10);
        for (var cn = 0; cn < 6; ++cn) Civic.advance(civicNight);
        var civicReflections = civicNight.reflections;
        var civicReflectOk = civicReflections.length > 0;
        for (var cr = 0; cr < civicReflections.length; ++cr) {
            var civicReflection = civicReflections[cr];
            if (!civicReflection.saw.length) civicReflectOk = false;
            if (civicReflection.honesty.indexOf("Rule-generated") !== 0) civicReflectOk = false;
            for (var cs = 0; cs < civicReflection.saw.length; ++cs) {
                var civicSeen = civicReflection.saw[cs];
                var civicSeenIssue = null;
                for (var csi = 0; csi < civicNight.issues.length; ++csi)
                    if (civicNight.issues[csi].id === civicSeen) civicSeenIssue = civicNight.issues[csi];
                var civicLinked = civicSeenIssue &&
                        (civicSeenIssue.owner === civicReflection.persona ||
                         civicSeenIssue.partner === civicReflection.persona ||
                         civicSeenIssue.verifiedBy === civicReflection.persona);
                if (!civicLinked) civicReflectOk = false;
            }
        }
        check("civic reflections cite only witnessed issues", civicReflectOk, civicReflections.length);

        function civicSignature(seed) {
            var state = Civic.create(seed, 10);
            for (var turn = 0; turn < 12; ++turn) Civic.advance(state);
            var rows = [];
            for (var issueIndex = 0; issueIndex < state.issues.length; ++issueIndex) {
                var row = state.issues[issueIndex];
                rows.push([row.id, row.templateId, row.status, row.owner, row.cost].join("|"));
            }
            return rows.join(";");
        }
        check("civic engine is deterministic for a seed", civicSignature(88) === civicSignature(88));

        var civicDayGuard = 0;
        while (!civicRun.done && civicDayGuard < 80) {
            Civic.advance(civicRun);
            civicDayGuard += 1;
        }
        var civicMetrics = Civic.metrics(civicRun);
        check("civic keeps the budget inside the pool",
              civicRun.budget.spent <= civicRun.budget.pool && civicRun.budget.spent > 0,
              civicRun.budget.spent);
        check("civic closes work with evidence across a week",
              civicMetrics.closed > 5 && civicMetrics.trust > 0 && civicMetrics.trust <= 1,
              JSON.stringify(civicMetrics));
        check("civic files a dusk digest for every day",
              civicRun.digests.length === 7 && Civic.digestToday(civicRun) !== null,
              civicRun.digests.length);
        var civicGateOk = true;
        var civicKnownGates = ["permit", "treasury", "safety-critical", "confidence", "budget", "rights"];
        for (var cg = 0; cg < civicRun.escalations.length; ++cg)
            if (civicKnownGates.indexOf(civicRun.escalations[cg].reason) === -1) civicGateOk = false;
        check("civic keeps asks to known human gates", civicGateOk, civicRun.escalations.length);
        check("civic limits are honest", Civic.LIMITS.indexOf("Simulation only") === 0, Civic.LIMITS.slice(0, 24));

        var civicCrew = Civic.create(1947, 10);
        var civicCrewGuard = 0;
        while (!civicCrew.done && civicCrewGuard < 80) { Civic.advance(civicCrew); civicCrewGuard += 1; }
        var civicCrewMetrics = Civic.metrics(civicCrew);
        check("civic agents consult, pair, hand off and peer-check",
              civicCrewMetrics.consults > 0 && civicCrewMetrics.joint > 0 &&
              civicCrewMetrics.handoffs > 0 && civicCrewMetrics.reviews > 0,
              civicCrewMetrics.consults + "/" + civicCrewMetrics.joint + "/" +
              civicCrewMetrics.handoffs + "/" + civicCrewMetrics.reviews);

        var civicPeerOk = true;
        for (var cpi = 0; cpi < civicCrew.issues.length; ++cpi) {
            var civicWork = civicCrew.issues[cpi];
            if (civicWork.partner && (civicWork.partner === civicWork.owner || !Civic.personaById(civicWork.partner))) civicPeerOk = false;
            if (civicWork.verifiedBy && (civicWork.verifiedBy === civicWork.owner || !Civic.personaById(civicWork.verifiedBy))) civicPeerOk = false;
            if (civicWork.handoffFrom && (civicWork.handoffFrom === civicWork.owner || !Civic.personaById(civicWork.handoffFrom))) civicPeerOk = false;
        }
        check("civic collaborators are real agents, never self", civicPeerOk, civicCrew.issues.length);

        var civicLinks = Civic.collabPairs(civicCrew, 0);
        var civicLinkSum = 0;
        var civicLinkOk = civicLinks.length > 0;
        for (var cl = 0; cl < civicLinks.length; ++cl) {
            var civicPair = civicLinks[cl];
            civicLinkSum += Civic.pairTotal(civicPair);
            if (civicPair.a === civicPair.b || Civic.pairTotal(civicPair) <= 0) civicLinkOk = false;
        }
        check("civic crew links reconcile with the counters",
              civicLinkOk && civicLinkSum === civicCrewMetrics.links,
              civicLinks.length + " links=" + civicLinkSum + "/" + civicCrewMetrics.links);

        var civicCredited = 0;
        var civicCreditOk = true;
        for (var ccr = 0; ccr < civicCrew.reflections.length; ++ccr) {
            var civicRec = civicCrew.reflections[ccr];
            if (!civicRec.partners || !civicRec.partners.length) continue;
            civicCredited += 1;
            if (civicRec.partners.indexOf(civicRec.agent) !== -1) civicCreditOk = false;
            if (civicRec.takeaway.indexOf("Worked with ") === -1) civicCreditOk = false;
        }
        check("civic reflections credit the agents they worked with",
              civicCredited > 0 && civicCreditOk, civicCredited);

        var civicCapacityOk = true;
        for (var ccp = 0; ccp < Civic.PERSONAS.length; ++ccp) {
            var civicHolder = Civic.PERSONAS[ccp];
            var civicHeld = 0;
            for (var cci = 0; cci < civicCrew.issues.length; ++cci) {
                var civicActive = civicCrew.issues[cci];
                if (civicActive.status !== "assigned" && civicActive.status !== "actioned" && civicActive.status !== "awaiting") continue;
                if (civicActive.owner === civicHolder.id || civicActive.partner === civicHolder.id) civicHeld += 1;
            }
            if (civicHeld > 2) civicCapacityOk = false;
        }
        check("civic paired work still respects the two-task cap", civicCapacityOk);

        app.navigate("civic");
        check("civic tab is registered after agro",
              app.pageOrder.indexOf("civic") === app.pageOrder.indexOf("agro") + 1 && app.activePage === "civic",
              app.activePage);
        check("civic tab has page metadata",
              app.pageMeta.civic && app.pageMeta.civic.section === "Civic" && app.pageMeta.civic.title.length > 4,
              app.pageMeta.civic ? app.pageMeta.civic.title : "missing");
        app.navigate("overview");

        // 12. Field map, produce inventory and calendar
        app.setRole("dhun");
        app.navigate("field");
        check("field map navigable", app.activePage === "field");
        check("field seed holds 12 activities", app.state.fieldActivities.length === 12, app.state.fieldActivities.length);
        var produceOffers = [];
        for (var i = 0; i < app.state.offers.length; ++i)
            if (app.state.offers[i].kind === "produce") produceOffers.push(app.state.offers[i]);
        check("wallet lists 12 produce lots", produceOffers.length === 12, produceOffers.length);
        check("produce lots carry locations", produceOffers[0].ingredientId === "bajra", produceOffers[0].ingredientId);

        var todayBase = new Date();
        todayBase.setHours(0, 0, 0, 0);
        var today0 = app.fieldTodayCount;
        var addedField = app.addFieldActivity({
            role: "dhun", type: "irrigation",
            title: "Test the drip line on the nursery beds",
            produceId: "moringa", zone: "kitchen",
            date: todayBase.getTime() + 9 * 3600000,
            status: "planned", notes: "Flow test activity",
            visibility: "room", source: "wallet",
            plot: { latitude: 26.7115, longitude: 75.5911 }
        });
        check("field activity added", addedField !== null && addedField.id === "FLD-013", addedField ? addedField.id : "null");
        check("field badge counts today", app.fieldTodayCount === today0 + 1, app.fieldTodayCount);
        check("field activity joins the calendar", fieldActivity(app, "FLD-013") !== null);
        app.setFieldActivityStatus("FLD-013", "done");
        check("field activity marked done", fieldActivity(app, "FLD-013").status === "done");
        check("field badge clears after done", app.fieldTodayCount === today0, app.fieldTodayCount);

        var orders0 = app.state.fieldOrders.length;
        var til = offerById(app, "OFF-18");
        var tilStock = Number(til.stock);
        var dhunBefore = Number(app.state.wallets.dhun);
        app.confirmPurchase(til, 1);
        check("produce allowance purchase settles", app.state.wallets.dhun === dhunBefore - 220, app.state.wallets.dhun);
        check("produce purchase records a field order", app.state.fieldOrders.length === orders0 + 1, app.state.fieldOrders.length);
        var firstOrder = app.state.fieldOrders[app.state.fieldOrders.length - 1];
        check("field order maps to the wallet lot", firstOrder.offerId === "OFF-18" && firstOrder.produceId === "til", firstOrder.offerId);
        check("field order notes the allowance path", firstOrder.path === "allowance", firstOrder.path);
        check("produce purchase reduces lot stock", Number(offerById(app, "OFF-18").stock) === tilStock - 1, offerById(app, "OFF-18").stock);

        var orders1 = app.state.fieldOrders.length;
        app.confirmPurchase(til, 3);
        var produceProposal = app.activeProposal;
        check("large produce order becomes a proposal", produceProposal !== null && produceProposal.kind === "purchase" && produceProposal.meta.offerId === "OFF-18");
        app.setRole("steward");
        app.approveActive();
        app.setRole("funder");
        app.activeProposal = app.proposalById(produceProposal.id);
        app.executeActive();
        check("produce proposal executed", app.proposalById(produceProposal.id).status === "executed");
        check("proposal produce order recorded", app.state.fieldOrders.length === orders1 + 1, app.state.fieldOrders.length);
        check("proposal produce order notes its path", app.state.fieldOrders[app.state.fieldOrders.length - 1].path === "proposal");
        check("field purchases preserved supply", walletSum(app) === app.state.token.issued, walletSum(app));

        var studioCount = app.state.fieldActivities.length;
        app.ingestStudioActivity({
            id: "STU-001", role: "steward", type: "harvest",
            title: "Studio harvest note", produceId: "anar", zone: "orchard",
            date: todayBase.getTime() + 11 * 3600000, status: "planned",
            notes: "Imported from the embedded studio", visibility: "room",
            source: "studio", plot: { latitude: 26.7121, longitude: 75.5916 }
        });
        check("studio activity imported", app.state.fieldActivities.length === studioCount + 1, app.state.fieldActivities.length);
        check("studio activity keeps its id", fieldActivity(app, "STU-001") !== null);
        app.ingestStudioActivity({
            id: "STU-001", role: "steward", type: "harvest",
            title: "Studio harvest note (edited)", produceId: "anar", zone: "orchard",
            date: todayBase.getTime() + 11 * 3600000, status: "done",
            notes: "Edited in the studio", visibility: "room",
            source: "studio", plot: { latitude: 26.7121, longitude: 75.5916 }
        });
        check("studio activity upserts in place", app.state.fieldActivities.length === studioCount + 1, app.state.fieldActivities.length);
        check("studio activity edit applies", fieldActivity(app, "STU-001").title === "Studio harvest note (edited)" && fieldActivity(app, "STU-001").status === "done");

        var roomMessages = app.state.messages["room-msig"].length;
        app.ingestFieldUpdate({ id: "UPD-FLOW-1", role: "dhun", title: "Til harvest clip", text: "Three bundles drying on the threshing floor", at: Date.now() });
        app.ingestFieldUpdate({ id: "UPD-FLOW-1", role: "dhun", title: "Til harvest clip", text: "Three bundles drying on the threshing floor", at: Date.now() });
        check("studio clip posts one room note", app.state.messages["room-msig"].length === roomMessages + 1, app.state.messages["room-msig"].length - roomMessages);
        var lastMessage = app.state.messages["room-msig"][app.state.messages["room-msig"].length - 1];
        check("clip note says the video stays local", lastMessage.text.indexOf("clip stays in the field studio") !== -1);

        app.openStudioOffer("bajra", "OFF-11", 4);
        check("studio offer opens the wallet drawer", app.activeOffer !== null && app.activeOffer.id === "OFF-11", app.activeOffer ? app.activeOffer.id : "null");
        check("studio order quantity carried", app.purchaseInitialQty === 4, app.purchaseInitialQty);
        app.activeOffer = null;

        var relayBefore = app.state.messages["room-msig"].length;
        app.relayInbox = [
            { id: "RLY-1", author: "Abhi", text: "Relay field note from Telegram" },
            { id: "RLY-2", author: "Abhi", text: "Second queued note" }
        ];
        check("relay queue exposes both notes", app.relayInbox.length === 2, app.relayInbox.length);
        var relayPosted = app.relayPost("RLY-1");
        var relayLast = app.state.messages["room-msig"][app.state.messages["room-msig"].length - 1];
        check("relay post appends one room note", relayPosted && app.state.messages["room-msig"].length === relayBefore + 1);
        check("relay note is attributed to Telegram", relayLast.text.indexOf("Telegram · Abhi: Relay field note from Telegram") === 0);
        check("relay post clears only that note", app.relayInbox.length === 1 && app.relayInbox[0].id === "RLY-2", app.relayInbox.length);
        app.relayDismiss("RLY-2");
        check("relay dismiss empties the queue", app.relayInbox.length === 0, app.relayInbox.length);

        // 13. Kitchen planner: menu -> farm sourcing, waste parts, natives, >20-day pantry
        app.navigate("kitchen");
        check("kitchen tab is registered", app.pageOrder.indexOf("kitchen") !== -1 && app.activePage === "kitchen", app.activePage);
        check("kitchen tab has page metadata", app.pageMeta.kitchen && app.pageMeta.kitchen.title === "Kitchen", app.pageMeta.kitchen ? app.pageMeta.kitchen.title : "missing");

        var winter = Kitchen.sampleMenus[0];
        var plan = Kitchen.buildPlan(app.state, { guests: winter.guests, month: winter.month, menuText: winter.text, now: 1761500000000 });
        check("winter sample menu parses", plan.ok && plan.dishes.length === 6, plan.reason + " dishes=" + plan.dishes.length);
        check("sourcing covers the mapped ingredients", plan.lines.length === 11, plan.lines.length);
        check("sourcing is grouped by farm zone", plan.groups.length >= 3, plan.groups.length);
        check("planning weight is computed", plan.totals.requiredKg > 15, plan.totals.requiredKg);
        check("total and per-person estimates are exposed", plan.totals.cost > 0 && plan.totals.perPersonCost > 0 && plan.totals.perPersonCostInr.indexOf("₹") === 0, plan.totals.costInr + " / " + plan.totals.perPersonCostInr);
        var itemizedTotal = plan.lines.reduce(function (sum, line) { return sum + line.cost; }, 0);
        check("total equals itemized source costs", Math.abs(itemizedTotal - plan.totals.cost) < 0.01, itemizedTotal + " vs " + plan.totals.cost);

        var sarsonLine = null;
        for (var li = 0; li < plan.lines.length; ++li)
            if (plan.lines[li].id === "sarson") sarsonLine = plan.lines[li];
        check("unlisted produce falls back to a field plot", sarsonLine !== null && sarsonLine.status === "plot" && sarsonLine.estimated, sarsonLine ? sarsonLine.status : "missing");
        check("plot fallback names the grower and price", sarsonLine !== null && sarsonLine.supplier.length > 0 && sarsonLine.price > 0, sarsonLine ? sarsonLine.supplier + " @" + sarsonLine.price : "missing");
        check("every line carries a need and a stock label", plan.lines.every(function (line) { return line.needLabel.length > 0 && line.stockLabel.length > 0; }));

        var partialState = JSON.parse(JSON.stringify(app.state));
        var bajraOffer = partialState.offers.filter(function (offer) { return offer.kind === "produce" && offer.ingredientId === "bajra"; })[0];
        if (bajraOffer) bajraOffer.stock = 0.5;
        var partialPlan = Kitchen.buildPlan(partialState, { guests: 24, month: 12, menuText: "Bajra Roti", now: 1761500000000 });
        var partialBajra = partialPlan.lines.filter(function (line) { return line.id === "bajra"; })[0];
        check("partial market lots include an estimated top-up", !!partialBajra && partialBajra.status === "partial" && partialBajra.marketCost > 0 && partialBajra.estimatedCost > 0 && Math.abs(partialBajra.cost - partialBajra.marketCost - partialBajra.estimatedCost) < 0.01, partialBajra ? partialBajra.cost + " / " + partialBajra.marketCost + " / " + partialBajra.estimatedCost : "missing");

        check("waste uses cover stalks, leaves and roots", plan.waste.length >= 8, plan.waste.length);
        var sarsonWaste = plan.waste.filter(function (item) { return item.ingredientId === "sarson"; })[0];
        var sarsonParts = sarsonWaste ? sarsonWaste.parts.map(function (part) { return part.part; }).join(" ") : "";
        check("sarson waste names its stalk", sarsonParts.indexOf("Stalk") !== -1, sarsonParts);
        check("waste parts carry a caution", plan.waste.every(function (item) {
            return item.parts.every(function (part) { return part.use.length > 0 && part.caution.length > 0; });
        }));

        check("native additions are suggested", plan.natives.length === 3, plan.natives.length);
        var moringa = plan.natives.filter(function (item) { return item.id === "moringa"; })[0];
        check("moringa is paired with the menu", !!moringa && moringa.action.length > 0 && moringa.caution.length > 0, moringa ? moringa.pairing : "missing");
        check("native notes avoid medical claims", plan.natives.every(function (item) {
            var text = item.caution.toLowerCase();
            return item.caution.length > 0 && text.indexOf("cure") === -1 && text.indexOf("treat ") === -1 && text.indexOf("heals") === -1;
        }));

        var driedRoti = plan.preserves.filter(function (item) { return item.id === "dried_roti"; })[0];
        var citrusSalt = plan.preserves.filter(function (item) { return item.id === "citrus_salt"; })[0];
        check("cooked leftovers are gated until checks pass", !!driedRoti && !driedRoti.allowed && driedRoti.blockers.length >= 3, driedRoti ? driedRoti.blockers.join(" | ") : "missing");
        check("raw routes survive a closed gate", !!citrusSalt && citrusSalt.allowed, citrusSalt ? citrusSalt.allowed : "missing");
        check("long-life route is at least 20 days", !!citrusSalt && citrusSalt.days >= 21, citrusSalt ? citrusSalt.days : "missing");
        check("only allowed routes count as long life", plan.longLifePreserves.every(function (item) { return item.allowed && item.days >= 21; }), plan.longLifePreserves.length);
        check("memorabilia is not for sale", !!plan.memorabilia && plan.memorabilia.notForSale === true);
        check("memorabilia carries a batch code", !!plan.memorabilia && /^DHN-K-[A-Z2-9]{5}$/.test(plan.memorabilia.batchCode), plan.memorabilia ? plan.memorabilia.batchCode : "missing");

        var openPlan = Kitchen.buildPlan(app.state, {
            guests: winter.guests, month: winter.month, menuText: winter.text, now: 1761500000000,
            safety: { cooledWithin2h: true, refrigerated: true, untouched: true, dehydrator: true }
        });
        var openRoti = openPlan.preserves.filter(function (item) { return item.id === "dried_roti"; })[0];
        check("checked leftovers unlock cooked preserves", !!openRoti && openRoti.allowed, openRoti ? openRoti.blockers.join(" | ") : "missing");
        check("open gate adds long-life routes", openPlan.longLifePreserves.length > plan.longLifePreserves.length, openPlan.longLifePreserves.length + " vs " + plan.longLifePreserves.length);

        var unknown = Kitchen.buildPlan(app.state, { guests: 10, month: 12, menuText: "Khadvi Sabzi" });
        check("unknown menu fails honestly", !unknown.ok && unknown.reason.length > 0, unknown.reason);

        var modelReply = Kitchen.parseModelReply("```json\n{\"dishes\":[{\"name\":\"Bajra Roti\"},{\"name\":\"Moth Dal\"},{\"name\":\"Khadvi Sabzi\"}],\"servings\":18}\n```");
        check("model reply parses fenced JSON", modelReply.ok && modelReply.dishes.length === 2 && modelReply.unmatched.length === 1, modelReply.dishes.length + "/" + modelReply.unmatched.length);
        check("model reply keeps suggested servings", modelReply.servings === 18, modelReply.servings);
        var strictReply = Kitchen.parseModelReply('{"dishes":["Bajra Roti","Moringa"]}', { allowExtras: false });
        check("local AI output cannot add unplanned extra ingredients", strictReply.matched === 1 && strictReply.extras.length === 0 && strictReply.unmatched.length === 1, strictReply.matched + "/" + strictReply.extras.length + "/" + strictReply.unmatched.length);
        var doubledPlan = Kitchen.buildPlan(app.state, { guests: 48, month: winter.month, menuText: winter.text, now: 1761500000000 });
        var winterBajra = plan.lines.filter(function (line) { return line.id === "bajra"; })[0];
        var doubledBajra = doubledPlan.lines.filter(function (line) { return line.id === "bajra"; })[0];
        check("changing guests scales ingredient requirements", !!winterBajra && !!doubledBajra && doubledBajra.gramsTotal === winterBajra.gramsTotal * 2 && doubledPlan.guests === 48, doubledBajra ? doubledBajra.gramsTotal + " g" : "missing");
        var kitchenPrompt = Assistant.kitchenMessages("vegetarian lunch", 24, 12, Kitchen.dishChoices(), [{ title: "Bajra", stock: 12, unit: "kg", pricePerUnit: 55 }]);
        check("local AI context includes guest and lot data", kitchenPrompt[1].content.indexOf('"guests":24') !== -1 && kitchenPrompt[1].content.indexOf('"listedProduceLots"') !== -1, kitchenPrompt[1].content.length);
        check("loopback endpoints are allowed", Kitchen.localEndpointAllowed("http://127.0.0.1:11434/v1") && Kitchen.localEndpointAllowed("http://localhost:8080/v1"));
        check("remote model endpoints are refused", !Kitchen.localEndpointAllowed("https://api.example.com/v1") && !Kitchen.localEndpointAllowed("http://10.0.0.5:11434/v1"));
        check("model URL joins the chat path", Kitchen.chatCompletionsUrl("http://127.0.0.1:11434/v1") === "http://127.0.0.1:11434/v1/chat/completions");

        // 14. Node page, steward signup and reward payout
        app.navigate("node");
        check("node tab is registered", app.pageOrder.indexOf("node") !== -1 && app.activePage === "node", app.activePage);
        check("node tab has page metadata", app.pageMeta.node && app.pageMeta.node.title === "Node & rewards", app.pageMeta.node ? app.pageMeta.node.title : "missing");
        check("catalog snapshot reports no download count", app.catalog && app.catalog.downloadsReported === false && app.catalog.host.length > 0, app.catalog ? app.catalog.host : "missing");
        check("catalog snapshot keeps a real read time", app.catalog && app.catalog.checkedAt.length > 0, app.catalog ? app.catalog.checkedAt : "missing");
        var fieldReward = null;
        for (var rw = 0; rw < app.state.rewards.length; ++rw)
            if (app.state.rewards[rw].ref === "field|FLD-013") fieldReward = app.state.rewards[rw];
        check("completing field work queues a reward", fieldReward !== null && fieldReward.amount === 8 && fieldReward.status === "earned", fieldReward ? fieldReward.amount : "missing");
        check("accrued rewards moved no money", walletSum(app) === app.state.token.issued, walletSum(app));

        var people0 = app.state.people.length;
        var steward = app.addPerson({ name: "Meera Rathore", place: "Barmer", note: "Nursery beds" });
        check("steward signup creates a profile", steward !== null && steward.role === "steward", steward ? steward.role : "null");
        check("signup adds one profile to the device", app.state.people.length === people0 + 1, app.state.people.length);
        check("signup signs the new steward in", app.activeRole === "steward" && app.activePersonId === steward.id, app.activeRole);
        var onboarded = null;
        for (var rw2 = 0; rw2 < app.state.rewards.length; ++rw2)
            if (app.state.rewards[rw2].rule === "steward-onboarding" && app.state.rewards[rw2].profileId === steward.id) onboarded = app.state.rewards[rw2];
        check("signup queues the onboarding reward", onboarded !== null && onboarded.amount === 10, onboarded ? onboarded.amount : "missing");
        check("signup minted nothing", walletSum(app) === app.state.token.issued, walletSum(app));
        check("nameless signup is refused", app.addPerson({ name: " " }) === null && app.state.people.length === people0 + 1, app.state.people.length);
        check("seeded people keep their party roles", app.state.people[0].role === "funder" && app.state.people[1].role === "dhun" && app.state.people[2].role === "steward");

        var vault0b = app.state.wallets.vault;
        var steward0 = app.state.wallets.steward;
        app.proposeRewardPayout(steward.id);
        var payout = app.activeProposal;
        check("payout proposal is queued", payout !== null && payout.kind === "reward" && payout.meta.profileId === steward.id, payout ? payout.kind : "null");
        check("payout proposal sums unclaimed rewards", payout !== null && payout.amount === 10, payout ? payout.amount : "missing");
        signWith(app, "funder", payout.id);
        app.setRole("steward");
        app.activeProposal = app.proposalById(payout.id);
        app.executeActive();
        check("payout executed", app.proposalById(payout.id).status === "executed", app.proposalById(payout.id).status);
        check("payout paid from the treasury", app.state.wallets.vault === vault0b - 10, app.state.wallets.vault);
        check("payout credits the steward wallet", app.state.wallets.steward === steward0 + 10, app.state.wallets.steward);
        check("payout preserves supply", walletSum(app) === app.state.token.issued, walletSum(app));
        var paidEntries = 0;
        for (var rw3 = 0; rw3 < app.state.rewards.length; ++rw3)
            if (app.state.rewards[rw3].proposalId === payout.id && app.state.rewards[rw3].status === "paid") paidEntries += 1;
        check("paid entries carry the payout proposal", paidEntries === 1, paidEntries);

        var assistantIdeas = Assistant.rewardIdeas(app);
        check("assistant grounds at least one DHN action", assistantIdeas.length >= 1, assistantIdeas.length);
        var hasKitchenIdea = false;
        for (var ai = 0; ai < assistantIdeas.length; ++ai)
            if (assistantIdeas[ai].id === "kitchen-plan") hasKitchenIdea = true;
        check("assistant suggests the kitchen reward", hasKitchenIdea, assistantIdeas.length);
        var assistantContext = Assistant.context(app);
        check("assistant context is labelled rehearsal data",
              String(assistantContext.note || "").indexOf("rehearsal") !== -1,
              assistantContext.note);

        var mood = Kitchen.interpretPrompt("I feel cold and tired. Lunch for 20 people.", 12);
        check("kitchen reads a mood prompt", mood.ok && mood.kind === "mood" && mood.dishes.length >= 2,
              mood.ok ? mood.kind : "none");
        check("kitchen reads guests from free text", mood.guests === 20, mood.guests);
        var moodPlan = Kitchen.buildPromptPlan(app, {
            promptText: "I feel cold and tired. Lunch for 20 people.",
            guests: 20,
            month: 12,
            safety: {}
        });
        check("mood prompt builds a sourcing plan", moodPlan.ok && moodPlan.totals.lines > 0,
              moodPlan.ok ? moodPlan.totals.lines : moodPlan.reason);
        check("mood plan carries zero-waste steps", moodPlan.ok && moodPlan.zeroWaste.length >= 2,
              moodPlan.ok ? moodPlan.zeroWaste.length : "none");
        check("mood plan records its provenance", moodPlan.ok && moodPlan.prompt && moodPlan.prompt.kind === "mood",
              moodPlan.ok && moodPlan.prompt ? moodPlan.prompt.kind : "missing");

        var assessment = Assistant.parseAssessment(
            '{"summary":"Nursery and seed work.","strengths":["Nursery beds"],' +
            '"projectIds":["PRJ-01","PRJ-99"],"fitNotes":"Fits field work.","gaps":"No formal certificate."}',
            app.state.projects);
        check("assessment keeps only real project ids",
              assessment && assessment.projectIds.length === 1 && assessment.projectIds[0] === "PRJ-01",
              assessment ? assessment.projectIds.join(",") : "null");
        check("fabricated project ids never reach allocation",
              assessment && assessment.projectIds.indexOf("PRJ-99") === -1,
              assessment ? assessment.projectIds.join(",") : "null");
        check("background save persists on the profile",
              app.saveProfileBackground(steward.id, "Ten years of nursery and seed-bank work.", JSON.stringify(assessment)) === true &&
              String(app.personById(steward.id).background || "").length > 10,
              app.personById(steward.id).background ? "saved" : "missing");
        check("capability assessment stays with the profile",
              app.personById(steward.id).capability &&
              app.personById(steward.id).capability.projectIds[0] === "PRJ-01",
              app.personById(steward.id).capability ? "saved" : "missing");
        check("assistant offline answer avoids model claims",
              Assistant.localAnswer(app, "How do I earn DHN?").indexOf("No OpenRouter key") === -1 &&
              Assistant.localAnswer(app, "What is the weather?").indexOf("no model was called") !== -1,
              "local answer checked");

        // 15. The 500-acre case page
        app.navigate("case");
        check("case tab is registered", app.pageOrder.indexOf("case") !== -1 && app.activePage === "case", app.activePage);
        check("case tab has page metadata", app.pageMeta.case && app.pageMeta.case.title === "The 500-acre case", app.pageMeta.case ? app.pageMeta.case.title : "missing");
        check("case tab is the last workspace entry", app.pageOrder.length === 13 && app.pageOrder[12] === "case", app.pageOrder.join(","));
        app.navigate("overview");
        check("case page leaves the workspace intact", app.activePage === "overview" && app.state.people.length === people0 + 1, app.activePage);

        console.log("SUMMARY checks=" + win.checks + " failures=" + win.failures + " supply=" + walletSum(app) + " issued=" + app.state.token.issued);
        finishTimer.start();
    }

    Timer {
        id: runTimer
        interval: 400
        running: false
        repeat: false
        onTriggered: win.run()
    }

    Timer {
        id: finishTimer
        interval: 500
        running: false
        repeat: false
        onTriggered: Qt.quit()
    }
}
