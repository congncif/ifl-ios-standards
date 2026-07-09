# Briefing — brain-flow-auto-mode

## Meta
- Created: 2026-07-09
- Flow mode: co-working
- Scale: medium
- Pattern binding: standards package update; Boardy+VIP-aware flow semantics
- Orchestrator model: N/A — single-agent documentation/spec update
- Base branch: main
- Branch: main — no feature branch was requested
- Workspace / Scheme / Destination: N/A — standards/skill Markdown-only change

## Requirement summary
- Ticket/work item ID and title: N/A — update `brain-flow` for requirement intake, auto/co-working modes, and end-to-end pipeline semantics.
- Business/user goal: Make `brain-flow` a true mode-aware end-to-end automation workflow while preserving human collaboration gates when requested and only escalating in auto mode for material ambiguity, product-impacting proposals, missing bindings, or serious blockers.
- In scope:
  - Upgrade Stage 1 from lightweight Analyze to Requirement Intake Gate.
  - Add required requirement summary structure.
  - Add open question/proposal classification and escalation rules.
  - Add `co-working` and `auto` modes.
  - Change Stage 4 from mandatory user approval to Plan Gate approval based on mode.
  - Formalize pattern binding → forwarding map → stage behavior, including Boardy+VIP mapping.
  - Clarify verification checkpoint semantics and failure loop.
  - Update briefing handoff contract to capture requirement/plan gates and AI reviewer verdicts.
  - Align dependent brain stage skills with the new approval semantics.
  - Write a lightweight handoff artifact for this work item.
- Out of scope:
  - Implementing a runtime engine beyond skill/standards documentation.
  - Changing Swift/iOS product source code.
  - Updating package release metadata or publishing a new plugin version.
  - Adding automated markdown lint tooling beyond sanity checks run in this session.
- UI/design requirements: N/A — documentation/skill flow only.
- API/backend/data requirements: N/A — no backend/API/data model changed.
- Source code areas likely affected:
  - `ifl-ios-standards/skills/brain-flow/SKILL.md`
  - `ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md`
  - `ifl-ios-standards/standards/process/requirement-intake.md`
  - `ifl-ios-standards/standards/process/approval-modes.md`
  - `ifl-ios-standards/skills/brain-plan/SKILL.md`
  - `ifl-ios-standards/skills/brain-execute/SKILL.md`
  - `ifl-ios-standards/skills/brain-review/SKILL.md`
  - `ifl-ios-standards/skills/brain-testing/SKILL.md`
  - `docs/02-working-docs/handoffs/brain-flow-auto-mode/briefing.md`
- Risks and assumptions:
  - Assumption: This update is intentionally documentation/skill-contract level; no runtime orchestration code exists to modify in this repo for this request.
  - Assumption: `co-working` remains the safe backward-compatible default when mode is not explicit.
  - Risk: Large Boardy delegated pipeline also needs orchestrator behavior to follow the same semantics; this is documented in `BRIEFING_HANDOFF.md`, but individual orchestrator agent prompt files may need a follow-up alignment if they exist elsewhere.
  - Risk: Auto approval wording must remain clear that AI can approve standards compliance and implementation details, but cannot invent product intent.
- Open questions: None remaining for this documentation/spec update.

## Requirement gate
- Mode: co-working
- Verdict: USER_APPROVED
- Reviewer(s): human user + assistant summary/review
- User confirmation, if any: User approved the proposal and later approved creating this artifact.
- Assumptions accepted:
  - Treat this as a standards/skill documentation update.
  - Do not create a branch or commit unless explicitly requested.
  - Use a lightweight briefing artifact under `docs/02-working-docs/handoffs/brain-flow-auto-mode/`.
- Open questions resolved:
  - Confirmed that plan/report artifacts had not yet been written.
  - Confirmed artifact creation after user approval.

STATUS: READY_FOR_PLAN_GATE

## Implementation plan
- Mode: co-working
- Phase summary:
  - Phase 1: Update `brain-flow` contract.
  - Phase 2: Extend briefing handoff and add shared process docs.
  - Phase 3: Align dependent brain stage skills.
  - Phase 4: Add this handoff/report artifact and run lightweight verification.
- Verification strategy:
  - Docs-only/skill Markdown change; use `git diff --check` and a basic Markdown file sanity script.
  - Full runtime build/test gate: N/A because no product source/runtime behavior changed.
