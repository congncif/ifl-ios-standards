# Briefing handoff — compact index, immutable assignments

The **briefing** is a compact Markdown handoff/index passed between stages/sub-agents during one task.
It replaces re-loading the same specs / re-running the same `find`/`git diff` across every hop. The
orchestrator appends short control pointers; each specialist reads one exact immutable assignment and
its cited inputs, then writes one unique result artifact. No specialist appends concurrently to the
briefing or a shared report.

The full audit trail for `/ifl-ios-standards:brain-flow` lives in the work-item folder: requirements,
plan, reports, handoffs, and artifacts are split by file so one report/briefing does not grow forever.

## File location

> **Optional, in-repo workspace.** The multi-agent pipeline (orchestrator → sub-agents) writes its
> work-item artifacts into the project's working-docs tree, per
> `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md` — **default
> `docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/`**. If the project's `CLAUDE.md` declares a
> different working-docs root, substitute it for `docs/02-working-docs/` throughout this file.

```text
docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/
├── requirements.md
├── plan.md
├── reports/
├── handoffs/
│   ├── briefing.md
│   └── assignments/
└── artifacts/
    ├── assignments/
    ├── lookups/
    └── reviews/
```

- `<WORK-ITEM-ID>` is provided by the user/tracker or generated during requirement intake.
- `{slug}` is the kebab-case task title (often also used for the git branch — `feature/{slug}`).
- One work-item folder per task. It survives the duration of the task and may be archived to
  `docs/99-archive/work-items/{YYYY-MM-DD}-<WORK-ITEM-ID>-<slug>/` after completion/merge.
- Support files such as `diff.patch`, `build.log`, screenshots, and context caches live under
  `artifacts/`; the briefing references them by relative path.

## Work-item file templates

### `requirements.md` (written by orchestrator or brain-flow Stage 1)

```markdown
# Requirements — {WORK-ITEM-ID} {title}

## Meta
- Created: {YYYY-MM-DD HH:MM}
- Flow mode: {co-working|auto}
- Scale: {trivial|small|medium|large|critical}
- Pattern binding: {none|Boardy+VIP|...}
- Orchestrator / runner: {agent, model, workflow, or N/A}
- Base branch: {from the project's configuration — see the consuming repo's CLAUDE.md}
- Branch: {branch name or N/A}
- Project execution target: {workspace/scheme/destination, package target, app target, or N/A}

## Requirement summary
- Ticket/work item ID and title: {provided ID, or generated <PROJECT-CODE>-NNNN + title}
- Business/user goal: {one paragraph or bullets}
- In scope: {list}
- Out of scope: {list}
- UI/design requirements: {list or N/A}
- API/backend/data requirements: {list or N/A}
- Source code areas likely affected: {paths/modules/components}
- Risks and assumptions: {list, may be empty}
- Open questions: {list, may be empty after approval}
- Definition of Done:
  - [ ] {observable completion criterion}

## Requirement gate
- Mode: {co-working|auto}
- Downstream mode after approval: {co-working|auto|N/A}
- Verdict: {USER_APPROVED|AUTO_APPROVED|USER_INPUT_REQUIRED|BLOCKED}
- Reviewer(s): {human user, self-review, subagent roles}
- User confirmation, if any: {summary + Definition of Done approval, or N/A}
- Definition of Done approved: {yes|no}
- Assumptions accepted: {list}
- Open questions resolved: {list}

## Task scope
- Goal: {one paragraph}
- Affected areas: {list}
- New modules / components / services: {list}
- Risks / ambiguities: {list, may be empty}

## Context cache
- Path: {optional cache path or N/A}
- Fields: {pattern/project-specific fields or N/A}

## Acceptance criteria
- [ ] {…}
```

`## Task scope` may be a normalized subset of `## Requirement summary`; keep it for compatibility with
existing specialist agents. `## Context cache` is optional; a bound pattern may define a concrete cache
schema below.

### `plan.md`

When `/ifl-ios-standards:brain-plan` runs, write an implementation plan and a gate record before any
execution begins:

