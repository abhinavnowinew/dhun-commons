# RFP-005 proposal — submission draft

> **Draft, not submitted.** This file is the working copy for the GitHub issue form at
> <https://github.com/logos-co/rfp/issues/new?template=proposal.yml>. It is not a claim
> that the project has been funded, audited or deployed.

## Read before posting

1. **Deadline has passed.** The RFP index lists RFP-005 with a submission deadline of
   **23/10/26**. At the time of drafting (**2026-10-25**) the listed deadline was two
   days past.
   Ask in [Discussions](https://github.com/logos-co/rfp/discussions) whether a late
   proposal will be reviewed, or wait for the RFP to be re-opened. Do not present this
   as an on-time submission.
2. **Fill every `[FILL]`.** Team names, contact details, social links, prior work and
   the audit firm's engagement status are deliberately blank. Do not submit
   placeholders or invented credentials.
3. **The current module is a demonstration, not the multisig.** `dhun_commons` in this
   repository runs in Logos Basecamp. It now includes a real LEZ public-testnet account
   panel: a local wallet, three public accounts, block-height and balance reads, and
   public-transfer submission through `lez_core`. The Funder account was funded
   externally with 0.1 LEZ in this evaluation; there is no in-app faucet. A 0.01 LEZ
   transfer submitted while the sequencer was stalled was later included in block
   67,293, and balances at block 67,389 read 89,996,136 / 10,000,000 / 0 lepta. Inclusion
   is not finality, and nothing here is called settled. There is no deployed multisig
   program, the DHN approvals are demo strings, and the room transcript is local state
   (the Logos Messaging group behind it is a real module call, with no peer delivery
   observed). This proposal funds the
   production implementation; the module is evidence that the application and
   coordination UX can be built and that wallet I/O works against the testnet, not
   evidence that RFP-005 is already implemented.
4. **Audit and budget are intentions, not quotes.** Confirm the audit firm, scope and
   price before submitting. The RFP requires a named tier-1 firm; the name below is a
   proposed target, not an engagement.
5. **Do not check the consent boxes below on the applicant's behalf.** They are
   intentionally left unchecked.

**Issue title:**

```text
[PROPOSAL] RFP-005 — Dhun Commons
```

---

## RFP ID

RFP-005 — Multisig and Coordination

## Your Project Name

**Dhun Commons** — a private-by-default multisig and seasonal resource-coordination
wallet for Logos.

## Team or Organization Name

`[FILL: legal team or organization name, or "Independent"]`

## Primary Contact

`[FILL: email, Telegram, Discord or Signal handle]`

## Team Members

> Replace every field below with confirmed information. The role split reflects the
> work in this proposal, not people who have already been contracted.

**Member 1**
- Name or pseudonym: `[FILL]`
- Social links: `[FILL: GitHub, X/Twitter, LinkedIn, website]`
- Role: Protocol lead — LEZ program, private state, approval verification, audit liaison
- Status: `[FILL: full-time / part-time / contractor]`

**Member 2**
- Name or pseudonym: `[FILL]`
- Social links: `[FILL]`
- Role: Cryptography / zkVM engineer — BIP-340 verification, nullifiers, selective disclosure
- Status: `[FILL]`

**Member 3**
- Name or pseudonym: `[FILL]`
- Social links: `[FILL]`
- Role: Coordination and module engineer — Logos chat integration, registry, module API, CLI
- Status: `[FILL]`

**Member 4**
- Name or pseudonym: `[FILL]`
- Social links: `[FILL]`
- Role: Product and QML engineer — Basecamp mini-app, secure signing UX, decode-before-sign, Figma, documentation
- Status: `[FILL]`

**Member 5**
- Name or pseudonym: `[FILL]`
- Social links: `[FILL]`
- Role: Security review and delivery — threat model, test matrix, release and audit coordination
- Status: `[FILL: part-time]`

## Project Summary

Shared custody is the missing primitive for treasuries, DAOs and shared program
administration on Logos. Existing multisigs make the chain read the quorum, so members,
threshold, approvals and actions become public. That visibility is also an attack
surface: in the Bybit and WazirX losses, the transaction the signers approved was not
the transaction they were shown. LEZ can do better. A program can enforce an M-of-N rule
while its configuration and vault live in private accounts, and a Logos chat room can
carry deliberation and approvals without publishing them.

Dhun Commons will deliver a complete implementation of RFP-005: a Rust program for LEZ testnet
0.4 with a private-by-default vault, attributed BIP-340 approvals verified at
execution, arbitrary target-program calls, an operator-selectable public posture,
timelock, spending limits, independent propose/approve/execute roles, configuration
changes through the same quorum, an encrypted coordination room, a content-addressed
target registry, decode-before-sign, selective disclosure, a module API, a headless
CLI, and a Basecamp mini-app. The first milestone measures real proving cost for
approval verification before the rest of the design is committed, because that cost
determines the viable M and is the largest unpriced risk in the RFP.

Our difference is the application. The same repository contains a working Basecamp
wallet for a real coordination problem: a funder, a field unit (Dhun) and a group of
land stewards share a seasonal treasury. They issue and place DHN, compete for project
awards, accept time-boxed cultivation challenges, buy inputs from a local market, and
route a conservation covenant on releases. That workload exercises the multisig end to
end: role separation, small single-signer allowances, competing claims on the same
pool, deadline-bound execution, and beneficiaries who are not protocol engineers. A
multisig that only a CLI user can operate will not reach those users.

The Basecamp module in this repository is currently a **hybrid demonstration**: a real
LEZ testnet account panel (wallet file, three public accounts, height and balance reads,
public-transfer submission via `lez_core`) sits beside a local DHN rehearsal whose
proposal state machine, allowance path, escrow accounting, covenants and ledger are real
application logic. The DHN signatures, escrow `txid`s and room transcript are simulated;
the LEZ Funder account holds 0.1 LEZ from an external faucet while Dhun and Steward hold
0, and one submitted transfer was not included by the sequencer. Its 67-check flow harness
(`tests/Flow.qml`) passes headlessly. This proposal funds the production LEZ multisig
program, the chat integration and the complete wallet connection. We will not describe
the demonstration as a deployed multisig, and we will not claim a prior production LEZ
deployment. `[FILL: add the team's actual LEZ, Rust, zkVM, custody or security
experience here with links; if there is none, say so.]` We will deliver under MIT OR
Apache-2.0, publish the module through our own catalog, and publish a tier-1 audit
before recommending any production deployment.

## Technical Approach

### Design principles

1. **The program is the only authority.** The room transports proposals, approvals and
   discussion; it never decides validity. Execution verifies approvals against the
   action bytes.
2. **Private by default, public by explicit choice.** The operator chooses a fully
   private or fully public posture at creation. Selective disclosure is an add-on to
   the private posture, not a change of posture.
3. **Decode what is signed.** The UI and CLI render the digest, target program and
   decoded instruction from the exact bytes covered by the approval, using the
   registry. A proposer-supplied description is never displayed as fact.
4. **No partial success.** Vault initialization, quorum, expiry, timelock, configuration
   epoch and replay checks all pass before the target call or state write occurs.
5. **Auditability is designed in.** Separate commitments for configuration, balance and
   activity allow scoped disclosure without exposing the whole treasury.

### Prior art and what we reuse

We reviewed the public prior art and the open RFP-005 proposal set. We reuse patterns,
not code, and we state where our choices differ.

| Source | What we take | Difference |
| --- | --- | --- |
| `logos-co/lez-multisig` public PoC | Public-path action and vault semantics; a useful reference only | Its fresh-zero-nonce member accounts cannot satisfy the private posture; we use program-controlled private state and a shared private vault |
| LP-0002 (Private M-of-N Multisig) | Design space for threshold proofs, nullifiers and the LEZ nonce constraint | R.1 requires approvals attributable to current members, so we use BIP-340 signatures rather than anonymous threshold proofs |
| Open RFP-005 proposals (for example Commonhold #233, Tessera #237, Accord #222, Conclave #213, LEZ Shared Treasury #211) | Off-chain room coordination, attributed approvals, epoch rotation and scoped disclosure as design patterns | Dhun Commons is application-first: a production Basecamp wallet for a three-party seasonal economy, with a full requirement-to-test matrix and an audit gate |
| Logos shared-private-account journey | Group-owned shared private vault | M1 validates the exact API and nonce behavior before the design is committed |

We do not claim to have invented these patterns, and we do not rely on another proposal's
unpublished code. The implementation is fresh and dual-licensed.

### Architecture

```text
┌────────────────────── Basecamp mini-app · CLI · other Logos modules ──────────────────────┐
│  proposal list + room      decode-before-sign      role/policy views      disclosure view  │
└───────────────┬───────────────────────────────────┬───────────────────────────────────────┘
                │ action bytes, digest              │ approvals (BIP-340 signatures)
                ▼                                   ▼
      ┌───────────────────┐                ┌───────────────────────────────────────┐
      │ Logos chat module │  E2EE room     │ dhun_msig program (LEZ testnet 0.4)    │
      │ invites, messages │◀──────────────▶│ private config + private vault         │
      │ room epochs       │                │ verify quorum, timelock, limits, roles │
      └───────────────────┘                │ execute exact bytes on target program  │
                                           └──────────────────┬────────────────────┘
                                                              │
                                           ┌──────────────────▼────────────────────┐
                                           │ target LEZ program (public or private)│
                                           └───────────────────────────────────────┘

      Public registry (content-addressed, publisher-signed, multi-source)
      ├── dhun_msig SPEL IDL
      └── target program IDL hashes + instruction schemas
```

### 1. Program, accounts and state

The `dhun_msig` program is written in Rust for the Risc0 zkVM and deployed to LEZ
testnet 0.4. It uses LEZ private accounts for the private posture; the operator may
instead create a fully public multisig at creation time.

- The **configuration state** is a private account controlled by the program. It holds
  a commitment to: N, threshold M, member signing-key commitments, optional weights,
  role assignments, timelock policy, spending-limit policy, registry trust roots,
  disclosure verification key, configuration epoch and proposal counter.
- The **vault** is a group-owned shared private account derived from a Group Master
  Secret, as described in the Logos shared-private-account journey. No member has
  unilateral spending rights; the program authorizes transfers. This deliberately
  avoids the fresh-zero-nonce assumption that makes `lez-multisig` incompatible with
  private accounts. Milestone 1 validates the exact account and nonce behaviour against
  the pinned LEZ 0.4 build. If the shared-account API cannot support the required
  authorization pattern, the fallback is a program-owned private vault with
  note/nullifier accounting; the approval design does not change.
- **Initialization** is a one-time state transition that binds the configuration, vault
  and disclosure key. Every value-moving instruction rejects with
  `E_NOT_INITIALIZED` until it has run. This is an explicit test case.
- **State commitments.** The private state root contains separate sub-commitments for
  configuration, vault balance, queued actions, activity log and approval attribution.
  Sub-commitments are the basis for scoped disclosure.

The program exposes an SPEL IDL (instruction schemas, accounts, errors and events) and
returns typed results to the module API. The IDL is the source of truth for decoding
the program itself.

### 2. Action format and approval lifecycle

The action digest is canonical and independent of the proposer's prose:

```text
action_digest = SHA-256(
  "dhun-msig/action/v1" ||
  multisig_id || config_epoch || proposal_nonce ||
  target_program_id || target_idl_hash || instruction_name ||
  canonical_account_metas || canonical_instruction_args ||
  value || expiry_slot || timelock_seconds
)
```

Every approval is a BIP-340 Schnorr signature by a current member over exactly this
digest. The target program, account metas and instruction arguments are the bytes the
program will execute. The IDL hash binds the schema used to render them.

**Approvals are collected off-chain by default**, in the E2EE coordination room. This
is the posture we propose for both private and public multisigs: pending-proposal
metadata stays in the room and per-approval on-chain writes are avoided. In the public
posture the operator may opt into on-chain approval receipts for audit; a private
multisig never writes approvals in the clear.

Lifecycle:

1. **Propose (off-chain).** A proposer publishes the canonical action bytes, digest and
   expiry to the room. Under the private posture no LEZ transaction is created yet.
2. **Approve or reject (off-chain, asynchronous).** Members verify the decoded action
   locally and post a BIP-340 approval or a signed rejection. Rejections are off-chain
   signals: M rejections mark the proposal rejected locally and stop further collection,
   but they do not prevent a malicious proposer from submitting a valid approval
   package; on-chain validity depends on approvals. A queued action can be cancelled
   on-chain by M approvals over a `cancel` action.
3. **Queue / execute (on-chain).** With timelock zero, `execute` verifies M distinct
   valid approvals from current members, the configuration epoch, expiry and the
   replay nullifier, then executes the target bytes atomically. With a non-zero
   timelock, `queue` performs the same verification and starts the delay; `execute`
   after the delay verifies the queued record, the frozen quorum epoch and the approval
   package again, then runs the target call. The approvals are verified inside the
   proof; the room is not trusted for validity.
4. **Expiry.** A proposal whose expiry has passed cannot queue or execute. A queue with
   a timelock that would end after expiry is rejected at queue time.
5. **Replay.** The executed action's nullifier and `(multisig_id, proposal_nonce)` pair
   are stored in private state. Re-submitting the same package fails with
   `E_ALREADY_EXECUTED`. Approvals cannot be replayed onto another action because the
   digest covers every action field, and they cannot be double-counted because the
   proof enforces distinct member commitments.

**Why approvals are verified at execution.** `execute` (or the atomic
queue+execute path) verifies the signatures against the action bytes in the same
transition that invokes the target program. A queued action is re-verified on
execution against the approval set frozen at its quorum epoch, so the timelock
delays execution but never replaces a proof check with trust in the room.

### 3. Configuration changes and the R.2 cutoff

Member additions/removals, threshold changes, weight changes, role changes, timelock
and spending-limit policy changes all use the same propose/approve/execute flow. They
cannot bypass quorum.

The cutoff is explicit:

- Every approval carries the `config_epoch` it was signed under. Executing a
  configuration change increments the epoch.
- **Before quorum is reached**, a configuration change invalidates all pending
  proposals and approvals from the old epoch. They fail with `E_CONFIG_EPOCH`; clients
  show them as *invalidated by a configuration change* and require a fresh proposal.
- **At quorum**, the queue transaction (or atomic execute, when timelock is zero)
  freezes the approval set under the quorum epoch. A later configuration change does
  not invalidate an already queued action. It executes after its timelock using the
  frozen approval set. This is the cutoff required by R.2.
- A member removed during the timelock does not cancel the queued action and cannot
  approve or cancel future actions. Executor authorization is evaluated at execution
  against the current configuration; if a restricted executor is removed, another
  current executor can submit the queued action, and if none remains the multisig can
  add one through quorum. Actions do not silently become uncancellable: M current
  members can queue a `cancel` action.
- A configuration action itself is checked against the epoch it was proposed under. If
  another configuration change executes first, the queued change fails rather than
  applying to a state it did not intend.
- The program rejects any configuration that would make N < 1, M < 1, M > N, or leave
  no executable role path.

### 4. Roles and guarantees

Roles are capability assignments over keys, changed only through quorum:

| Capability | Who can hold it | Guarantee |
| --- | --- | --- |
| Propose | Members and optional delegated proposer keys | A proposer can create room proposals but cannot approve unless it is also a member, and cannot execute without a valid quorum. |
| Approve | Current members only, with optional weights | Only signatures by member keys current at the quorum epoch count; a queued action keeps the set frozen at that epoch per R.2. Approvals are attributed for display inside the room and, if scoped, in disclosure; they are not published on-chain in the private posture. |
| Execute | Permissionless relayer by default, or an allowlisted executor set | An executor cannot create authority. It can only submit a package that already satisfies quorum, epoch, expiry, timelock and limit checks. |
| Configure | Current members, through quorum | No single key can change members, threshold, roles, timelock or limits. |
| Spend within limit | A configured member key (operator) or a k-of-n sub-quorum of members | Capped by a cumulative per-policy-period limit; cannot change the limit or recipient policy. |

The minimum requirement is met directly: a proposing key need not be an approving key.
The documentation will state these guarantees per role and test them.

### 5. Spending-limit policy

A multisig may configure either a single member key (an operator) or a k-of-n
sub-quorum of members that can execute transfers up to a cumulative limit per policy
period without full M-of-N approval. The policy period is configurable (default 30 days) and is distinct from the
configuration epoch; the limit is in the configuration commitment, resets at the start
of each period, and is enforced inside the same transition as the transfer.
Spending-limit transfers are recorded in the activity commitment and appear in
disclosure bundles. The policy is changed only through
quorum. The limit applies to transfers; arbitrary target-program calls still require
quorum unless a future policy explicitly extends it (not in v1).

### 6. Privacy postures and selective disclosure

The operator chooses at creation:

- **Private (default):** configuration, member set, threshold, approvals, pending
  proposals, action payload, vault balance, execution linkage and co-signing graph are
  not published in the clear. The chain sees program invocation and private
  commitments. Coordination content is always E2EE.
- **Public:** configuration, holdings, approvals and activity are public, for
  treasuries that want continuous public inspection. Coordination content remains
  E2EE; approval receipts may optionally be written on-chain.

Under the private posture, the ten data items are handled as follows:

| Data item | Private posture | Public posture | Selective disclosure scope |
| --- | --- | --- | --- |
| Existence of the multisig | Program invocation may show that a private instance exists; no members or purpose | Public | — |
| Member set | Commitment only; room membership is separate | Public | `config` |
| Threshold and weights | Commitment only | Public | `config` |
| Per-signer approval attribution | Inside proof / E2EE room; not on-chain | Public if on-chain receipts chosen | `approvals` |
| Pending-proposal metadata | Room only | Room only by default | `activity` (if scoped) |
| Action payload | Not in clear; target-program effects may reveal it | Public | `activity` |
| Vault balance | Commitment only | Public | `balance` |
| Execution linkage | Private account transition; timing/graph residual | Public | `activity` |
| Coordination content | E2EE room | E2EE room | Not disclosed by default |
| Co-signing social graph | Not readable from chain; room/timing residual | Public if receipts chosen | `approvals` |

**Selective disclosure.** The configuration commits to a disclosure verification key
and a scope policy authorized by quorum. The key is separate from every spending and
approval key. It can sign scoped bundles repeatedly without a new quorum vote; changing
the scope requires quorum. A bundle contains the state snapshot for the requested
scopes (`config`, `balance`, `activity`, `approvals`), Merkle inclusion proofs against
the state commitment, a monotonic sequence number, the previous bundle hash, and the
on-chain commitment it corresponds to. The audience verifies the signature, proofs and
on-chain commitment. The key cannot authorize spending.

- A narrow audience (one auditor) receives a bundle encrypted to its key. A wide
  audience (all DAO members) receives a bundle encrypted to a group key whose membership
  is managed by the multisig. Rotation is a quorum action.
- **Ongoing assurance:** every disclosure bundle is sequenced and hash-chained, so a
  later joiner can obtain current evidence rather than a setup-time claim. A stale
  bundle is detectable.
- **What the audience unavoidably learns:** the facts in the disclosed scopes, the
  timing and cadence of updates, the fact that it was granted access, and any
  correlation with public chain activity (for example, a publicly visible target
  program effect). It does not learn the undisclosed scopes or gain spending power.

**Mixed postures (soft requirement #3):** not supported in v1. The operator can choose
fully private plus scoped disclosure, or fully public; arbitrary per-item combinations
(for example, public holdings with a private member set) are not offered. The table
above is therefore the complete answer for both supported postures, and we state this
explicitly rather than implying more granularity than we deliver.

**Proof of holding (soft requirement #2):** we will document a design for an inequality
proof over the vault commitment, but we do not claim it is expressible with today's
primitives. It is a research note, not a budgeted implementation.

**Weighted approvals (soft requirement #1):** supported as an additive policy: quorum
requires at least M distinct member approvals and a cumulative weight at least the
configured threshold. R.1's distinct-approval floor is preserved.

### 7. Coordination room and LEZ-to-chat binding

Each multisig provisions one room using the Logos chat module.

**Room identity and transport metadata.** The room ID is a random 256-bit value derived
from a secret room seed, not a public hash of the multisig ID. The room title and
display names are pseudonymous and contain no role labels. No multisig identifier,
member identifier or role is placed in transport fields. The Logos chat module may
still expose participant, size or timing metadata to its transport; that residual is
outside our program, is named in the privacy documentation, and is checked against the
PR.2 test list. We do not claim metadata resistance beyond what the pinned chat module
provides.

**Binding mechanism.** At creation each member supplies the public key of their LEZ
member account — the member signing key — and a chat identity. Inside the E2EE room,
each member posts a binding attestation:

```text
sig = BIP340_sign(member_key,
  "dhun-msig/binding/v1" || multisig_id || room_id || room_epoch ||
  chat_identity_key || member_commitment)
```

The attestation proves control of the member's LEZ account key and links it to the chat
identity; the member commitment and account details are only inside the encrypted room.
Clients verify the attestation against the member-set commitment before showing a
message as "from member i". The program does **not** verify chat bindings at execution:
quorum is verified from BIP-340 signatures by those same member keys, so a compromised
chat identity cannot create an approval. The chat identity alone never authorizes
anything. This separation is deliberate and documented.

**Invite/accept.** The creator creates the room, invites the chat identities from the
binding records, and each member accepts and posts their attestation. A room is
provisioned only when every current member has a verified attestation; otherwise
clients show a *room not ready* state and do not accept approvals until every current
member is verified.

**Configuration changes.** Every executed configuration change provisions a new room
epoch with a new room ID and fresh invites to current members, keeping room membership
and the room epoch aligned with the program's configuration. The old room is archived
read-only. A removed member keeps messages they already received, and may see messages
until the new epoch room is active; after rotation they receive no new content. This is
the honest limit of removal without key erasure, and it is stated in the docs. Clients
show a rotation banner and refuse new approvals in the old room once the change is
queued.

**Threat model for the room.** Participants can withhold, reorder, replay, inject or
show different members different views:

- Withholding is a liveness failure only; the proposal expires and can be re-proposed.
- Reordering and replay have no effect: approvals are bound to the action digest and
  the execution nullifier.
- Injection fails signature verification; clients show only locally verified senders.
- Split views are detectable by comparing signed message digests; there is no room
  consensus. Execution on-chain is the authoritative record, and members can
  re-broadcast a proposal or approval. The design tolerates a malicious room for
  safety, not for liveness.

**Cross-layer correlations (PR.3).** The privacy requirements apply per layer; the
combination still leaks some signals. The documentation will state each one:

- **Timing.** A burst of room traffic followed by a LEZ execution correlates the two,
  even when the payloads are private. Mitigations: randomized submission delay,
  relayer submission and batching of unrelated operations. A determined observer who
  sees both layers can still infer that *some* action followed *some* deliberation;
  the design does not claim traffic-analysis resistance.
- **Fee payer and relayer.** If a member pays fees directly, the fee account links the
  member to the multisig. The default path uses a relayer; the client warns when a user
  overrides it. Residual: the relayer learns the transaction it submits, so it should
  be operated separately from the member set.
- **LEZ-to-chat binding.** The binding attestation is carried only inside the E2EE room;
  it is not a chain signal. Room participants learn which chat identity maps to which
  member commitment; an on-chain observer does not. Residual: a room participant who
  also observes chain timing can link the two, and a chat identity that appears in only
  one room is more linkable than one used across many rooms.
- **Target-program effects.** A private multisig cannot hide the effects of a call to a
  public target. The action payload may be inferable from the target's public state
  change. Sensitive flows should use private targets; the disclosure and privacy docs
  name the leakage for each target.
- **Transaction shape.** Note sizes, instruction counts and timing can distinguish
  operations. Where practical, action payloads are padded and unrelated operations are
  batched; the residual fingerprint is documented.
- **Funding graph.** If a member funds the vault from their own public account, the
  funding edge is public. Recommended onboarding uses a private transfer or a
  third-party desk; the limitation is stated rather than hidden.
- **Disclosure audience.** A disclosure audience learns the disclosed scopes, the update
  cadence and that it was granted access. It does not gain spending power, but it can
  correlate the bundle with public chain events.

### 8. Registry and decode-before-sign

The registry serves two schemas: the `dhun_msig` program's own SPEL IDL, and target
program IDLs.

- Entries are content-addressed: `(program_id, idl_hash, publisher_key,
  instruction_schema, source_url)`. Publishers sign entries; clients verify the
  signature and the IDL hash. The registry contains no treasury data and is public in
  both postures.
- Clients can resolve the same entry from at least two independent paths (the on-chain
  registry account, a Git-pinned snapshot shipped with the module, and a mirror). If
  the hashes disagree, the client displays all versions and refuses automatic
  approval until the user resolves it. There is no single trusted registry server.
- **Unregistered target program:** the UI shows the program ID, raw instruction bytes
  (hex), account list and IDL hash, with an *unverified schema* warning. It does not
  invent names or amounts. Approval requires an explicit advanced acknowledgement and
  is recorded as unverified in the disclosure activity. This is what a client displays
  when coverage is missing.
- **Decode-before-sign:** the approval screen is generated from the exact
  `action_digest` and the target IDL, not from proposer prose. It shows target program,
  decoded instruction, accounts, amounts, expiry, timelock and digest. The module's
  own packaged IDL is used for multisig actions, so a malicious registry cannot
  disguise a configuration change as a transfer. The production module package is
  installed as a signed LGX and its developer signature is verified at install time.

### 9. Module API, CLI and mini-app

**Module API (U.1).** A Logos module exposes typed calls: `create`, `propose`,
`approve`, `reject`, `execute`, `queue`, `cancel`, `getProposal`, `getState`,
`updateConfig`, `disclose`, `provisionRoom` and `roomStatus`. Calls return proposal IDs,
digests and long-running operation handles. Other Logos modules can use the same API
without the GUI. Signing is delegated to the Logos wallet/keystore module; the multisig
module never exports private keys. Milestone 1 confirms the current wallet signing
interface; if it is not yet available, we use an encrypted local keystore with explicit
export and backup, and document the migration path.

**CLI (U.3).** `dhun-msig` uses the Logos core headless framework and covers create,
propose, approve, reject, execute, queue, cancel, config changes, decode and status.
It supports `--json` for automation, `--dry-run` for decoding without signing, and
prints proving progress as discrete stages rather than blocking silently.

**Basecamp mini-app (U.2).** QML module, packaged as LGX, listed in our own module
catalog. The proposal list and the coordination room are visible side by side. It
includes the role switcher, decode panel, policy/timelock/limit configuration,
selective-disclosure view, long-running execution progress and actionable error
states. The current rehearsal module establishes the visual language and interaction
model; production replaces its local `seed.js` state with module API calls and its
demo signatures with BIP-340 approvals from the wallet.

**Figma or equivalent (S.11).** A Figma file covering the proposal list, approval
sheet, room, decode panel, disclosure view and error states, linked from the README.
If Figma is unavailable, an equivalent annotated design file with the same screens is
accepted as the deliverable; the choice will be recorded in the design log.

### 10. Integration stack and pinned dependencies

| Layer | Choice |
| --- | --- |
| Program | Rust, Risc0 zkVM, LEZ testnet 0.4 actor model |
| IDL | SPEL |
| Private state | LEZ private accounts; group-owned shared private account for the vault |
| Approvals | BIP-340 Schnorr over canonical action digest |
| Coordination | Logos chat module, one E2EE room per multisig epoch |
| Module API | Logos module interface, QML/JS bindings |
| Wallet | Logos wallet/keystore signing interface (validated in M1) |
| Mini-app | Qt 6 QML, QtQuick Controls, LGX packaging |
| CLI | Logos core headless framework |
| CI | GitHub Actions + LEZ standalone sequencer |
| Build | Nix flake, reproducible builds, pinned `Cargo.lock` |

Milestone 1 records exact commits/tags for LEZ 0.4, the chat module and Basecamp, and
publishes a compatibility matrix. If an upstream interface changes, we publish a new
matrix and adjust the milestone plan; we do not silently float on `main`.

### 11. Testing, CI and benchmarks

Every hard requirement in Functionality, Usability and Reliability has at least one
test, mapped in a checked-in matrix. The suite includes:

- **Quorum safety:** execution below M fails; duplicate approvals fail; approvals from
  non-members fail; approvals over a different action fail; approvals on an expired
  proposal fail; replay of a completed action fails; a vault cannot be drained before
  initialization.
- **Configuration:** member/threshold/weight/role changes respect quorum; pre-quorum
  approvals are invalidated by an epoch bump; queued actions survive a change;
  removing a member during a timelock has the documented outcome; invalid N/M
  configurations are rejected.
- **Timelock:** early execution fails; execution after the delay succeeds; zero timelock
  is atomic; expiry before timelock end is rejected.
- **Spending limit:** cumulative cap per policy period; over-limit transfer requires quorum;
  limit changes require quorum; sub-quorum threshold is enforced.
- **Arbitrary actions:** a target program call executes exactly the approved bytes;
  unknown target programs are flagged by the UI, not silently decoded.
- **Room and binding:** binding attestations verify; injected/replayed messages fail;
  room epoch rotation removes new-message access; stale-room approvals are refused.
- **Selective disclosure:** disclosed scopes verify against the commitment; undisclosed
  scopes are absent; disclosure keys cannot execute; stale bundles are detected.
- **Privacy checks:** static review of public payloads for member identifiers and role
  labels; a documented correlation analysis; no member identity in chat transport
  fields.

End-to-end tests run against a LEZ sequencer in standalone mode and are part of CI. CI
must be green on the default branch at each milestone. The benchmark harness is
committed, reproducible and run with **real proving**; development-mode figures are
never reported.

**P.1 and P.2.** Milestone 1 and Milestone 5 report, per on-chain operation: compute
units, transaction size, client-side proving time and the LEZ 0.4 block-limit
comparison. Approval-verification cost is swept across M = 2..N with N at least 5 and
reported as a function of M, including the largest viable M. **M ≥ 5 must remain viable.** If the
measurement says otherwise, that is a reportable result and triggers a scope
discussion, not a silent reduction of the ceiling. Benchmarks use specified hardware
and pinned software; the harness and raw results are public.

### 12. Anticipated challenges

| Challenge | Why it matters | Mitigation / decision |
| --- | --- | --- |
| BIP-340 verification inside a zkVM is expensive | Approval cost is on the critical path and scales with M; it may cap M | M1 spike measures real proving first; optimize batch verification and circuit layout; report the ceiling; scope discussion if M=5 fails |
| Private account and nonce constraints | The public `lez-multisig` architecture assumes fresh zero-nonce member accounts, which private accounts cannot satisfy | Use program-controlled private state and group-owned shared private vault; verify the exact API in M1; fallback is a program-owned vault with note/nullifier accounting |
| Target-program effects can leak the action | A private multisig cannot hide what a public target program does | Document per-target leakage; prefer private targets for sensitive flows; include it in the privacy correlation analysis and disclosure docs |
| Chat module availability and metadata | The room is a hard dependency; transport metadata is outside our program | Pin the version; M1 confirms APIs; publish a fallback encrypted-relay design if the chat room cannot be provisioned, without claiming it satisfies F.9 until it does |
| Room/program membership divergence | Removing a member from the program does not evict them from an existing room | Provision a new room epoch on every configuration change; old room archived; state the residual access window |
| Registry trust | A registry can mislabel an action | Content-addressed entries, publisher signatures, multiple retrieval paths, packaged IDL for the multisig itself, explicit unverified state |
| Long proving times | Users experience minutes-long execution | Long-running operation handles, stage progress, resumable UI, no request/response assumptions |
| Selective disclosure design | Proving partial state without over-disclosing is subtle | Separate scoped commitments and Merkle proofs; disclosure key separate from spend keys; audit scope; document what the audience learns |
| Audit timing | A late audit can block delivery | Audit procurement starts in M3; release candidate at week 20; audit milestone M6 before any mainnet recommendation |

### 13. Requirement traceability

| Requirement | How this proposal addresses it | Milestone |
| --- | --- | --- |
| F.1 M-of-N, configurable | Program config with N, M, members, weights, roles; tests for below-threshold execution | M2 |
| F.2 Lifecycle, async, expiry, private | Off-chain propose/approve/reject in room; queue/execute; expiry in digest; no payload on-chain in clear | M2, M3 |
| F.3 Arbitrary target programs | Canonical target program ID + instruction bytes + accounts + value | M2 |
| F.4 Registry | Content-addressed, publisher-signed registry; multi-source resolution; explicit unregistered state | M3 |
| F.5 Configuration changes | Same M-of-N flow; epoch increment; invalid-config rejection | M2 |
| F.6 Role separation | Independent propose/approve/execute/configure/limit capabilities; guarantee table; tests | M2 |
| F.7 Optional timelock | Queue starts delay; zero is atomic; early execution fails; expiry check | M2 |
| F.8 Spending limit | Operator or k-of-n sub-quorum; cumulative cap per policy period; quorum to change | M2 |
| F.9 E2EE room + binding | Chat module room; binding of each LEZ account key to a chat identity via BIP-340 attestation inside the room; invite/accept; epoch rotation | M3 |
| F.10 Private by default, public option, disclosure | Private accounts by default; creation-time public posture; scoped disclosure bundles | M2, M4 |
| U.1 Module API | Typed create/propose/approve/reject/execute/config/disclose calls | M3 |
| U.2 Basecamp mini-app | LGX QML app with proposal list + room; local build instructions; module catalog | M4 |
| U.3 CLI | Headless CLI covering all core operations and configuration changes | M3 |
| U.4 SPEL IDL | Checked-in IDL for the multisig program; decode tests | M2 |
| U.5 Public/private documentation | Per-action, per-posture table including disclosure audiences | M4, M5 |
| U.6 Decode before sign | Exact-byte decoding via packaged IDL + registry; digest display; unknown-program warning | M3, M4 |
| U.7 Actionable errors | Stable error codes, human-readable remediation, UI states | M2, M4 |
| R.1 Distinct current approvals, no replay | Proof-enforced distinct member commitments; digest binding; execution nullifier; tests | M2 |
| R.2 Config invalidation cutoff | Pre-quorum epoch invalidation; queued actions frozen at quorum; removed-member behavior defined | M2 |
| P.1 Real benchmarks | M1 and M5 report compute, size and proving time with real proving | M1, M5 |
| P.2 Cost vs M, M ≥ 5 | M sweep; largest viable M; M=5 gate; public harness and results | M1, M5 |
| S.1–S.4 LEZ/chat/testnet/deployment | LEZ 0.4 program, chat room, deployed and tested on testnet 0.4 | M2, M3, M5 |
| S.5–S.7 CI, green branch, tests | Standalone-sequencer E2E in CI; green default branch; requirement-to-test matrix | M2–M5 |
| S.8–S.10 README, API, CLI docs | Deployment, addresses, every module call, operator and developer integration journeys | M4 |
| S.11 Figma/equivalent | Proposal list, room, decode, disclosure, errors | M4 |
| S.12 Own module catalog | Catalog built from the Logos module catalog template; installable LGX | M4 |
| S.13 Audit programme | Named tier-1 target, $50,000 budget, M6 timeline, published report before any mainnet recommendation | M6 |
| S.14 Design decision log | Starter ADRs in `docs/design-decisions.md`; updated with context, options, decision and trade-offs at each milestone | M2–M5 |
| PR.1 No on-chain member/role identity | Private accounts; approvals inside proof; relayer submission; no member identifiers in public payloads | M2, M5 |
| PR.2 No transport identity linkage | Random room ID, pseudonymous labels, binding attestations only inside E2EE | M3, M5 |
| PR.3 Cross-layer correlation documented | Timing, fee payer, target effects, funding graph, binding signal; mitigations and residuals documented | M5 |
| F.S.1–F.S.3 Soft requirements | Weighted approvals supported; proof-of-holding documented as research only; mixed postures explicitly unsupported, with the delivered postures and their disclosure stated | M2, M5 |

## Milestones, Payout and Timeline

> Duration is measured from project kickoff. Target kickoff is within two weeks of a
> signed grant agreement; the delivery deadline is kickoff plus 26 weeks. Overlaps are
> intentional: the audit track starts on the release candidate while hardening and the
> testnet release finish.

### Milestone 1 — Approval-verification spike and go/no-go

**Payout:** $16,000
**Duration:** 4 weeks (weeks 1–4)

**Deliverables**
- A standalone Rust/Risc0 harness on the pinned LEZ 0.4 build that verifies BIP-340
  approvals over a canonical action digest and exercises a private vault.
- Real-proving measurements for compute units, transaction size and client-side proving
  time across M = 2..N with N at least 5, including M = 5, with specified hardware and a
  reproducible command.
- Validation (or rejection) of the group-owned shared private account pattern for the
  vault, plus the fallback design if the API does not support it.
- Dependency audit for LEZ 0.4, the Logos chat module, the wallet signing interface and
  Basecamp, with pinned commits.
- A public go/no-go memo: the viable M ceiling, the main risks, and any scope adjustment
  proposed before the remainder is committed.
- Platform ramp-up is included here; no separate ramp-up budget is claimed. M2 starts
  only after the go/no-go.

**Acceptance:** the harness runs from a clean clone with real proving; the report and raw
results are public; M = 5 is measured and either viable or explicitly escalated for the
RFP's scope discussion.

### Milestone 2 — LEZ multisig program

**Payout:** $30,000
**Duration:** 8 weeks (weeks 5–12)

**Deliverables**
- `dhun_msig` program: initialization, private config, private/shared vault, proposal
  state, approval/rejection package handling, queue/execute, expiry, replay nullifiers,
  arbitrary target calls, configuration changes, independent roles, timelock, spending
  limit, public posture and the scoped commitments used by disclosure.
- SPEL IDL checked in; canonical action encoding and digest specified; decode tests.
- Unit, property and integration tests mapped to F.1–F.8, R.1–R.2, including
  below-threshold, duplicate, replay, expiry, config-epoch and vault-initialization
  cases.
- Deployment on LEZ testnet 0.4 with program addresses recorded in the README.
- Design decision log entries for the program, account and quorum decisions.

**Acceptance:** CI is green; the requirement test matrix passes; a testnet 0.4
deployment is reproducible from the documented steps.

### Milestone 3 — Coordination room, registry, module API and CLI

**Payout:** $22,000
**Duration:** 8 weeks (weeks 9–16)

**Deliverables**
- Chat-module room provisioning, invite/accept, binding attestations, room epoch
  rotation on configuration change, and stale-room rejection.
- Off-chain approval package format; signed proposal/approval/rejection messages;
  replay and injection handling; room threat-model documentation.
- Content-addressed target registry with publisher signatures and multi-source
  resolution; unregistered-program decode state.
- Logos module API for create/propose/approve/reject/queue/execute/cancel/config/
  disclose/room calls.
- Headless `dhun-msig` CLI covering the core operator journey, including config changes,
  `--dry-run` decode and proving progress.
- E2E tests against a standalone LEZ sequencer in CI; API and CLI documentation drafts.

**Acceptance:** a room-based proposal is approved off-chain and executed on the
standalone sequencer via both CLI and module API; registry and unknown-program tests
pass; CI is green.

### Milestone 4 — Basecamp mini-app, Figma and public artefacts

**Payout:** $20,000
**Duration:** 8 weeks (weeks 12–19)

**Deliverables**
- Production QML mini-app installed as an LGX: proposal list and room side by side,
  role switcher, timelock/limit configuration, decode-before-sign, selective-disclosure
  view, public-posture support, long-running execution progress, actionable errors.
- Figma (or equivalent) designs for the proposal list, approval sheet, room, decode
  panel, disclosure view and error states.
- Module catalog published from the Logos module catalog template, with installable
  modules and downloadable release assets; README, API documentation covering every
  module call and the developer integration journey, and CLI operator documentation
  complete.
- The mini-app loading from a git repository / catalog in Basecamp 0.2.x with documented
  local build steps.

**Acceptance:** U.1–U.7 are demonstrable in Basecamp; the module is installable from the
catalog; docs cover deployment, addresses, room provisioning and both CLI/UI journeys;
CI is green.

### Milestone 5 — Hardening, benchmarks and testnet release

**Payout:** $12,000
**Duration:** 3 weeks (weeks 20–22)

**Deliverables**
- Full hard-requirement test matrix closed; fuzz/property tests for decoding and
  approval packages; green CI on the default branch.
- Real-proving benchmark report for every on-chain operation (P.1) and the cost-vs-M
  report (P.2), with raw data and a reproducible harness.
- Final testnet 0.4 deployment and reproducibility check from documentation.
- Privacy correlation analysis (PR.3): on-chain/room timing, fee payer, target effects,
  funding graph, binding signal, residual risks and mitigations.
- Release candidate tagged at the start of M5; after that only audit-driven fixes and
  test/documentation changes.
- Audit readiness pack: release candidate, architecture notes, threat model, test
  evidence, known issues, design log current.

**Acceptance:** all tests pass; benchmark reports public; no open critical/high issues;
audit readiness pack accepted by the audit firm; M = 5 viability restated with final
measurements.

### Milestone 6 — Tier-1 audit and remediation

**Payout:** $50,000
**Duration:** 6 weeks (weeks 21–26; audit starts on the release candidate and overlaps M5)

**Deliverables**
- Engagement with a tier-1 audit firm covering: the multisig program, approval
  verification, configuration-change and timelock logic, spending-limit policy, private
  state transitions, selective disclosure, decode/registry path and room binding.
- Public audit report; remediation of findings; re-test and re-audit where required;
  final green CI.
- A statement that no production/mainnet deployment is recommended until critical and
  high findings are closed and the report is published.

**Intended firm:** `[FILL: confirm one and record its status — proposed target: Trail of
Bits; alternates: OpenZeppelin, Spearbit, Cantina]`. The firm is **not yet engaged** at
the time of drafting; procurement begins in M3 so the engagement letter is in place
before the release candidate. If the firm cannot commit, the audit budget remains
committed and the applicant will name a replacement tier-1 firm before M6 starts.

**Acceptance:** signed audit report published; remediation verified; no open critical or
high findings; final CI green.

### Timeline and budget summary

| Milestone | Weeks | Payout (USD) |
| --- | --- | --- |
| M1 — Approval-verification spike and go/no-go | 1–4 | $16,000 |
| M2 — LEZ multisig program | 5–12 | $30,000 |
| M3 — Room, registry, module API, CLI | 9–16 | $22,000 |
| M4 — Basecamp mini-app, Figma, artefacts | 12–19 | $20,000 |
| M5 — Hardening, benchmarks, testnet release | 20–22 | $12,000 |
| M6 — Tier-1 audit and remediation | 21–26 | $50,000 |
| **Total** | **26 weeks** | **$150,000** |

The 26-week end date is the critical path. M2–M4 overlap deliberately, and M6 overlaps
the end of M5; payments are per milestone acceptance, not per calendar week. The audit budget is
33% of the total because the approval-verification path is security-critical and the
RFP requires a tier-1 programme. No travel, hardware or infrastructure line items are
hidden in the engineering milestones; testnet and proving infrastructure are included.

## Total Requested Budget (USD)

**$150,000** — equal to the sum of the six milestone payouts above.

## Relevant Experience

> This section must be completed truthfully. Do not submit the rehearsal as a shipped
> multisig or list credentials that cannot be verified.

- **Dhun Commons Basecamp module** — `[FILL: public repository URL]`. A working QML
  rehearsal of the three-party wallet: 2-of-3 proposal queue with decode-before-sign,
  role-specific allowances, external token placement, market purchases, competing
  project bids, time-boxed cultivation challenges, milestone and challenge releases,
  a conservation covenant, a local coordination room and a seasonal landscape atlas.
  Its 40-scenario flow check passes headlessly. It is **not** connected to LEZ and has
  no real keys or funds.
- **Dhun / dhun.life** — `[FILL: URL and a short description of the seasonal culinary
  map and landscape work]`.
- **Prior protocol / Rust / zkVM work** — `[FILL: links to repos, shipped products or
  audits. If none, say so plainly.]`
- **Prior custody, signing-UX or security work** — `[FILL: links]`
- **Team profiles** — `[FILL: GitHub, personal sites, publications]`

We are not claiming a prior production LEZ deployment. Milestone 1 is structured to
retire the platform risk before the full build is committed, and the team will state
its actual ramp-up assumptions in the kickoff document.

## Post-Delivery Plan

- **Maintainer:** `[FILL: named maintainer or team]` owns the repository, releases and
  security responses after delivery.
- **Included support:** 90 days of critical security fixes and compatibility updates
  after the final milestone, at no additional cost.
- **Ongoing maintenance:** optional 12-month maintenance agreement at `[FILL: rate]`,
  covering upstream LEZ/chat/basecamp compatibility, dependency updates, release
  management and a quarterly privacy review.
- **Security:** a `SECURITY.md` disclosure policy, a public issue tracker, and a
  documented response target for critical findings. Audit reports remain published with
  the codebase.
- **Maintenance of the public artefacts:** module catalog releases remain installable;
  breaking changes follow semantic versioning; the design decision log stays current
  through the support period.
- **Production deployment:** we will not recommend a mainnet deployment before the
  audit is closed and its report is public. Any third-party deployment is the
  operator's responsibility; the documentation will say so.
- **Licensing:** all code is released under MIT OR Apache-2.0.

## Permissions and Consent

- [ ] I/We confirm Logos may contact me using the primary contact information provided
  above for follow-ups and next steps. *(required)*
- [ ] I/We consent to Logos using information from this proposal publicly, such as
  blogs, case studies, social posts or analytical reporting. Redactions can be requested
  at any time. *(optional)*

## Program Requirements

- [ ] I/We have read and agree to the Logos RFP Terms and Conditions and understand
  that no Grant is awarded and no right to payment arises unless a Grant Agreement is
  executed. *(required)*
- [ ] I/We understand that RFP specifications are proposals rather than instructions,
  that Logos makes no representations as to their legal or regulatory treatment, and
  that we are responsible for assessing what we build, deploy or operate and for
  complying with the laws that apply to us. *(required)*
- [ ] I/We understand this project must be open-sourced under the MIT and Apache 2.0
  Licenses unless explicitly approved otherwise. *(required)*
- [ ] I/We are prepared to deliver milestone-based outcomes. *(required)*

---

## Appendix A — What exists today vs what this proposal funds

| Layer | Today (this repository) | Funded by this proposal |
| --- | --- | --- |
| Basecamp wallet | Working local QML module; LEZ testnet account panel via `lez_core`; state persisted locally | Production module wired to the module API, wallet and chat |
| Proposal logic | QML/JS state machine, 2-of-3 quorum, roles, allowance, covenants, ledger | On-chain program and verifier; same flows exercised against LEZ |
| Chain | LEZ public-testnet accounts, height, balances and public-transfer submission; Funder funded 0.1 LEZ, submitted transfer unconfirmed, multisig not deployed | LEZ testnet private accounts for the multisig program, deployed and tested |
| Signatures | Deterministic demo strings derived from digests | BIP-340 approvals from the wallet; verified in the proof |
| Room | Local transcript plus a live `chat_module` group with 0 peers observed | Logos chat E2EE room, binding, invites and epoch rotation |
| Registry | None | Content-addressed target registry and decode-before-sign |
| Audit | None | Tier-1 audit, public report and remediation |
| Documentation | README, demo notes | README deployment/addresses, API/CLI docs, Figma, design log, privacy analysis |

## Appendix B — Submission checklist

- [ ] Confirm with the RFP maintainers whether late submissions after 23/10/26 are
  being reviewed.
- [ ] Fill every `[FILL]`; remove this draft notice and the checklist from the issue
  body.
- [ ] Confirm team member names, social links, roles and availability.
- [ ] Confirm the primary contact and consent checkbox.
- [ ] Confirm the audit firm (name, scope, quote, engagement status) and adjust M6 if the
  quote differs; keep the total equal to the milestone sum.
- [ ] Publish the repository, screenshots or a demo video, and the Figma file; add the
  URLs to Relevant Experience.
- [ ] Check that the budget arithmetic is $16,000 + $30,000 + $22,000 + $20,000 +
  $12,000 + $50,000 = **$150,000**.
- [ ] Re-read the RFP hard requirements and confirm every row in the traceability table
  has a real deliverable and test in the plan.
- [ ] Do not claim the DHN treasury or multisig is on-chain, audited or
  production-ready; do not present the externally funded 0.1 LEZ as app-generated, or a
  submitted transfer as settled.
