# Requirements — IIS-0004 RC3 qualification readiness

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Delivery target: `1.0.0-rc.3` engineering-complete candidate
- Baseline: RC2 engineering-complete commit `9a300f246b938337f767f1f826a353b6f71eeb3d`
- Branch: `codex/standards-1.0`
- Execution worktree: `/private/tmp/ifl-ios-pack-standards-v1`
- Change class: profile routing, candidate metadata, and release-governance correction
- Verification owner: one joined AI consistency review; no build/test is required for documentation-only
  changes, while an observed executable-helper defect receives only its focused output signal

## Authority and boundary

- The user authorized continued full-auto work toward the complete enterprise standard and granted
  scoped local stage/commit authority for semantic tasks in this standards plan.
- RC2 engineering completion did not authorize qualification, publication, installation, push, tag,
  marketplace change, or GA. Those boundaries remain unchanged.
- `IIS-0003-standards-1.0-ga` and `IIS-0002-enterprise-v1-candidate` are historical records and remain
  untouched.
- This corrective work item resolves candidate defects found during pre-qualification audit. Field
  qualification Q1-Q6 is a subsequent work item against the immutable result of this work item.
- Canon remains normative. This work item does not introduce a new architecture decision, Profile,
  enterprise chapter, runtime kernel, verifier, evidence framework, CI implementation, or Boardy
  distribution mechanism.

## Trigger and disposition

Pre-qualification audit found one promotion-blocking inconsistency:

- **F-RC2-QUAL-001 — P1 candidate defect:** Core and the Brain stages are defined as pattern-neutral,
  but `skills/init/SKILL.md` describes project initialization only as Boardy+VIP adoption and routes
  every initialized project to Boardy-specific next steps. This can cause Q1 Core-only auto flow to
  load Boardy and contradicts the optional-Profile contract.

The end-to-end init audit then found a second promotion-blocking inconsistency before Task 1 was
committed:

- **F-RC2-QUAL-002 — P1 candidate defect:** `bin/ifl-init` detects Bazel, CocoaPods, or SwiftPM but
  still substitutes retired `{DependencyManager}` and `{ModuleDependencyFile}` tokens. The bundled
  2.5.0 starter uses `{BuildSystem}` and `{BuildIntegration}`, so generated bindings discard the
  observed package/build-system result while the helper reports that it filled it.

Per `RELEASE.md`, a P1 candidate defect cannot be hidden in qualification cleanup. It requires a new
semantic candidate revision and a final joined review before qualification starts.

The absence of an upstream Boardy `Package.swift` is not classified as a plugin defect. Standards 1.0
does not distribute Boardy or own adopter build integration. Q3 must prove the advertised SwiftPM path
through a representative project-owned local integration in an isolated greenfield pilot; if that
executable path fails, qualification records the resulting finding against the exact candidate.

## Goal

Produce an immutable `1.0.0-rc.3` candidate whose project-init route is genuinely Profile-neutral,
whose helper emits the package/build bindings it actually detects, whose active metadata and
release-governance text truthfully identify the new unpublished revision, and whose complete
corrective diff passes one joined AI consistency review with no open P0/P1.

## Product decisions

1. `init` adopts Standards Core and project bindings; it does not select Boardy by default.
2. Initialization infers or records the actual architecture/UI Profiles. Boardy skills are offered
   only when the target project or change selects Boardy/VIP.
3. The pattern-neutral next step is `brain-flow`; `enterprise-ios` is used when governed enterprise
   chapters apply; `boardy-adopt` remains the conditional Boardy migration/setup route.
4. The corrected candidate is `1.0.0-rc.3`, unpublished. The public marketplace stays pinned to
   published `v1.0.0-rc.1` until separately authorized external release operations occur.
5. Qualification must use the immutable RC3 commit. RC2 qualification results cannot be inferred,
   reused, or relabeled as RC3 results.
6. `ifl-init` may fill only values established by unambiguous repository evidence. Its output tokens
   must match the current starter contract; governed or ambiguous values remain placeholders.

## In scope

- Make `skills/init/SKILL.md` Profile-neutral in its trigger description, title, workflow language,
  confirmation criteria, and next-step routing.
- Audit every active `init` entrypoint used by the skill, the bundled starter template, and one generated
  `CLAUDE.md`/`AGENTS.md` output from `ifl-init`. Correct only the smallest surface that selects or
  recommends Boardy by default. If helper behavior is defective, treat it as an executable change and
  run one focused generated-output signal; do not silently classify it as documentation-only.