```markdown
# Plan — {WORK-ITEM-ID} {title}

## Implementation plan
- Mode: {co-working|auto}
- Downstream mode source: {initial mode|co-working user switched to auto after DoD approval}
- Phase/wave summary: {sequencing containers only}
- Definition of Done coverage: {map DoD item IDs/checklist entries to semantic checkpoints}
- Verification ownership: {checkpoint proofs and one owner for each wave/release obligation}
- Pattern forwarding: {Boardy IO/Sources/Plugins seams or N/A}
- Cross-checkpoint dependencies: {list or none}

### Checkpoint CP-1 — {semantic outcome}
- DoD obligations: {IDs/checklist entries}
- Atomic cascade / exact scope: {artifacts that must agree in one valid state}
- Boundary validity: {why the state is independently valid}
- Independent rollback: {how this checkpoint can be reverted safely}
- Evidence input closure: {ordered path/blob/mode manifest or conservative tree scope plus environment fields}
- Commit boundary: {one post-verification commit or approved exception}

Boundary-rule evaluation (evaluate every rule in order; a later rule never overrides an earlier one):
| Order | Rule | Result | Evidence / justification |
|-------|------|--------|--------------------------|
| 1 | Semantic completeness | {SATISFIED|EXCEPTION_REQUESTED} | {why this is one complete domain/DoD outcome} |
| 2 | Independently valid state | {SATISFIED|EXCEPTION_REQUESTED} | {why no half-migration/cascade remains} |
| 3 | Independent rollback | {SATISFIED|EXCEPTION_REQUESTED} | {revert proof} |
| 4 | Coherent impact and reviewer ownership | {SATISFIED|EXCEPTION_REQUESTED} | {owners/blast radius} |
| 5 | Cognitive size tie-breaker only | {SATISFIED|NOT_APPLICABLE|EXCEPTION_REQUESTED} | {why split/merge is still economical} |

Boundary exception:
- Requested: {no|yes — exact deviation}
- Ordered-rule justification: {explicit treatment of rules 1 through 5; never cite LOC/file/task count alone}
- Safer compliant alternative considered: {alternative or none}
- Exception authority: {authority ID or N/A}

Work slices:
| ID | Causal implementation outcome | TDD tier | Earliest sufficient signal |
|----|-------------------------------|----------|----------------------------|
| WS-1 | {outcome} | {1|2|3} | {behavioral/static/schema proof} |

Review coverage:
| Risk / obligation | Artifact scope | Primary reviewer | Independent lens, if justified | Proof |
|-------------------|----------------|------------------|--------------------------------|-------|
| {risk} | {paths/contracts} | {owner} | {bounded scope or none} | {signal} |
- Root-cause vocabulary: {checkpoint-local cause classes and owning-surface aliases used by the canonical key grammar}

Verification and failure return:
- Review-readiness proof: {signal ID, command/binding, selector, minimum causal/static/schema obligations, and success predicate}
- Accumulated focused signal: {signal ID, canonical command/binding, selector, obligations, and success predicate}
- Checkpoint owning gate: {gate ID/version, command/binding, obligations, and success predicate}
- Owning-gate timing: {POST_JOIN_DEFAULT|PRE_REVIEW_REQUIRED — observable prerequisite and why review-readiness proof is insufficient}
- Focused signal and checkpoint gate identical: {yes — one receipt binds both labels|no — explain distinct obligations}
- Higher wave/release owning gate: {gate ID/version, schedule, command/binding, and exact obligations|none}
- Lower-gate decision before execution: {RUN:<gate-id>|<gate-id> SUBSUMED_BY:<higher-gate-id>} — {lean-verification.md §6 seven-condition record}
- Evidence receipt path: {unique artifact path}
- Evidence receipt required fields: {all fields from lean-verification.md §7: gate/version; command/arguments/selector; base/parent; ordered path/blob/mode input closure; schema/generator/digest inputs and outputs; dependency lock; toolchain; configuration; target/destination; environment/external-state/TTL; obligations/DoD; exact result}
- Fingerprint invalidation: {relevant source/test/generated/schema/digest/dependency/toolchain/config/command/target/destination/merge/environment/external-state/TTL changes}
- Expected Tier-1 RED predicate: {behavioral failure that must be observed by the orchestrator|N/A}
- Product RED policy: {return to WS/CP; or PLAN_REOPEN_REQUIRED when contract/boundary/ownership changes; never blind-rerun}
- Capability failure policy: {repair/re-preflight and supersede assignment, or CAPABILITY_BLOCKED/BLOCKED; never classify as product RED}
- Post-commit wave/release failure policy: {new corrective semantic checkpoint by default; amend only an unshared commit under explicit object-scoped authority; never rewrite shared history}

Commit authority (a distinct object-scoped grant, not implied by this plan or by auto mode):
- Authority ID: {AUTH-COMMIT-...|NOT_GRANTED}
- Action: COMMIT
- Object: {CP-ID + exact final candidate fingerprint, or a user-approved candidate selector/path/parent constraint that must resolve before use}
- Grantee: {orchestrator/agent identity}
- Scope: {exact staged changed-file manifest and commit-message constraint}
- Preconditions: {current owning receipt; joined REVIEW_APPROVED; staged-manifest match}
- Validity / consumption: {expiry and one-shot consumption rule}
- Explicit exclusions: {push, PR, merge, tag, publish, release, history rewrite}

## Plan gate
- Mode: {co-working|auto}
- Definition of Done coverage: {all items mapped|exceptions listed}
- Checkpoint-map validity: {semantic/valid/rollback/reviewer/gate/fingerprint/commit fields complete}
- Boundary exceptions: {none|all five ordered rules evaluated + exception authority IDs}
- Authority grants: {object-scoped IDs; approval of this plan is not itself an action grant}
- Verdict: {USER_APPROVED|AUTO_APPROVED|CHANGES_REQUIRED|USER_INPUT_REQUIRED|BLOCKED}
- Reviewer(s): {human user or AI reviewer roles}
- User approval, if any: {summary or N/A}
- Findings resolved: {list}
- Deferred non-blocking work: {list or none}
```

