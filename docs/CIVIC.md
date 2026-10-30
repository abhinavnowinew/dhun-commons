# Civic simulation

A native Dhun Commons tab that runs a seven-day, day-by-day simulation of eight
residents whose agents take over the coordination work of the commons: water,
roads, agriculture, safety, waste and care. The premise is simple — most civic
work is not physical labour, it is chasing. The agents draft the letter, book the
crew, collect the evidence, follow the department and report back. Agents also
work with each other — consulting the domain lead, pairing on hard jobs, handing
tasks to an idle teammate and peer-checking evidence — so the commons is run by a
crew, not eight parallel queues. The human is pulled in only for money, permits,
safety-critical calls, rights and repeated evidence gaps.

Everything on the page is synthetic. No department, vendor, crew or resident is
contacted, and no model is called. The engine is deterministic for a given seed.

The structure follows the pattern of the Zugrama residency simulation
(`Deceptrax123/Zugrama-residency-agent-simulation`): authored identities, agents
that only remember what they witnessed, per-agent budgets, explicit human gates,
a disclosed fairness facilitator and a nightly reflection cycle. Dhun replaces the
networking event with a civic board and the USD allowances with a DHN civic
envelope.

## Personas and domains

| Resident | Agent | Role | Base zone | Domains (capability) | Asks/day |
| --- | --- | --- | --- | --- | --- |
| Meera Rathore | Jal | Water steward | Farms | water 3, agri 1, waste 1 | 2 |
| Arjun Sain | Marg | Road guardian | Estate | roads 3, safety 1, water 1 | 2 |
| Saira Bano | Beej | Agri steward | Orchards | agri 3, water 1, waste 1 | 2 |
| Dev Gurjar | Goth | Dairy steward | Dairy | agri 2, waste 2, water 1 | 1 |
| Lata Sharma | Chulha | Kitchen & waste lead | Kitchen | waste 3, care 1, agri 1 | 2 |
| Kabir Nair | Pehra | Safety lead | Estate | safety 3, roads 2, care 1 | 1 |
| Nila Vyas | Saanjh | Care worker | Hamlet | care 3, safety 1, water 1 | 1 |
| Ravi Meena | Dhoop | Energy & commons | Farms | water 2, roads 2, safety 1 | 2 |

Six domains carry per-domain DHN envelopes:

| Domain | Envelope | Guardian | Examples |
| --- | --- | --- | --- |
| Water & drainage | 1,200 DHN | Meera | blocked drain, dry handpump, leaking gate, overflow tank |
| Roads & access | 1,200 DHN | Arjun | school-lane potholes, washed shoulder, dead streetlight, rutted track |
| Agri & soil | 900 DHN | Saira | armyworm, clogged drip line, fodder gap, seed viability |
| Safety & nights | 700 DHN | Kabir | open well, compost-yard snakes, unlit night walk, firewood under thatch |
| Waste & sanitation | 400 DHN | Lata | pit capacity, plastic mulch, dairy greywater, compost turning |
| Care & health | 400 DHN | Nila | missed health van, kitchen heat, expired first-aid kit, transport contact |

Twenty-four report templates are weighted by month (monsoon drainage and washouts,
cold-season fire load, hot-season heat safety, harvest-season seed and fodder) and
damped against repetition within ten days.

## The daily loop

`qml/civic.js` runs six phases per day. `Start` advances one phase every 1.2 s;
`Run day` completes the rest of the day; `Reset` starts a new seed.

1. **Dawn scan.** Two to four synthetic reports are added to the board as backlog.
   Held asks from yesterday's digest are released.
2. **Triage.** Backlog is sorted by priority score. Each issue goes to the most
   capable free agent: capability must be at least 2 for the domain, an agent may
   hold at most two active tasks, and at most three assignments per day. If nobody
   qualifies, the issue stays in backlog honestly. At the end of triage an agent
   carrying two tasks hands the lower-priority one to an idle, capable teammate and
   keeps the sharper report; a blocked board can also trade one task to free a
   specialist.