- Update `bin/ifl-init` to populate the current starter's `{BuildSystem}` and `{BuildIntegration}`
  bindings for unambiguous Bazel, CocoaPods, and SwiftPM repositories without inventing targets,
  commands, destinations, policy owners, or other governed values.
- Align the smallest necessary active index/README reference if it still presents `init` as a
  Boardy-only capability.
- Update candidate version/manifests/changelogs/readmes/release text from unpublished RC2 to
  unpublished RC3 without moving the public marketplace reference.
- Record one final joined AI review over the exact corrective candidate range and apply at most one
  in-scope corrective batch.
- Produce a concise final report naming the immutable RC3 candidate and the next qualification work
  item boundary.

## Out of scope

- Running Q1-Q6, provider model sessions, adopter builds, or product migrations.
- Adding `Package.swift` to the Boardy repository or changing Boardy source/distribution.
- Changing Canon Rules, Profiles, accepted ADR decisions, enterprise chapter obligations, or the
  Q1-Q6 support matrix merely to make qualification easier.
- Plugin-owned scripts, verification tooling, receipts, evidence digests, CI, or release automation.
- Editing adopter repositories, `.superpowers/`, historical work items, or unrelated files.
- Merge, push, tag, GitHub release, marketplace publication, local plugin installation/update, or GA.

## Risks and controls

- **Hidden scope expansion:** only the identified profile-routing contradiction and truthful candidate
  metadata are corrected; a new architecture/support decision starts another plan.
- **False qualification:** no row is marked passed by this work item; Q1-Q6 remain `not qualified`.
- **Version drift:** all active internal RC references move together while the public marketplace ref
  remains on RC1.
- **Review churn:** one semantic implementation task, one joined final review, at most one corrective
  batch, and no routine re-review or documentation test loop.

## Definition of Done

- [x] **D1 — Init is Profile-neutral end to end.** The skill, every active entrypoint it uses, bundled
  starter, and observed generated bindings neither require nor recommend Boardy for a Core-only
  project; Boardy routing is conditional on the selected Profile.
- [x] **D2 — Routing and generated build bindings are actionable.** The default next step is
  pattern-neutral `brain-flow`, with conditional `enterprise-ios` and `boardy-adopt` routes stated
  without ambiguity; Bazel, CocoaPods, and SwiftPM fixtures emit their observed current
  `{BuildSystem}`/`{BuildIntegration}` values and retain governed unknowns as placeholders.
- [x] **D3 — RC3 metadata is honest.** Active candidate manifests, version text, changelogs, readmes,
  and release-governance text agree on unpublished `1.0.0-rc.3`; public install/marketplace references
  remain on published RC1.
- [x] **D4 — Qualification claims are preserved.** Q1-Q6 are unchanged and remain `not qualified`;
  no support claim is narrowed or declared passed by documentation.
- [x] **D5 — Review is conclusive.** One exact baseline-to-implementation `review-input range` is
  writer-frozen for one joined independent AI consistency review. All accepted P0/P1 findings are
  resolved in at most one batch, no routine second review runs, and the resulting post-review commit
  is recorded separately as the immutable RC3 qualification candidate.
- [ ] **D6 — Scope and history are clean.** Only explicit paths are staged, each semantic task has one
  commit, `.superpowers/` and unrelated files stay excluded, and no external release operation occurs.

## Requirement gate

- Mode: auto
- Gate owner: independent AI reviewer who did not author this document
- Approval rubric:
  - The P1 trigger, candidate-revision rule, goal, scope, exclusions, and terminal boundary are explicit.
  - Every DoD item is observable and maps to a bounded semantic task.
  - The work neither weakens the qualification matrix nor creates new tooling/build integration.
  - The plan can proceed continuously without routine human approval or external release authority.
- Verdict: AUTO_APPROVED
- Reviewer: independent Requirement Gate agent (`iis0004_requirement_gate`)
- Findings resolved:
  - Expanded the init boundary to every active entrypoint, the bundled starter, and observed generated
    bindings, with executable-defect reclassification if needed.
  - Distinguished the frozen review-input range from the immutable post-review RC3 candidate commit.
  - Retained amendment classified the stale helper/starter build-binding tokens as executable P1
    `F-RC2-QUAL-002` and bounded the correction to the current template contract.
- Open material questions: none

STATUS: READY_FOR_PLAN
