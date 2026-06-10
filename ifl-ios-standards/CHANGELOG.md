# Changelog — ifl-ios-standards plugin

SemVer. The `version` in `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` drives
auto-update for installed plugins — bump it on every content change so installs pick it up
(a content change without a version bump won't reach existing installs via `marketplace update`).

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
