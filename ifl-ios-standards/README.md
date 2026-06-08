# ifl-ios-standards

A Claude Code plugin packaging the **Boardy+VIP iOS engineering standard**: specialist agents,
a task-routing skill set, the full architecture rulebook/specs as bundled reference, and Bazel
module/board scaffolders.

## What's inside

| Component | What it is |
|-----------|------------|
| `agents/` (10) | Delegated pipeline: `ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe`, `optimization` |
| `skills/` (12) | Router `boardy-vip` (auto-fires, reads the QUICK_REF routing table) + 11 clustered task skills: `new-module`, `new-board`, `io-interface`, `communication`, `service-layer`, `plugin-composition`, `testing`, `review`, `refactor`, `troubleshoot`, `adopt` |
| `standards/` | Bundled reference: `rules/` (7), `brain/` (rulebook + patterns), `specs/` (43 incl. compact), `scripts/` (4 lint), `templates/portable-claude/` |
| `bin/` | `ifl-new-module`, `ifl-new-board` — Bazel scaffolders, added to PATH when the plugin is enabled |

## Activate

```bash
# every task type is also auto-detected by description — these are explicit entry points:
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:new-module
/ifl-ios-standards:new-board
/ifl-ios-standards:review
# … :io-interface :communication :service-layer :plugin-composition :testing :refactor :troubleshoot :adopt
```

Or just describe an iOS Boardy task — the router (broadest `description`) fires first and points
at the matching task skill.

## How references resolve

Every reference inside agents/skills points at bundled content via `${CLAUDE_PLUGIN_ROOT}` (the
plugin's installed dir — substituted inline by Claude Code in skill + agent content). So the pack
is **self-contained and portable**: it works in any project once enabled, no file copying.

**Per-project values are NOT bundled** — scheme, simulator, module roots, build/test commands,
base branch, git remote, naming prefix, and ADR/decisions location live in the **consuming repo's
`CLAUDE.md`**. Copy a starter from `standards/templates/portable-claude/`. The multi-agent
scratch workspace (default `.superpowers/`) is **optional**, used only by the orchestrator pipeline.

## Install

See [INSTALL.md](INSTALL.md). One command (default = global):

```bash
scripts/install-claude.sh            # global (user scope) — all projects
scripts/install-claude.sh --scope=project --project=/path/to/repo
```

## Versioning

`plugin.json` `version` mirrors the upstream pack `VERSION` (currently `0.14.0`). Bump on content
changes so installs pick up updates.
