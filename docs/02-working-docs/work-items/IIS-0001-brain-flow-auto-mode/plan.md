# Plan — IIS-0001 brain-flow-auto-mode

## Implementation plan
- Mode: co-working
- Downstream mode source: co-working user approved execution in this session.
- Phase summary:
  - Phase 1: Add AI loop DoD semantics to brain-flow and stage skills.
  - Phase 2: Add ticket ID generation and DoD rules to process/handoff docs.
  - Phase 3: Add per-work-item folder structure and split artifact guidance.
  - Phase 4: Migrate the current working artifact into the split work-item folder and verify.
- Definition of Done coverage:
  - DoD items 1–5 → Phase 1 + Phase 2.
  - DoD items 6–7 → Phase 3 + Phase 4.
  - Final verification item → Phase 4.
- Verification strategy:
  - `git diff --check -- ifl-ios-standards docs`
  - sanity check required strings and ensure work-item split files exist.
  - Full runtime build/test gate: N/A — docs/skill/process update only.
- TDD tiers: Tier 3 — docs/skill/process declarations only.
- Pattern forwarding: N/A; this update is pattern-neutral with Boardy examples preserved as extensions.
- Risks / rollback:
  - Roll back by reverting changed Markdown files and removing the work-item folder migration.

### Phase 1: AI loop DoD semantics [verify: L0]
- [x] T1.1 Add Definition of Done to `brain-flow` Requirement Intake summary.
- [x] T1.2 Define approved DoD as agent loop goal.
- [x] T1.3 Align plan/execute/testing/review stages with DoD mapping.
Checkpoint:
- Command: `git diff --check -- ifl-ios-standards docs`
- Expected signal: no output.

### Phase 2: Ticket ID + gate artifacts [verify: L0]
- [x] T2.1 Add `<PROJECT-CODE>-NNNN` ticket generation rule.
- [x] T2.2 Add downstream mode after DoD approval to approval modes.
- [x] T2.3 Add DoD and downstream fields to handoff templates.
Checkpoint:
- Command: sanity check for `<PROJECT-CODE>-NNNN`, `Definition of Done`, and downstream mode fields.
- Expected signal: pass.

### Phase 3: Per-work-item documentation model [verify: L0]
- [x] T3.1 Add `docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/` to docs organization.
- [x] T3.2 Update long-document writing to split by purpose before chunking.
- [x] T3.3 Update requirement intake and brain-flow artifact paths.
- [x] T3.4 Update briefing handoff to be a compact handoff/index rather than the full audit trail.
Checkpoint:
- Command: sanity check for `work-items`, `requirements.md`, `plan.md`, `reports`, `handoffs`, and `artifacts` references.
- Expected signal: pass.

### Phase 4: Artifact migration and final report [verify: L0]
- [x] T4.1 Create split work-item folder for `IIS-0001-brain-flow-auto-mode`.
- [x] T4.2 Write `requirements.md`, `plan.md`, split reports, and `handoffs/briefing.md`.
- [x] T4.3 Remove or supersede the legacy monolithic handoff path.
- [x] T4.4 Run final verification after migration.
Checkpoint:
- Command: `git diff --check -- ifl-ios-standards docs` plus split-file sanity check.
- Expected signal: pass.

## Plan gate
- Mode: co-working
- Definition of Done coverage: all current DoD items mapped to phases.
- Verdict: USER_APPROVED
- Reviewer(s): human user + assistant plan review
- User approval, if any: User said "go ahead" for the AI loop patch and then clarified the per-work-item documentation model.
- Findings resolved:
  - Monolithic report risk addressed by per-work-item folder and split files.
- Deferred non-blocking work: none.

STATUS: READY_FOR_EXECUTION
