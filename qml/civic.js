.pragma library

// Deterministic civic-action simulation for the Dhun commons.
// Every report, action and closure is synthetic; nothing leaves this machine.

var HORIZON = 7;

var PHASES = ["dawn", "triage", "act", "verify", "dusk", "night"];

var PHASE_LABEL = {
    dawn: "Dawn scan",
    triage: "Triage",
    act: "Field action",
    verify: "Verification",
    dusk: "Dusk report",
    night: "Night reflection"
};

var PHASE_HINT = {
    dawn: "Synthetic reports arrive and are scored.",
    triage: "Owners are matched by domain, capability and capacity.",
    act: "Coordination work is drafted, booked and chased.",
    verify: "Evidence is checked; incomplete work reopens.",
    dusk: "The day is summarised and fairness is audited.",
    night: "Agents file reflections from what they witnessed."
};

var LIMITS = "Simulation only. Reports are synthetic and no department, crew or vendor is contacted. Agents consult, pair up, hand work over and peer-check each other, but every report, reply and reflection is rule-generated from the simulated record — no language model is called. They draft, schedule, chase and verify coordination work; they do not do physical labour, issue permits or override the 2-of-3 treasury sign-off. Every brief stays unverified until a human signs.";

var DOMAINS = [
    { id: "water", label: "Water & drainage", short: "Water", color: "#5A7684", cap: 1200, guardian: "meera",
      brief: "Handpumps, canal gates, drains and storage",
      reply: "sends the gate-seal checklist and last week's loss figure" },
    { id: "roads", label: "Roads & access", short: "Roads", color: "#9B6D22", cap: 1200, guardian: "arjun",
      brief: "Lanes, shoulders, lighting and school routes",
      reply: "sends the crew contact and the last patch quote" },
    { id: "agri", label: "Agri & soil", short: "Agri", color: "#5C7A3F", cap: 900, guardian: "saira",
      brief: "Pest scouting, irrigation, fodder and seed",
      reply: "sends the scouting sheet and the spray window" },
    { id: "safety", label: "Safety & nights", short: "Safety", color: "#A8442F", cap: 700, guardian: "kabir",
      brief: "Wells, fire load, night walks and hazards",
      reply: "sends the night-walk route and the barricade stock count" },
    { id: "waste", label: "Waste & sanitation", short: "Waste", color: "#7A6A4F", cap: 400, guardian: "lata",
      brief: "Pits, greywater, mulch and compost",
      reply: "sends the pit-depth log and the pickup rota" },
    { id: "care", label: "Care & health", short: "Care", color: "#B06A8A", cap: 400, guardian: "nila",
      brief: "Elders, heat safety, first aid and transport",
      reply: "sends the visit list and the driver call sheet" }
];

var ZONES = [
    { id: "farms", name: "Farms & market garden", short: "Farms" },
    { id: "orchard", name: "Orchards & groves", short: "Orchards" },
    { id: "kitchen", name: "Kitchen garden", short: "Kitchen" },
    { id: "dairy", name: "Dairy & poultry", short: "Dairy" },
    { id: "estate", name: "Estate commons", short: "Estate" },
    { id: "hamlet", name: "Hamlet & school lane", short: "Hamlet" }
];

var PERSONAS = [
    { id: "meera", name: "Meera Rathore", role: "Water steward", zone: "farms", agent: "Jal",
      voice: "Slow water, steady fields.",
      capability: { water: 3, agri: 1, waste: 1 }, askCap: 2, hoursWeek: 6 },
    { id: "arjun", name: "Arjun Sain", role: "Road guardian", zone: "estate", agent: "Marg",
      voice: "Every lane is a promise.",
      capability: { roads: 3, safety: 1, water: 1 }, askCap: 2, hoursWeek: 5 },
    { id: "saira", name: "Saira Bano", role: "Agri steward", zone: "orchard", agent: "Beej",
      voice: "Read the leaf before the label.",
      capability: { agri: 3, water: 1, waste: 1 }, askCap: 2, hoursWeek: 7 },
    { id: "dev", name: "Dev Gurjar", role: "Dairy steward", zone: "dairy", agent: "Goth",
      voice: "The herd sets the clock.",
      capability: { agri: 2, waste: 2, water: 1 }, askCap: 1, hoursWeek: 5 },
    { id: "lata", name: "Lata Sharma", role: "Kitchen & waste lead", zone: "kitchen", agent: "Chulha",
      voice: "Nothing leaves the gate as trash.",
      capability: { waste: 3, care: 1, agri: 1 }, askCap: 2, hoursWeek: 6 },
    { id: "kabir", name: "Kabir Nair", role: "Safety lead", zone: "estate", agent: "Pehra",
      voice: "Night is just a different shift.",
      capability: { safety: 3, roads: 2, care: 1 }, askCap: 1, hoursWeek: 4 },
    { id: "nila", name: "Nila Vyas", role: "Care worker", zone: "hamlet", agent: "Saanjh",
      voice: "Count the people, then the tasks.",
      capability: { care: 3, safety: 1, water: 1 }, askCap: 1, hoursWeek: 8 },
    { id: "ravi", name: "Ravi Meena", role: "Energy & commons", zone: "farms", agent: "Dhoop",
      voice: "Fix the boring thing before it fails.",
      capability: { water: 2, roads: 2, safety: 1 }, askCap: 2, hoursWeek: 5 }
];

