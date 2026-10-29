.pragma library
.import "logic.js" as Logic
.import "rewards.js" as Rewards

var SYSTEM_PROMPT =
    "You are the Dhun Commons assistant inside Logos Basecamp. You help a steward earn DHN and use " +
    "the commons well. Answer in plain text, under 180 words, no tables. Use only the context JSON " +
    "provided. Never invent balances, wallet addresses, signatures, transaction hashes, chain height, " +
    "farmer stock, or project awards. Balances and rewards in the context are local rehearsal data, " +
    "not chain state. Reward rules: node-day 25 DHN per device per calendar day while the Logos " +
    "Messaging node reports ready; field-task 8 DHN when a calendar task is marked done; " +
    "challenge-evidence 15 DHN when evidence is filed on a claimed challenge; kitchen-plan 5 DHN once " +
    "per day for a built sourcing plan; steward-onboarding 10 DHN when a profile is created. Payouts " +
    "still need two of three signatures, so say 'queued' or 'proposed', never 'paid'. For food, give " +
    "practical zero-waste steps with a food-safety caveat; never promise a >20-day shelf life unless " +
    "the user follows a tested preservation method. Do not give medical advice or health claims for " +
    "plants."

var KITCHEN_PROMPT =
    "You are planning a farm kitchen menu for Dhun Commons. From the user's dish, mood or free text, " +
    "choose dishes ONLY from the allowed dish list, and optionally whole ingredients from the " +
    "available farm offers. Reply with a single JSON object and nothing else: " +
    "{\"dishes\":[\"exact dish name\"],\"extras\":[\"ingredient name\"],\"servings\":number," +
    "\"wasteTips\":[\"short practical zero-waste step\"],\"notes\":[\"short caution\"]}. " +
    "Use 2-5 dishes that fit the mood, season and guest count. Waste tips must reuse stalks, leaves, " +
    "roots, whey, soaking water or trim safely, or route them to compost or livestock. Include a " +
    "food-safety caution when a tip involves cooked food, dairy or leftovers. Do not invent prices, " +
    "stock or shelf lives. Do not give medical or nutrition claims."

var PROFILE_PROMPT =
    "You assess a steward's background for Dhun Commons project allocation. Be conservative and " +
    "evidence-based. Reply with a single JSON object and nothing else: " +
    "{\"summary\":\"at most 60 words\",\"strengths\":[\"3 to 5 short items\"]," +
    "\"projectIds\":[\"only ids from the supplied project list\"]," +
    "\"fitNotes\":\"at most 60 words on where the person fits\"," +
    "\"gaps\":\"one short sentence on what the background does not prove\"}. " +
    "Never invent qualifications, certificates, years of experience, or project awards. If the " +
    "background is thin, say so and return few or no project ids. Allocation is a suggestion only: " +
    "the person must still submit a proposal and collect signatures."

function dateKey(timestamp) {
    return Rewards.dateKey(timestamp === undefined ? Date.now() : timestamp);
}

function hasRef(state, ref) {
    return Rewards.hasRef(state, ref);
}

function rewardIdeas(app) {
    var ideas = [];
    if (!app || !app.state) return ideas;
    var state = app.state;
    var now = Number(app.now) || Date.now();
    var today = dateKey(now);
    var person = app.activePerson;
    var who = person ? person.name : "you";

    if (!hasRef(state, "node|" + today)) {
        ideas.push({
            id: "node-day",
            title: "Log today's node day",
            detail: "Keep the Logos Messaging node ready in Basecamp; one node day is recorded per device per calendar day.",
            amount: Rewards.amountFor("node-day"),
            page: "room",
            action: "Open room"
        });
    }

    var openTasks = 0;
    if (state.fieldActivities) {
        var todayTasks = Logic.fieldActivitiesOnDay(state, app.activeRole, now);
        for (var i = 0; i < todayTasks.length; ++i)
            if (todayTasks[i].status !== "done") openTasks += 1;
    }
    if (openTasks > 0) {
        ideas.push({
            id: "field-task",
            title: "Finish " + openTasks + " field task" + (openTasks === 1 ? "" : "s") + " today",
            detail: "Mark the calendar task done after the work is actually fielded. Reopening it removes the unclaimed reward.",
            amount: Rewards.amountFor("field-task") * openTasks,
            page: "field",
            action: "Open field map"
        });
    }

    if (!hasRef(state, "kitchen|" + today)) {
        ideas.push({
            id: "kitchen-plan",
            title: "File a zero-waste kitchen plan",
            detail: "Type a dish or mood, review the sourcing lines and waste uses, then file the plan once today.",
            amount: Rewards.amountFor("kitchen-plan"),
            page: "kitchen",
            action: "Open kitchen"
        });
    }

    var challenge = null;
    if (state.challenges) {
        for (var c = 0; c < state.challenges.length; ++c) {
            var item = state.challenges[c];
            var status = Logic.challengeState(item, now);
            if (status === "claimed" && item.claimedBy === app.activeRole) { challenge = item; break; }
            if (!challenge && (status === "open" || status === "claimed")) challenge = item;
        }
    }
    if (challenge) {
        ideas.push({
            id: "challenge-evidence",
            title: "File evidence on " + challenge.title,
            detail: "Claim the window if it is still open, then file field evidence. Release still needs two signatures.",
            amount: Rewards.amountFor("challenge-evidence"),
            page: "challenges",
            action: "Open challenges"
        });
    }

    if (!person || person.role !== "steward") {
        ideas.push({
            id: "steward-onboarding",
            title: "Create a steward profile",
            detail: "Add a name and background on this device to join the steward party. This is not a chain account.",
            amount: Rewards.amountFor("steward-onboarding"),
            page: "profile",
            action: "Open profile"
        });
    }

    if (app.pendingRewardCount > 0) {
        ideas.push({
            id: "payout",
            title: "Propose a payout for " + app.pendingRewardCount + " queued reward" + (app.pendingRewardCount === 1 ? "" : "s"),
            detail: "Queued DHN becomes a treasury proposal; it moves only after two of three signatures and execution.",
            amount: 0,
            page: "node",
            action: "Open node & rewards"
        });
    }

    return ideas;
}