The review-readiness proof, accumulated focused signal, checkpoint owning gate, and higher wave/release
owner are separate plan fields even when two resolve to one command. “Identical” is valid only when
obligations, command/configuration, signal predicate, and required fingerprint are identical; bind
both labels to one current green receipt rather than running twice. Equality is plan metadata, not
proof that a receipt exists, and review-readiness evidence cannot discharge the owner by equality.
Default the owning gate to `POST_JOIN_DEFAULT`; `PRE_REVIEW_REQUIRED` needs the observable prerequisite
required by `lean-verification.md` and must complete GREEN before review dispatch.

Before issuing any lower-gate assignment, the orchestrator MUST evaluate all seven subsumption
conditions from `lean-verification.md` §6 and append either `RUN:<lower-gate-id>` or
`<lower-gate-id> SUBSUMED_BY:<higher-gate-id>`. `PENDING`, an assumed future gate, or a decision made
after the lower run is not valid subsumption. The evidence receipt is reusable only with every §7
field present and matching.

A boundary exception record is complete only when it evaluates all five ordered boundary rules. Rules
1–4 cannot be waived into a commit boundary that is semantically incomplete, invalid, unsafe to
rollback, or ownerless; instead merge/split the checkpoint or reopen Plan. Rule 5 is only a size
tie-breaker. Approval of an exception and approval of the plan still do not grant an action authority.

### Report files

Reports live under `reports/` instead of being appended forever to the briefing. They are joined
views written only by the orchestrator; specialist agents write immutable assignment artifacts, never
these shared files:

```text
reports/implementation-report.md
reports/verification-report.md
reports/review-report.md
reports/docs-report.md
reports/final-report.md
```

| Report | Orchestrator-owned inventory |
|--------|------------------------------|
| `implementation-report.md` | checkpoint/work-slice outcomes, source assignment IDs, changed-surface manifest |
| `verification-report.md` | gate ownership, subsumption decisions, evidence receipts/fingerprints, failure dispositions |
| `review-report.md` | expected lanes, lane artifacts, joined findings, remediation dispositions, confirmation, `REVIEW_APPROVED` transition |
| `docs-report.md` | product/living/release documentation obligations, source assignment IDs, documentation evidence; not the work-item audit ledger itself |
| `final-report.md` | DoD closure, candidate/ledger identities, commits and separately authorized downstream actions, remaining work |

Every report states the relevant Definition-of-Done status and links to immutable evidence under
`artifacts/`. The orchestrator aggregates; it does not rewrite specialist evidence.

### `handoffs/briefing.md`

The briefing is a lightweight current-context index and append-only control ledger. It should link to
`../requirements.md`, `../plan.md`, relevant `../reports/*`, and `../artifacts/*`. Only the orchestrator
appends assignment pointers, candidate freezes, state transitions, authority consumption, and handoff indexes
to it. Specialists never edit the briefing.

Before collect-all review, append a **current checkpoint handoff** containing the checkpoint ID,
approved plan-map reference, frozen base/candidate fingerprint, changed-file manifest, immutable diff
artifact, review-readiness receipt, accumulated/checkpoint/higher-gate ownership and timing/subsumption
decision, reviewer coverage lanes, and review collection status. All reviewers consume that same
fingerprint. Under `POST_JOIN_DEFAULT`, the accumulated/checkpoint receipt remains explicitly pending
until the complete join and final mutation.

## Candidate identity versus audit-ledger identity

These identities are intentionally separate:

- **Candidate fingerprint:** the delivery/runtime source, tests, generated artifacts, product docs,
  configuration, and environment closure being verified and reviewed. It carries every receipt field
  required by `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` §7.
- **Audit-ledger identity:** a digest of the ordered path/blob/file-mode manifest under the work-item
  folder, including the append-only briefing, assignment artifacts, lookups, review artifacts, and
  aggregate reports at a named instant.

The work-item audit ledger is excluded from the runtime candidate by default. Appending an assignment,
transition, or report changes the ledger identity but does not invalidate runtime evidence. If a
product/living/release document is a delivery output, list it explicitly in the candidate closure; do
not treat it as ledger merely because it is Markdown.

Each frozen candidate record contains:

```markdown
## Candidate freeze — {CANDIDATE-ID}
- Checkpoint: {CP-ID}
- Base/parent identity: {commit/tree/digest}
- Candidate fingerprint: {digest}
- Candidate changed-file manifest: {immutable artifact with ordered path/blob/file-mode entries}
- Full evidence input closure: {receipt-compatible artifact per lean-verification.md §7}
- Immutable diff: {artifact path + digest}
- Audit-ledger identity at freeze: {ledger ID + digest}
- Final staged-manifest check: {PENDING|MATCH — receipt path|MISMATCH}
```

