# Design decision log

Status: **proposal-stage decisions**. The RFP requires a current decision log at every
milestone. This file seeds the log for the design in
[RFP-005-proposal.md](RFP-005-proposal.md). Entries marked *validate in M1* are
constraints to test against the pinned LEZ 0.4 build, not established platform facts.

---

## ADR-001 — Build an application-first reference wallet

**Status:** accepted for the proposal.

**Context.** Most RFP-005 proposals focus on the protocol. A private multisig is only
useful if non-specialists can operate it, and the treasury it protects has real
coordination work around it.

**Options considered.**
1. Protocol-only deliverable with a generic test UI.
2. Application-first wallet with a concrete three-party economy, plus the full protocol.
3. Wallet as a thin wrapper over a future third-party multisig.

**Decision.** Option 2. Dhun Commons models a funder, a field unit (Dhun) and a
steward collective sharing a seasonal treasury: issuance, external placement, project
bids, cultivation windows, market purchases and conservation covenants.

**Rationale and trade-offs.** The application gives every protocol feature a
load-bearing use: role separation for allowances, competing claims for quorum,
deadline-bound challenges for timelock and expiry, and beneficiaries who cannot be
expected to read raw instructions. The cost is a larger surface than a protocol-only
deliverable; the milestone split keeps the program and audit on the critical path.

**Validation.** The current Basecamp module exercises the UX and now includes a real
LEZ public-testnet account panel (wallet, public accounts, height/balances,
public-transfer submission, and a live `chat_module` group). The multisig program,
approval verification and private transactions remain funded work. In this evaluation
the Funder account held externally supplied 0.1 LEZ; one 0.01 LEZ transfer submitted
while the sequencer was stalled was later included in block 67,293 (balances at block
67,389: 89,996,136 / 10,000,000 / 0 lepta). That is sequencer inclusion, not finality.

---

## ADR-002 — Private by default; public posture at creation; no mixed posture in v1

**Status:** accepted for the proposal.

**Context.** RFP F.10 requires private-by-default operation, an operator-selectable
fully public posture, and selective disclosure. Soft requirement #3 asks for arbitrary
per-item mixed postures.

**Options considered.**
1. Private by default plus a fully public creation option and scoped disclosure.
2. Arbitrary per-item mixed postures from day one.
3. Public by default with optional privacy.

**Decision.** Option 1. The operator chooses fully private or fully public at creation.
Private multisigs can disclose scoped state to a chosen audience. Per-item mixed
postures are explicitly out of scope for v1.

**Rationale and trade-offs.** A fully public posture is a simple, auditable mode; scoped
disclosure covers the real need for partial transparency without multiplying state
invariants and test combinations. Option 2 would touch every state transition and
weaken the privacy review. We state the limitation rather than implying support.

**Validation.** The public/private split is documented per action (U.5) and tested in
M2/M5.

---

## ADR-003 — Use program-controlled private state and a shared private vault

**Status:** accepted for the proposal; validate in M1.

**Context.** The public `lez-multisig` prior art requires member accounts to be fresh
zero-nonce keypairs claimed by the program. LEZ private accounts are owned by the
privacy protocol and increment their nonce on use, so that architecture cannot carry the
private posture. The RFP points to group-owned shared private accounts.

**Options considered.**
1. Reuse the public fresh-key architecture and accept a public-only multisig.
2. Program-controlled private configuration plus a group-owned shared private vault.
3. A program-owned private vault with note/nullifier accounting only.

**Decision.** Option 2, with option 3 as the fallback if the shared-account API does not
support the required authorization pattern. Members never need fresh zero-nonce
accounts; their approvals are signatures, not account nonce claims.

**Rationale and trade-offs.** It preserves the private posture and avoids asking members
to manage one-shot accounts. The shared-account API is a platform dependency; M1
validates it before the program is committed. The fallback changes vault plumbing, not
the approval or quorum design.

**Validation.** M1 spike; exact API and nonce behaviour recorded in the compatibility
matrix.

---

## ADR-004 — Collect approvals off-chain in the E2EE room

**Status:** accepted for the proposal.

**Context.** RFP F.2 allows approvals on-chain or off-chain, provided the proposer
states which. On-chain approvals add a transaction per approval and publish
attribution; off-chain collection removes both costs but makes the room part of the
liveness path.

**Options considered.**
1. On-chain approvals for every member.
2. Off-chain approvals in the Logos chat room, verified at execution.
3. Hybrid by default.

**Decision.** Option 2 for both postures. Public multisigs may opt into on-chain
approval receipts for audit. Private multisigs never write approvals in the clear.

**Rationale and trade-offs.** It removes per-approval transaction cost and keeps
pending-proposal metadata off-chain. The room is not trusted: withholding can delay a
proposal, but cannot forge one. Approval packages are bound to the action digest, so
reordering, injection and replay fail verification.

**Validation.** Room threat model and replay/injection tests in M3; execution
verification tests in M2.

---

