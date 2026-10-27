.pragma library

var RULES = [
    {
        id: "node-day",
        label: "Run a Logos node",
        amount: 25,
        unit: "day",
        route: "Coordination room",
        evidence: "One node day is recorded per device per calendar day while the Logos Messaging node reports ready in Basecamp. Closing the app stops the clock."
    },
    {
        id: "field-task",
        label: "Complete field work",
        amount: 8,
        unit: "task",
        route: "Field calendar",
        evidence: "A task on the shared field calendar is marked done. Reopening it removes the unclaimed reward."
    },
    {
        id: "challenge-evidence",
        label: "File challenge evidence",
        amount: 15,
        unit: "challenge",
        route: "Challenges",
        evidence: "Evidence text is filed on a claimed cultivation window. Release still needs two signatures."
    },
    {
        id: "kitchen-plan",
        label: "File a kitchen plan",
        amount: 5,
        unit: "day",
        route: "Kitchen",
        evidence: "A built plan with sourcing, waste uses and a shelf-life route is filed. One filing counts per day."
    },
    {
        id: "steward-onboarding",
        label: "Onboard a steward",
        amount: 10,
        unit: "profile",
        route: "Signup",
        evidence: "A person creates a steward profile on this device. The profile joins the steward party."
    }
];

var STEWARD_RULES = ["steward-onboarding", "kitchen-plan", "field-task", "challenge-evidence", "node-day"];

function rule(id) {
    for (var i = 0; i < RULES.length; ++i)
        if (RULES[i].id === id) return RULES[i];
    return null;
}

function amountFor(id) {
    var entry = rule(id);
    return entry ? Number(entry.amount) : 0;
}

function labelFor(id) {
    var entry = rule(id);
    return entry ? entry.label : id;
}

function dateKey(timestamp) {
    var date = new Date(Number(timestamp) || Date.now());
    return date.getFullYear() + "-" +
        ("0" + (date.getMonth() + 1)).slice(-2) + "-" +
        ("0" + date.getDate()).slice(-2);
}

function entries(state) {
    return state && Array.isArray(state.rewards) ? state.rewards : [];
}

function forProfile(state, profileId) {
    var result = [];
    var list = entries(state);
    for (var i = 0; i < list.length; ++i)
        if (list[i].profileId === profileId && list[i].status !== "cancelled") result.push(list[i]);
    return result;
}

function forRole(state, roleId) {
    var result = [];
    var list = entries(state);
    for (var i = 0; i < list.length; ++i)
        if (list[i].role === roleId && list[i].status !== "cancelled") result.push(list[i]);
    return result;
}

function earnedForProfile(state, profileId) {
    var result = [];
    var list = forProfile(state, profileId);
    for (var i = 0; i < list.length; ++i)
        if (list[i].status === "earned") result.push(list[i]);
    return result;
}

function earnedForRole(state, roleId) {
    var result = [];
    var list = forRole(state, roleId);
    for (var i = 0; i < list.length; ++i)
        if (list[i].status === "earned") result.push(list[i]);
    return result;
}

function total(list) {
    var sum = 0;
    for (var i = 0; i < list.length; ++i) sum += Number(list[i].amount || 0);
    return sum;
}

function hasRef(state, ref) {
    var list = entries(state);
    for (var i = 0; i < list.length; ++i)
        if (list[i].ref === ref && list[i].status !== "cancelled") return true;
    return false;
}

function byRule(list) {
    var rows = [];
    for (var r = 0; r < RULES.length; ++r) {
        var count = 0;
        var sum = 0;
        for (var i = 0; i < list.length; ++i) {
            if (list[i].rule !== RULES[r].id) continue;
            count += 1;
            sum += Number(list[i].amount || 0);
        }
        if (count > 0)
            rows.push({ id: RULES[r].id, label: RULES[r].label, count: count, amount: sum });
    }
    return rows;
}

function profileTotals(state, personId) {
    var pending = total(earnedForProfile(state, personId));
    var paid = 0;
    var list = forProfile(state, personId);
    for (var i = 0; i < list.length; ++i)
        if (list[i].status === "paid") paid += Number(list[i].amount || 0);
    return { pending: pending, paid: paid, total: pending + paid };
}

function roleTotals(state, roleId) {
    var list = forRole(state, roleId);
    var pending = 0;
    var paid = 0;
    for (var i = 0; i < list.length; ++i) {
        if (list[i].status === "earned") pending += Number(list[i].amount || 0);
        else if (list[i].status === "paid") paid += Number(list[i].amount || 0);
    }
    return { pending: pending, paid: paid, total: pending + paid };
}

function pendingCount(state) {
    var list = entries(state);
    var count = 0;
    for (var i = 0; i < list.length; ++i)
        if (list[i].status === "earned") count += 1;
    return count;
}