Immediately before a checkpoint commit, the staged changed-file manifest MUST exactly match the
reviewed candidate manifest and the owning receipts MUST still bind that fingerprint. Missing or extra
paths are a mismatch, not a reason to silently expand the candidate. A byte-identical staging or commit
operation does not require a runtime rerun.

Work-item ledger files are not staged by default. If repository governance requires them in the same
semantic-checkpoint commit, seal their ordered manifest before staging and stop appending to that
sealed copy. The staged identity then binds two explicit closures: the unchanged reviewed candidate
and the sealed audit ledger. This does not rerun unrelated runtime gates, but the Commit authority must
name both manifests and the ledger needs its applicable documentation/integrity proof. Do not create a
ledger-only/evidence-only commit merely because the ledger was excluded from runtime proof. If a ledger
file changes runtime behavior, it was classified incorrectly and must enter the candidate closure.

## Object-scoped authority

Authority is append-only, action-specific, object-specific, and one-shot unless its record says
otherwise. Use this schema in the briefing or approved plan:

```markdown
## Authority {AUTHORITY-ID}
- Action: {BRANCH|COMMIT|PUSH|OPEN_PR|MERGE_PR|TAG|PUBLISH|RELEASE|REWRITE_HISTORY}
- Object: {CP-ID/candidate fingerprint, commit, branch, PR, tag, or release ID}
- Grantee: {exact actor}
- Mode/source: {co-working explicit user grant|pre-approved project policy}
- Scope: {exact paths/ref/destination}
- Preconditions: {states/receipts}
- Valid until / uses: {timestamp or event; one-shot by default}
- State: {GRANTED|CONSUMED|EXPIRED|REVOKED}
```

Requirement approval, Plan approval, auto mode, `REVIEW_APPROVED`, or a Commit grant does not imply
permission to push, open/merge a PR, tag, publish, release, or rewrite history. Each such action needs a
separate grant for its own object. A Commit grant is valid only for its named checkpoint fingerprint
and exact staged manifest; a changed candidate requires a new grant or an explicitly fingerprint-
parameterized policy.

## Typed append-only assignments

The orchestrator delegates through immutable assignment records, not prose-only prompts. Assignment
IDs are work-item-local, zero-padded, and strictly monotonic (`A-000001`, `A-000002`, ...). Never reuse
an ID, mutate an issued assignment, or infer “latest.” A correction or retry gets the next ID and names
the prior ID in `Supersedes`; the superseded record remains in the ledger.

Write this schema to `handoffs/assignments/{A-NNNNNN}.md`, then append only its ID/path/digest pointer
to the briefing index before invoking a specialist:

```markdown
## Assignment {A-NNNNNN}
- Assignment ID: {A-NNNNNN}
- Supersedes: {A-NNNNNN|none}
- Checkpoint ID: {CP-N|N/A}
- Work-slice ID: {WS-N|N/A}
- Agent: {exact registered agent/role identity}
- Activity: {REQUIREMENTS_REVIEW|DESIGN|ARCHITECTURE|PLAN_REVIEW|IMPLEMENT|VERIFY|REVIEW_DISCOVERY|REMEDIATE|REVIEW_CONFIRMATION|LOOKUP|DOCS|FINAL_AUDIT}
- Mode: {co-working|auto}
- Scope: {exact included paths/symbols/obligations and explicit exclusions}
- Input paths: {ordered exact paths; no directory shorthand unless the directory manifest is itself fingerprinted}
- Input fingerprints: {path/blob/mode or artifact digest for every input, candidate fingerprint if applicable, and audit-ledger identity at issue time}
- Output artifact: {one unique artifacts/assignments/...|artifacts/reviews/...|artifacts/lookups/... path}
- Canonical signal predicate: {exact observable completion/evidence predicate; never merely “agent says done”}
- State: ISSUED
```

`Output artifact` is mandatory and unique. Implementation/test/docs activities normally use
`artifacts/assignments/<A-NNNNNN>.md`; review uses
`artifacts/reviews/<CP-ID>/<lane>-<discovery|confirmation>-<A-NNNNNN>.md`; lookup uses
`artifacts/lookups/<A-NNNNNN>.md`. No assignment writes two workflow receipts and no two assignments
share an output path. Specialists do not write `reports/*`, `plan.md`, `requirements.md`, or
`briefing.md`; the orchestrator alone aggregates and appends control records.

The invocation passes only the assignment selector and entry point:

```text
ASSIGNMENT_ID={A-NNNNNN}
BRIEFING={work-item}/handoffs/briefing.md
ASSIGNMENT={work-item}/handoffs/assignments/{A-NNNNNN}.md
Read the briefing pointer and exact assignment file, verify ID/digest/input fingerprints, and execute
only that record. Write its one unique Output artifact. Return the same canonical STATUS written there.
```