// Each template is a plausible recurring civic report. Costs are DHN in the
// simulated civic envelope; humanMinutes is coordination time the agent absorbs.
var TEMPLATES = [
    { id: "w-drain", domain: "water", zone: "farms", months: [6, 7, 8, 9],
      title: "Silt blocks the north field drain", detail: "The drain below the bajra block is half full of silt; the next heavy rain will back up into the seedling beds.",
      urgency: 4, impact: 4, equity: 3, effort: 3, risk: "medium", cost: 75, humanMinutes: 90,
      evidence: "photos of the cleared culvert line",
      actions: ["booked the village works crew for the culvert line", "sent the silt photos to the ward engineer", "scheduled a drain walk before the next rain"] },
    { id: "w-handpump", domain: "water", zone: "hamlet",
      title: "The hamlet handpump runs dry by noon", detail: "Four households queue from 11am; the pump recovers only after dark.",
      urgency: 5, impact: 5, equity: 5, effort: 3, risk: "medium", cost: 120, humanMinutes: 70,
      evidence: "noon pump test with two witnesses",
      actions: ["logged the dry-hour readings and filed a repair request", "asked the panchayat for a tanker slot on Thursday", "put a water rota on the pump board"] },
    { id: "w-gate", domain: "water", zone: "farms",
      title: "Canal outlet gate leaks overnight", detail: "The outlet loses water for six hours after every rotation.",
      urgency: 3, impact: 3, equity: 2, effort: 2, risk: "low", cost: 40, humanMinutes: 40,
      evidence: "gate seal check after one night",
      actions: ["replaced the outlet gasket and logged the loss", "added the gate to the weekly water walk"] },
    { id: "w-tank", domain: "water", zone: "kitchen", months: [6, 7, 8, 9],
      title: "Roof-harvest tank overflows in the first rain", detail: "The kitchen tank has no float valve; the first flush runs straight to the lane.",
      urgency: 2, impact: 2, equity: 2, effort: 2, risk: "low", cost: 25, humanMinutes: 25,
      evidence: "overflow photo and first-flush note",
      actions: ["fitted a float valve and cleaned the first-flush diverter"] },

    { id: "r-school", domain: "roads", zone: "hamlet", months: [6, 7, 8, 9],
      title: "Potholes on the school lane", detail: "Six craters between the bus stop and the school gate; two are deep enough to catch a bicycle wheel.",
      urgency: 4, impact: 4, equity: 5, effort: 3, risk: "high", cost: 600, humanMinutes: 180,
      evidence: "pothole measurements and crew sign-off",
      actions: ["measured and flagged the school-lane craters", "collected two patch-repair quotes", "booked the patch crew for the school-run window"] },
    { id: "r-bend", domain: "roads", zone: "orchard", months: [6, 7, 8, 9],
      title: "Gravel shoulder washed out at the orchard bend", detail: "The bend narrows to one tractor width after the rain.",
      urgency: 3, impact: 3, equity: 2, effort: 3, risk: "medium", cost: 220, humanMinutes: 110,
      evidence: "before-and-after shoulder photos",
      actions: ["rebuilt the washed shoulder with local gravel", "added a bend mirror and slow-marking"] },
    { id: "r-light", domain: "roads", zone: "estate",
      title: "Streetlight out at the bus stop", detail: "The pole tag is faded; the stop is dark by 6:40pm.",
      urgency: 3, impact: 4, equity: 4, effort: 1, risk: "medium", cost: 150, humanMinutes: 45,
      evidence: "pole tag photo and ticket number",
      actions: ["raised a streetlight ticket with the pole tag", "placed a temporary solar lamp at the stop"] },
    { id: "r-track", domain: "roads", zone: "farms",
      title: "Tractor track rutted after harvest runs", detail: "Loaded trailers are cutting the track into the fodder block.",
      urgency: 2, impact: 3, equity: 2, effort: 4, risk: "low", cost: 90, humanMinutes: 130,
      evidence: "track camber photo after levelling",
      actions: ["graded the tractor track before rabi sowing", "rerouted harvest trailers for one week"] },

    { id: "a-worm", domain: "agri", zone: "farms", months: [8, 9, 10],
      title: "Fall armyworm spots in the bajra block", detail: "Three scouting points show fresh whorl damage on the late-sown bajra.",
      urgency: 5, impact: 4, equity: 3, effort: 2, risk: "medium", cost: 60, humanMinutes: 80,
      evidence: "scouting sheet with three leaf samples",
      actions: ["set pheromone traps and opened a scouting sheet", "scheduled a neem spray at dusk", "alerted the neighbouring bajra plots"] },
    { id: "a-drip", domain: "agri", zone: "orchard",
      title: "Orchard drip lines clogged with salt", detail: "Emitter flow is uneven on the western row; young trees are stressed.",
      urgency: 3, impact: 3, equity: 2, effort: 3, risk: "low", cost: 80, humanMinutes: 100,
      evidence: "flow test at six emitters",
      actions: ["flushed and acid-cleaned the drip lines", "replaced six clogged emitters"] },
    { id: "a-fodder", domain: "agri", zone: "dairy", months: [10, 11, 12],
      title: "Fodder gap before the herd moves", detail: "Silage stock covers 11 days; the next cut is three weeks away.",
      urgency: 3, impact: 4, equity: 3, effort: 4, risk: "medium", cost: 300, humanMinutes: 170,
      evidence: "silage stock count and delivery note",
      actions: ["lined up two fodder suppliers for the gap", "wrote a silage ration plan with the dairy crew"] },
    { id: "a-seed", domain: "agri", zone: "farms", months: [9, 10, 11],
      title: "Rabi seed lot needs a viability check", detail: "Last season's wheat and mustard seed are stored in the loft; germination is unknown.",
      urgency: 2, impact: 3, equity: 2, effort: 2, risk: "low", cost: 0, humanMinutes: 35,
      evidence: "germination test on 100 seeds",
      actions: ["ran a germination test on the rabi seed lot", "priced replacement seed only if viability is under 80%"] },

    { id: "s-well", domain: "safety", zone: "orchard", months: [5, 6, 7, 8, 9, 10],
      title: "Open well near the orchard path has no cover", detail: "The old well sits 12 metres from the path children take to the grove.",
      urgency: 5, impact: 5, equity: 4, effort: 2, risk: "high", cost: 450, humanMinutes: 160,
      evidence: "cover photo and barricade check",
      actions: ["barricaded the open well tonight", "cast a reinforced cover with the works crew", "added the well to the night walk"] },
    { id: "s-snake", domain: "safety", zone: "estate", months: [6, 7, 8, 9],
      title: "Snakes sheltering in the compost yard", detail: "The yard has pallets stacked against the wall and long grass at the edge.",
      urgency: 4, impact: 4, equity: 3, effort: 2, risk: "medium", cost: 120, humanMinutes: 70,
      evidence: "compost-yard clearance photo",
      actions: ["cleared the compost yard and restacked the pallets", "briefed the crew on the snake protocol"] },
    { id: "s-night", domain: "safety", zone: "hamlet",
      title: "Night bus drop leaves women walking 800 m unlit", detail: "The last bus stops on the highway; the walk into the hamlet has no working light.",
      urgency: 4, impact: 5, equity: 5, effort: 4, risk: "high", cost: 900, humanMinutes: 200,
      evidence: "light audit along the 800 m walk",
      actions: ["audited the unlit walk and mapped six pole sites", "asked the bus operator for a gate-side drop", "organised a walking-buddy rota until the lights arrive"] },
    { id: "s-fire", domain: "safety", zone: "dairy", months: [11, 12, 1, 2],
      title: "Firewood stack sits under the thatch store", detail: "Two months of firewood is stacked against the thatch wall.",
      urgency: 3, impact: 4, equity: 2, effort: 2, risk: "medium", cost: 100, humanMinutes: 55,
      evidence: "stack separation photo and extinguisher check",
      actions: ["moved the firewood clear of the thatch store", "placed a dry-powder extinguisher at the dairy gate"] },

    { id: "t-pit", domain: "waste", zone: "kitchen",
      title: "Kitchen waste pit nears capacity", detail: "The pit is 80 cm from the rim and the weekend rush is coming.",
      urgency: 3, impact: 3, equity: 3, effort: 3, risk: "low", cost: 60, humanMinutes: 80,
      evidence: "pit depth reading and turnaround plan",
      actions: ["scheduled a pit pump-out before the weekend rush", "started a two-bin separation rota"] },
    { id: "t-mulch", domain: "waste", zone: "farms",
      title: "Plastic mulch has no buyer after sowing", detail: "Eight bales sit by the store; nobody has collected them.",
      urgency: 2, impact: 3, equity: 2, effort: 3, risk: "low", cost: 0, humanMinutes: 55,
      evidence: "bale weight and buyer note",
      actions: ["baled the mulch and listed it on the market board", "asked two recyclers for a pickup quote"] },
    { id: "t-grey", domain: "waste", zone: "dairy",
      title: "Greywater from the dairy washes into the lane", detail: "Wash water crosses the walking lane before it soaks away.",
      urgency: 3, impact: 3, equity: 3, effort: 2, risk: "medium", cost: 150, humanMinutes: 70,
      evidence: "greywater channel photo and sample",
      actions: ["cut a soak channel away from the lane", "booked a mason for a grease trap"] },
    { id: "t-compost", domain: "waste", zone: "estate",
      title: "Compost heap turned too late and smells at the gate", detail: "The heap has gone anaerobic and the gate complaint book has two entries.",
      urgency: 2, impact: 2, equity: 2, effort: 1, risk: "low", cost: 0, humanMinutes: 40,
      evidence: "turning log and heap temperature",
      actions: ["turned the heap and logged the temperature", "covered the heap before the next rain"] },

    { id: "c-elders", domain: "care", zone: "hamlet",
      title: "Two elders miss the mobile health van", detail: "The van came at 9am; both were at the fields and missed the announcement.",
      urgency: 4, impact: 5, equity: 5, effort: 2, risk: "medium", cost: 0, humanMinutes: 90,
      evidence: "visit list with two confirmed names",
      actions: ["built a visit list for the mobile health van", "arranged a shared ride for two elders"] },
    { id: "c-heat", domain: "care", zone: "kitchen", months: [4, 5, 6],
      title: "Kitchen staff work through heat without shade breaks", detail: "Prep runs 11am–3pm with no shade and no written water break.",
      urgency: 3, impact: 4, equity: 4, effort: 2, risk: "medium", cost: 200, humanMinutes: 50,
      evidence: "shade and water-break log",
      actions: ["set shade and water breaks for kitchen shifts", "moved prep to the cool hours"] },
    { id: "c-kit", domain: "care", zone: "dairy",
      title: "First-aid kit at the dairy is expired", detail: "Antiseptic and bandages expired last year; the emergency numbers are missing.",
      urgency: 4, impact: 3, equity: 3, effort: 1, risk: "high", cost: 180, humanMinutes: 25,
      evidence: "kit inventory with expiry dates",
      actions: ["replaced the expired first-aid kit", "posted the emergency numbers at the dairy gate"] },
    { id: "c-transport", domain: "care", zone: "hamlet",
      title: "New mothers need a transport contact", detail: "The nearest ambulance is 18 km away and the shared jeep leaves before dawn.",
      urgency: 3, impact: 4, equity: 5, effort: 3, risk: "medium", cost: 0, humanMinutes: 60,
      evidence: "contact sheet with two confirmed drivers",
      actions: ["collected two volunteer drivers on a call sheet", "shared the sheet with the health worker"] }
];