3. **Field action.** For each assigned issue the agent consults the domain lead
   (or a second reader), pairs with a teammate on high-effort and high-risk work,
   then either performs coordination work (draft, book, chase, collect evidence)
   against the domain envelope, or escalates to the human. High-risk work changes
   hands to the specialist, who keeps the original agent as partner. Escalation
   reasons: high-risk work (permit or safety-critical), spend above 300 DHN
   (treasury), insufficient domain budget, or two failed evidence checks
   (confidence).
4. **Verification.** A different agent peer-checks the evidence string. A pass
   closes the issue and counts its coordination minutes as human time returned; a
   failure reopens it in backlog with a retry counter and the reviewer says why.
5. **Dusk report.** The day is summarised and the facilitator audits fairness.
6. **Night reflection.** Each agent that touched work files a short reflection that
   cites only the issue ids it owned, partnered on or peer-checked, and names the
   teammates it worked with.

Priority score (0–100):

```
score = (0.38·urgency + 0.27·impact + 0.20·equity + 0.15·(6 − effort)) / 5 × 100
```

Urgency, impact and equity are 1–5; effort is 1–5 and enters inverted, so cheap,
high-equity fixes rise first. The formula is visible in `scoreIssue` and is the
only routing policy.

## How the agents interact

Agents are not eight parallel queues. Every interaction is rule-triggered and
visible in the play-by-play with issue ids, so it can be audited.

| Interaction | Trigger | What happens |
| --- | --- | --- |
| Consult | Owner is not the domain lead, or the plan is risky or heavy | Owner asks the lead for the domain call; the lead replies with the checklist, crew contact or last figure. Otherwise a second reader flags one assumption to test first. |
| Paired job | Effort ≥ 3 or high risk | A capable teammate with room joins the job. Both are named in the action line and both may cite it at night. |
| Handoff | Agent carries two tasks and a teammate is idle; or a high-risk job has a specialist free | The lower-priority task moves to the idle peer, or the risky job moves to the specialist who keeps the original agent as partner. |
| Peer check | Every actioned issue at verification | An agent who is neither owner nor partner checks the evidence. A pass closes and names both agents; a failure reopens with the reviewer's note. |
| Reflection credit | Night phase | Each reflection names the teammates on the issues it touched and counts "helped a peer on N" separately from work it owned. |

Hard bounds:

- a collaborator is always another authored persona, never the owner itself;
- the two-active-task cap counts partnerships as well as ownership;
- a high-risk handoff requires the specialist to have room and higher domain
  capability, and the original owner stays attached as partner;
- link counts are derived from issue events, so `collabPairs` reconciles exactly
  with the counters shown on the page;
- every line is generated from the simulated record. No model is called and no
  real agent, resident or department receives anything.

## Human gates and burnout guard

The human only sees asks, never the whole board queue.

- **Treasury** — spend above 300 DHN needs a sign. Signing commits the amount to
  the domain envelope and moves the task to actioned.
- **Permit & liability** — high-risk work outside safety.
- **Safety-critical** — high-risk safety work. The hazard stays flagged until the
  ask is answered.
- **Budget** — the domain envelope cannot cover the task.
- **Evidence** — two failed verification rounds; a third blind retry is refused.
- **Rights & order** — reserved for tasks that change who is served first.

Each person has a per-day ask cap (1–2). Extra asks are **batched** into the next
day's digest rather than interrupting eight people all afternoon — the
burnout guard. Declining returns the task to the board with a note; a second
decline (or any decline on an evidence ask) parks it.

The **fairness facilitator** is a disclosed, non-user agent. At dusk it reads only
the public action log. If one zone received at least 60% of the day's actions
while another zone has at least two open tasks, it posts a public fairness note
and gives the ignored zone a +12 priority bonus in the next triage. It holds no
private memory and does not act.

## Memory and reflection

An agent's nightly reflection contains:

- `saw`: issue ids the agent owned, partnered on or peer-checked that day —
  nothing else;
- `partners`: the agents it worked with on those issues;
- `assisted`: how many of those issues belonged to someone else;
- `takeaway`: closed / helped / carried / waiting counts in plain language,
  ending with "Worked with …" when there were collaborators;