The reader MUST match the exact ID/path/digest pointer, reject a missing/duplicate/mismatched record
with `BRIEFING_REQUIRED`, and never substitute a newer assignment. On completion, the specialist writes:

```markdown
# Assignment result — {A-NNNNNN}
- Assignment ID: {A-NNNNNN}
- Observed input fingerprints: {ordered values}
- Scope actually read/changed: {exact paths}
- Canonical signal observation: {predicate + evidence/receipt path}
- Output artifact: {this unique receipt path}
- Summary: {bounded result}
- STATUS: {canonical status}
```

The orchestrator validates the output path, assignment ID, fingerprints, scope, and canonical signal
predicate before appending a transition. A specialist result never mutates the assignment's issued
state; current state is derived from the last valid transition for that ID.

## Canonical statuses and transitions

Specialists return exactly one of these statuses:

- `COMPLETED`
- `REVIEW_LANE_COMPLETE`
- `CONFIRMED`
- `LOOKUP_REQUIRED`
- `CAPABILITY_BLOCKED`
- `PRODUCT_RED`
- `PLAN_REOPEN_REQUIRED`
- `INFO_REQUIRED`
- `BRIEFING_REQUIRED`
- `BLOCKED`

`REVIEW_APPROVED` is a joined checkpoint state emitted only by the orchestrator after review and
evidence aggregation; it is not a specialist self-verdict. An expected Tier-1 RED is likewise not an
assignment status. It is an evidence predicate that the orchestrator must observe in the assigned
receipt before it accepts the eventual `COMPLETED` result. A capability failure, invalid fixture, or
helper compile error cannot satisfy that predicate.

Every accepted result causes one immutable transition record:

```markdown
## Transition {T-NNNNNN}
- Assignment ID: {A-NNNNNN|checkpoint aggregate}
- From: {ISSUED|canonical prior state}
- Event/status: {canonical status}
- To: {canonical next state}
- Evidence: {assignment/receipt/report path + digest}
- Decision: {deterministic action from the table below}
- Timestamp/sequence: {monotonic ledger sequence; timestamp informational only}
```

| Observed result/state | Required orchestrator transition |
|-----------------------|----------------------------------|
| `COMPLETED` with matching predicate | Accept evidence, mark that activity complete, and issue only the next assignment declared by the approved checkpoint map. A completed lookup triggers the lookup-resume rule below. |
| `REVIEW_LANE_COMPLETE` | Record the lane; wait until every expected discovery lane for the same candidate fingerprint is present, then join/deduplicate once. Do not start lane-local remediation. |
| completed initial register records `DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE` | Ensure the current owning-gate receipt exists; then emit joined `REVIEW_APPROVED`. If the gate is pending, issue it first. Never infer this decision from an incomplete or later-resolved set. |
| completed initial register contains `ACCEPTED_CURRENT_SCOPE` remediation | Issue one joined remediation assignment covering exactly those canonical remediation IDs; after its last mutation freeze a new candidate, run its owning gate, then issue bounded confirmation assignments. |
| `CONFIRMED` | Mark only the assigned remediation IDs/surfaces confirmed. When every required confirmation and current owning-gate receipt is present, emit joined `REVIEW_APPROVED`. |
| material discovery during confirmation | Reject `CONFIRMED`; transition the checkpoint to `PLAN_REOPEN_REQUIRED` and return to Requirement Intake/Design/Architecture/Plan according to the violated intent or boundary. Never begin an ad-hoc discovery/remediation loop. |
| `LOOKUP_REQUIRED` | Keep the original activity unresolved; issue one `LOOKUP` assignment with a unique lookup artifact, then follow the lookup-resume protocol. |
| `CAPABILITY_BLOCKED` | Apply the Plan's capability policy. Repair/re-preflight without product mutation and issue a superseding assignment, or transition to `BLOCKED`. Never record product RED/GREEN. |
| `PRODUCT_RED` | Apply the declared Product RED policy: return to the bounded WS/CP with a superseding assignment, or transition to `PLAN_REOPEN_REQUIRED` if contract, boundary, ownership, or scope changes. Never blind-rerun. |
| post-commit wave/release `PRODUCT_RED` | Apply the Plan's post-commit policy: open a separately traceable corrective semantic checkpoint by default. Amend only an unshared commit under a matching object-scoped authority; a shared-history rewrite is `BLOCKED` unless separately and explicitly authorized. |
| `PLAN_REOPEN_REQUIRED` | Suspend execution and reopen Requirement Intake, Design, Architecture, or Plan as required; any new boundary/fingerprint gets new assignments and authority evaluation. |
| `INFO_REQUIRED` | Suspend the affected checkpoint and ask the user only for the exact missing decision; resume through a superseding assignment. |
| `BRIEFING_REQUIRED` | Orchestrator appends the missing/corrected control record, then issues a superseding assignment; the specialist does not repair the ledger. |
| `BLOCKED` | Stop the affected checkpoint and escalate with evidence; do not infer a bypass. |
| joined `REVIEW_APPROVED` | Verify the current object-scoped Commit authority, then expose/consume `ready_for_commit` only through the bound `commit-checkpoint` route; its derived staged manifest must match the reviewed candidate. Generic effect authorization and caller path inputs are forbidden. PR/push/merge/tag/publish/release remain separately authorized. |