function pad(value, width) {
    var out = String(value);
    while (out.length < width) out = "0" + out;
    return out;
}

function byId(list, id) {
    for (var i = 0; i < list.length; ++i) if (list[i].id === id) return list[i];
    return null;
}

function domainById(id) { return byId(DOMAINS, id); }
function personaById(id) { return byId(PERSONAS, id); }
function zoneById(id) { return byId(ZONES, id); }

function clone(state) {
    return JSON.parse(JSON.stringify(state));
}

function actorLabel(actor) {
    if (actor === "system") return "Civic desk";
    if (actor === "facilitator") return "Fairness facilitator";
    if (actor === "you") return "You";
    var persona = personaById(actor);
    return persona ? persona.agent + " · " + persona.name : actor;
}

function actorAgent(actor) {
    var persona = personaById(actor);
    return persona ? persona.agent : actor;
}

function create(seed, month) {
    var chosen = seed || 1947;
    var s = {
        seed: chosen,
        month: month || 10,
        day: 1,
        phase: "dawn",
        horizon: HORIZON,
        cursor: (chosen * 7919) | 0,
        done: false,
        issues: [],
        escalations: [],
        log: [],
        reflections: [],
        digests: [],
        budget: { pool: 4800, spent: 0, byDomain: {} },
        fairness: { focus: null, posts: 0, lastDay: 0 },
        collab: { consults: 0, joint: 0, handoffs: 0, reviews: 0, pairs: {} },
        counters: { issue: 0, log: 0, ask: 0 },
        dayStats: {}
    };
    for (var i = 0; i < DOMAINS.length; ++i) s.budget.byDomain[DOMAINS[i].id] = 0;
    pushLog(s, "system", "system", "Eight residents' agents open the civic board. Reports are synthetic; no department is contacted.", [], "neutral");
    return s;
}

function rng(state) {
    state.cursor = (state.cursor + 0x6D2B79F5) | 0;
    var t = state.cursor;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

function pushLog(state, kind, actor, text, refs, tone) {
    state.counters.log += 1;
    state.log.push({
        id: "LOG-" + pad(state.counters.log, 3),
        day: state.day,
        phase: state.phase,
        kind: kind,
        actor: actor,
        text: text,
        refs: refs || [],
        tone: tone || "neutral"
    });
}

function scoreIssue(issue) {
    var raw = 0.38 * issue.urgency + 0.27 * issue.impact + 0.20 * issue.equity + 0.15 * (6 - issue.effort);
    return Math.round(raw / 5 * 100);
}

function findIssue(state, id) {
    for (var i = 0; i < state.issues.length; ++i) if (state.issues[i].id === id) return state.issues[i];
    return null;
}

function findAsk(state, id) {
    for (var i = 0; i < state.escalations.length; ++i) if (state.escalations[i].id === id) return state.escalations[i];
    return null;
}

function addIssue(state, templateId) {
    var tpl = byId(TEMPLATES, templateId);
    if (!tpl) return null;
    state.counters.issue += 1;
    var issue = {
        id: "ISSUE-" + pad(state.counters.issue, 3),
        templateId: tpl.id,
        domain: tpl.domain,
        zone: tpl.zone,
        title: tpl.title,
        detail: tpl.detail,
        urgency: tpl.urgency,
        impact: tpl.impact,
        equity: tpl.equity,
        effort: tpl.effort,
        risk: tpl.risk,
        cost: tpl.cost,
        humanMinutes: tpl.humanMinutes,
        evidence: tpl.evidence,
        actions: tpl.actions.slice(0),
        status: "reported",
        score: scoreIssue(tpl),
        owner: null,
        partner: null,
        verifiedBy: null,
        handoffFrom: null,
        consulted: false,
        escalation: null,
        action: "",
        reportedDay: state.day,
        assignedDay: 0,
        actionDay: 0,
        closedDay: 0,
        retries: 0,
        declines: 0
    };
    state.issues.push(issue);
    return issue;
}

function pickTemplate(state, used) {
    var options = [], weights = [], total = 0;
    for (var i = 0; i < TEMPLATES.length; ++i) {
        var t = TEMPLATES[i];
        if (used[t.id]) continue;
        var weight = 1;
        if (t.months && t.months.indexOf(state.month) !== -1) weight *= 2.4;
        var recent = 0;
        for (var j = 0; j < state.issues.length; ++j) {
            if (state.issues[j].templateId === t.id && state.issues[j].reportedDay >= state.day - 10) recent += 1;
        }
        weight = weight / (1 + recent * 1.4);
        options.push(t);
        weights.push(weight);
        total += weight;
    }
    if (!options.length || total <= 0) return null;
    var roll = rng(state) * total;
    for (var k = 0; k < options.length; ++k) {
        roll -= weights[k];
        if (roll <= 0) return options[k];
    }
    return options[options.length - 1];
}

function activeCount(state, personaId) {
    var count = 0;
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.owner !== personaId && issue.partner !== personaId) continue;
        if (issue.status === "assigned" || issue.status === "actioned" || issue.status === "awaiting") count += 1;
    }
    return count;
}

