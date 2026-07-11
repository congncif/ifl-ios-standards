---
name: brain-flow
description: >-
  Use when the user wants the whole workflow automated end-to-end — requirements → design →
  architect → plan → execute → review → done — instead of driving each stage by hand. Supports
  co-working mode (human approval gates) and auto mode (AI gate approval with escalation only for
  material ambiguity/blockers). Pattern-neutral with auto-detection of a bound pattern such as
  Boardy+VIP. Triggers: "take this feature from idea to done", "run the full workflow", "automate
  the whole process", "end-to-end on this task", "full auto".
---

# Brain — Flow (mode-aware end-to-end workflow automation)

Runs the brain stage skills in sequence as one pipeline. Each stage loads only its own rulebook
chapters (see the per-stage skills); this file orchestrates mode, gates, pattern forwarding, semantic
checkpoints, review economics, and verification ownership.

## Stage 0 — Detect mode + scale + pattern binding

1. **Detect flow mode.**
   - Explicit co-working request ("co-working", "review with me", "ask before continuing") →
     **co-working mode**.
   - Explicit automation request ("auto", "full auto", "end-to-end automation", "run until done") →
     **auto mode**.
   - Project binding may declare a default. If no default exists, use **co-working mode** for backward
     compatibility and safety.
   - Mode controls approval gates only. Both modes still require clear requirements, an approved plan,
     checkpoint verification, and factual reporting.
2. **Read the consuming repo's `CLAUDE.md`** (+ bindings per
   `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md` §5).
   - Declares Boardy+VIP → **Boardy mode on**: stages also forward to the matching `boardy-*` skill
     or standard in the forwarding map below.
   - No pattern bound → run pure brain rulebook; no forwarding.
   - Missing binding value → stop and ask; do not guess workspace, scheme, destination, module roots,
     or docs root.
3. **Size the task.**
   - **Trivial**: docs/copy/config or a very small one-file tweak with no runtime behavior. Use an
     abbreviated pipeline but still report assumptions and verification applicability.
   - **Small**: ≤1 module/board, few files, no major public API/data-flow change → run the inline
     pipeline below.
   - **Medium**: one module/board but multiple layers, moderate data flow, or non-trivial testing → run
     the inline pipeline with a written briefing/spec and full gates.
   - **Large**: spans >1 board/module, adds a module/board/service, changes public contracts, or has
     significant data flow. If the bound pattern supplies an orchestrator, delegate the whole delivery
     to that orchestrator pipeline and pass the detected flow mode; for Boardy+VIP this is the
     `ios-orchestrator` briefing-handoff pipeline. If no orchestrator is bound, continue inline with
     full requirement/plan gates or stop and ask for an execution strategy.
   - **Critical**: money, auth, permissions, transaction/data integrity, or security-sensitive behavior
     → use the strictest applicable TDD/review path. If a suitable orchestrator pipeline is available,
     prefer it.

## Approval modes

### Co-working mode

- Stage 1 (Requirement Intake Gate) presents the requirement summary, open questions, proposals, and
  Definition of Done checklist.
- The user confirms the requirement summary and Definition of Done before Design starts.
- After that approval, ask whether downstream stages should continue in co-working mode or switch to
  auto mode until the Definition of Done is complete.
- Stage 4 (Plan Gate) follows the selected downstream mode: human approval if co-working continues,
  AI gate approval if the user switches downstream execution to auto.

### Auto mode

- Stage 1 and Stage 4 are reviewed by AI gate reviewers/subagents instead of requiring routine user
  approval.
- Auto mode **does not mean guessing product intent**. Ask the user when material requirements,
  scope, UX, API/data contracts, bindings, destructive actions, or standards conflicts are unclear.
- Continue automatically only when the relevant gate verdict is `AUTO_APPROVED`.
- If a reviewer returns fixable `CHANGES_REQUIRED`, revise the summary/plan and rerun the gate review.
- If a reviewer returns `USER_INPUT_REQUIRED` or `BLOCKED`, stop and escalate to the user with the
  smallest necessary question.

See `${CLAUDE_PLUGIN_ROOT}/standards/process/approval-modes.md` for the shared gate semantics.

## Stage 1 — Requirement Intake Gate

This stage replaces the old lightweight "Analyze" step. It is interactive in co-working mode and
AI-reviewed in auto mode.

1. Read the request, attached docs, referenced ticket/spec, and relevant project bindings.
2. Locate likely affected source areas using the smallest sufficient lookup. In Boardy mode, use the
   Boardy router/spec map to classify the change.