## ADR-005 — Attributed BIP-340 approvals, not anonymous threshold proofs

**Status:** accepted for the proposal.

**Context.** LP-0002 explores anonymous threshold proofs where the verifier does not
learn which members approved. RFP R.1 instead requires M distinct valid approvals from
current members, attributable to members at execution. The two models are different.

**Options considered.**
1. Anonymous threshold proof (LP-0002 model).
2. BIP-340 signatures from identified member keys, verified inside the proof.
3. A ring signature or nullifier-only scheme.

**Decision.** Option 2. Approvals are BIP-340 signatures over the canonical action
digest. Attribution is available inside the room and to disclosure audiences; it is not
published on-chain in the private posture.

**Rationale and trade-offs.** It matches R.1 and supports accountability and selective
disclosure. It does not give signer anonymity to other room members, which is a
deliberate product choice for a treasury. BIP-340 verification inside a zkVM is the
largest cost risk; M1 measures it with real proving.

**Validation.** M1 cost sweep; M2 distinctness, replay and wrong-action tests.

---

## ADR-006 — Quorum freezes at queue; configuration changes invalidate only pre-quorum approvals

**Status:** accepted for the proposal.

**Context.** R.2 requires a precise cutoff: approvals gathered before a member-set or
threshold change must not count after it, unless the action already reached quorum and
entered its timelock or was submitted for execution.

**Options considered.**
1. Invalidate every pending action on any configuration change, including queued ones.
2. Freeze queued actions at quorum; invalidate all pre-quorum approvals.
3. Let approvals survive a configuration change if the signer is still a member.

**Decision.** Option 2. Approvals carry the configuration epoch. The queue transaction
(which is atomic with execution when the timelock is zero) verifies quorum and freezes
the approval set. A queued action survives a later member removal for the remainder of
its timelock and executes. Pre-quorum approvals from the old epoch fail with
`E_CONFIG_EPOCH`.

**Rationale and trade-offs.** It gives a deterministic cutoff and avoids a queued
treasury payment being silently cancelled by a membership change. The trade-off is that
a removed member's approval can still contribute to an action queued before removal;
that is the R.2-sanctioned point. Cancelation remains possible through a new quorum.

**Validation.** M2 tests for epoch invalidation, queued-action survival, removed-member
behaviour and invalid N/M configurations.

---

## ADR-007 — Independent propose, approve, execute and limit roles

**Status:** accepted for the proposal.

**Context.** RFP F.6 requires role separation: at minimum a proposing key need not be an
approving key, and documentation must state the guarantee for each role.

**Options considered.**
1. One member key with all capabilities.
2. Capability sets over keys, with an explicit guarantee table.
3. Separate multisig instances per role.

**Decision.** Option 2. Propose, approve, configure, execute and limit-spend are
independent capabilities assigned in configuration and changed through quorum.
Execution is permissionless relayer by default, or an allowlisted executor set.

**Rationale and trade-offs.** It covers delegated proposers and operational relayers
without giving them authority; an executor can only submit an already-authorized
package. The cost is more configuration state and tests. Option 3 would fragment
custody and is rejected.

**Validation.** M2 role tests and documentation table.

---

## ADR-008 — Spending limit: operator or sub-quorum, cumulative per policy period, transfers only

**Status:** accepted for the proposal.

**Context.** RFP F.8 requires an optional policy where a member or sub-quorum can
execute transfers up to a configured limit without full M-of-N approval.

**Options considered.**
1. Per-transaction cap with no cumulative window.
2. Cumulative cap per policy period (default 30 days) for a configured operator key or
   k-of-n sub-quorum.
3. A separate low-value multisig.

**Decision.** Option 2. The policy period is distinct from the configuration epoch. The
limit is enforced in the same transition as the transfer, resets at the start of each
period, and covers transfers only. Changing the limit or operator requires quorum.

**Rationale and trade-offs.** A per-transaction cap can be drained by repeated
transactions; a cumulative window is safer. Extending the limit to arbitrary target
programs would widen the attack surface, so v1 does not do it. Policy-period resets are
simple to reason about and disclose.

**Validation.** M2 cumulative-cap and policy-change tests.

---

## ADR-009 — A new room epoch on every configuration change

**Status:** accepted for the proposal.

**Context.** Program membership and chat membership are separate state. Removing a
member through quorum does not evict them from an existing room, and a stale client can
keep showing them as a participant.

**Options considered.**
1. Remove the member from the existing room and rely on the chat module.
2. Keep one room forever and mark the member as removed in the UI.
3. Provision a new room epoch with a new random room ID and fresh invites.

**Decision.** Option 3, with chat-level removal as defense-in-depth where available.
The old room is archived read-only. A removed member retains messages they already
received and may see messages until rotation completes; after that they receive no new
content.

**Rationale and trade-offs.** It does not depend on chat-module eviction semantics and
makes the access window explicit. The cost is one room transition per configuration
change and a client-side epoch check. We document the residual history access rather
than implying cryptographic erasure.