function pairKey(a, b) {
    return a < b ? a + "|" + b : b + "|" + a;
}

function recordPair(state, a, b, kind) {
    if (!a || !b || a === b) return null;
    var key = pairKey(a, b);
    var pair = state.collab.pairs[key];
    if (!pair) {
        pair = { key: key, a: a < b ? a : b, b: a < b ? b : a, consults: 0, joint: 0, handoffs: 0, reviews: 0 };
        state.collab.pairs[key] = pair;
    }
    pair[kind] = (pair[kind] || 0) + 1;
    state.collab[kind] = (state.collab[kind] || 0) + 1;
    return pair;
}

function pairTotal(pair) {
    return (pair.consults || 0) + (pair.joint || 0) + (pair.handoffs || 0) + (pair.reviews || 0);
}

function collabPairs(state, limit) {
    var out = [];
    for (var key in state.collab.pairs) out.push(state.collab.pairs[key]);
    out.sort(function (a, b) {
        var diff = pairTotal(b) - pairTotal(a);
        if (diff !== 0) return diff;
        return a.key < b.key ? -1 : 1;
    });
    return limit ? out.slice(0, limit) : out;
}

function collabLinks(state) {
    var total = 0;
    for (var key in state.collab.pairs) total += pairTotal(state.collab.pairs[key]);
    return total;
}

function personaPeers(state, personaId, limit) {
    var out = [];
    for (var key in state.collab.pairs) {
        var pair = state.collab.pairs[key];
        if (pair.a !== personaId && pair.b !== personaId) continue;
        out.push({ persona: pair.a === personaId ? pair.b : pair.a, total: pairTotal(pair) });
    }
    out.sort(function (a, b) {
        if (b.total !== a.total) return b.total - a.total;
        return a.persona < b.persona ? -1 : 1;
    });
    return limit ? out.slice(0, limit) : out;
}

function backlogCount(state) {
    var count = 0;
    for (var i = 0; i < state.issues.length; ++i) if (state.issues[i].status === "backlog") count += 1;
    return count;
}

function zoneBacklog(state, zone) {
    var count = 0;
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.zone === zone && (issue.status === "backlog" || issue.status === "assigned" || issue.status === "awaiting")) count += 1;
    }
    return count;
}

function remainingBudget(state, domain) {
    var domain_ = domainById(domain);
    if (!domain_) return 0;
    return domain_.cap - (state.budget.byDomain[domain] || 0);
}

function spend(state, domain, amount) {
    if (!amount) return;
    state.budget.spent += amount;
    state.budget.byDomain[domain] = (state.budget.byDomain[domain] || 0) + amount;
}

function pickOwner(state, issue) {
    var stats = state.dayStats[state.day] || { assigned: {} };
    var candidates = [];
    for (var i = 0; i < PERSONAS.length; ++i) {
        var persona = PERSONAS[i];
        var capability = persona.capability[issue.domain] || 0;
        if (capability < 2) continue;
        if (activeCount(state, persona.id) >= 2) continue;
        if ((stats.assigned[persona.id] || 0) >= 3) continue;
        candidates.push({ persona: persona, capability: capability });
    }
    if (!candidates.length) return null;
    candidates.sort(function (a, b) {
        if (b.capability !== a.capability) return b.capability - a.capability;
        var loadA = activeCount(state, a.persona.id);
        var loadB = activeCount(state, b.persona.id);
        if (loadA !== loadB) return loadA - loadB;
        return a.persona.id < b.persona.id ? -1 : 1;
    });
    return candidates[0].persona;
}

// Spread load at the end of triage: an agent carrying two tasks hands the
// lower-priority one to an idle, capable peer and keeps the sharper report.
function balanceLoads(state) {
    var stats = state.dayStats[state.day] || { assigned: {} };
    var moved = 0;
    for (var i = 0; i < PERSONAS.length; ++i) {
        var holder = PERSONAS[i];
        var owned = [];
        for (var j = 0; j < state.issues.length; ++j) {
            var issue = state.issues[j];
            if (issue.owner !== holder.id || issue.status !== "assigned") continue;
            if (issue.partner || issue.escalation || issue.consulted) continue;
            owned.push(issue);
        }
        if (owned.length < 2) continue;
        owned.sort(function (a, b) { return a.score - b.score; });
        for (var o = 0; o < owned.length; ++o) {
            var task = owned[o];
            var peer = null;
            var peerScore = -1;
            for (var k = 0; k < PERSONAS.length; ++k) {
                var candidate = PERSONAS[k];
                if (candidate.id === holder.id) continue;
                var capability = candidate.capability[task.domain] || 0;
                if (capability < 2) continue;
                if (activeCount(state, candidate.id) > 0) continue;
                if ((stats.assigned[candidate.id] || 0) >= 3) continue;
                var score = capability * 10;
                if (score > peerScore || (score === peerScore && peer && candidate.id < peer.id)) {
                    peer = candidate;
                    peerScore = score;
                }
            }
            if (!peer) continue;
            task.owner = peer.id;
            task.handoffFrom = holder.id;
            stats.assigned[peer.id] = (stats.assigned[peer.id] || 0) + 1;
            recordPair(state, holder.id, peer.id, "handoffs");
            pushLog(state, "handoff", holder.id, holder.agent + " was carrying two and hands \"" + task.title + "\" to " + peer.agent + ", keeping the sharper report.", [task.id], "neutral");
            moved += 1;
            break;
        }
    }
    return moved;
}

function pickAction(state, issue) {
    var index = Math.floor(rng(state) * issue.actions.length);
    return issue.actions[Math.min(index, issue.actions.length - 1)];
}

function pickPartner(state, issue) {
    var stats = state.dayStats[state.day] || { assigned: {} };
    var guardian = domainById(issue.domain).guardian;
    var best = null;
    var bestScore = -1;
    for (var i = 0; i < PERSONAS.length; ++i) {
        var persona = PERSONAS[i];
        if (persona.id === issue.owner) continue;
        var capability = persona.capability[issue.domain] || 0;
        if (capability < 1) continue;
        if (activeCount(state, persona.id) >= 2) continue;
        if ((stats.assigned[persona.id] || 0) >= 3) continue;
        var score = capability * 100 - activeCount(state, persona.id) * 10 + (persona.id === guardian ? 5 : 0);
        if (score > bestScore || (score === bestScore && best && persona.id < best.id)) {
            best = persona;
            bestScore = score;
        }
    }
    return best;
}

function pickReviewer(state, issue) {
    var guardian = domainById(issue.domain).guardian;
    var best = null;
    var bestScore = -1;
    for (var i = 0; i < PERSONAS.length; ++i) {
        var persona = PERSONAS[i];
        if (persona.id === issue.owner || persona.id === issue.partner) continue;
        var capability = persona.capability[issue.domain] || 0;
        if (capability < 1) continue;
        var score = capability * 10 + (persona.id === guardian ? 2 : 0);
        if (score > bestScore || (score === bestScore && best && persona.id < best.id)) {
            best = persona;
            bestScore = score;
        }
    }
    return best;
}