- TDD tiers:
  - Tier 3 — docs/skill/process declarations only; no tests required.
- Pattern forwarding:
  - Boardy+VIP forwarding map documented in `brain-flow`.
  - Large delegated flow mode propagation documented in `BRIEFING_HANDOFF.md`.
- Risks / rollback:
  - Rollback by reverting the touched Markdown files.
  - If orchestrator prompts exist separately and are later found out of sync, update them in a follow-up.

### Phase 1: Brain-flow contract [verify: L0]
- [x] T1.1 Add mode detection and approval mode semantics — Tier 3.
- [x] T1.2 Replace Stage 1 Analyze with Requirement Intake Gate — Tier 3.
- [x] T1.3 Add Stage 4 Plan Gate behavior by mode — Tier 3.
- [x] T1.4 Add pattern forwarding map and checkpoint/failure loop semantics — Tier 3.
Checkpoint:
- Command: `git diff --check -- <affected markdown files>`
- Expected signal: no whitespace/error output.
- Failure loop: edit affected Markdown and rerun check.

### Phase 2: Shared process and handoff docs [verify: L0]
- [x] T2.1 Add `standards/process/requirement-intake.md` — Tier 3.
- [x] T2.2 Add `standards/process/approval-modes.md` — Tier 3.
- [x] T2.3 Extend `standards/rules/BRIEFING_HANDOFF.md` with requirement/plan gates and reviewer verdicts — Tier 3.
Checkpoint:
- Command: `git diff --check -- <affected markdown files>`
- Expected signal: no whitespace/error output.
- Failure loop: edit affected Markdown and rerun check.

### Phase 3: Dependent brain skill alignment [verify: L0]
- [x] T3.1 Update `brain-plan` approval wording — Tier 3.
- [x] T3.2 Update `brain-execute` approved-plan guardrail — Tier 3.
- [x] T3.3 Update `brain-review` drift handling — Tier 3.
- [x] T3.4 Update `brain-testing` checkpoint wording — Tier 3.
Checkpoint:
- Command: basic Markdown sanity script.
- Expected signal: `markdown sanity check passed`.
- Failure loop: edit affected Markdown and rerun check.

### Phase 4: Handoff artifact and final report [verify: L0]
- [x] T4.1 Create `docs/02-working-docs/handoffs/brain-flow-auto-mode/briefing.md` — Tier 3.
- [ ] T4.2 Run final lightweight verification after artifact creation — Tier 3.
- [ ] T4.3 Report final changed files, commands, and remaining work — Tier 3.
Checkpoint:
- Command: `git diff --check -- <affected markdown files including this artifact>`
- Expected signal: no whitespace/error output.
- Failure loop: edit affected Markdown and rerun check.

## Plan gate
- Mode: co-working
- Verdict: USER_APPROVED
- Reviewer(s): human user + assistant plan proposal
- User approval, if any: User approved the detailed proposal and instructed execution.
- Findings resolved:
  - Added missing artifact/report trace after user pointed out the gap.
- Deferred non-blocking work:
  - Potential follow-up: inspect/update any separate `ios-orchestrator` agent prompt files if they contain hardcoded old approval semantics.

STATUS: READY_FOR_EXECUTION

## Implementation report
- Files modified:
  - `ifl-ios-standards/skills/brain-flow/SKILL.md`
  - `ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md`
  - `ifl-ios-standards/skills/brain-plan/SKILL.md`
  - `ifl-ios-standards/skills/brain-execute/SKILL.md`
  - `ifl-ios-standards/skills/brain-review/SKILL.md`
  - `ifl-ios-standards/skills/brain-testing/SKILL.md`
- Files added:
  - `ifl-ios-standards/standards/process/requirement-intake.md`
  - `ifl-ios-standards/standards/process/approval-modes.md`
  - `docs/02-working-docs/handoffs/brain-flow-auto-mode/briefing.md`
- Summary of changes:
  - `brain-flow` now defines mode detection, Requirement Intake Gate, Plan Gate, auto/co-working approval semantics, Boardy+VIP forwarding map, checkpoint semantics, and auto escalation rules.
  - `BRIEFING_HANDOFF.md` now captures requirement and plan gate records, reviewer verdict schema, gate aggregation rules, and mode propagation to delegated orchestrator pipelines.
  - New process docs split reusable requirement intake and approval mode rules out of the skill file.
  - Dependent brain skills now reference the new approval model and checkpoint behavior.
