# Requirements — IIS-0001 brain-flow-auto-mode

## Meta
- Created: 2026-07-09
- Flow mode: co-working
- Downstream mode after approval: auto-capable
- Scale: medium
- Pattern binding: standards package update; Boardy+VIP-aware flow semantics
- Base branch: main
- Branch: chore/brain-flow-ai-loop-dod
- Project execution target: N/A — standards/skill Markdown-only change

## Requirement summary
- Ticket/work item ID and title: IIS-0001 — brain-flow auto mode and AI loop readiness.
- Business/user goal: Make `brain-flow` a maintainable, mode-aware end-to-end workflow that supports co-working and auto approval, AI loop execution against a Definition of Done, and per-work-item documentation that does not collapse all artifacts into one growing report file.
- In scope:
  - Add co-working and auto approval modes.
  - Add Requirement Intake Gate with requirement summary, open questions/proposals, generated ticket ID, and Definition of Done checklist.
  - Treat approved Definition of Done as downstream agent loop goal.
  - Let co-working users choose downstream co-working or downstream auto after approving summary + DoD.
  - Add per-work-item docs folder structure with split requirements, plan, reports, handoffs, and artifacts.
  - Update process docs and briefing handoff rules to reference the split artifact model.
- Out of scope:
  - Changing product Swift/iOS runtime code.
  - Changing Claude Code runtime behavior beyond plugin skill/process docs.
  - Publishing this follow-up unless explicitly requested.
- UI/design requirements: N/A — documentation/skill flow only.
- API/backend/data requirements: N/A — no backend/API/data model changed.
- Source code areas likely affected:
  - `ifl-ios-standards/skills/brain-flow/SKILL.md`
  - `ifl-ios-standards/skills/brain-plan/SKILL.md`
  - `ifl-ios-standards/skills/brain-execute/SKILL.md`
  - `ifl-ios-standards/skills/brain-review/SKILL.md`
  - `ifl-ios-standards/skills/brain-testing/SKILL.md`
  - `ifl-ios-standards/standards/process/docs-organization.md`
  - `ifl-ios-standards/standards/process/long-document-writing.md`
  - `ifl-ios-standards/standards/process/requirement-intake.md`
  - `ifl-ios-standards/standards/process/approval-modes.md`
  - `ifl-ios-standards/standards/rules/BRIEFING_HANDOFF.md`
  - `docs/02-working-docs/work-items/IIS-0001-brain-flow-auto-mode/*`
- Risks and assumptions:
  - Assumption: `IIS` is the generated project code for `ifl-ios-standards`.
  - Assumption: This is a docs/skill/process update, so Tier 3 verification is sufficient.
  - Risk: Existing historical artifact at `docs/02-working-docs/handoffs/brain-flow-auto-mode/briefing.md` should be migrated/removed to avoid duplicate sources of truth.
- Open questions: None remaining for this follow-up.

## Definition of Done
- [x] Requirement Intake summary includes Definition of Done checklist.
- [x] Missing ticket/work item IDs are generated as `<PROJECT-CODE>-NNNN` using uppercase project abbreviation and auto-increment.
- [x] Approved DoD is documented as the downstream agent loop goal.
- [x] Co-working mode offers a downstream choice after summary + DoD approval: continue co-working or switch downstream stages to auto.
- [x] Plan, execute, testing, review, and final report docs map work back to DoD items.
- [x] Docs organization defines one work-item folder per ticket/work item.
- [x] Work-item folders split `requirements.md`, `plan.md`, `reports/*`, `handoffs/*`, and `artifacts/*` instead of one growing file.
- [x] Final verification passes after migrating this artifact to the new split work-item folder.

## Requirement gate
- Mode: co-working
- Downstream mode after approval: auto-capable; user may choose downstream auto after DoD approval.
- Verdict: USER_APPROVED
- Reviewer(s): human user + assistant review
- User confirmation, if any: User approved the AI loop DoD patch and then added the per-work-item folder requirement.
- Definition of Done approved: yes
- Assumptions accepted:
  - Use `IIS-0001` for this work item.
  - Keep this as docs/skill/process update only.
- Open questions resolved:
  - Project code format: uppercase project abbreviation.
  - Work item docs should be split by file under one folder.

STATUS: READY_FOR_PLAN