// A blocked agent offers one of its own tasks to an idle peer so it can take
// a higher-priority report. Returns the freed persona, or null.
function relieveFor(state, issue) {
    var stats = state.dayStats[state.day] || { assigned: {} };
    for (var i = 0; i < PERSONAS.length; ++i) {
        var holder = PERSONAS[i];
        if ((holder.capability[issue.domain] || 0) < 2) continue;
        if (activeCount(state, holder.id) < 2) continue;
        if ((stats.assigned[holder.id] || 0) >= 3) continue;
        for (var j = 0; j < state.issues.length; ++j) {
            var moved = state.issues[j];
            if (moved.owner !== holder.id || moved.status !== "assigned") continue;
            if (moved.partner || moved.escalation || moved.consulted) continue;
            var peer = null;
            var peerScore = -1;
            for (var k = 0; k < PERSONAS.length; ++k) {
                var candidate = PERSONAS[k];
                if (candidate.id === holder.id || candidate.id === issue.owner) continue;
                var capability = candidate.capability[moved.domain] || 0;
                if (capability < 2) continue;
                if (activeCount(state, candidate.id) >= 2) continue;
                if ((stats.assigned[candidate.id] || 0) >= 3) continue;
                var score = capability * 10 - activeCount(state, candidate.id);
                if (score > peerScore || (score === peerScore && peer && candidate.id < peer.id)) {
                    peer = candidate;
                    peerScore = score;
                }
            }
            if (!peer) continue;
            moved.owner = peer.id;
            moved.handoffFrom = holder.id;
            moved.assignedDay = state.day;
            stats.assigned[peer.id] = (stats.assigned[peer.id] || 0) + 1;
            recordPair(state, holder.id, peer.id, "handoffs");
            pushLog(state, "handoff", holder.id, holder.agent + " hands \"" + moved.title + "\" to " + peer.agent + " to make room, and takes \"" + issue.title + "\".", [moved.id, issue.id], "neutral");
            return holder;
        }
    }
    return null;
}

function escalationReason(state, issue) {
    if (issue.retries >= 2) return "confidence";
    if (issue.risk === "high") return issue.domain === "safety" ? "safety-critical" : "permit";
    if (issue.cost > 300) return "treasury";
    if (issue.cost > remainingBudget(state, issue.domain)) return "budget";
    return "";
}

function askTextFor(reason, issue) {
    if (reason === "treasury") return "Release " + issue.cost + " DHN from the " + domainById(issue.domain).short.toLowerCase() + " envelope for: " + issue.title + ".";
    if (reason === "permit") return "The agent has the plan ready but needs your call on permits and liability: " + issue.title + ".";
    if (reason === "safety-critical") return "Safety-critical. Confirm the crew dispatch and budget for: " + issue.title + ".";
    if (reason === "rights") return "This changes who gets served first. Confirm the order for: " + issue.title + ".";
    if (reason === "budget") return "The " + domainById(issue.domain).short.toLowerCase() + " envelope has " + Math.max(0, remainingBudget(state, issue.domain)) + " DHN left; this task needs " + issue.cost + " DHN.";
    if (reason === "confidence") return "Two evidence checks failed on: " + issue.title + ". Authorise a third attempt or park it?";
    return "Confirm the next step for: " + issue.title + ".";
}

function consequenceFor(reason, issue) {
    if (reason === "treasury") return "Without it the work waits for the next funding window, about two weeks.";
    if (reason === "permit") return "Acting without a permit exposes the resident crew to liability.";
    if (reason === "safety-critical") return "The hazard stays open; the agent keeps it flagged and rechecks daily.";
    if (reason === "rights") return "The agent keeps collecting names but will not act until you decide.";
    if (reason === "budget") return "The task stays in backlog and may miss its seasonal window.";
    if (reason === "confidence") return "A third blind retry is likely to repeat the same gap.";
    return "The task stays in the backlog until someone answers.";
}

function hasOpenAsk(state, issueId) {
    for (var i = 0; i < state.escalations.length; ++i) {
        var ask = state.escalations[i];
        if (ask.issueId === issueId && (ask.status === "open" || ask.status === "batched")) return true;
    }
    return false;
}

function escalate(state, issue, reason) {
    state.counters.ask += 1;
    var persona = personaById(issue.owner) || PERSONAS[0];
    var sameDay = 0;
    for (var i = 0; i < state.escalations.length; ++i) {
        var existing = state.escalations[i];
        if (existing.persona === issue.owner && existing.openedDay === state.day && existing.status !== "signed" && existing.status !== "declined") sameDay += 1;
    }
    var batched = sameDay >= persona.askCap;
    var ask = {
        id: "ASK-" + pad(state.counters.ask, 3),
        issueId: issue.id,
        persona: issue.owner,
        domain: issue.domain,
        reason: reason,
        status: batched ? "batched" : "open",
        day: batched ? state.day + 1 : state.day,
        openedDay: state.day,
        deadline: state.day + 2,
        cost: issue.cost,
        ask: askTextFor(reason, issue),
        consequence: consequenceFor(reason, issue),
        title: issue.title
    };
    state.escalations.push(ask);
    issue.escalation = ask.id;
    if (!issue.action) issue.action = pickAction(state, issue);
    return ask;
}

function openAsks(state) {
    var out = [];
    for (var i = 0; i < state.escalations.length; ++i) {
        if (state.escalations[i].status === "open") out.push(state.escalations[i]);
    }
    return out;
}

function batchedAsks(state) {
    var out = [];
    for (var i = 0; i < state.escalations.length; ++i) {
        if (state.escalations[i].status === "batched") out.push(state.escalations[i]);
    }
    return out;
}

function sign(state, id) {
    var ask = findAsk(state, id);
    if (!ask || (ask.status !== "open" && ask.status !== "batched")) return state;
    ask.status = "signed";
    var issue = findIssue(state, ask.issueId);
    if (issue && issue.status !== "closed" && issue.status !== "parked") {
        issue.status = "actioned";
        issue.actionDay = state.day;
        if (!issue.action) issue.action = pickAction(state, issue);
        spend(state, issue.domain, ask.cost);
        var stats = state.dayStats[state.day];
        if (stats) {
            stats.actions += 1;
            stats.domainActions[issue.domain] = (stats.domainActions[issue.domain] || 0) + 1;
            stats.zoneActions[issue.zone] = (stats.zoneActions[issue.zone] || 0) + 1;
        }
    }
    pushLog(state, "sign", "you", "You signed \"" + ask.title + "\" (" + ask.cost + " DHN). The agent proceeds and will verify with evidence.", [ask.issueId], "good");
    return state;
}