- `unresolved`: whether a human signature is pending;
- `intention`: the next domain queue to recheck;
- `honesty`: an explicit "rule-generated, unverified" label.

No reflection cites a private ask or an unwitnessed report.
The engine has no model, so the text is templated; it is intentionally boring and
checkable rather than fluent and unverifiable.

## Metrics

| Metric | Definition |
| --- | --- |
| Open now | Every issue not closed or parked |
| Closed with evidence | Passed the simulated verification check |
| Trust | closed ÷ (closed + reopen events) |
| Median response | Median days between report and closure |
| Human hours returned | Sum of coordination minutes on closed issues ÷ 60 |
| Asks for you | Open plus batched human asks |
| Civic budget left | 4,800 DHN pool minus committed spend |
| Coverage today | Domains with at least one action this day |
| Crew links | Sum of consults, paired jobs, handoffs and peer checks |
| Consults / paired / handoffs / checks | Per-kind interaction counts shown in the crew-interplay card |

## Honesty limits

- Reports, evidence and closures are simulated. Nothing is sent to a department,
  vendor or crew, and no physical work is executed.
- The engine makes no model calls and has no network access. The text is generated
  by rules, so it cannot discover information the templates do not contain.
- Agents do coordination work only: drafting, scheduling, chasing, evidence
  collection and reporting. They do not issue permits, certify safety or replace
  the 2-of-3 treasury sign-off.
- Simulation state lives in the page for the session. Reset starts a new seed; the
  run does not persist across app restarts yet.
- The civic envelope (4,800 DHN) is simulated and separate from the wallet's
  rehearsal ledger; no signing here moves real or rehearsal DHN.

## Tests

`tests/Flow.qml` adds 24 checks to the 160 existing ones (184 total):

- six domains, eight personas, and the named causes present;
- dawn opens reports; triage assigns only capable agents and caps active load at two;
- high-risk work escalates to a human;
- signing a safety-critical ask spends exactly the task cost and moves it to actioned;
- declining returns the task to backlog with a decline count;
- per-person ask caps batch extra asks;
- the facilitator rebalances a lopsided day to the ignored zone;
- reflections cite only issues the persona owned, partnered on or peer-checked,
  and carry the honesty label;
- the engine is deterministic for a seed across twelve phases;
- spend never exceeds the pool; the week closes work with a bounded trust score;
- a dusk digest exists for every day; every ask uses a known human gate;
- the limits copy starts with "Simulation only";
- a week contains consults, paired jobs, handoffs and peer checks;
- collaborators are real personas and never the owner;
- crew links reconcile with the per-kind counters;
- reflections credit collaborators and never themselves;
- paired work still respects the two-active-task cap;
- the tab is registered directly after Agro and carries its page metadata.

Run them with the same offscreen command used for the rest of the harness; see
[DEMO.md](DEMO.md).

## Reading the page

- **Day strip** — day, phase, phase hint, envelope bar, per-phase chips and the
  latest dusk line.
- **Six stat tiles** — the metrics above.
- **Your inbox** — one card per ask with reason, ask, consequence, cost, deadline
  and the agent holding it. Sign or decline inline. When empty the page says so.
- **Agents on the desk** — all eight agents with domain, current load, top peer
  links and hours returned.
- **Crew interplay** — consult / paired / handoff / peer-check counts, the busiest
  pairs and what each pair actually did.
- **Civic queue** — six domain lanes with open/active/closed counts, the top two
  issues, status and envelope left.
- **Play-by-play** — the newest 36 log entries with day, phase and issue refs,
  including who asked whom, who paired, who handed over and who checked.
- **Night reflections** — the latest day's agent reflections and cited ids.

## Files

| Path | Purpose |
| --- | --- |
| `qml/civic.js` | Personas, domains, report templates, deterministic engine, gates, metrics |
| `qml/pages/Civic.qml` | Day controls, inbox, roster, queue, feed and reflections |
| `qml/components/Sidebar.qml` | Civic navigation entry |
| `qml/components/Icon.qml` | Civic icon |
| `qml/Main.qml` | Page order, metadata and stack entry |
| `tests/Flow.qml` | Civic engine and navigation checks |