Status precedence for one result is deterministic: `BLOCKED` > `INFO_REQUIRED` >
`PLAN_REOPEN_REQUIRED` > `BRIEFING_REQUIRED` > `CAPABILITY_BLOCKED` > `PRODUCT_RED` >
`LOOKUP_REQUIRED` > the activity's success status. A result that contains conflicting statuses is
invalid and transitions to `BRIEFING_REQUIRED` for correction.

## Lookup and resume protocol

A specialist that needs an unassigned path, symbol, contract, or external fact does not expand its
own scope. It returns `LOOKUP_REQUIRED` with the exact question, reason, desired evidence, and current
assignment ID in its assignment artifact.

1. The orchestrator issues the next monotonic assignment ID to the designated researcher with
   activity `LOOKUP`, exact bounded scope, and unique output
   `artifacts/lookups/<lookup-assignment-id>.md`.
2. The researcher records paths + line/symbol references, source identity, and digest in the lookup
   artifact and returns `COMPLETED`; it does not edit the original assignment or aggregates.
3. The orchestrator appends the lookup transition and issues a new assignment for the original
   activity. The new record names the original in `Supersedes` and includes the lookup paths and
   fingerprints in its ordered inputs.
4. The original specialist resumes only under the new assignment ID. The old assignment remains
   unresolved/superseded in the audit ledger and is never silently retried.

## Reviewer verdict format

Requirement and plan reviewers must use this format so the orchestrator/brain-flow runner can merge
results deterministically:

```markdown
## {Requirement|Plan} review verdict

Reviewer: {role}
Verdict: APPROVED | CHANGES_REQUIRED | USER_INPUT_REQUIRED | BLOCKED

Findings:
- Severity: blocking | material | non-blocking
- Standard/rule:
- Finding:
- Required action:
```

Gate aggregation rules:

- any `BLOCKED` → gate verdict `BLOCKED`;
- any `USER_INPUT_REQUIRED` → gate verdict `USER_INPUT_REQUIRED`;
- `CHANGES_REQUIRED` only → revise the artifact and rerun review if the change stays within approved scope;
- all `APPROVED`, or only non-blocking findings recorded/deferred → `AUTO_APPROVED` in auto mode;
- explicit human approval → `USER_APPROVED` in co-working mode.

## Review findings, joining, and confirmation

Every discovery lane uses the same frozen candidate and emits all findings non-fail-fast. Each finding
uses this stable schema; prose-only findings are invalid:

```markdown
### Finding {LANE-ID}-F{NNNN}
- Lane finding ID: {LANE-ID}-F{NNNN}
- Root-cause key: {<obligation-id>::<cause-class>::<owning-surface-id> using the Plan vocabulary}
- Severity: {BLOCKER|HIGH|MEDIUM|LOW}
- Obligation: {DoD/rule/risk ID}
- Evidence: {path:line/symbol and immutable artifact/receipt references}
- Symptoms: {ordered observable effects; one or many manifestations of this cause}
- Proposed action: {bounded correction or explicit defer rationale}
```

Lane IDs, four-digit finding sequences, cause classes, and owning-surface aliases are declared in the
review coverage map. The canonical key grammar is
`<obligation-id>::<cause-class>::<owning-surface-id>`; the key describes cause/owner, not prose or
symptoms. After every expected lane reports `REVIEW_LANE_COMPLETE`, the orchestrator alone:

1. validates the grammar and normalizes case plus declared path/symbol/surface aliases;
2. records semantically equivalent provisional strings as aliases of one canonical key; if equivalence
   is uncertain, keeps them separate and resolves ownership/materiality before mutation rather than
   guessing;
3. groups canonical keys and preserves every lane key in an alias ledger;
4. orders groups by severity (`BLOCKER`, `HIGH`, `MEDIUM`, `LOW`) then canonical root-cause key
   lexicographically;
5. allocates stable checkpoint-local IDs `REM-<CP-ID>-001`, `REM-<CP-ID>-002`, ...;
6. records one canonical disposition for each group in `reports/review-report.md`.