function decline(state, id) {
    var ask = findAsk(state, id);
    if (!ask || (ask.status !== "open" && ask.status !== "batched")) return state;
    ask.status = "declined";
    var issue = findIssue(state, ask.issueId);
    var message = "You declined \"" + ask.title + "\".";
    if (issue) {
        issue.declines += 1;
        if (issue.declines >= 2 || ask.reason === "confidence") {
            issue.status = "parked";
            message += " The agent parked it and noted why.";
            pushLog(state, "decline", "you", message, [issue.id], "bad");
        } else {
            issue.status = "backlog";
            issue.owner = null;
            issue.assignedDay = 0;
            message += " It returns to the board with your note.";
            pushLog(state, "decline", "you", message, [issue.id], "warn");
        }
    } else {
        pushLog(state, "decline", "you", message, [], "warn");
    }
    return state;
}

function dawnPhase(state) {
    var stats = { opened: 0, closed: 0, actions: 0, asks: 0, humanMinutes: 0, zoneActions: {}, domainActions: {}, assigned: {}, reopened: 0 };
    state.dayStats[state.day] = stats;
    var count = 2 + (rng(state) < 0.55 ? 1 : 0) + (rng(state) < 0.2 ? 1 : 0);
    var used = {};
    var opened = 0;
    for (var i = 0; i < count; ++i) {
        var tpl = pickTemplate(state, used);
        if (!tpl) break;
        used[tpl.id] = true;
        var issue = addIssue(state, tpl.id);
        issue.status = "backlog";
        stats.opened += 1;
        opened += 1;
        pushLog(state, "scan", "system", "New report · " + issue.title + " (" + zoneById(issue.zone).short + ").", [issue.id], issue.urgency >= 4 ? "warn" : "neutral");
    }
    for (var e = 0; e < state.escalations.length; ++e) {
        var ask = state.escalations[e];
        if (ask.status === "batched" && ask.day <= state.day) {
            ask.status = "open";
            pushLog(state, "escalate", ask.persona, "Held ask released from yesterday's digest.", [ask.issueId], "warn");
        }
    }
    pushLog(state, "scan", "system", "Day " + state.day + " scan: " + opened + " report(s), " + backlogCount(state) + " in backlog.", [], "neutral");
}

function triagePhase(state) {
    var order = [];
    for (var i = 0; i < state.issues.length; ++i) {
        if (state.issues[i].status === "backlog") order.push(state.issues[i]);
    }
    order.sort(function (a, b) {
        var bonusA = state.fairness.focus && a.zone === state.fairness.focus ? 12 : 0;
        var bonusB = state.fairness.focus && b.zone === state.fairness.focus ? 12 : 0;
        return (b.score + bonusB) - (a.score + bonusA);
    });
    var assigned = 0;
    for (var k = 0; k < order.length; ++k) {
        var issue = order[k];
        var owner = pickOwner(state, issue);
        if (!owner) continue;
        issue.status = "assigned";
        issue.owner = owner.id;
        if (!issue.assignedDay) issue.assignedDay = state.day;
        assigned += 1;
        var stats = state.dayStats[state.day];
        stats.assigned[owner.id] = (stats.assigned[owner.id] || 0) + 1;
        pushLog(state, "assign", owner.id, owner.agent + " takes \"" + issue.title + "\" (" + domainById(issue.domain).short + " · " + issue.risk + " risk).", [issue.id], "neutral");
    }
    for (var r = 0; r < order.length; ++r) {
        var waiting = order[r];
        if (waiting.status !== "backlog") continue;
        var freed = relieveFor(state, waiting);
        if (!freed) continue;
        waiting.status = "assigned";
        waiting.owner = freed.id;
        waiting.assignedDay = state.day;
        state.dayStats[state.day].assigned[freed.id] = (state.dayStats[state.day].assigned[freed.id] || 0) + 1;
        assigned += 1;
        pushLog(state, "assign", freed.id, freed.agent + " takes \"" + waiting.title + "\" after the trade (" + domainById(waiting.domain).short + " · " + waiting.risk + " risk).", [waiting.id], "neutral");
    }
    balanceLoads(state);
    if (state.fairness.focus) {
        pushLog(state, "fairness", "facilitator", "Triage gave " + zoneById(state.fairness.focus).name + " first look today.", [], "neutral");
        state.fairness.focus = null;
    }
    if (assigned === 0) pushLog(state, "assign", "system", "No free agent matched today's backlog. " + backlogCount(state) + " report(s) wait.", [], "warn");
}

function actPhase(state) {
    var stats = state.dayStats[state.day] || { actions: 0, asks: 0, zoneActions: {}, domainActions: {} };
    var acted = 0;
    var escalated = 0;
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.status !== "assigned") continue;
        if (hasOpenAsk(state, issue.id)) continue;
        var guardian = personaById(domainById(issue.domain).guardian);
        if (issue.risk === "high" && guardian && guardian.id !== issue.owner) {
            var ownerRole = personaById(issue.owner);
            var holderStats = state.dayStats[state.day] || { assigned: {} };
            if (ownerRole && (ownerRole.capability[issue.domain] || 0) < (guardian.capability[issue.domain] || 0) &&
                    activeCount(state, guardian.id) < 2 && (holderStats.assigned[guardian.id] || 0) < 3) {
                var handedFrom = issue.owner;
                issue.owner = guardian.id;
                issue.handoffFrom = handedFrom;
                if (!issue.partner) issue.partner = handedFrom;
                holderStats.assigned[guardian.id] = (holderStats.assigned[guardian.id] || 0) + 1;
                recordPair(state, handedFrom, guardian.id, "handoffs");
                pushLog(state, "handoff", handedFrom, actorAgent(handedFrom) + " hands the high-risk \"" + issue.title + "\" to " + actorAgent(guardian.id) + " and stays on as partner.", [issue.id], "warn");
            }
        }
        if (!issue.consulted) {
            issue.consulted = true;
            if (guardian && guardian.id !== issue.owner) {
                recordPair(state, issue.owner, guardian.id, "consults");
                pushLog(state, "consult", issue.owner, actorAgent(issue.owner) + " asks " + actorAgent(guardian.id) + " for the " + domainById(issue.domain).short.toLowerCase() + " call on \"" + issue.title + "\".", [issue.id], "neutral");
                pushLog(state, "consult", guardian.id, actorAgent(guardian.id) + " " + domainById(issue.domain).reply + ".", [issue.id], "neutral");
            } else if (issue.risk !== "low" || issue.effort >= 3) {
                var second = pickReviewer(state, issue);
                if (second) {
                    recordPair(state, issue.owner, second.id, "consults");
                    pushLog(state, "consult", issue.owner, actorAgent(issue.owner) + " asks " + actorAgent(second.id) + " to second-read the " + domainById(issue.domain).short.toLowerCase() + " plan for \"" + issue.title + "\".", [issue.id], "neutral");
                    pushLog(state, "consult", second.id, actorAgent(second.id) + " reads it back and flags one assumption to test first.", [issue.id], "neutral");
                }
            }
        }
        var reason = escalationReason(state, issue);
        if (reason) {
            var ask = escalate(state, issue, reason);
            issue.status = "awaiting";
            stats.asks += 1;
            escalated += 1;
            if (ask.status === "batched") {
                pushLog(state, "escalate", issue.owner, "Ask for \"" + issue.title + "\" is held for tomorrow's digest (one human, one bundle).", [issue.id], "neutral");
            } else {
                pushLog(state, "escalate", issue.owner, actorAgent(issue.owner) + " · " + ask.ask, [issue.id], reason === "safety-critical" ? "bad" : "warn");
            }
            continue;
        }
        if (!issue.partner && (issue.effort >= 3 || issue.risk === "high")) {
            var partner = pickPartner(state, issue);
            if (partner) {
                issue.partner = partner.id;
                recordPair(state, issue.owner, partner.id, "joint");
                pushLog(state, "joint", issue.owner, actorAgent(issue.owner) + " and " + actorAgent(partner.id) + " pair up on \"" + issue.title + "\" before booking the crew.", [issue.id], "neutral");
            }
        }
        var action = pickAction(state, issue);
        issue.action = action;
        spend(state, issue.domain, issue.cost);
        issue.status = "actioned";
        issue.actionDay = state.day;
        stats.actions += 1;
        stats.domainActions[issue.domain] = (stats.domainActions[issue.domain] || 0) + 1;
        stats.zoneActions[issue.zone] = (stats.zoneActions[issue.zone] || 0) + 1;
        acted += 1;
        var together = issue.partner ? " + " + actorAgent(issue.partner) : "";
        pushLog(state, "action", issue.owner, actorAgent(issue.owner) + together + " · " + action, [issue.id], "good");
    }
    if (acted || escalated) pushLog(state, "action", "system", "Action round: " + acted + " moved with evidence, " + escalated + " ask(s) wait on a human.", [], "neutral");
}