function ideasText(ideas) {
    var lines = [];
    for (var i = 0; i < ideas.length; ++i) {
        lines.push((i + 1) + ". " + ideas[i].title +
            (ideas[i].amount > 0 ? " (+" + ideas[i].amount + " DHN)" : "") + " — " + ideas[i].detail);
    }
    return lines.join("\n");
}

function starterPrompts() {
    return [
        "How do I raise my DHN balance today?",
        "I feel cold and tired; plan a low-waste field lunch for 20 people.",
        "Read my background and suggest which project fits me."
    ];
}

function context(app) {
    if (!app || !app.state) return {};
    var state = app.state;
    var now = Number(app.now) || Date.now();
    var person = app.activePerson;
    var today = dateKey(now);
    var openTasks = 0;
    if (state.fieldActivities) {
        var todayTasks = Logic.fieldActivitiesOnDay(state, app.activeRole, now);
        for (var t = 0; t < todayTasks.length; ++t)
            if (todayTasks[t].status !== "done") openTasks += 1;
    }
    var projects = [];
    if (state.projects) {
        for (var p = 0; p < state.projects.length; ++p) {
            var project = state.projects[p];
            projects.push({
                id: project.id,
                title: project.title,
                status: project.status,
                funded: !!project.funded,
                budget: Number(project.budget) || 0,
                summary: String(project.summary || "").substring(0, 180)
            });
        }
    }
    var challenges = [];
    if (state.challenges) {
        for (var c = 0; c < state.challenges.length; ++c) {
            var challenge = state.challenges[c];
            var status = Logic.challengeState(challenge, now);
            if (status === "open" || status === "claimed")
                challenges.push({ id: challenge.id, title: challenge.title, status: status });
        }
    }
    var wallets = state.wallets || {};
    return {
        role: app.activeRole,
        person: person ? {
            name: person.name,
            role: person.role,
            place: person.place || "",
            background: String(person.background || "").substring(0, 4000),
            capability: person.capability ? person.capability.summary || "" : ""
        } : null,
        balances: {
            thisRoleDHN: Number(wallets[app.activeRole] || 0),
            vaultDHN: Number(wallets.vault || 0)
        },
        pendingRewards: Number(app.pendingRewardCount || 0),
        today: {
            nodeDayLogged: hasRef(state, "node|" + today),
            kitchenPlanFiled: hasRef(state, "kitchen|" + today),
            openFieldTasks: openTasks
        },
        rewardRules: {
            nodeDay: Rewards.amountFor("node-day"),
            fieldTask: Rewards.amountFor("field-task"),
            challengeEvidence: Rewards.amountFor("challenge-evidence"),
            kitchenPlan: Rewards.amountFor("kitchen-plan"),
            stewardOnboarding: Rewards.amountFor("steward-onboarding")
        },
        projects: projects,
        openChallenges: challenges,
        note: "All balances, rewards and inventory are local rehearsal data, not chain state."
    };
}

function chatMessages(app, history, prompt) {
    var messages = [{ role: "system", content: SYSTEM_PROMPT }];
    messages.push({
        role: "system",
        content: "Context JSON (local rehearsal data): " + JSON.stringify(context(app))
    });
    var list = history || [];
    var start = Math.max(0, list.length - 8);
    for (var i = start; i < list.length; ++i) {
        if (!list[i] || list[i].source === "built-in") continue;
        messages.push({
            role: list[i].mine ? "user" : "assistant",
            content: String(list[i].text || "").substring(0, 4000)
        });
    }
    messages.push({ role: "user", content: String(prompt || "") });
    return messages;
}