**Validation.** M3 rotation and stale-room rejection tests.

---

## ADR-010 — Content-addressed, multi-source registry; packaged IDL for the multisig itself

**Status:** accepted for the proposal.

**Context.** RFP F.4 requires a registry so any client can confirm what a proposal's
bytes mean and which program they invoke, without a single trusted source. U.6 requires
decoding the exact signed bytes.

**Options considered.**
1. A single registry server maintained by the team.
2. Content-addressed entries with publisher signatures, resolved from multiple paths.
3. No registry; show raw bytes only.

**Decision.** Option 2. Entries are `(program_id, idl_hash, publisher_key, schema)` and
are fetched from an on-chain registry, a Git-pinned snapshot and a mirror. Disagreement
is surfaced. The multisig's own SPEL IDL ships with the module and is used for
multisig actions, so a bad registry entry cannot disguise a configuration change.
Unregistered targets show raw bytes and require explicit acknowledgement.

**Rationale and trade-offs.** It removes the single-server trust point and keeps
coverage honest. It cannot prove a schema is semantically safe; it only proves which
schema the publisher attested. The UI says so.

**Validation.** M3 registry disagreement and unknown-program tests.

---

## ADR-011 — Scoped disclosure with a separate disclosure key

**Status:** accepted for the proposal; mechanism validated in M2/M4.

**Context.** RFP F.10 requires selective disclosure to a chosen audience without
granting spending power and with ongoing assurance.

**Options considered.**
1. Publish the whole private state to the audience.
2. Separate commitments for configuration, balance, activity and approvals, with
   scoped Merkle proofs and a dedicated disclosure key.
3. A zero-knowledge predicate circuit for each query (for example, balance ≥ X).

**Decision.** Option 2. A disclosure key, committed in configuration and separate from
all spend/approval keys, signs sequenced bundles containing the requested scopes,
inclusion proofs against the on-chain commitment, and a hash chain for freshness. It
cannot authorize spending.

**Rationale and trade-offs.** It supports narrow and wide audiences and repeated
evidence without a new proof system. It discloses exact facts in the chosen scopes, not
inequalities; the audience must be trusted with those facts. Option 3 overlaps the
proof-of-holding soft requirement and is left as a research note.

**Validation.** M4 disclosure flow; M5 verification and privacy analysis; audit scope.

---

## ADR-012 — Measure approval cost before committing the design

**Status:** accepted for the proposal.

**Context.** The RFP says approval verification is the largest unpriced item and may
determine the largest workable M. Development-mode benchmarks are not acceptable.

**Options considered.**
1. Build the full system and benchmark at the end.
2. A four-week real-proving spike and go/no-go before the full build.
3. Assume the public prior art's figures.

**Decision.** Option 2. M1 delivers a standalone harness, a real-proving M sweep, a
private-vault validation and a go/no-go memo. If M = 5 is not viable, the finding is
reported and triggers a scope discussion rather than a silent ceiling reduction.

**Rationale and trade-offs.** It de-risks the critical path and may change scope before
most of the budget is spent. It adds a milestone and delays the program start by a few
weeks; that is cheaper than discovering the cap after implementation. It also produces
the performance harness required by P.1/P.2.

**Validation.** M1 acceptance; final figures restated in M5 with the shipped code.

---

## ADR-013 — Telegram as a read-and-queue relay, never a signer

**Status:** accepted for the demonstration.

**Context.** The operator wants to follow the commons and post into the coordination
room from Telegram. Two shapes are possible: a bot that holds wallet or module
credentials and can act, or a bot that only reads published state and queues text.

**Options considered.**
1. Give the bot module access so it can approve proposals or submit transfers.
2. A file-based relay: the app publishes snapshots, the bridge reads the public
   sequencer directly, and the only write path is an inbox of room messages.
3. A hosted server that stores state and pushes it.

**Decision.** Option 2. `telegram/bridge.mjs` long-polls the Bot API, answers read
commands from `state.json` or the public sequencer, and writes `/say` text to
`inbox.json`. The app polls that file and offers **Post to room** or **Dismiss**. The
bot never signs, approves, transfers, or opens the wallet file.

**Rationale and trade-offs.** The treasury's safety property is that approval requires
keys inside the app; removing that with a chat command would be a categorical
regression, not a convenience. A relay keeps the attack surface to: read access to two
JSON files, a public RPC endpoint, and whatever the operator types into a room that was
already mirrored to Logos Messaging. The cost is that Telegram is a second transport
for unsigned text, so it cannot confirm or execute anything; it also means the snapshot
is only fresh while a Dhun Commons view is open.

**Validation.** Eight Node tests against a stub Bot API and stub sequencer, five relay
assertions in the QML harness, and one live stub run that read block 67,394 and queued a
`/say` message. The bridge was not run against real Telegram because no token exists in
this workspace; that limitation is stated in the README and [TELEGRAM.md](TELEGRAM.md).