function verifyPhase(state) {
    var stats = state.dayStats[state.day] || { closed: 0, humanMinutes: 0, reopened: 0 };
    var closed = 0;
    var reopened = 0;
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.status !== "actioned" || issue.actionDay > state.day) continue;
        var reviewer = pickReviewer(state, issue);
        var threshold = issue.risk === "high" ? 0.92 : 0.86;
        if (reviewer) {
            issue.verifiedBy = reviewer.id;
            recordPair(state, reviewer.id, issue.owner, "reviews");
        }
        if (rng(state) <= threshold) {
            issue.status = "closed";
            issue.closedDay = state.day;
            stats.closed += 1;
            stats.humanMinutes += issue.humanMinutes;
            closed += 1;
            if (reviewer) {
                pushLog(state, "review", reviewer.id, actorAgent(reviewer.id) + " peer-checked " + actorAgent(issue.owner) + "'s evidence for \"" + issue.title + "\" (" + issue.evidence + ") and closed it.", [issue.id], "good");
            } else {
                pushLog(state, "verify", issue.owner, "Closed \"" + issue.title + "\". Evidence: " + issue.evidence + " (simulated, day " + state.day + ").", [issue.id], "good");
            }
        } else {
            issue.status = "backlog";
            issue.retries += 1;
            stats.reopened += 1;
            reopened += 1;
            if (reviewer) {
                pushLog(state, "review", reviewer.id, actorAgent(reviewer.id) + " sent \"" + issue.title + "\" back to " + actorAgent(issue.owner) + ": evidence was incomplete.", [issue.id], "bad");
            } else {
                pushLog(state, "verify", issue.owner, "Reopened \"" + issue.title + "\": evidence was incomplete.", [issue.id], "bad");
            }
        }
    }
    if (!closed && !reopened) pushLog(state, "verify", "system", "Nothing to verify yet today.", [], "neutral");
}

function pickIgnoredZone(state, excludeZone) {
    var best = null;
    var bestCount = 0;
    for (var i = 0; i < ZONES.length; ++i) {
        var zone = ZONES[i].id;
        if (zone === excludeZone) continue;
        var count = zoneBacklog(state, zone);
        if (count > bestCount) {
            bestCount = count;
            best = zone;
        }
    }
    return bestCount >= 2 ? best : null;
}

function facilitatorCheck(state) {
    var stats = state.dayStats[state.day];
    if (!stats) return null;
    var total = 0;
    var maxZone = null;
    var maxCount = 0;
    for (var zone in stats.zoneActions) {
        total += stats.zoneActions[zone];
        if (stats.zoneActions[zone] > maxCount) {
            maxCount = stats.zoneActions[zone];
            maxZone = zone;
        }
    }
    if (total < 3 || !maxZone) return null;
    if (maxCount / total < 0.6) return null;
    if (state.fairness.lastDay === state.day) return null;
    if (state.fairness.focus) return null;
    var ignored = pickIgnoredZone(state, maxZone);
    if (!ignored) return null;
    state.fairness.focus = ignored;
    state.fairness.lastDay = state.day;
    state.fairness.posts += 1;
    pushLog(state, "fairness", "facilitator", "Fairness check: " + maxCount + " of " + total + " actions landed in " + zoneById(maxZone).name + " while " + zoneById(ignored).name + " still has " + zoneBacklog(state, ignored) + " open. Tomorrow starts with " + zoneById(ignored).name + ".", [], "warn");
    return ignored;
}

function duskPhase(state) {
    var stats = state.dayStats[state.day] || { opened: 0, closed: 0, actions: 0, asks: 0, humanMinutes: 0, reopened: 0 };
    var digest = {
        day: state.day,
        opened: stats.opened,
        closed: stats.closed,
        actions: stats.actions,
        asks: stats.asks,
        humanMinutes: stats.humanMinutes,
        humanHours: Math.round(stats.humanMinutes / 6) / 10,
        reopened: stats.reopened
    };
    state.digests.push(digest);
    pushLog(state, "digest", "system", "Dusk report: " + digest.closed + " closed, " + digest.actions + " action(s), " + digest.asks + " ask(s), " + digest.humanHours + " human hour(s) returned.", [], "neutral");
    facilitatorCheck(state);
    var waiting = openAsks(state).length;
    if (waiting > 0) pushLog(state, "digest", "system", waiting + " ask(s) wait in your inbox.", [], "warn");
}

function mostCommonDomain(state, ids) {
    var counts = {};
    var best = null;
    var bestCount = 0;
    for (var i = 0; i < ids.length; ++i) {
        var issue = findIssue(state, ids[i]);
        if (!issue) continue;
        counts[issue.domain] = (counts[issue.domain] || 0) + 1;
        if (counts[issue.domain] > bestCount) {
            bestCount = counts[issue.domain];
            best = issue.domain;
        }
    }
    return best || "water";
}

function reflectionTakeaway(persona, closed, waiting, carried, assisted, partners, domain) {
    var parts = [];
    if (closed > 0) parts.push("closed " + closed);
    if (assisted > 0) parts.push("helped a peer on " + assisted);
    if (carried > 0) parts.push("carried " + carried + " into tomorrow");
    if (waiting > 0) parts.push("left " + waiting + " for a human signature");
    if (!parts.length) parts.push("kept the " + domainById(domain).short.toLowerCase() + " board moving");
    var line = persona.agent + ": " + parts.join(", ") + ". " + persona.voice;
    if (partners.length) line += " Worked with " + partners.join(", ") + ".";
    return line;
}

function intentionLine(persona, domain) {
    return "Recheck the " + domainById(domain).short.toLowerCase() + " queue before the " + zoneById(persona.zone).short.toLowerCase() + " walk.";
}

