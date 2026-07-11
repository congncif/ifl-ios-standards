# Process — Lean Verification and Checkpoint Economics

**Trigger:** Before implementing a change, when writing or approving an implementation plan, and
whenever a workflow chooses commit, review, or verification boundaries.

This policy preserves strict engineering evidence while removing duplicate execute → verify → review
loops. It changes granularity and evidence ownership, not quality. Project bindings provide canonical
commands; this document defines when a signal is required, when another gate may subsume it, and when
existing evidence is still valid.

## 1. Required terms

- **Work slice:** the smallest implementation batch that can produce a useful causal signal. A slice
  is not automatically a commit, review, checkpoint, or full-gate boundary.
- **Semantic checkpoint:** one complete domain invariant, user-story outcome, or Definition-of-Done
  outcome that is independently valid, reviewable, and rollbackable. A checkpoint may contain many
  work slices and files. The default is one verified commit per semantic checkpoint.
- **Wave gate:** integration/global-regression evidence across multiple semantic checkpoints. A wave
  gate does not merge those checkpoints into one commit.
- **Owning gate:** the one declared gate responsible for a particular set of verification obligations
  on one evidence fingerprint. Local/checkpoint and global/release obligations may have different
  owners, but an obligation never has duplicate owners.

Do not use `task`, `phase`, `slice`, `checkpoint`, `commit`, and `gate` as synonyms.

## 2. Classify behavior by TDD tier

Classify the affected behavior before writing production code. When tiering is genuinely ambiguous,
ask once; do not silently weaken Tier 1.

**Tier 1 — strict test-first RED → GREEN**

- Core domain logic, algorithms, transforms, and non-obvious invariants.
- Public/wire API contracts and their handlers.
- Money, authentication, permissions, transaction boundaries, security, or data integrity.
- Bug fixes where regression is plausible.

The RED must be behavioral and causal. A missing tool, stale cache, sandbox failure, helper compile
error, or invalid fixture is capability/test-infrastructure evidence, not the required RED.

**Tier 2 — test-after, batched within the semantic checkpoint**

- Adapters, mappers, vendor boundaries, ordinary CRUD, and composition-root wiring without business
  rules.

**Tier 3 — no runtime test required**

- Documentation, comments, styling, declarative configuration, type-only declarations, and explicit
  throwaway spikes.

When a change spans tiers, apply the highest tier to the behavior it covers. Tiering changes when a
signal runs; it never permits an applicable test or quality obligation to disappear.

## 3. Select semantic checkpoints

Choose a boundary in this order. Every proposed boundary, merge, split, and exception MUST pass the
rules in this order; a later rule or an approval label cannot waive an earlier one:

1. **Semantic completeness:** one domain invariant, user story, or DoD outcome is complete.
2. **Boundary validity:** the repository state at the boundary is independently valid; no half-migrated
   schema, digest, or protocol state remains.
3. **Independent rollback:** reverting the checkpoint does not break adjacent checkpoints.
4. **Coherent impact and ownership:** blast radius, reviewer ownership, and verification obligations
   form one understandable unit.
5. **Cognitive review size:** use size only as a tie-breaker between otherwise valid semantic seams.

LOC, file count, layer count, or an arbitrary target such as “3–7 tasks” MUST NOT create a boundary by
itself. Atomic-cascade integrity is also mandatory: no exception may leave a half-valid canonical
state.

### Atomic cascades

Artifacts that jointly establish one canonical invariant stay in one semantic checkpoint and, when
separately authorized, one commit. Typical cascades include schema/wire model, fixtures, generated
artifacts, digest/provenance,
compatibility or migration receipts, and the verifier that closes the same invariant. Do not create an
evidence-only, generated-only, or digest-only commit merely to shrink a diff when the intermediate
state is not independently valid. A shared generator, reviewer, gate, or digest mechanism is not by
itself an atomic cascade: when each semantic outcome can regenerate a complete valid state and be
rolled back independently, the outcomes remain separate checkpoints.

### Split and merge tests

Independent semantic outcomes **MUST split** once each outcome passes semantic completeness,
independent validity, rollback, and sufficient-proof rules. A shared higher gate, reviewer, tool,
version, or digest never merges them when each boundary can regenerate a valid canonical state.

Merge only parts of the same semantic outcome when a candidate intermediate state is invalid, rollback
is coupled, or severing the same version/digest/migration cascade would violate atomicity. For every
exceptional merge or split, record the ordered boundary evaluation and preserve every atomic cascade.

