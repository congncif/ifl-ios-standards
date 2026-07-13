# Requirements — IIS-0003 Standards 1.0 GA readiness

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Delivery target: `1.0.0-rc.2` content candidate, then field qualification for `1.0.0` GA
- Baseline: `v1.0.0-rc.1` at `481b203ab1f855ccd3ff6c8a907a077e3f239400`
- Branch: `codex/standards-1.0`
- Execution worktree: `/private/tmp/ifl-ios-pack-standards-v1`
- Change class: standards, skills, agent contracts, governance, packaging, and scaffolding
- Verification owner: AI consistency review; CI remains outside plugin scope

## Authority and work-item boundary

- This is the sole active post-RC work item for Standards 1.0.
- `IIS-0002-enterprise-v1-candidate` is a historical working archive. It is not an active plan or publication authority and must remain untouched.
- Canon remains the normative standards authority. ADRs explain accepted architecture decisions. Skills and operating documents translate those authorities into agent behavior. Templates, quick references, examples, and scaffolds are derived artifacts and must not create independent mandates.
- Provider-native orchestration from Codex, Claude Code, or an equivalent runtime owns assignment, context, and agent lifecycle. A custom workflow kernel, receipt system, verifier framework, and CI implementation are not required for Standards 1.0.

## Goal

Close the authority, package-boundary, architecture, conformance, and operating-model defects found after RC1 so the plugin can run an enterprise iOS change from approved requirements to engineering completion in full-auto mode, while remaining safe for human-in-the-loop operation and ready for a separately authorized RC2 publication and GA qualification.

## Product decisions

1. The next content candidate is `1.0.0-rc.2`; RC1 does not promote directly to GA.
2. “Full auto” means uninterrupted engineering execution through implementation, proportionate executable-code testing, one final joined AI review, one corrective batch when required, semantic task commits when Git authority is granted, and a release-readiness report.
3. Full auto does not implicitly authorize branch integration, push, tag, marketplace publication, local installation, production rollout, or other external release actions.
4. Domain and application policy remain independent of Boardy, UIKit, SwiftUI, networking, persistence, and utility frameworks. Boardy is an optional orchestration/presentation profile around application use cases, not an exception to dependency direction.
5. Views remain humble objects. Presentation-ready values, formatting, and business decisions belong to Presenter or the selected presentation adapter. A View may hold minimal ephemeral UI/UX state, but must not create untestable derived business or presentation values.
6. Verification remains lean: no plugin-owned verifier, workflow receipt/evidence digest pipeline, lint, smoke-suite, or CI framework. Existing Canon integrity fields such as ADR Markdown and record digests remain part of Canon data integrity, not workflow evidence. Executable code changes receive focused tests or commands proportional to risk; documentation-only changes do not trigger build/test loops. One final AI consistency review covers the completed plan.
7. New enterprise chapters are added only when adoption evidence demonstrates a GA blocker. Platform/toolchain lifecycle, API/network contract lifecycle, and app/background/platform lifecycle are planned for 1.1 unless qualification proves otherwise.

## In scope

### A. Package boundary and YAGNI cleanup

- Relocate only the frozen custom-kernel backlog and its kernel-owned schemas, registry, tooling, and verification assets from the installable plugin subtree to a repository-root post-1.0 backlog.
- Preserve active Canon schemas, registries, Rules, Profiles, ADRs, and other normative material inside the plugin payload.
- Keep the backlog explicitly inactive and excluded from both Claude and Codex plugin payloads.
- Remove active documentation references that imply the rejected tooling is required to operate Standards 1.0.
- Do not replace it with another runtime, script suite, or evidence system.

### B. Normative authority convergence

- Align all ADR Markdown lifecycle states with their accepted JSON records.
- Recompute the affected Markdown digests and ADR index record digests so every representation describes the same accepted decision.
- Remove or repair derived documents that compete with Canon, add unconditional build/test requirements, or map requirements to incorrect Canon IDs.
- Make publication evidence, adopter conformance evidence, guidance, and normative requirements distinguishable.

### C. Architecture and Boardy profile closure

- Reconcile Boardy layering, SDK guidance, adoption guidance, ADR-0002, scaffold output, and Canon dependency direction.
- Keep Services/Domain and Services/Application free of Boardy and SiFUtilities dependencies.
- Allow Boardy only in the selected Boardy orchestration/presentation shell and adapters.
- Remove the blanket SiFUtilities pre-approval and remove generated imports that are not required by emitted code.
- Preserve UIKit and SwiftUI adapter support and the humble-view contract.

### D. Full-auto provider operating model

- Give implementation and testing agents the provider capabilities required to run the commands their contracts promise.
- Make base roles pattern-neutral; load Boardy-specific behavior only when the project selects that profile.
- Define the independent AI Requirement and Plan gate owner/rubric for auto mode so no agent approves its own material output.
- Define auto eligibility and preflight, authority binding, co-working/auto mode transitions, task assignment, failure classification, bounded recovery, context handoff/resume, and the condition for a true user blocker.
- Define the final review candidate precisely: baseline/range, included paths, writer freeze, treatment of unrelated dirty files, finding severity, disposition authority, and focused testing after a corrective executable-code mutation.
- State the full-auto terminal boundary as engineering completion and release readiness, not publication.
- Align model tiering and all active agent/skill/template instructions with this operating contract.

### E. Enterprise adoption and conformance