function nightPhase(state) {
    var count = 0;
    for (var i = 0; i < PERSONAS.length; ++i) {
        var persona = PERSONAS[i];
        var saw = [];
        var closed = 0;
        var waiting = 0;
        var carried = 0;
        var assisted = 0;
        var partners = [];
        for (var j = 0; j < state.issues.length; ++j) {
            var issue = state.issues[j];
            var mine = issue.owner === persona.id;
            var helped = issue.partner === persona.id || issue.verifiedBy === persona.id;
            if (!mine && !helped) continue;
            var touched = issue.assignedDay === state.day || issue.actionDay === state.day || issue.closedDay === state.day;
            if (!touched) continue;
            saw.push(issue.id);
            if (!mine) {
                assisted += 1;
                var links = [issue.owner, issue.partner, issue.verifiedBy];
                for (var l = 0; l < links.length; ++l) {
                    var other = links[l];
                    if (!other || other === persona.id) continue;
                    var otherAgent = actorAgent(other);
                    if (partners.indexOf(otherAgent) === -1) partners.push(otherAgent);
                }
                continue;
            }
            if (issue.status === "closed") closed += 1;
            else if (issue.status === "awaiting") waiting += 1;
            else carried += 1;
        }
        if (!saw.length) continue;
        var domain = mostCommonDomain(state, saw);
        state.reflections.push({
            day: state.day,
            persona: persona.id,
            agent: persona.agent,
            saw: saw,
            partners: partners,
            assisted: assisted,
            takeaway: reflectionTakeaway(persona, closed, waiting, carried, assisted, partners, domain),
            unresolved: waiting > 0 ? "Waiting on your signature for " + waiting + " task(s)." : "No task is waiting on a human.",
            intention: intentionLine(persona, domain),
            honesty: "Rule-generated from witnessed issues only. Unverified, not a human statement."
        });
        count += 1;
    }
    pushLog(state, "night", "system", count + " agent reflection(s) filed for day " + state.day + ".", [], "neutral");
}

function advance(state) {
    if (state.done) return state;
    var phase = state.phase;
    if (phase === "dawn") dawnPhase(state);
    else if (phase === "triage") triagePhase(state);
    else if (phase === "act") actPhase(state);
    else if (phase === "verify") verifyPhase(state);
    else if (phase === "dusk") duskPhase(state);
    else if (phase === "night") nightPhase(state);
    if (phase === "night") {
        if (state.day >= state.horizon) {
            state.done = true;
            state.phase = "night";
            pushLog(state, "system", "system", "Seven-day horizon reached. The simulation can be reset with a new seed.", [], "neutral");
        } else {
            state.day += 1;
            state.phase = "dawn";
        }
    } else {
        state.phase = PHASES[PHASES.indexOf(phase) + 1];
    }
    return state;
}

function median(values) {
    if (!values.length) return 0;
    var sorted = values.slice(0).sort(function (a, b) { return a - b; });
    var middle = Math.floor(sorted.length / 2);
    if (sorted.length % 2) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
}

function metrics(state) {
    var open = 0;
    var closed = 0;
    var parked = 0;
    var reopened = 0;
    var minutes = 0;
    var responses = [];
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        reopened += issue.retries;
        if (issue.status === "closed") {
            closed += 1;
            minutes += issue.humanMinutes;
            responses.push(Math.max(0, issue.closedDay - issue.reportedDay));
        } else if (issue.status === "parked") {
            parked += 1;
        } else {
            open += 1;
        }
    }
    var asks = 0;
    var batched = 0;
    for (var e = 0; e < state.escalations.length; ++e) {
        var ask = state.escalations[e];
        if (ask.status === "open") asks += 1;
        else if (ask.status === "batched") { asks += 1; batched += 1; }
    }
    var today = state.dayStats[state.day] || { domainActions: {} };
    var coverage = 0;
    var domainActions = today.domainActions || {};
    for (var d = 0; d < DOMAINS.length; ++d) if (domainActions[DOMAINS[d].id]) coverage += 1;
    var attempts = closed + reopened;
    return {
        opened: state.issues.length,
        open: open,
        closed: closed,
        parked: parked,
        reopened: reopened,
        asks: asks,
        batched: batched,
        medianResponse: responses.length ? median(responses) : 0,
        humanMinutes: minutes,
        humanHours: Math.round(minutes / 6) / 10,
        spent: state.budget.spent,
        left: state.budget.pool - state.budget.spent,
        coverage: coverage,
        trust: attempts > 0 ? closed / attempts : 1,
        consults: state.collab.consults || 0,
        joint: state.collab.joint || 0,
        handoffs: state.collab.handoffs || 0,
        reviews: state.collab.reviews || 0,
        links: collabLinks(state),
        day: state.day,
        horizon: state.horizon,
        done: state.done
    };
}

function digestToday(state) {
    for (var i = state.digests.length - 1; i >= 0; --i) {
        if (state.digests[i].day === state.day) return state.digests[i];
    }
    return null;
}

function latestReflections(state) {
    var latest = 0;
    for (var i = 0; i < state.reflections.length; ++i) {
        if (state.reflections[i].day > latest) latest = state.reflections[i].day;
    }
    var out = [];
    for (var j = 0; j < state.reflections.length; ++j) {
        if (state.reflections[j].day === latest) out.push(state.reflections[j]);
    }
    return out;
}

function recentLog(state, limit) {
    var out = [];
    for (var i = state.log.length - 1; i >= 0 && out.length < limit; --i) out.push(state.log[i]);
    return out;
}

function topIssues(state, domainId, limit) {
    var out = [];
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.domain !== domainId) continue;
        if (issue.status === "closed" || issue.status === "parked") continue;
        out.push(issue);
    }
    out.sort(function (a, b) { return b.score - a.score; });
    return out.slice(0, limit);
}

function domainStats(state, domainId) {
    var open = 0;
    var active = 0;
    var closed = 0;
    for (var i = 0; i < state.issues.length; ++i) {
        var issue = state.issues[i];
        if (issue.domain !== domainId) continue;
        if (issue.status === "closed") closed += 1;
        else if (issue.status === "parked") { /* not counted */ }
        else if (issue.status === "assigned" || issue.status === "actioned" || issue.status === "awaiting") { open += 1; active += 1; }
        else open += 1;
    }
    return { open: open, active: active, closed: closed, top: topIssues(state, domainId, 2) };
}

function statusLabel(status) {
    if (status === "reported") return "Reported";
    if (status === "backlog") return "Backlog";
    if (status === "assigned") return "Assigned";
    if (status === "actioned") return "Actioned";
    if (status === "awaiting") return "Awaiting you";
    if (status === "closed") return "Closed";
    if (status === "parked") return "Parked";
    return status;
}

function reasonLabel(reason) {
    if (reason === "treasury") return "Treasury";
    if (reason === "permit") return "Permit & liability";
    if (reason === "safety-critical") return "Safety-critical";
    if (reason === "rights") return "Rights & order";
    if (reason === "budget") return "Budget";
    if (reason === "confidence") return "Evidence";
    return "Decision";
}

function asksForPersona(state, personaId) {
    var out = [];
    for (var i = 0; i < state.escalations.length; ++i) {
        var ask = state.escalations[i];
        if (ask.persona === personaId && (ask.status === "open" || ask.status === "batched")) out.push(ask);
    }
    return out;
}
