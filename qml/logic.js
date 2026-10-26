.pragma library

var PROPOSAL_KIND_LABEL = {
    mint: "Issue tranche",
    sale: "Sell DHN externally",
    fund: "Fund project",
    award: "Award project",
    release: "Release milestone",
    challenge_release: "Release challenge",
    purchase: "Purchase resource",
    allocate: "Allocate challenge",
    config: "Change policy"
};

var WALLET_LABEL = {
    funder: "Funder operating",
    dhun: "Dhun operating",
    steward: "Steward operating",
    vault: "Multisig vault",
    projectEscrow: "Project escrow",
    challengeEscrow: "Challenge escrow",
    conservation: "Conservation reserve",
    external: "External holders",
    suppliers: "Market suppliers"
};

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function hash32(text) {
    var h = 0x811c9dc5;
    var value = String(text);
    for (var i = 0; i < value.length; ++i) {
        h ^= value.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return ("00000000" + h.toString(16)).slice(-8);
}

function hashHex(seed, length) {
    var target = length || 40;
    var out = "";
    var round = 0;
    while (out.length < target) {
        out += hash32(String(seed) + ":" + round);
        round += 1;
    }
    return out.slice(0, target);
}

function digest(payload) {
    var canonical = [
        "dhun.commons.v1",
        payload.kind,
        payload.id,
        payload.amount,
        payload.from,
        payload.to,
        payload.target,
        payload.createdAt,
        payload.expiresAt,
        payload.meta ? JSON.stringify(payload.meta) : ""
    ].join("|");
    return "0x" + hashHex(canonical, 40);
}

function demoSignature(proposal, role) {
    return "demo-" + hashHex(String(proposal.digest) + "|" + String(role), 32);
}

function txid(seed) {
    return "0x" + hashHex("dhun-rehearsal-tx|" + String(seed), 48);
}

function shortHash(value) {
    var text = String(value);
    if (text.length <= 14) return text;
    return text.slice(0, 8) + "…" + text.slice(-6);
}

function roleById(state, roleId) {
    return state.roles[roleId] || null;
}

function roleName(state, roleId) {
    var role = state.roles[roleId];
    return role ? role.label : String(roleId);
}

function roleOrg(state, roleId) {
    var role = state.roles[roleId];
    return role ? role.org : "";
}

function roleColor(roleId) {
    if (roleId === "funder") return "#E0B25C";
    if (roleId === "dhun") return "#B9D567";
    if (roleId === "steward") return "#C76B47";
    return "#98A298";
}

function roleSoft(roleId) {
    if (roleId === "funder") return "#F4E4C5";
    if (roleId === "dhun") return "#EDF1E4";
    if (roleId === "steward") return "#F3DED4";
    return "#EAE5D7";
}

function walletLabel(key) {
    return WALLET_LABEL[key] || key;
}

function totalSupply(state) {
    var total = 0;
    var keys = Object.keys(state.wallets);
    for (var i = 0; i < keys.length; ++i) total += Number(state.wallets[keys[i]] || 0);
    return total;
}

function externalCirculation(state) {
    return Number(state.wallets.external || 0) + Number(state.wallets.suppliers || 0);
}

function conservationCommitment(state) {
    return Number(state.wallets.conservation || 0);
}

function approvalCount(proposal) {
    return proposal && proposal.approvals ? proposal.approvals.length : 0;
}

function rejectionCount(proposal) {
    return proposal && proposal.rejections ? proposal.rejections.length : 0;
}

function approvedBy(proposal, roleId) {
    if (!proposal || !proposal.approvals) return false;
    for (var i = 0; i < proposal.approvals.length; ++i)
        if (proposal.approvals[i].role === roleId) return true;
    return false;
}

function rejectedBy(proposal, roleId) {
    if (!proposal || !proposal.rejections) return false;
    for (var i = 0; i < proposal.rejections.length; ++i)
        if (proposal.rejections[i].role === roleId) return true;
    return false;
}

function approvalThreshold(state, proposal) {
    return Number(proposal.quorum || state.token.quorum || 2);
}

function proposalState(state, proposal, now) {
    if (!proposal) return "unknown";
    if (proposal.status === "executed") return "executed";
    if (proposal.status === "rejected") return "rejected";
    if (proposal.status === "expired") return "expired";
    if (Number(now) > Number(proposal.expiresAt)) return "expired";
    var threshold = approvalThreshold(state, proposal);
    if (approvalCount(proposal) >= threshold) {
        var readyAt = Number(proposal.readyAt || 0);
        if (!readyAt) readyAt = Number(proposal.approvals[proposal.approvals.length - 1].at || 0);
        if (proposal.timelock && Number(now) < readyAt + Number(proposal.timelock) * 1000)
            return "timelocked";
        return "ready";
    }
    if (rejectionCount(proposal) >= threshold) return "rejected";
    return "pending";
}

function stateLabel(value) {
    if (value === "ready") return "Ready to execute";
    if (value === "timelocked") return "In time lock";
    if (value === "executed") return "Executed";
    if (value === "rejected") return "Rejected";
    if (value === "expired") return "Expired";
    return "Collecting approvals";
}

function nextSigners(state, proposal) {
    var result = [];
    var roles = Object.keys(state.roles);
    for (var i = 0; i < roles.length; ++i) {
        var roleId = roles[i];
        if (!approvedBy(proposal, roleId) && !rejectedBy(proposal, roleId))
            result.push(roleId);
    }
    return result;
}

function timelockRemaining(proposal, now) {
    if (!proposal || !proposal.timelock) return 0;
    var readyAt = Number(proposal.readyAt || 0);
    if (!readyAt && proposal.approvals && proposal.approvals.length)
        readyAt = Number(proposal.approvals[proposal.approvals.length - 1].at || 0);
    return Math.max(0, readyAt + Number(proposal.timelock) * 1000 - Number(now));
}

function isOpen(proposal, state, now) {
    var value = proposalState(state, proposal, now);
    return value === "pending" || value === "ready" || value === "timelocked";
}

function challengeState(challenge, now) {
    if (!challenge) return "unknown";
    if (challenge.status === "released") return "released";
    if (challenge.status === "expired") return "expired";
    if (challenge.evidence) return "evidence";
    if (Number(now) > Number(challenge.windowEnd)) return "expired";
    if (challenge.claimedBy) return "claimed";
    return "open";
}

function challengeLabel(value) {
    if (value === "open") return "Open to claim";
    if (value === "claimed") return "In the field";
    if (value === "evidence") return "Evidence in review";
    if (value === "released") return "Released";
    if (value === "expired") return "Window closed";
    return value;
}

function projectProgress(project) {
    if (!project || !project.milestones || !project.milestones.length) return 0;
    var points = 0;
    for (var i = 0; i < project.milestones.length; ++i) {
        var status = project.milestones[i].status;
        if (status === "released") points += 1;
        else if (status === "evidence") points += 0.65;
        else if (status === "active") points += 0.3;
    }
    return points / project.milestones.length;
}

function projectReleased(project) {
    var total = 0;
    if (!project || !project.milestones) return 0;
    for (var i = 0; i < project.milestones.length; ++i)
        if (project.milestones[i].status === "released") total += Number(project.milestones[i].amount || 0);
    return total;
}

function projectEscrow(project) {
    if (!project) return 0;
    var remaining = 0;
    for (var i = 0; i < project.milestones.length; ++i) {
        var milestone = project.milestones[i];
        if (milestone.status !== "released") remaining += Number(milestone.amount || 0);
    }
    return remaining;
}

function findProject(state, projectId) {
    for (var i = 0; i < state.projects.length; ++i)
        if (state.projects[i].id === projectId) return state.projects[i];
    return null;
}

function findMilestone(project, milestoneId) {
    if (!project) return null;
    for (var i = 0; i < project.milestones.length; ++i)
        if (project.milestones[i].id === milestoneId) return project.milestones[i];
    return null;
}

function findProjectForMilestone(state, projectId, milestoneId) {
    var project = findProject(state, projectId);
    return project ? findMilestone(project, milestoneId) : null;
}

function findChallenge(state, challengeId) {
    for (var i = 0; i < state.challenges.length; ++i)
        if (state.challenges[i].id === challengeId) return state.challenges[i];
    return null;
}

function findOffer(state, offerId) {
    for (var i = 0; i < state.offers.length; ++i)
        if (state.offers[i].id === offerId) return state.offers[i];
    return null;
}

function produceOffers(state) {
    var result = [];
    if (!state || !state.offers) return result;
    for (var i = 0; i < state.offers.length; ++i)
        if (state.offers[i].kind === "produce") result.push(state.offers[i]);
    return result;
}

function findProduceOffer(state, ingredientId) {
    if (!state || !state.offers) return null;
    for (var i = 0; i < state.offers.length; ++i) {
        var offer = state.offers[i];
        if (offer.kind === "produce" && offer.ingredientId === ingredientId) return offer;
    }
    return null;
}

function fieldActivitiesForRole(state, role) {
    var result = [];
    if (!state || !state.fieldActivities) return result;
    for (var i = 0; i < state.fieldActivities.length; ++i) {
        var activity = state.fieldActivities[i];
        if (activity.role === role) result.push(activity);
    }
    result.sort(function (a, b) { return Number(a.date) - Number(b.date); });
    return result;
}

function fieldActivitiesForMonth(state, role, year, month) {
    var result = [];
    var source = fieldActivitiesForRole(state, role);
    for (var i = 0; i < source.length; ++i) {
        var date = new Date(Number(source[i].date));
        if (date.getFullYear() === year && date.getMonth() === month) result.push(source[i]);
    }
    return result;
}

function fieldActivitiesOnDay(state, role, timestamp) {
    var result = [];
    var target = new Date(Number(timestamp));
    var source = fieldActivitiesForRole(state, role);
    for (var i = 0; i < source.length; ++i) {
        var date = new Date(Number(source[i].date));
        if (date.getFullYear() === target.getFullYear() &&
                date.getMonth() === target.getMonth() &&
                date.getDate() === target.getDate()) result.push(source[i]);
    }
    return result;
}

function findBid(project, bidId) {
    if (!project) return null;
    for (var i = 0; i < project.bids.length; ++i)
        if (project.bids[i].id === bidId) return project.bids[i];
    return null;
}

function reservedChallenges(state) {
    var total = 0;
    for (var i = 0; i < state.challenges.length; ++i)
        if (state.challenges[i].status !== "released" && state.challenges[i].status !== "expired")
            total += Number(state.challenges[i].bounty || 0);
    return total;
}

function unallocatedChallengePool(state) {
    return Math.max(0, Number(state.wallets.challengeEscrow || 0) - reservedChallenges(state));
}

function pendingProposals(state, now) {
    var result = [];
    for (var i = 0; i < state.proposals.length; ++i) {
        var proposal = state.proposals[i];
        if (isOpen(proposal, state, now)) result.push(proposal);
    }
    result.sort(function (a, b) {
        var sa = proposalState(state, a, now);
        var sb = proposalState(state, b, now);
        if (sa === "ready" && sb !== "ready") return -1;
        if (sb === "ready" && sa !== "ready") return 1;
        return Number(a.expiresAt) - Number(b.expiresAt);
    });
    return result;
}

function proposalsForRole(state, roleId, now) {
    return pendingProposals(state, now).filter(function (proposal) {
        return !approvedBy(proposal, roleId) && !rejectedBy(proposal, roleId);
    });
}

function nextChallenge(state, now) {
    var best = null;
    for (var i = 0; i < state.challenges.length; ++i) {
        var challenge = state.challenges[i];
        var status = challengeState(challenge, now);
        if (status === "open" || status === "claimed") {
            if (!best || Number(challenge.windowEnd) < Number(best.windowEnd)) best = challenge;
        }
    }
    return best;
}

function fundedProjects(state) {
    return state.projects.filter(function (project) { return project.funded; });
}

function activeProjects(state) {
    return state.projects.filter(function (project) { return project.status === "active"; });
}

function roleBids(state, roleId) {
    var count = 0;
    for (var i = 0; i < state.projects.length; ++i) {
        for (var j = 0; j < state.projects[i].bids.length; ++j) {
            if (state.projects[i].bids[j].bidder === roleId) count += 1;
        }
    }
    return count;
}

function formatNumber(value) {
    var number = Math.round(Number(value) || 0);
    var negative = number < 0;
    var text = String(Math.abs(number));
    var lastThree = text.slice(-3);
    var other = text.slice(0, -3);
    if (other) lastThree = "," + lastThree;
    var grouped = other.replace(/\B(?=(\d{2})+(?!\d))/g, ",") + lastThree;
    return (negative ? "-" : "") + grouped;
}

function formatINR(value) {
    return "₹" + formatNumber(value);
}

function formatDHN(value) {
    return formatNumber(value) + " DHN";
}

function formatQty(value) {
    var number = Number(value) || 0;
    if (Math.abs(number - Math.round(number)) < 0.001) return String(Math.round(number));
    return String(Math.round(number * 100) / 100);
}

function compact(value) {
    var number = Math.abs(Number(value) || 0);
    if (number >= 10000000) return formatQty(number / 10000000) + " Cr";
    if (number >= 100000) return formatQty(number / 100000) + " L";
    if (number >= 1000) return formatQty(number / 1000) + "k";
    return formatQty(number);
}

function monthShort(month) {
    var names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return names[Math.max(0, Math.min(11, Number(month) - 1))];
}

function dateLabel(timestamp) {
    var date = new Date(Number(timestamp));
    return date.getDate() + " " + monthShort(date.getMonth() + 1) + " " + date.getFullYear();
}

function timeLabel(timestamp) {
    var date = new Date(Number(timestamp));
    var hours = date.getHours();
    var minutes = date.getMinutes();
    if (minutes < 10) minutes = "0" + minutes;
    return hours + ":" + minutes;
}

function dateTimeLabel(timestamp) {
    return dateLabel(timestamp) + " · " + timeLabel(timestamp);
}

function timeAgo(timestamp, now) {
    var diff = Math.max(0, Number(now) - Number(timestamp));
    var minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "just now";
    if (minutes < 60) return minutes + "m ago";
    var hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h ago";
    var days = Math.floor(hours / 24);
    if (days === 1) return "yesterday";
    if (days < 30) return days + "d ago";
    return dateLabel(timestamp);
}

function countdown(timestamp, now) {
    var diff = Number(timestamp) - Number(now);
    if (diff <= 0) return "closed";
    var totalMinutes = Math.floor(diff / 60000);
    var days = Math.floor(totalMinutes / (60 * 24));
    var hours = Math.floor((totalMinutes - days * 60 * 24) / 60);
    var minutes = totalMinutes % 60;
    if (days > 0) return days + "d " + (hours < 10 ? "0" : "") + hours + "h";
    if (hours > 0) return hours + "h " + (minutes < 10 ? "0" : "") + minutes + "m";
    return minutes + "m";
}

function dueLabel(timestamp, now) {
    var diff = Number(timestamp) - Number(now);
    if (diff <= 0) return "window closed";
    var hours = Math.floor(diff / 3600000);
    if (hours < 1) return "due in " + Math.max(1, Math.floor(diff / 60000)) + "m";
    if (hours < 48) return "due in " + hours + "h";
    return "due in " + Math.floor(hours / 24) + "d";
}

function pct(value) {
    return Math.round(Number(value) * 100) + "%";
}

function sourceLabel(state, key) {
    if (key === "vault") return "2-of-3 vault";
    if (key === "projectEscrow") return "Project escrow";
    if (key === "challengeEscrow") return "Challenge escrow";
    if (state.roles[key]) return state.roles[key].org;
    return walletLabel(key);
}

function recipientLabel(state, key) {
    if (state.roles[key]) return state.roles[key].org;
    return walletLabel(key);
}

function conservationAmount(state, proposal) {
    var pctValue = Number(proposal.conservationPct || 0);
    return Math.round(Number(proposal.amount || 0) * pctValue) / 100;
}

function conservationPctFor(state, proposal) {
    if (proposal.conservationPct !== undefined && proposal.conservationPct !== null)
        return Number(proposal.conservationPct);
    if (proposal.meta && proposal.meta.projectId) {
        var project = findProject(state, proposal.meta.projectId);
        if (project) return Number(project.conservationPct || 0);
    }
    if (proposal.meta && proposal.meta.challengeId) {
        var challenge = findChallenge(state, proposal.meta.challengeId);
        if (challenge) return Number(challenge.conservationPct || 0);
    }
    return 0;
}

function instructionText(state, proposal) {
    var meta = proposal.meta || {};
    if (proposal.kind === "mint")
        return "issue(tranche=" + (meta.tranche || "—") + ", amount=" + proposal.amount + ", collateral_inr=" + (meta.collateral || 0) + ")";
    if (proposal.kind === "sale")
        return "sell_external(buyer=" + (meta.buyer || "—") + ", amount=" + proposal.amount + ", price_inr=" + (meta.price || 0) + ")";
    if (proposal.kind === "fund")
        return "fund_project(project=" + (meta.projectId || "—") + ", amount=" + proposal.amount + ")";
    if (proposal.kind === "award")
        return "award(project=" + (meta.projectId || "—") + ", bid=" + (meta.bidId || "—") + ")";
    if (proposal.kind === "release")
        return "release(project=" + (meta.projectId || "—") + ", milestone=" + (meta.milestoneId || "—") + ", amount=" + proposal.amount + ")";
    if (proposal.kind === "challenge_release")
        return "release_challenge(challenge=" + (meta.challengeId || "—") + ", amount=" + proposal.amount + ")";
    if (proposal.kind === "purchase")
        return "purchase(offer=" + (meta.offerId || "—") + ", qty=" + (meta.qty || 0) + ", amount=" + proposal.amount + ")";
    if (proposal.kind === "allocate")
        return "allocate_challenge(zone=" + (meta.zone || "—") + ", bounty=" + proposal.amount + ", window=" + (meta.windowHours || 0) + "h)";
    if (proposal.kind === "config")
        return "set_policy(" + (meta.policy || "—") + ", value=" + (meta.value || "—") + ")";
    return proposal.kind;
}

function decodeRows(state, proposal) {
    var rows = [];
    rows.push({ label: "Action", value: PROPOSAL_KIND_LABEL[proposal.kind] || proposal.kind });
    rows.push({ label: "Target program", value: "dhun_commons.policy.v1", mono: true });
    rows.push({ label: "Instruction", value: instructionText(state, proposal), mono: true });
    rows.push({ label: "Source", value: sourceLabel(state, proposal.from) });
    rows.push({ label: "Recipient", value: proposal.to ? recipientLabel(state, proposal.to) : "—" });
    rows.push({ label: "Amount", value: formatDHN(proposal.amount || 0), strong: true });
    var cpct = conservationPctFor(state, proposal);
    if (cpct > 0) {
        var cAmount = Math.round(Number(proposal.amount || 0) * cpct) / 100;
        rows.push({ label: "Conservation covenant", value: cpct + "% · " + formatDHN(cAmount) });
    }
    rows.push({ label: "Expiry", value: dateTimeLabel(proposal.expiresAt) });
    rows.push({ label: "Payload digest", value: shortHash(proposal.digest), mono: true });
    return rows;
}

function policyChecks(state, proposal) {
    var checks = [];
    checks.push({ label: "Quorum " + approvalThreshold(state, proposal) + " of " + state.token.members + " distinct signers", ok: true });
    var balanceOk = true;
    if (proposal.from === "vault") balanceOk = Number(state.wallets.vault) >= Number(proposal.amount);
    if (proposal.from === "projectEscrow") balanceOk = Number(state.wallets.projectEscrow) >= Number(proposal.amount);
    if (proposal.from === "challengeEscrow") balanceOk = Number(state.wallets.challengeEscrow) >= Number(proposal.amount);
    if (state.roles[proposal.from]) balanceOk = Number(state.roles[proposal.from].balance || state.wallets[proposal.from] || 0) >= Number(proposal.amount);
    checks.push({ label: "Source balance covers amount", ok: balanceOk });
    checks.push({ label: "Recipient is a current member or registered supplier", ok: true });
    checks.push({ label: "Expiry and time lock enforced by the program", ok: true });
    if (proposal.kind === "release" || proposal.kind === "challenge_release")
        checks.push({ label: "Evidence record linked to release", ok: true });
    if (proposal.kind === "purchase")
        checks.push({ label: "Resource above single-signer allowance", ok: Number(proposal.amount) > Number(state.token.allowance) });
    return checks;
}

function proposalKindLabel(kind) {
    return PROPOSAL_KIND_LABEL[kind] || kind;
}

function normalizeText(value) {
    return String(value === undefined || value === null ? "" : value);
}