- Deferred work:
  - DEFERRED: Align any separate orchestrator agent prompt files if they duplicate old Stage 4 approval language — owner: follow-up standards update.

STATUS: READY_FOR_VERIFICATION

## Test / Verification report
- Classification: Tier 3 docs/skill/process update.
- Commands already run before this artifact was created:
  - `git diff --check -- ifl-ios-standards/skills/brain-flow/SKILL.md ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md ifl-ios-standards/standards/process/requirement-intake.md ifl-ios-standards/standards/process/approval-modes.md ifl-ios-standards/skills/brain-plan/SKILL.md ifl-ios-standards/skills/brain-execute/SKILL.md ifl-ios-standards/skills/brain-review/SKILL.md ifl-ios-standards/skills/brain-testing/SKILL.md`
  - Result: passed; no output.
  - Basic Python Markdown sanity script over affected Markdown files.
  - Result: `markdown sanity check passed`.
- Final verification after this artifact creation: pending at time of writing this section.
- Full runtime build/test gate: N/A — no product source/runtime surface changed.

STATUS: READY_FOR_FINAL_CHECK

## Final report
- Status: pending final lightweight verification after artifact creation.
- Remaining work:
  - Run final `git diff --check` including this briefing artifact.
  - Update user-facing final response with verification result.

STATUS: READY_FOR_FINAL_REPORT

## Correction — Final report
- Reason: the original final report was written before final lightweight verification completed, and a follow-up long-document-writing rule was added afterward.
- Additional files added after the original final report:
  - `ifl-ios-standards/standards/process/long-document-writing.md`
  - `ifl-ios-standards/standards/process/README.md`
- Additional files updated after the original final report:
  - `ifl-ios-standards/standards/process/docs-organization.md`
  - `ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md`
  - `ifl-ios-standards/skills/brain-flow/SKILL.md`
  - `ifl-ios-standards/standards/process/requirement-intake.md`
  - `ifl-ios-standards/standards/process/approval-modes.md`
- Final verification commands completed before this correction section:
  - `git diff --check -- ifl-ios-standards/standards/process/long-document-writing.md ifl-ios-standards/standards/process/docs-organization.md ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md ifl-ios-standards/skills/brain-flow/SKILL.md ifl-ios-standards/standards/process/requirement-intake.md ifl-ios-standards/standards/process/approval-modes.md ifl-ios-standards/standards/process/README.md docs/02-working-docs/handoffs/brain-flow-auto-mode/briefing.md`
  - Result: passed; no output.
  - Long-document references sanity check.
  - Result: `long-document references sanity check passed`.
- Full runtime build/test gate: N/A — docs/skill/process update only; no product source/runtime surface changed.
- Remaining work:
  - Optional follow-up: inspect/update any separate `ios-orchestrator` agent prompt files if they duplicate old approval semantics.

STATUS: READY

## Correction — Review and genericization pass
- Reason: user requested a review before commit to standardize and genericize the updates so reusable standards are not over-bound to one implementation detail.
- Review performed:
  - Eight review angles were run: line diff, removed behavior, cross-file trace, reuse, simplification, efficiency, altitude, and conventions.
  - Findings retained for current diff scope: none requiring correctness fixes.
  - One cross-file candidate referenced files in an isolated agent worktree outside the current working-tree diff; it was not applied as an in-scope finding.
- Genericization fixes applied:
  - `brain-flow` large-task behavior now delegates to a bound pattern orchestrator when one exists, with Boardy+VIP as an example rather than the generic rule.
  - `brain-flow` now defines a generic pattern extension contract before the Boardy+VIP mapping.
  - `BRIEFING_HANDOFF.md` top sections now use generic affected areas, components/services, project execution target, and context cache wording.
  - `BRIEFING_HANDOFF.md` per-hop headings now describe generic stage/agent roles instead of only `ios-*` agents.
  - `BRIEFING_HANDOFF.md` cache guidance is now an optional generic context cache with a Boardy+VIP extension example.
- Verification after genericization:
  - `git diff --check -- ifl-ios-standards docs`
  - Result: passed; no output.
  - Genericization sanity check.
  - Result: `genericization sanity check passed`.
- Remaining work:
  - None required before commit from this review pass.
  - Optional future follow-up: separately review portable Claude templates/changelog terminology if those files are in a future diff.

STATUS: READY