If an indivisible cascade exceeds the declared review budget, do not manufacture an invalid boundary.
Instead:

1. record a **split-minimality proof** naming each plausible seam and the earliest ordered rule or
   atomic-cascade invariant it fails;
2. divide implementation into the smallest causal work slices;
3. partition review into non-overlapping risk/obligation lanes and use deterministic schema/generated/
   digest comparison where applicable; and
4. add reviewer capacity or schedule another review window when the declared coverage still exceeds
   available capacity.

Review budget controls reviewer capacity and lane scope; it is not permission to skip coverage or to
combine independent outcomes.

### Commit contract

- Default, when separately authorized: one commit after each verified/reviewed semantic checkpoint.
- A work slice does not create a commit.
- A wave gate does not require a commit.
- Where project governance says **commit by task**, `task` means the approved semantic checkpoint in
  the checkpoint map, not each internal subtask or work slice.
- A separate prerequisite/evidence commit is allowed only when it independently passes every ordered
  boundary rule above, preserves every atomic cascade, and is declared at the Plan Gate.
- After verification, the staged candidate manifest must byte-match the reviewed candidate fingerprint.
  A separately sealed audit-ledger manifest may accompany the same commit only when governance and
  object-scoped authority require it; it does not create an evidence-only commit or runtime rerun.
  A byte-identical commit does not require another test run.
- Plan approval, including `AUTO_APPROVED`, is engineering approval only. Commit, amend, history
  rewrite, push, and corrective-commit actions require separate explicit authority scoped to that Git
  action and repository. Without commit authority, stop before the commit operation and report the
  verified candidate; never invent a status or infer authority from the checkpoint map.

## 4. Plan Gate checkpoint map

Every executable plan must include a checkpoint map. For each semantic checkpoint, declare these as
separate fields:

- semantic outcome and mapped DoD obligations;
- atomic cascade and exact expected scope;
- internal work slices and TDD tiers;
- validity and rollback boundary;
- impact/reviewer coverage matrix, review budget, and split-minimality proof when required;
- accumulated focused signal: ID, command/selector, obligations, and schedule;
- checkpoint owning gate: ID, command/selector, and complete obligation set;
- whether the accumulated focused signal and checkpoint owning gate are exactly equal in command,
  obligations, and candidate fingerprint (`EQUAL` or `DISTINCT`);
- higher wave/release owner: ID, schedule, and complete obligation set;
- intended lower-to-higher subsumption and the planned pre-run evaluation of all §6 conditions;
- the complete normative §7 candidate-fingerprint/input-closure fields and invalidation conditions;
- Product RED return policy for expected/unexpected behavior failures;
- capability/preflight failure policy that never misclassifies infrastructure as product behavior;
- post-commit wave/release failure policy covering complete capture, clustering, corrective boundaries,
  authority, and one rerun;
- commit boundary plus the separate scoped Git-authority reference, or `NONE`; and
- every pre-approved boundary exception with its ordered-rule and atomic-cascade proof.

The approval applies to the map, not to every work slice, and never grants Git authority. A materially
different scope or contract reopens Requirement/Design/Architecture as appropriate; a different
checkpoint boundary, risk owner, obligation, gate, or verification owner reopens the Plan Gate.

## 5. Verification cadence and signals

Use the cheapest causal signal at the earliest useful point and the expensive signal only at its owner:

| Signal | Purpose | Cadence |
|---|---|---|
| Causal/static/schema | Prove one changed behavior or mechanical invariant | During a work slice; Tier 1 observes RED → GREEN |
| Accumulated focused signal | Prove the affected seam and accumulated checkpoint behavior | After related slices or before freezing the checkpoint |
| Checkpoint owning gate | Prove every checkpoint-owned obligation for commit/readiness | Once after the checkpoint's last mutation, unless equal to the accumulated signal or subsumed |
| Wave/release canonical gate | Full build, suite, integration, or release qualification | At the declared higher owner after the last relevant mutation |

Commands come from the consuming project's bindings/canonical scripts. Do not hard-code a Go, Kotlin,
iOS, scheme, destination, or tool command in this policy.

Do not rerun unrelated targeted tests after every slice. Run the new causal proof, then one accumulated
targeted set at the semantic boundary. Plan one authoritative full-suite/build execution per evidence
fingerprint at its owning higher gate. A real failure, invalid capability run, or subsequent relevant
mutation justifies a rerun; an unchanged green tree does not.

