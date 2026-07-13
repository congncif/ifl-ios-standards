# Plan — IIS-0003 Standards 1.0 GA readiness

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md` — `AUTO_APPROVED`
- Baseline: `v1.0.0-rc.1` / `481b203ab1f855ccd3ff6c8a907a077e3f239400`
- Working candidate: `1.0.0-rc.2`
- Execution branch/worktree: `codex/standards-1.0` in `/private/tmp/ifl-ios-pack-standards-v1`
- Integration owner: primary agent; only the integration owner updates this plan, requirements, release metadata, or final report.

## Execution strategy

- Execute four complete semantic tasks continuously after the Plan Gate. Do not create per-file, per-layer, or per-finding checkpoints.
- Commit once after each complete semantic task using explicit paths. The existing user grant authorizes local stage and commit for these plan tasks only.
- Specialists may work only on disjoint assigned paths. The integration owner joins their output and owns cross-document consistency.
- Do not run a documentation build, plugin-owned verifier, workflow evidence command, CI, or duplicate green signal.
- The only intermediate executable signal is the focused scaffolder check in Task 2 because that task changes a shipped executable. Canon SHA-256 values are data-integrity fields, not workflow verification evidence.
- After Tasks 1–4, freeze writers and run one joined AI consistency review over the complete candidate. Apply all accepted P0/P1 corrections in one Task 5 batch; do not schedule a routine re-review.
- Public marketplace installation stays pinned to `v1.0.0-rc.1`. Push, tag, publish, install, and release are not part of this plan.

## DoD coverage

| DoD | Owning task |
|---|---|
| D1, D2 | Task 1 — payload and Canon integrity |
| D3, D4 | Task 2 — authority and architecture closure |
| D5, D6, D7 | Task 3 — full-auto operating model and conformance |
| D8, D9 | Task 4 — RC2/GA governance and metadata |
| D10 | Task 5 — final joined review and corrective batch |
| D11, D12 | Every task; integration owner enforces scope and explicit-path commits |

## Planning baseline commit

After the Plan Gate is approved, commit only this work item's `requirements.md` and `plan.md` as the semantic planning baseline. This is not an implementation checkpoint and triggers no build/test/review loop.

## Task 1 — Quarantine frozen tooling and converge ADR lifecycle

**Outcome:** the installable plugin contains only active standards/skills/agents/scaffolders, while Canon's eleven accepted ADRs have one coherent lifecycle representation.

**Status:** COMPLETE

### Changes

- Move `ifl-ios-standards/backlog/post-1.0/custom-kernel/` to repository-root `backlog/post-1.0/custom-kernel/`.
- Move `ifl-ios-standards/tools/` and `ifl-ios-standards/verification/` beneath that root backlog, preserving history and marking all material inactive/non-shipping.
- Preserve `ifl-ios-standards/standards/canon/schemas/` and `ifl-ios-standards/standards/canon/registry/` unchanged except for the required ADR index digest values.
- Change the lifecycle status in all eleven `standards/canon/adrs/*.md` records to Accepted.
- Update each paired JSON `markdown_digest`, then update all eleven `record_digest` entries in `standards/canon/registry/adrs.index.json` from the resulting JSON bytes.
- Mark Task 1 and D1/D2 complete in this work item only after the move and integrity values are complete.

### Bounded checks

- Compute each Markdown and JSON SHA-256 once while writing the required integrity fields.
- Inspect the resulting plugin top-level tree once to confirm that `tools/`, `verification/`, and `backlog/` are absent and active Canon schemas/registry remain.
- No build, test, package validation, or intermediate AI review.

### Commit boundary

- Explicit paths: root `backlog/`, removed plugin-owned backlog/tools/verification paths, ADR Markdown/JSON/index files, and this work item's task state.
- Commit intent: `chore: quarantine frozen kernel and accept ADR records`.

## Task 2 — Restore one authority model and close Boardy layering

**Outcome:** Canon/ADRs own obligations; derived guidance is correctly mapped or clearly advisory; Boardy remains an optional outward profile around framework-neutral application policy.

**Status:** COMPLETE

**Focused executable signal:** `bash -n` passed; one UIKit board scaffold emitted only Boardy, module,
and UIKit imports and used UIKit `show(_:sender:)`. This signal is not repeated unless the executable changes.

### Changes

- Make `standards/brain/QUICK_REF.md`, relevant Brain rulebook chapters, and `standards/rules/QUICK_REF.md` state the Canon-first authority hierarchy and risk-based executable verification model.
- Correct the domain-purity mapping to `CORE-DEP-001`; remove discovery-cache and unconditional per-task build/test language from active routing/reference surfaces.
- Label pattern checklists, examples, and reviewer aids as derived guidance where they are not direct Rule restatements. Update the smallest necessary set among `standards/specs/BOARDY_FOUNDATIONS.md`, `REVIEWER_CHECKLIST.md`, `REVIEW_PLAYBOOK.md`, and related compact guidance.
- Reconcile `standards/specs/SDK_FIRST.md`, `LAYERING.md`, `SERVICE_LAYER.md`, `ARCHITECTURE.md`, and ADR-0002-derived wording around a framework-neutral Domain/Application boundary.
- Scope Boardy imports to Boardy orchestration/presentation adapters. Remove blanket SiFUtilities approval and update `bin/ifl-new-board` so it emits no unused SiFUtilities import.
- Preserve the Presenter-owned presentation-value/formatting contract and minimal ephemeral UX state rule across VIP, UIKit, SwiftUI, and Boardy guidance.
- Mark Task 2 and D3/D4 complete after the full semantic surface is internally consistent.

### Bounded checks

- Inspect the changed authority/layering statements as one semantic set.
- Run `bash -n ifl-ios-standards/bin/ifl-new-board` and one focused scaffold invocation into a temporary directory; inspect only the emitted imports/boundaries affected by this task.
- Do not rerun this signal at final review unless Task 5 changes the executable.

### Commit boundary

- Explicit paths: the changed Brain/rule/spec guidance, `bin/ifl-new-board`, and this work item's task state.
- Commit intent: `docs: align authority and Boardy application boundaries`.

## Task 3 — Complete provider-native full-auto operation and enterprise conformance

**Outcome:** active roles can execute what they promise, auto gates are independently owned, provider-native recovery/resume is specified, and enterprise adoption works with or without Boardy.

**Status:** COMPLETE

### Changes

- Add one concise active operating contract under `standards/process/` covering:
  - full-auto eligibility and preflight;
  - Git/repository/organization/release authority binding;
  - co-working and auto transitions;
  - independent Requirement/Plan gate ownership and measurable rubrics;
  - assignment ownership and shared-writer prevention;
  - failure classes, bounded retries, escalation, and provider-native resume/handoff;
  - final candidate baseline/range/path identity, unrelated dirty files, writer freeze, finding severity/disposition, and one corrective batch;
  - focused tests after a corrective executable mutation;
  - engineering-completion terminal boundary.
- Route that contract from `brain-flow`, `brain-plan`, `brain-execute`, `brain-review`, `brain-testing`, process docs, and active handoff/commit/plan rules without duplicating it.
- Give `ios-coder` and `ios-tester` command capability; make base agents pattern-neutral; route Boardy-specific behavior only when the profile applies.
- Align all nine agent contracts and `standards/AGENT_MODEL_TIERING.md` with one-plan continuous execution, provider-native state, joined final review, and actual model/task responsibilities.
- Make `enterprise-ios` load Core always and only applicable Boardy/UI/enterprise chapters with explicit dependency closure.
- Expand `standards/specs/ADOPTION.md` to define profile selection, chapter applicability, organization policy owners, full/partial/transitional conformance, non-applicable requirements, and owned/expiring exceptions. Reconcile strict-concurrency destination with migration posture.
- Update portable CLAUDE/AGENTS setup/config examples only where needed to bind default mode, authority, policy owners, recovery, and final disposition consistently; remove unconditional confirmation wording that conflicts with eligible auto mode.
- Mark Task 3 and D5/D6/D7 complete when all active entry points route to the same operating contract.

### Bounded checks

- No build/test. Inspect frontmatter/tool capabilities and the routed contract once as part of implementation.
- No lane-local review or confirmation pass.

### Commit boundary

- Explicit paths: agents, affected Brain/enterprise skills, process/rules, adoption and portable-template files, plus this work item's task state.
- Commit intent: `feat: define enterprise full-auto operating contract`.

## Task 4 — Define RC2-to-GA governance and honest candidate metadata

**Outcome:** RC2 is a truthful unpublished working candidate with a measurable path to GA and no unsafe release instructions.

**Status:** COMPLETE

**Package signal:** the official Codex plugin validator passed after metadata was finalized. Its first
launch could not import the bundled YAML dependency; the same validation event completed under the
available cached dependency without changing candidate content.

### Changes

- Rewrite `ifl-ios-standards/RELEASE.md` as the RC2-to-GA promotion contract: feedback intake, severity/defect policy, allowed candidate changes, field qualification matrix, named sign-off roles, rollback/de-promotion, and external release authority.
- Align `standards/GOVERNANCE.md` and `standards/COMPATIBILITY.md` with the operating/conformance model and clarify that the frozen backlog is repository-root, inactive, and non-shipping.
- Replace `git add .` and equivalent broad staging in root `DEPLOY.md` with explicit-path examples; separate first publication from an existing-repository update.
- Add a repository-level `ROADMAP.md` with evidence-triggered 1.1 lifecycle domains and the post-1.0 custom-kernel decision boundary.
- Update root/plugin READMEs, plugin manifests, `ifl-ios-standards/VERSION`, and relevant changelogs to `1.0.0-rc.2` working-candidate semantics.
- Do not change `.codex-plugin/marketplace.json` away from the published `v1.0.0-rc.1` ref; describe RC2 as unpublished until separately authorized.
- Run the provider's official manifest/package metadata validation once after metadata is final. This is the sole package validation signal in the plan.
- Mark Task 4 and D8/D9 complete after governance and metadata agree.

### Bounded checks

- One official plugin manifest/package metadata validation after all Task 4 metadata changes.
- No install, update, build, test, tag, push, or publication.

### Commit boundary

- Explicit paths: release/governance/compatibility/deploy/roadmap/readme/changelog/version/manifest files and this work item's task state; public marketplace ref only if explanatory text changes without changing its RC1 tag.
- Commit intent: `docs: define RC2 qualification and GA promotion`.

## Task 5 — One final joined AI review and one corrective batch

**Outcome:** the complete candidate has one consolidated, dispositioned review and a release-readiness report.

### Candidate freeze

- Authority inputs: the approved `requirements.md` and `plan.md` in the planning-baseline commit.
- Candidate range: the exact planning-baseline SHA (exclusive) through the exact Task 4 HEAD SHA (inclusive).
- Included paths: the explicit tracked path boundary changed by Tasks 1–4 in this worktree.
- Excluded paths: `.superpowers/`, `IIS-0002`, and all unrelated/untracked user files.
- Writers stop before reviewers begin. Reviewers are read-only and examine the same complete candidate.
- `review.md` records both exact SHAs and the included/excluded path boundary. Review outputs and the
  Task 5 corrective batch are not part of the frozen input candidate.

### Review lanes and join

- Canon/ADR and derived-authority consistency.
- Architecture, Boardy profile, UIKit/SwiftUI, and humble-View consistency.
- Provider-native full-auto safety, recovery, authority, agent executability, and conformance usability.
- Packaging, governance, RC2/GA qualification, metadata, scope, and YAGNI.
- The integration owner joins and deduplicates all findings once, records severity and disposition, then applies all accepted P0/P1 changes in one bounded corrective batch.
- Task 5 may batch only in-scope corrections that do not change the approved plan. A finding requiring a
  material goal, scope, public-contract, architecture, security, or authority change blocks this plan
  and requires a new approved plan; it cannot be silently absorbed or used to start another review loop.
- If the corrective batch changes executable code, run only its affected focused signal. Do not run a routine second review.

### Artifacts and completion

- Write `review.md` with candidate identity, joined findings, dispositions, and any focused corrective signal.
- Write `final-report.md` with DoD status, semantic commits, deferred 1.1 items, residual risks, and the separately governed publication decision.
- Complete D10–D12 and all remaining task/DoD checkboxes only from evidence in the final joined review.

### Commit boundary

- Explicit paths: accepted corrective files, `review.md`, `final-report.md`, `requirements.md`, and `plan.md`.
- Commit intent: `docs: close RC2 final consistency review`.

## Plan Gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this plan
- Approval rubric:
  - Every approved DoD item has one owning semantic task and an observable completion signal.
  - Task boundaries are large enough to avoid repeated review/test loops and narrow enough for one coherent commit.
  - Shared writers, authority boundaries, dependencies, and candidate identity are explicit.
  - No task rebuilds the rejected kernel/verifier, runs CI, changes public release state, or touches excluded user files.
  - The plan can execute continuously with no routine human approval.
- Verdict: AUTO_APPROVED
- Reviewer: independent Plan Gate agent (`iis0003_requirement_gate`)
- Findings resolved:
  - Froze the review candidate as the exact planning-baseline-to-Task-4 range and path boundary, excluding review outputs.
  - Limited Task 5 to non-plan-changing corrections and made material decision changes a new-plan blocker.

STATUS: READY_FOR_EXECUTION