```markdown
### Remediation {REM-CP-ID-NNN}
- Record ID: {REM-CP-ID-NNN-R001}
- Supersedes: {prior record ID|none}
- Canonical remediation ID: {REM-CP-ID-NNN}
- Root-cause key: {key}
- Provisional key aliases: {sorted lane key strings}
- Joined lane finding IDs: {sorted IDs}
- Canonical severity: {highest member severity}
- Obligation: {canonical obligation IDs}
- Disposition: {ACCEPTED|ACCEPTED_CURRENT_SCOPE|DEFERRED|REJECTED|DUPLICATE_OF:<remediation-id>|REOPEN_REQUIRED:<gate>}
- Disposition rationale / authority: {reason and approver/policy}
- Remediation assignment: {A-NNNNNN|none}
- Confirmation assignments: {IDs|none}
- State: {JOINED|REMEDIATED|CONFIRMED|DEFERRED|REJECTED|PLAN_REOPEN_REQUIRED}
```

Corrections keep the canonical remediation ID and append the next record revision with `Supersedes`;
never edit the prior record or renumber IDs. After the complete join and materiality classification,
only `ACCEPTED_CURRENT_SCOPE` findings form one remediation batch. Confirmation is bounded
to the canonical remediation IDs and changed surfaces; it is not a second discovery pass. If a
confirmation lane discovers a new **material** root cause, it returns `PLAN_REOPEN_REQUIRED`, and the
orchestrator reopens Requirement Intake/Design/Architecture/Plan as appropriate instead of scheduling
another execute → review loop.

The orchestrator emits joined `REVIEW_APPROVED` only when all expected lanes are present, every
canonical remediation has a terminal disposition, the owning-gate receipt binds the final candidate,
and exactly one of these paths is proven: every initial `ACCEPTED_CURRENT_SCOPE` item is remediated and
confirmed once, or the immutable initial-register decision is
`DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE`. This joined state is mandatory before commit or PR
consideration but does not itself authorize either action.

## Artifact ownership

The orchestrator owns mutable workspace coordination and every aggregate. Every specialist owns only
the unique outputs named by its assignment.

All control/evidence history is append-only. The briefing, requirements/plan gate history, and
aggregate reports add sequence-numbered revision or correction sections; they never replace prior
records. Immutable specialist artifacts are never reopened. The current value is the highest valid
monotonic sequence that explicitly supersedes its predecessor, never whichever file has the newest
wall-clock timestamp.

| Actor/activity | One mandatory unique workflow artifact | Aggregate owner |
|----------------|----------------------------------------|-----------------|
| requirements/design/architecture/plan specialist | `artifacts/assignments/<assignment-id>.md` | orchestrator updates `requirements.md` / `plan.md` and gate records |
| implementer/remediator | `artifacts/assignments/<assignment-id>.md` | orchestrator updates `reports/implementation-report.md` |
| verifier/tester | `artifacts/assignments/<assignment-id>.md` | orchestrator updates `reports/verification-report.md` |
| discovery/confirmation review lane | `artifacts/reviews/<CP-ID>/<lane>-<kind>-<assignment-id>.md` | orchestrator joins only in `reports/review-report.md` |
| researcher lookup | `artifacts/lookups/<assignment-id>.md` | orchestrator appends pointers and issues superseding assignment |
| docs specialist | `artifacts/assignments/<assignment-id>.md` | orchestrator updates `reports/docs-report.md` |
| final-audit specialist | `artifacts/assignments/<assignment-id>.md` | orchestrator updates `reports/final-report.md` |

Specialists never aggregate one another's output and never append control state. If a prior fact is
wrong, the specialist reports `BRIEFING_REQUIRED`; the orchestrator appends a correction and issues a
superseding assignment. This preserves one writer per aggregate and deterministic append-only history.

## Reading rules (every hop)

1. Read the compact briefing index and exact assignment path supplied by the invocation; locate only
   their matching ID/pointer records rather than loading unrelated append history. If either is absent
   or mismatched, return `STATUS: BRIEFING_REQUIRED` and stop.
2. Verify the assignment digest/input fingerprints and read only its ordered input paths. If anything
   else is needed, return `LOOKUP_REQUIRED`; do not broaden scope or invoke a researcher yourself.
3. **Use compact specs by default** (`${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/*.compact.md`).
   A full spec must be an assigned input or obtained through the lookup protocol.
4. In auto mode, a gate verdict of `AUTO_APPROVED` is enough to proceed. Do not ask the user again
   unless the current hop discovers material ambiguity, missing bindings, destructive action, or a
   blocker.
5. Reviewers read only their assigned coverage lane on the frozen checkpoint fingerprint. They return
   all findings non-fail-fast; they do not trigger a fix pass independently.

## Writing rules (every hop)

1. **Write only assigned outputs.** The mandatory assignment artifact and any activity artifact are
   unique to the assignment. Never edit `briefing.md`, an aggregate report, or another assignment's
   artifact.
2. **Write long artifacts section-by-section.** Follow
   `${CLAUDE_PLUGIN_ROOT}/standards/process/long-document-writing.md`: create a skeleton first,
   append one major section per chunk, and write final status only after final verification.
