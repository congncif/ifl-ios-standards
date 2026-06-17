# ifl-ios-standards

A Claude Code plugin packaging reusable **iOS engineering standards**: specialist agents,
pattern-neutral brain workflows, Boardy/VIP task skills, bundled architecture references, and Bazel
module/board scaffolders.

## What's inside

| Component | What it is |
|-----------|------------|
| `agents/` (9) | Delegated pipeline: `ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe` |
| `skills/` (20) | **Brain stages** (pattern-neutral, brain-rulebook-driven): `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`, `brain-review`, `brain-flow` (end-to-end automation) · **Boardy/VIP tasks**: router `boardy-vip` (for Boardy/VIP routing) + `boardy-new-module`, `boardy-new-board`, `boardy-io-interface`, `boardy-communication`, `boardy-service-layer`, `boardy-plugin-composition`, `boardy-testing`, `boardy-review`, `boardy-refactor`, `boardy-troubleshoot`, `boardy-adopt` · `init` |
| `standards/` | Bundled reference: `rules/` (7), `brain/` (rulebook + patterns), `specs/` (43 incl. compact), `process/` (docs-organization, lean-verification), `scripts/` (4 lint), `templates/portable-claude/` |
| `bin/` | `ifl-init` (seed CLAUDE.md/AGENTS.md), `ifl-new-module`, `ifl-new-board` — Claude exposes these on PATH; Codex installs stable shims via `scripts/install-codex.sh` |

## Activate

```bash
# every task type is also auto-detected by description — these are explicit entry points:
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:brain-flow          # automate the whole workflow: analyze → … → done
/ifl-ios-standards:boardy-new-module
/ifl-ios-standards:boardy-new-board
/ifl-ios-standards:boardy-review
# … boardy: :boardy-io-interface :boardy-communication :boardy-service-layer :boardy-plugin-composition :boardy-testing :boardy-refactor :boardy-troubleshoot :boardy-adopt
# … brain stages: :brain-design :brain-architect :brain-plan :brain-execute :brain-testing :brain-review
```

Or describe the iOS task and choose the matching skill family: `brain-*` for pattern-neutral flow,
`boardy-*` for Boardy/VIP projects.

## How references resolve

Every reference inside agents/skills points at bundled content via `${CLAUDE_PLUGIN_ROOT}` (the
plugin's installed dir — substituted inline by Claude Code in skill + agent content). So the pack
is **self-contained and portable**: it works in any project once enabled, no file copying.

**Per-project values are NOT bundled** — scheme, simulator, module roots, build/test commands,
base branch, git remote, naming prefix, and ADR/decisions location live in the **consuming repo's
`CLAUDE.md`**. Copy a starter from `standards/templates/portable-claude/`. The multi-agent pipeline's
handoff workspace (in-repo under `docs/02-working-docs/handoffs/` per the docs-organization process
standard) is **optional**, used only by the orchestrator pipeline.

## Install

See [INSTALL.md](INSTALL.md). One command (default = global):

```bash
scripts/install-claude.sh            # global (user scope) — all projects
scripts/install-claude.sh --scope=project --project=/path/to/repo
```

## Versioning

`plugin.json` `version` mirrors the upstream pack `VERSION` (currently `0.18.1`). Bump on content
changes so installs pick up updates.