function localAnswer(app, prompt) {
    var text = String(prompt || "").toLowerCase();
    var ideas = rewardIdeas(app);
    if (/kitchen|cook|dish|mood|food|menu|waste/.test(text)) {
        return "Open Kitchen and type the dish or how you feel in the new prompt line. The built-in planner " +
            "maps it to dishes in the kitchen library, then shows the farm lines, waste uses and the pantry " +
            "gate. Filing a built plan queues " + Rewards.amountFor("kitchen-plan") + " DHN once today. " +
            "The OpenRouter model is not configured, so no model was called.";
    }
    if (/profile|cv|background|skill|project|allocate|capab/.test(text)) {
        return "Open your profile from the sidebar. Paste a background or load a .txt/.md file, then run " +
            "the capability check. Without an OpenRouter key the check cannot call a model; you can still " +
            "read the local project list and start an allocation proposal by hand. Allocations are " +
            "suggestions, and release still needs two of three signatures.";
    }
    if (/earn|balance|dhn|reward|wallet|money/.test(text)) {
        return "The built-in guidance uses the same reward rules as the app. Nothing here is paid until a " +
            "treasury proposal is executed.\n\n" + ideasText(ideas);
    }
    return "No OpenRouter key is configured, so no model was called. Here are today's grounded actions:\n\n" +
        ideasText(ideas) + "\n\nTo enable model answers, set OPENROUTER_API_KEY before launching Basecamp " +
        "or write the key to ~/.config/dhun-commons/openrouter.json and chmod 600.";
}

function kitchenMessages(freeText, guests, month, dishNames, offerNames) {
    return [
        { role: "system", content: KITCHEN_PROMPT },
        {
            role: "user",
            content: "Request: " + String(freeText || "").substring(0, 2000) +
                "\nGuests: " + Number(guests || 0) +
                "\nMonth: " + Number(month || 0) +
                "\nAllowed dishes: " + (dishNames || []).join(", ") +
                "\nAvailable farm offers: " + (offerNames || []).join(", ")
        }
    ];
}

function profileMessages(person, background, projects) {
    var list = [];
    for (var i = 0; i < (projects || []).length; ++i) {
        var project = projects[i];
        list.push({
            id: project.id,
            title: project.title,
            status: project.status,
            funded: !!project.funded,
            summary: String(project.summary || "").substring(0, 240)
        });
    }
    return [
        { role: "system", content: PROFILE_PROMPT },
        {
            role: "user",
            content: "Person: " + JSON.stringify({
                name: person ? person.name : "",
                place: person ? person.place || "" : "",
                existingNote: person ? person.note || "" : ""
            }) +
                "\nProjects: " + JSON.stringify(list) +
                "\nBackground supplied by the person:\n" + String(background || "").substring(0, 12000)
        }
    ];
}

function parseJsonObject(content) {
    var text = String(content || "").trim();
    text = text.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/i, "").trim();
    var start = text.indexOf("{");
    var end = text.lastIndexOf("}");
    if (start === -1 || end === -1 || end <= start) return null;
    try {
        return JSON.parse(text.substring(start, end + 1));
    } catch (error) {
        return null;
    }
}

function parseAssessment(content, projects) {
    var payload = parseJsonObject(content);
    if (!payload) return null;
    var allowed = {};
    for (var i = 0; i < (projects || []).length; ++i) allowed[projects[i].id] = projects[i];
    var ids = [];
    var raw = payload.projectIds || [];
    for (var k = 0; k < raw.length; ++k) {
        var id = String(raw[k] || "");
        if (allowed[id] && ids.indexOf(id) === -1) ids.push(id);
    }
    var strengths = [];
    var rawStrengths = payload.strengths || [];
    for (var s = 0; s < rawStrengths.length && strengths.length < 5; ++s) {
        var value = String(rawStrengths[s] || "").trim();
        if (value) strengths.push(value.substring(0, 120));
    }
    return {
        summary: String(payload.summary || "").substring(0, 400),
        strengths: strengths,
        projectIds: ids,
        fitNotes: String(payload.fitNotes || "").substring(0, 400),
        gaps: String(payload.gaps || "").substring(0, 240)
    };
}

function assessmentText(assessment) {
    if (!assessment) return "";
    var lines = [];
    if (assessment.summary) lines.push(assessment.summary);
    if (assessment.strengths.length) lines.push("Strengths: " + assessment.strengths.join(" · "));
    if (assessment.fitNotes) lines.push("Fit: " + assessment.fitNotes);
    if (assessment.gaps) lines.push("What this does not prove: " + assessment.gaps);
    return lines.join("\n");
}
