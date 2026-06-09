# Changelog — ifl-ios-standards plugin

SemVer. The `version` in `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` drives
auto-update for installed plugins — bump it on every content change so installs pick it up
(a content change without a version bump won't reach existing installs via `marketplace update`).

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