The accumulated focused proof may itself be the checkpoint owning gate. If the Plan Gate declared them
`EQUAL` and their obligations, command, and candidate fingerprint still match, execute once and bind
both labels to one receipt. If declared or observed `DISTINCT`, both obligations remain pending unless
valid §6 subsumption applies.

### Capability preflight

Before an expensive gate, cheaply verify and fingerprint what the gate needs: executable/wrapper and
supported flags, scheme/target/destination, toolchain/dependencies, external scratch permissions, and
credentials/network/service availability where applicable. Classify capability failure separately
from product failure. Reuse the preflight until its environment fingerprint changes.

## 6. Gate subsumption

Evaluate subsumption **before** running lower gate `A`; never run `A` and retroactively call it
subsumed. Higher gate `B` may subsume `A` only when **all** conditions hold:

1. `B` executes every obligation/assertion owned by `A`; a broader name is insufficient.
2. Both gates use the same relevant input fingerprint.
3. Command, configuration, target/destination, toolchain, and environment are equivalent or `B` is
   demonstrably stricter.
4. `B` runs after the final mutation in `A`'s scope.
5. `B` reports `A`'s obligations distinctly enough to diagnose and archive evidence.
6. No earlier commit, rollback, approval, promotion, or human gate requires `A`'s evidence first.
7. `B` is actually available and scheduled at the current boundary, not merely planned later.

When all hold, record `SUBSUMED_BY:<gate-id>` before `A` would run and do not run `A`. If any condition
is unknown, run `A`. A higher green gate cannot retroactively replace a Tier-1 behavioral RED that was
never observed.

Example: an immediate wave gate that invokes the exact checkpoint script and then adds integration
checks should run once, not once as a checkpoint and immediately again as a wave. It cannot subsume a
checkpoint proof needed for a commit that occurs before the wave.

## 7. Evidence fingerprint, reuse, and invalidation

This complete section is normative for every consuming skill, agent, verifier, and evidence store.
Consumers may extend the record but MUST NOT omit a field below or replace the contract with a shorter
local definition.

- **Candidate fingerprint:** deterministic content identity of the exact base/parent plus ordered input
  closure being evaluated. Recompute it when any candidate input changes; record execution context and
  obligations separately in the evidence record below.
- **Audit-ledger identity:** unique append-only identity of a gate attempt, review lane result,
  aggregation, disposition, or confirmation event. It points to a candidate fingerprint but is never
  reused, rewritten, or treated as the candidate's content identity.

Every reusable evidence record binds at least:

- candidate fingerprint and unique audit-ledger identity;
- gate ID/version, command, arguments, and test selector;
- base/parent identity and an ordered path/blob/file-mode manifest or equivalent hash of the declared
  source/test/generated input closure;
- schema/generator/digest inputs and outputs where applicable;
- dependency lock, toolchain, configuration, target, and destination;
- environment/external-state stamp or TTL when it affects results;
- obligations/DoD items proven and the exact result.

Reuse a green receipt only when every relevant field still matches. Invalidate it when relevant source,
test, generated output, schema/digest cascade, dependency, toolchain, configuration, command, target,
destination, merge/rebase result, environment, external state, or TTL changes. A read-only review,
staging, or byte-identical commit does not invalidate it.

A change proven outside the declared closure—such as a work-item note—does not invalidate runtime
evidence. If the closure cannot be established reliably, fall back to the whole source tree rather
than guessing. Before commit or completion, the final staged candidate manifest MUST byte-match the
candidate fingerprint referenced by both the current owning-gate receipt and the final review or
confirmation disposition record.

## 8. Review economics

At the Plan Gate, map:

`risk/obligation → artifact scope → primary reviewer → independent secondary lens (if any) → proof`

- Give every obligation one primary owner.
- Add a second reviewer only for a genuinely independent lens.
- Do not add a generic reviewer when specialist scopes already cover the checkpoint. If a generalist
  is needed, limit it to unowned integration seams.
- Freeze one immutable checkpoint baseline and collect all findings non-fail-fast before mutation.
- Each finding MUST carry a stable lane ID, lane-local finding ID, root-cause key, severity, mapped
  obligation, evidence, and all observed symptoms. The aggregator assigns a canonical remediation ID
  and one intake disposition: `ACCEPTED`, `DEFERRED`, `REJECTED`, or
  `DUPLICATE_OF:<remediation-id>`. Kernel-bound records map terminal forms to
  `deferred_by_policy`, `rejected_with_evidence`, and `duplicate` respectively.