3. Produce a concise requirement summary:
   - Ticket/work item ID and title. If absent, auto-generate `<PROJECT-CODE>-NNNN`, where
     `PROJECT-CODE` is the uppercase project-name abbreviation (or explicit project binding) and
     `NNNN` is the next zero-padded auto-increment ID found from existing task artifacts.
   - Business/user goal.
   - In scope.
   - Out of scope.
   - UI/design requirements.
   - API/backend/data requirements.
   - Source code areas likely affected.
   - Risks and assumptions.
   - Open questions.
   - Definition of Done checklist.
4. Surface open questions and proposals:
   - **Material requirement question**: affects goal, scope, UX, API/data contract, security, money,
     permissions, or externally visible behavior → must be answered by the user.
   - **Material proposal**: changes the user's intended requirement or creates a significant product
     tradeoff → must be accepted by the user.
   - **Technical assumption**: internal naming, file placement, layering, or implementation detail
     where standards clearly prefer one option → may be auto-selected and recorded.
   - **Non-blocking clarification**: record as an assumption; do not block the pipeline.
5. If anything material is unclear, stop and ask the user. After receiving answers or additional
   documents, reread the new context and update the summary and Definition of Done.
6. Treat the approved Definition of Done as the **agent loop goal**. Downstream stages must plan,
   execute, test, review, and report against this checklist until every item is completed, explicitly
   deferred, or blocked with a reason.
7. Gate approval:
   - **Co-working mode**: present the summary and Definition of Done, then ask the user to confirm.
     After approval, ask whether downstream stages should keep co-working gates or switch to auto mode
     until the Definition of Done is complete.
   - **Auto mode**: spawn requirement reviewers/subagents for completeness, scope guard, product
     ambiguity, Definition-of-Done measurability, technical surface, and bound-pattern compliance.
     Continue only when the requirement gate is `AUTO_APPROVED`.
8. Once requirements are clear and approved, create the work-item folder and write the summary/spec to
   `docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/requirements.md` (or the project's bound
   working-docs root). Keep related files in the same folder using the canonical structure:
   `requirements.md`, `plan.md`, `reports/{implementation-report,verification-report,review-report,final-report}.md`,
   `handoffs/briefing.md`, and `artifacts/*`. Do not invent additional top-level work-item files unless
   the user or project binding explicitly requires them; put design/architecture notes in `plan.md` or
   link to a separate living/standalone doc when they become durable docs. For long artifacts, follow
   `${CLAUDE_PLUGIN_ROOT}/standards/process/long-document-writing.md`: split by purpose first, then
   append one major section per chunk. Then continue to Design.

See `${CLAUDE_PLUGIN_ROOT}/standards/process/requirement-intake.md` for the template and reviewer
contract.

## Pattern forwarding map

A bound pattern contributes detection rules, stage forwarding, scale behavior, required artifacts, and
extra gate reviewers. The base brain stage always runs first; the pattern extension then constrains or
specializes the output.

### Pattern extension contract

Each bound pattern should define:

- detection rule and required bindings;
- optional orchestrator for large/critical work;
- stage extensions for requirement intake, design, architecture, planning, execution, testing, and review;
- extra auto-mode gate reviewers;
- required artifacts and archive behavior.

### Boardy+VIP binding

| Brain stage | Boardy extension |
|-------------|------------------|
| Requirement Intake | `/ifl-ios-standards:boardy-vip` router for task classification and spec routing |
| Design | `boardy-vip` + `${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md` |
| Architect | `${CLAUDE_PLUGIN_ROOT}/standards/specs/LAYERING.md`, `CROSS_MODULE_DI.md` via router |
| Plan Gate | Sequence IO → Sources → Plugins work slices without forcing checkpoint boundaries; include Boardy-specific reviewers in auto mode |
| Execute | Matching `boardy-*` implementation skill for the change type, such as new module/board, IO interface, communication, service layer, or plugin composition |
| Test / Checkpoint | `:boardy-testing` |
| Review | `:boardy-review` |

## Inline pipeline (small/medium tasks)