- Route Core standards always and load Boardy, UIKit, SwiftUI, and enterprise chapters only when applicable to the selected profile and change impact.
- Define full adoption, partial adoption, transitional conformance, non-applicable requirements, approved exceptions, and expiration/review semantics.
- Record owners for organization policy bindings that AI cannot decide, including deployment targets, privacy/security policy, accessibility targets, observability, data retention, and release sign-off.
- Preserve strict Swift concurrency as the destination while supporting an explicit, time-bounded migration posture for existing codebases.

### F. RC2 and GA governance

- Define the RC-to-GA promotion contract: feedback intake, severity and defect policy, allowed RC changes, qualification matrix, required sign-offs, and rollback/de-promotion rules.
- Replace unsafe broad staging examples with explicit path staging and distinguish initial repository setup from updates to an existing repository.
- Update metadata and package documentation coherently for an RC2 working candidate without pointing a public marketplace at a tag that does not yet exist.
- Record the 1.1 lifecycle backlog and keep the custom kernel post-1.0 and evidence-driven.

## Out of scope

- Building or activating a custom orchestration kernel, provider-independent state engine, contract compiler, receipt/digest system, verifier, lint suite, smoke suite, or CI pipeline.
- Adding the three deferred lifecycle chapters without qualification evidence.
- Modifying an adopter product application or migrating product Swift code.
- Changing third-party runtime-provider behavior.
- Editing or staging `IIS-0002`, `.superpowers/`, or unrelated untracked/user-owned files.
- Branch merge, push, tag, GitHub release, marketplace publication, local plugin install/update, or production rollout.

## Risks and controls

- **Authority drift:** one normative hierarchy and one final joined review; derived artifacts cannot silently introduce policy.
- **Over-automation:** authority bindings and material-blocker rules prevent agents from crossing organization or release decisions.
- **False confidence:** GA requires field qualification and named sign-offs, not documentation completeness alone.
- **Payload regression:** public marketplace references remain on the published RC1 tag until RC2 release authority is granted.
- **Boardy leakage:** framework-neutral application boundaries are stated once and propagated to profile guidance and scaffolds.
- **Review cost:** tasks are grouped by semantic impact; no per-finding rerun or duplicate green signal.

## Definition of Done

- [x] **D1 — Installable payload is lean.** No frozen custom-kernel backlog or kernel-owned tooling, verification, schema, or registry implementation remains under `ifl-ios-standards/`; the frozen material exists only in an explicitly inactive repository-root post-1.0 backlog, while active Canon schemas and registries remain in the plugin.
- [x] **D2 — ADR state is coherent.** All eleven ADR Markdown and JSON records are Accepted, every JSON `markdown_digest` matches its Markdown document, and the ADR index digests match their records.
- [ ] **D3 — Canon has one voice.** Loaded quick references, rulebooks, templates, examples, and reviewer aids either map mandates to the correct Canon/ADR authority or label them as guidance; the known domain-purity mapping and unconditional per-task build/test contradictions are removed.
- [ ] **D4 — Architecture is consistent.** Domain and application policy are framework-neutral; Boardy is profile-scoped; SiFUtilities has no blanket exception; scaffolds do not emit unused dependency imports; UIKit/SwiftUI and humble-view rules remain aligned.
- [ ] **D5 — Agent roles are executable.** Coder and tester can run their promised commands, base roles are pattern-neutral, auto gates have an independent owner and measurable rubric, and model-tiering/agent contracts agree.
- [ ] **D6 — Full-auto operation is complete.** Active Brain-Flow documentation covers eligibility, preflight, authority, mode transitions, assignment, failure/retry/escalation, resume/handoff, candidate identity/freeze, finding disposition, corrective-code focused tests, and the engineering-completion terminal boundary.
- [ ] **D7 — Enterprise conformance is adoptable.** Profiles, chapter applicability, policy owners, full/partial/transitional conformance, non-applicable status, and exception lifecycle are defined without requiring Boardy.
- [ ] **D8 — GA promotion is governed.** RC feedback, defect/change policy, qualification matrix, sign-offs, rollback/de-promotion, explicit Git staging, and external release authority are documented.
- [ ] **D9 — Candidate metadata is honest.** Internal version/package documentation consistently identifies an RC2 working candidate while all public install references remain pinned to published RC1 until a separately authorized release.
- [ ] **D10 — Review is lean and conclusive.** The complete plan receives one final joined AI consistency review; all P0/P1 findings are resolved in at most one semantic corrective batch, with no duplicate documentation build/test signal.
- [ ] **D11 — Scope is preserved.** `IIS-0002`, `.superpowers/`, unrelated user files, CI, and release operations remain untouched.
- [ ] **D12 — Git history is reviewable.** Each complete semantic task is staged with explicit paths and committed exactly once under the scoped Git authority; unrelated/untracked files are excluded and no intermediate review or test gate is introduced merely to permit the commit.

## Requirement gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this requirements document
- Approval rubric:
  - Goal, scope, exclusions, authority, and terminal boundary are explicit.
  - Every DoD item is observable and can be mapped to a semantic implementation task.
  - No material architecture, governance, or release decision is left implicit.
  - The work can proceed without creating prohibited tooling or requiring routine human approval.
- Verdict: AUTO_APPROVED
- Reviewer: independent Requirement Gate agent (`iis0003_requirement_gate`)
- Findings resolved:
  - Restricted payload relocation to frozen kernel-owned material and explicitly preserved active Canon schemas and registries.
  - Distinguished Canon integrity digests from the prohibited workflow evidence/digest pipeline.
  - Added an observable explicit-path, one-commit-per-semantic-task history requirement.
- Open material questions: none

STATUS: READY_FOR_PLAN