3. **Cite, don't repeat.** Reference paths + line numbers; never paste full source.
4. **Mark deferred work explicitly** with `DEFERRED: {what} — owner: {agent}`. The next hop is
   responsible for picking it up or escalating.
5. End the mandatory assignment artifact with exactly one canonical `STATUS:` from the status section.
   Put the explanation in structured fields; do not invent `READY_FOR_*` or `CORRECTION_NEEDED` states.

## Orchestrator delegation pattern

When invoking a specialist via the `Task` tool:

```text
ASSIGNMENT_ID={A-NNNNNN}
BRIEFING=docs/02-working-docs/work-items/{work-item-id}-{task-slug}/handoffs/briefing.md
ASSIGNMENT=docs/02-working-docs/work-items/{work-item-id}-{task-slug}/handoffs/assignments/{A-NNNNNN}.md
Read the matching briefing pointer and exact assignment. Follow the assignment/status/reading/writing
contracts in `${CLAUDE_PLUGIN_ROOT}/standards/rules/BRIEFING_HANDOFF.md`. Verify fingerprints; write
only the one unique output named by the assignment; return the same canonical STATUS as that artifact.
```

No additional context paste. The work-item folder is the entire context; the briefing is the entry index.
The assignment record identifies the approved checkpoint/work-slice ID, operating mode, bounded
scope, exact inputs/outputs, and signal predicate. Internal work slices do not create approval, review,
commit, or full-gate handoffs by themselves.

For any task delegated by `brain-flow`, pass the detected flow mode in the briefing `## Meta`. The
orchestrator must preserve the same gate semantics:

- co-working mode → user confirms requirements and approves the plan;
- auto mode → AI gate reviewers approve requirements and plan; user is asked only for escalation cases.

Both modes use the same assignments, statuses, candidate/evidence identities, joined review, and
object-scoped action authority. Auto mode changes the gate approver; it does not grant Commit, push,
PR, merge, tag, publish, release, or history-rewrite authority.

## Optional context cache

A context cache is optional and pattern-specific. Use it when discovery is expensive or reused by
multiple hops. Keep the cache project-wide only when it is safe to share across tasks; otherwise keep
it under the work-item `artifacts/` folder.

```jsonc
{
  "config_hash": "sha256 of project binding/config files",
  "generated_at": "2026-05-23T10:00:00Z",
  "base_branch": "main",
  "project_targets": ["workspace/scheme/package target/app target"],
  "module_roots": ["path/to/modules"],
  "contract_index": [
    { "id": "contract-or-entrypoint-id", "visibility": "public|internal", "owner": "module/component" }
  ],
  "composition_roots": ["path/or/type names"],
  "verification_commands": ["targeted test/build commands"]
}
```

### Invalidation rules

The cache is **invalid** (must be rebuilt by the owning researcher/discovery stage) whenever any of
these is true:
1. `config_hash` no longer matches the project binding/config files used to build it.
2. A module/component target appears, disappears, or changes ownership.
3. `generated_at` is older than the pattern's cache TTL, defaulting to 7 days.
4. The current task creates or renames modules/components/contracts included in the cache.

### How stages consume it

- **Orchestrator / runner:** checks existence + hash; if invalid, delegates rebuild to the owning
  researcher/discovery stage, then reads.
- **Architect:** consumes module roots and contract indexes to avoid collisions; never edits.
- **Implementer:** consumes composition roots and project targets for wiring/build context.
- **Researcher/discovery stage:** the **only** writer. Writes via tool-supported file writes; never edits
  in place from another stage.
- **Reviewer / tester / docs stage:** read-only consumers.

### Boardy+VIP cache extension

A Boardy+VIP binding may extend the generic cache with fields such as:

```jsonc
{
  "workspace": "{Workspace}.xcworkspace",
  "main_scheme": "{MainScheme}",
  "xcodebuild_destination": "platform=iOS Simulator,name=iPhone 17,OS=latest",
  "service_map_classes": [
    { "module": "Cart", "class": "CartServiceMap", "accessor": "modCart" }
  ],
  "boardid_index": [
    { "id": "pub.mod.Cart.Checkout", "visibility": "public", "module": "Cart" },
    { "id": "mod.Cart.LineItem", "visibility": "internal", "module": "Cart" }
  ],
  "podspecs": ["submodules/Modules/Cart/Cart.podspec", "..."]
}
```

## Archival

After PR merge/completion, the orchestrator may move the work-item folder to
`docs/99-archive/work-items/{YYYY-MM-DD}-<WORK-ITEM-ID>-<slug>/` for traceability. Do not delete — the
work-item folder is the audit trail for the change.

## Why this exists

The orchestrator pays discovery cost once; each specialist loads only the exact assignment, cited
inputs, and role-specific compact rules. Unique artifacts preserve traceability without repeated
discovery, concurrent report writes, or unsupported savings claims.