| Stage | Skill / action | Gate behavior | Forward when Boardy mode |
|-------|----------------|---------------|--------------------------|
| 1. Requirement Intake Gate | Understand request, locate likely code, summarize requirements, define DoD loop goal, surface unknowns/proposals | Co-working: user confirms summary + DoD and chooses downstream co-working or auto. Auto: AI requirement gate approves. | `/ifl-ios-standards:boardy-vip` router for spec routing |
| 2. Design | `/ifl-ios-standards:brain-design` | No approval gate unless material design proposal changes requirements. | `boardy-vip` → `DECISION_TREES.md` |
| 3. Architect | `/ifl-ios-standards:brain-architect` | Stop only for missing bindings or material architecture tradeoff not settled by standards. | `LAYERING.md`, `CROSS_MODULE_DI.md` via router |
| 4. Plan Gate | `/ifl-ios-standards:brain-plan` | Approve a checkpoint map: semantic outcomes, atomic cascades, work slices, owning gates, reviewer coverage, evidence fingerprints, and commits. Co-working: user approves. Auto: AI plan gate approves. | Sequence work along IO → Sources → Plugins seams without turning every seam into a checkpoint |
| 5. Execute work slices | `/ifl-ios-standards:brain-execute` | Execute only the approved map. Each slice gets its causal signal; no automatic review, commit, or full gate per slice. | `:boardy-new-module` `:boardy-new-board` `:boardy-io-interface` `:boardy-communication` `:boardy-service-layer` `:boardy-plugin-composition` per change type |
| 6. Freeze + collect-all review | `/ifl-ios-standards:brain-testing` + `/ifl-ios-standards:brain-review` | Prospectively subsume or run the accumulated focused proof, freeze one candidate fingerprint, then collect all assigned review lanes before the aggregator canonicalizes root causes and dispositions. | `:boardy-testing` + `:boardy-review` |
| 7. Remediate + owning gate + authorized commit | `/ifl-ios-standards:brain-execute` + `/ifl-ios-standards:brain-testing` | Classify materiality before mutation; apply one in-scope batch, run affected proof/pending owner, refreeze versioned candidate evidence, then bounded confirmation. Commit only under separate scoped Git authority. | Matching Boardy execution skill + `:boardy-testing` |
| 8. Wave/Final Gate + Report | Run only the declared higher owner on the current candidate fingerprint, then report facts | A higher gate may subsume a lower gate only under `lean-verification.md`; write `reports/final-report.md` with changed files, evidence receipts, DoD status, results, and remaining work. | — |

## Stage 4 — Plan Gate

The plan may use phases/waves as sequencing containers, but approval is based on a **semantic
checkpoint map**, not task/file counts. Each checkpoint must declare:

- its complete domain invariant, user-story outcome, or Definition-of-Done outcome;
- the DoD obligations it closes and any atomic schema/generated/digest/migration cascade that must
  remain one valid state;
- internal work slices and TDD tier/causal signal for each affected behavior;
- why the boundary is independently valid and rollbackable;
- exact impact scope, reviewer coverage matrix, review budget, and split-minimality proof when an
  indivisible cascade exceeds that budget;
- accumulated focused signal with its ID, command/selector, obligations, and schedule;
- checkpoint owning gate with its ID, command/selector, and complete obligations;
- an explicit `EQUAL`/`DISTINCT` decision between those two signals;
- higher wave/release owner with its ID, schedule, complete obligations, and any intended subsumption
  evaluated before the lower gate would run;
- the complete normative evidence record from `lean-verification.md` §7, distinguishing candidate
  fingerprint from append-only audit-ledger identities;
- separate Product RED, capability/preflight, and post-commit wave/release failure policies; and
- the post-verification commit boundary plus a separate scoped Git-authority reference or `NONE`.

Use semantic completeness, validity, rollback, and coherent impact ownership before cognitive size.
Independent semantic outcomes MUST split even when they share a gate, reviewer, tool, or digest if
each boundary can regenerate a valid state. LOC, file count, layer count, or an arbitrary number of
tasks must not create a checkpoint. Keep an atomic cascade together and split its implementation into
work slices when needed. Every checkpoint exception must pass all ordered boundary rules and preserve
atomic cascades. Follow
`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` for the normative selection and
subsumption algorithm.

- **Downstream co-working mode**: present the phased implementation plan and stop for user approval
  before execution.
- **Downstream auto mode**: spawn plan reviewers/subagents for scope alignment, Definition-of-Done
  coverage, architecture, pattern compliance, verification semantics, execution feasibility, and risk.
  Revise and rerun review for fixable findings. Continue only when the plan gate verdict is
  `AUTO_APPROVED`.
- Always ask the user for material product/scope tradeoffs, missing binding values, or blockers that
  cannot be resolved without changing the approved requirement summary.

## Checkpoint operating loop

For each approved semantic checkpoint, run this sequence:

`work-slice causal signals → prospective subsumption decision → focused/owner receipt → freeze candidate → collect-all review →`
`classify materiality → {direct convergence | one remediation batch → owning gate → bounded confirmation} → ready-for-commit route`

- A work slice is not a checkpoint, review, commit, approval, or full-gate boundary. Do not ask the
  user to approve routine slices in co-working mode.
- Under commit-by-task governance, the approved semantic checkpoint is the traceable task/commit;
  internal subtasks and work slices do not create extra commits. A commit still requires separate,
  explicit, object-scoped Git authority; Plan or AUTO approval never supplies it.
- In a Kernel-bound flow, consume `ready_for_commit` only through the bound launcher:
  `ifl-workflow commit-checkpoint --run-receipt <receipt> --checkpoint-id <id> --message <message>`.
  The command derives the exact reviewed path/tree set from authenticated checkpoint state; callers
  supply no paths, directories, globs, or pathspecs. Never route `vcs.git-commit` through generic
  `authorize-effect`. Without matching authority, retain `ready_for_commit` as a resumable wait. After
  the typed commit receipt is recorded, call `resume`/`next`; do not manufacture a new workflow stage.
  A Plan-declared bootstrap adapter may stand in only before this command exists and must enforce the
  same object scope and receipt contract.
- Only after the complete frozen-roster join and materiality classification may the authoritative
  initial register return `DIRECT_CONVERGENCE_NO_ACCEPTED_CURRENT_SCOPE`. Consume that recorded
  decision—not a transient empty set or later `resolved` state—to skip remediation and confirmation
  only. Run any pending checkpoint owning gate unless it equals the accumulated proof or was
  prospectively subsumed.
- Reviewers inspect the same immutable fingerprint, cover assigned non-overlapping risks, and return
  all findings before mutation. Each finding carries stable lane/finding IDs, root-cause key, severity,
  obligation, evidence, and symptoms; the aggregator assigns canonical remediation IDs/dispositions.
- Classify every intake-`ACCEPTED` finding before mutation. Contract/scope divergence becomes an
  upstream reopen; owner/boundary/obligation/gate divergence reopens Plan. Only findings classified
  `ACCEPTED_CURRENT_SCOPE` enter the current checkpoint's remediation batch.
  Behavioral defects get causal regression tests; mechanical defects use static/lint/schema/Tier-3
  proof as applicable.
- Confirmation checks accepted dispositions and changed surfaces only; it is not a new discovery pass.
  Any material new confirmation finding reopens the appropriate upstream gate, even when observed
  outside the changed or assigned surface.
- Run full suite/build/integration only at the declared owning wave/release gate. When a scheduled
  higher gate covers a lower gate on the same fingerprint, evaluate subsumption before the lower run,
  record `SUBSUMED_BY:<gate-id>`, and do not duplicate it. If any condition is unknown, run the lower.
- Apply the complete evidence contract in `lean-verification.md` §7. Candidate fingerprints identify
  evaluated content/context; append-only audit IDs identify attempts and dispositions. Before commit,
  the final staged manifest must match the fingerprint referenced by owning-gate and final-review
  evidence.
- A real red signal returns to the affected work slice or checkpoint. If failure exposes an unclear
  requirement, invalid boundary, public-contract change, or wrong risk owner, return to the relevant
  Requirement, Design, Architecture, or Plan Gate.
- Docs-only/config-only changes may report a runtime gate as N/A only when no product-source behavior
  or applicable obligation changed.
- After a post-commit wave failure, capture all diagnostics before mutation, cluster root causes and
  affected checkpoints, apply one coordinated corrective set, and rerun the wave once. Default to
  separately traceable corrective checkpoints; amend only an explicitly authorized, exact unshared
  commit. Corrective commits require their own scoped Git authority.

Co-working and auto mode use this identical loop, evidence, review budget, and quality bar; only the
gate approver differs.

## Guardrails

- Do not implement before requirements are clear and the Requirement Intake Gate is approved.
- Do not execute before the Plan Gate is approved: human approval in co-working mode, AI gate approval
  in auto mode.
- Plan/AI approval authorizes engineering execution, not Git commit, amend, rewrite, push, or corrective
  commit. Require separate explicit authority scoped to the action and repository.
- Auto mode may decide internal implementation details when standards clearly determine the answer;
  it may not invent product intent.
- Missing binding value → stop and ask, don't guess.
- Report states facts: what changed, what was verified, the final status of every Definition of Done item, and what remains.
