# Changelog — ifl-ios-standards plugin

SemVer. The `version` in `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` drives
auto-update for installed plugins — bump it on every content change so installs pick it up
(a content change without a version bump won't reach existing installs via `marketplace update`).

## [1.0.0-rc.3] — 2026-07-14 (unpublished working candidate)

### Fixed
- Made project initialization Profile-neutral end to end: Core is the default, Brain Flow is the
  general next step, and Boardy/VIP routing occurs only when that optional Profile is selected.
- Aligned `ifl-init` with portable template 2.5.0 so observed Bazel, CocoaPods, and SwiftPM repositories
  populate `{BuildSystem}` and `{BuildIntegration}` instead of retired placeholder names.
- Reset field qualification to the exact RC3 candidate. No RC2 result may be inferred or reused;
  Q1-Q6 remain `not qualified` until observed against the immutable RC3 commit.

### Release boundary
- Kept the latest published release and public Codex marketplace source pinned to
  `v1.0.0-rc.1`; RC3 preparation grants no push, tag, publication, installation, or rollout authority.

## [1.0.0-rc.2] — 2026-07-14 (unpublished working candidate)

### Changed
- Quarantined the frozen custom-kernel backlog outside the installable plugin while preserving active
  Canon schemas, registries, Rules, Profiles, and accepted ADR authority.
- Converged Canon/ADR lifecycle data and derived guidance around one authority hierarchy and a
  risk-based executable verification model.
- Kept Domain and Services/Application policy framework-neutral; scoped Boardy to the selected
  orchestration/presentation adapter profile; removed blanket utility-framework approval and unused
  generated imports; retained equivalent UIKit/SwiftUI humble-View adapters.
- Defined provider-native co-working/full-auto eligibility, independent gates, scoped authority,
  bounded recovery/resume, enterprise conformance, one complete plan, and one joined final AI review.
- Versioned the portable project-binding template as `2.5.0` and pinned public install guidance to
  immutable RC1 while RC2 remains unpublished.
- Added RC-to-GA qualification governance and an evidence-triggered 1.1/post-1.0 roadmap without
  introducing a custom runtime, verifier, evidence system, or CI framework.
- Marked RC2 as an unpublished candidate. The latest published release and the public Codex
  marketplace source remain pinned to `v1.0.0-rc.1` pending separate release authority.

## [1.0.0-rc.1] — 2026-07-13

### Changed
- Aligned the dual-provider package at 9 agents and 21 skills, including `enterprise-ios`, with provider-native Brain Flow and ten focused enterprise chapters.
- Described the module/board generators as thin build-system-neutral source scaffolders and refreshed release-candidate install pins.
- Approved public distribution of the marketplace and packaged plugin under the MIT License.
- Pinned the Codex marketplace payload to the immutable `v1.0.0-rc.1` release tag.

## [0.18.4] — 2026-07-09

### Fixed
- Clarified the canonical work-item artifact structure so E2E `brain-flow` does not infer extra top-level `design.md` or `architecture.md` files.

## [0.18.3] — 2026-07-09

### Added
- `brain-flow` Requirement Intake now produces a Definition of Done checklist that becomes the downstream agent loop goal.
- Co-working mode can switch downstream stages to auto mode after the user approves the requirement summary and Definition of Done.
- Requirement Intake can auto-generate missing ticket/work item IDs as `<PROJECT-CODE>-NNNN`.
- Work-item documentation now uses one folder per ticket/work item with split `requirements.md`, `plan.md`, `reports/*`, `handoffs/*`, and `artifacts/*` files.

### Changed
- Briefing handoff is now a compact handoff/index over split work-item files instead of the full audit trail.
- Long-document writing now requires splitting work-item material by purpose before chunking sections.

## [0.18.2] — 2026-07-09

### Added
- `brain-flow` now supports co-working and auto approval modes with a Requirement Intake Gate, Plan Gate, pattern extension contract, and checkpoint/failure-loop semantics.
- Added process docs for requirement intake, approval modes, long-document writing, and a process-doc index.

### Changed
- `BRIEFING_HANDOFF.md` now records requirement/plan gates and uses a generic context-cache contract with Boardy+VIP as a pattern extension.
- Brain plan/execute/review/testing stages now align with human vs AI gate approval and checkpoint-only verification.

## [0.18.1] — 2026-06-17

### Changed
- Portable Claude templates now define the cross-module import rule as a generic **Public contract boundary**, covering IO contracts, documented public library APIs, shared contracts, design-system primitives, platform abstractions, generated schema contracts, test-only support imports, and IO/facade boundaries for modules without a clear contract.

## [0.16.0] — 2026-06-10

### Added
- **Brain process-stage skills** (pattern-neutral, driven by `standards/brain/` rulebook chapters):
  `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`,
  `brain-review` — one skill per lifecycle stage, each loading only its chapters, each with a
  Boardy forwarding hook when the project's `CLAUDE.md` binds the pattern.
- **`brain-flow`** — end-to-end workflow automation (analyze → design → architect → plan →
  execute → test → review → done). Detects scale + pattern binding: large Boardy tasks delegate
  to the `ios-orchestrator` pipeline; small tasks run the inline stage pipeline with per-stage
  `boardy-*` forwarding.

### Changed
- **BREAKING — skill renames**: all Boardy task skills gained the `boardy-` prefix to separate the
  pattern layer from the new brain process layer: `adopt`→`boardy-adopt`,
  `communication`→`boardy-communication`, `io-interface`→`boardy-io-interface`,
  `new-board`→`boardy-new-board`, `new-module`→`boardy-new-module`,
  `plugin-composition`→`boardy-plugin-composition`, `refactor`→`boardy-refactor`,
  `review`→`boardy-review`, `service-layer`→`boardy-service-layer`, `testing`→`boardy-testing`,
  `troubleshoot`→`boardy-troubleshoot`. `boardy-vip` (router) and `init` unchanged. Old slash
  names no longer resolve — update any project docs referencing them (the bundled
  `portable-claude` templates and specs are already updated).
- `boardy-vip` router now also routes process-stage work to the `brain-*` skills.

## [0.15.0] — 2026-06-09

### Added
- **`init` command** — seed a project's `CLAUDE.md` + `AGENTS.md` bindings:
  - `bin/ifl-init` — detects git remote/branch, dependency manager (Bazel/CocoaPods/SPM), module
    root, workspace; pre-fills the starter; refuses overwrite without `--force`.
  - `skills/init/SKILL.md` — agent-driven wrapper; fills scheme/build/test by introspection.
- **Codex support** — `.codex-plugin/marketplace.json` + `ifl-ios-standards/.codex-plugin/plugin.json`
  + `scripts/install-codex.sh`. One repo serves Claude Code and Codex.
- **Process standards** bundled: `standards/process/{docs-organization,lean-verification}.md`.

### Changed
- Model aliases → standard tiers: `combo-giao-su`→`opus`, `combo-huy-diet`→`sonnet`,
  `combo-giup-viec`→`haiku`.
- Agent workspace refs generic: `.superpowers/…` → in-repo `docs/02-working-docs/…` per docs-organization.
- Legacy docs (GREENFIELD/BROWNFIELD/portable-claude/TROUBLESHOOTING/REFACTOR) realigned from the
  dead `.standards/` submodule + `bootstrap.sh`/`install-rules.sh`/`audit-pack.sh` flow to the
  plugin model; package-manager-neutral (CocoaPods/Bazel/SPM).
- `PLAN_EXECUTION.md` reduced to a pointer at `process/lean-verification.md`.

### Fixed
- Template `Module root` value cell carried inline prose/backticks, breaking the scaffolders'
  `resolve_module_root()` parse (returned `Module` not `Modules`). Value cells are now single bare tokens.

## [0.14.0]

Initial published marketplace: 9 agents, router + clustered task skills, bundled rulebook/specs,
Bazel `ifl-new-module`/`ifl-new-board` scaffolders.
