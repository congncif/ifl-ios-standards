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
chapters (see the per-stage skills); this file orchestrates mode, gates, pattern forwarding, and
verification checkpoints.

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
   working-docs root). Keep related plan/report/handoff/artifact files in that same folder. For long
   artifacts, follow `${CLAUDE_PLUGIN_ROOT}/standards/process/long-document-writing.md`: split by
   purpose first, then append one major section per chunk. Then continue to Design.

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
| Plan Gate | Phase along IO → Sources → Plugins seams; include Boardy-specific reviewers in auto mode |
| Execute | Matching `boardy-*` implementation skill for the change type, such as new module/board, IO interface, communication, service layer, or plugin composition |
| Test / Checkpoint | `:boardy-testing` |
| Review | `:boardy-review` |

## Inline pipeline (small/medium tasks)

| Stage | Skill / action | Gate behavior | Forward when Boardy mode |
|-------|----------------|---------------|--------------------------|
| 1. Requirement Intake Gate | Understand request, locate likely code, summarize requirements, define DoD loop goal, surface unknowns/proposals | Co-working: user confirms summary + DoD and chooses downstream co-working or auto. Auto: AI requirement gate approves. | `/ifl-ios-standards:boardy-vip` router for spec routing |
| 2. Design | `/ifl-ios-standards:brain-design` | No approval gate unless material design proposal changes requirements. | `boardy-vip` → `DECISION_TREES.md` |
| 3. Architect | `/ifl-ios-standards:brain-architect` | Stop only for missing bindings or material architecture tradeoff not settled by standards. | `LAYERING.md`, `CROSS_MODULE_DI.md` via router |
| 4. Plan Gate | `/ifl-ios-standards:brain-plan` | Co-working: user approves. Auto: AI plan gate approves. | Phase along IO → Sources → Plugins seams |
| 5. Execute | `/ifl-ios-standards:brain-execute` | Execute only an approved plan. | `:boardy-new-module` `:boardy-new-board` `:boardy-io-interface` `:boardy-communication` `:boardy-service-layer` `:boardy-plugin-composition` per change type |
| 6. Test / Checkpoint | `/ifl-ios-standards:brain-testing` | Verify at phase boundaries only. Red checkpoint loops back to Execute for the current phase. | `:boardy-testing` |
| 7. Review | `/ifl-ios-standards:brain-review` | Blocking findings loop back to Execute; non-blocking findings may be batched or deferred explicitly. | `:boardy-review` |
| 8. Final Gate + Report | Full gate once after the last code change, then factual report | Write `reports/final-report.md` with changed files, commands run, DoD status, results, and remaining work. | — |

## Stage 4 — Plan Gate

The plan must group work into phases of related tasks, declare the TDD tier per task, map each phase
back to the approved Definition of Done items, and place verification steps at phase boundaries only
(`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`). Each phase names likely files, the
cheapest sufficient checkpoint, and the bound-pattern forwarding needed for that phase.

- **Downstream co-working mode**: present the phased implementation plan and stop for user approval
  before execution.
- **Downstream auto mode**: spawn plan reviewers/subagents for scope alignment, Definition-of-Done
  coverage, architecture, pattern compliance, verification semantics, execution feasibility, and risk.
  Revise and rerun review for fixable findings. Continue only when the plan gate verdict is
  `AUTO_APPROVED`.
- Always ask the user for material product/scope tradeoffs, missing binding values, or blockers that
  cannot be resolved without changing the approved requirement summary.

## Checkpoints and failure loop

- Verify at phase boundaries only (`${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`).
- Use the cheapest sufficient check first; escalate only when needed.
- Full build + full suite exactly once, after the last code change and before the final report.
- Each checkpoint records which Definition of Done items it proves or leaves open.
- A failed checkpoint loops back to Execute for that phase — never skip forward past a red signal.
- If repeated failure exposes an unclear requirement or invalid plan, go back to the relevant gate
  (Requirement Intake or Plan Gate) instead of patching blindly.
- Docs-only/config-only changes may report a non-runtime final gate as N/A, but only when no product
  source behavior changed.

## Guardrails

- Do not implement before requirements are clear and the Requirement Intake Gate is approved.
- Do not execute before the Plan Gate is approved: human approval in co-working mode, AI gate approval
  in auto mode.
- Auto mode may decide internal implementation details when standards clearly determine the answer;
  it may not invent product intent.
- Missing binding value → stop and ask, don't guess.
- Report states facts: what changed, what was verified, the final status of every Definition of Done item, and what remains.