- Plans declare a root-cause grammar/vocabulary. The aggregator normalizes declared aliases before
  grouping, records every provisional alias, and keeps uncertain equivalence separate until ownership
  and materiality are resolved; it never relies on independently worded exact strings alone.
- Before mutation, classify every `ACCEPTED` finding's materiality. An in-scope finding becomes
  `ACCEPTED_CURRENT_SCOPE` (Kernel wire value `accepted_current_scope`). Scope/contract divergence
  becomes `REOPEN_REQUIRED` for Requirement, Design, or Architecture as appropriate;
  owner/boundary/obligation/gate divergence becomes `REOPEN_REQUIRED` for Plan. A finding cannot
  remain generically `ACCEPTED` at the mutation boundary; mutate only after any required gate is
  approved again and a successor checkpoint/baseline owns it.
- Apply one remediation batch only for `ACCEPTED_CURRENT_SCOPE` findings.
  Behavioral defects get causal regression tests at their applicable tier. Mechanical/generated/docs
  defects use static, lint, schema/digest proof, or Tier 3 as applicable; never create a fake behavioral
  test merely to satisfy the loop.
- Run the affected focused proof and the still-pending checkpoint owning gate only after the batch's
  final mutation. Only after the complete roster join and materiality classification may the immutable
  initial-register decision select `DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE`. That decision skips
  remediation and confirmation only; it does not skip the checkpoint owning gate unless that gate
  already equals the accumulated proof or was prospectively subsumed under §6. Never recompute this
  branch from later `resolved` dispositions.
- After remediation's final mutation and owning proof, recompute the candidate fingerprint and create
  immutable versioned manifest/diff evidence before issuing bounded confirmation.
- Confirmation checks dispositions and changed surfaces only. It MUST NOT become another discovery
  pass over the full diff.
- Any material new finding observed during confirmation signals a faulty plan/boundary/coverage
  matrix, regardless of whether it lies inside the changed or assigned surface. Reopen Requirement,
  Design, Architecture, or Plan as appropriate instead of starting an ad-hoc execute → review loop.

Prefer collect-all review before an expensive owning gate when review is likely to trigger mutation.
Review and a gate may run in parallel only against the same immutable fingerprint and only when the
saved latency justifies the risk of discarded gate evidence.

## 9. Co-working and auto parity

Both modes use the same checkpoint boundaries, evidence, tests, review budget, and quality gates.

- **Co-working:** the user approves the checkpoint map at the Plan Gate. Do not ask again after each
  work slice; pause only at declared human gates or material divergence/ambiguity.
- **Auto:** the AI gate approves the same map, records its rationale, and escalates only material
  ambiguity, blocker, or authority expansion.

Mode changes who approves; it does not change engineering rigor or multiply gates.

If a wave/release gate fails after earlier checkpoint commits:

1. freeze mutation and capture the complete diagnostics from that failed run;
2. cluster all symptoms by root cause and affected semantic checkpoint before editing;
3. plan one coordinated corrective set, splitting independent corrective outcomes by §3 and reopening
   the required upstream gate for material divergence;
4. apply the set, run its causal/focused proofs and checkpoint owners after the final mutation; then
5. rerun the failed wave/release gate once on the resulting candidate fingerprint.

The default is a separately traceable corrective semantic-checkpoint commit for each independent
outcome. Commit/amend still requires explicit corrective Git authority. Amend only when that separate
authority preauthorizes the exact unshared commit; never rewrite shared history or merge unrelated
repairs to hide the failure.

## 10. Completion checklist

Completion requires:

- every checkpoint/DoD obligation mapped and closed or explicitly deferred;
- applicable Tier-1 causal RED → GREEN evidence;
- one current green owning gate per required evidence scope/fingerprint;
- review findings joined with canonical remediation IDs/dispositions, one remediation batch completed
  when needed, and bounded confirmation green;
- final staged candidate manifest byte-equal to the candidate fingerprint referenced by current
  owning-gate and review/confirmation records;
- no duplicate gate run on an unchanged fingerprint.

## Non-goals

- Lowering test coverage or skipping applicable verification.
- Replacing CI or configuring a CI provider; canonical local scripts and evidence are in scope, CI
  provider implementation is not.
- Forcing small commits by LOC/file count.
- Disabling or forking another workflow plugin.
