# ifl-ios-standards

A dual-provider plugin packaging reusable **iOS engineering standards**: 9 specialist agents,
21 skills including `enterprise-ios`, provider-native Brain Flow, Boardy/VIP task routing, ten
focused enterprise chapters, and thin build-system-neutral module/board source scaffolders.

## What's inside

| Component | What it is |
|-----------|------------|
| `agents/` (9) | Delegated pipeline: `ios-orchestrator` (tech lead), `ios-planner`, `ios-researcher`, `ios-architect`, `ios-coder`, `ios-tester`, `ios-reviewer`, `ios-review-triage`, `ios-doc-scribe` |
| `skills/` (21) | **Brain stages** (pattern-neutral, provider-native): `brain-design`, `brain-architect`, `brain-plan`, `brain-execute`, `brain-testing`, `brain-review`, `brain-flow` (end-to-end automation) · **Boardy/VIP tasks**: router `boardy-vip` + `boardy-new-module`, `boardy-new-board`, `boardy-io-interface`, `boardy-communication`, `boardy-service-layer`, `boardy-plugin-composition`, `boardy-testing`, `boardy-review`, `boardy-refactor`, `boardy-troubleshoot`, `boardy-adopt` · **Enterprise iOS**: router `enterprise-ios` · `init` |
| `standards/` | Bundled reference: `rules/` (6), `brain/` (rulebook + patterns), `specs/` (44 incl. compact), ten focused `enterprise/` chapters, plan-scale process guidance, and `templates/portable-claude/` |
| `bin/` | `ifl-init` (seed CLAUDE.md/AGENTS.md), `ifl-new-module`, `ifl-new-board` — Claude exposes these on PATH; Codex installs stable shims via `scripts/install-codex.sh` |

## Activate

```bash
# every task type is also auto-detected by description — these are explicit entry points:
/ifl-ios-standards:boardy-vip          # router — read first, routes to the right skill/spec
/ifl-ios-standards:brain-flow          # automate the whole workflow: analyze → … → done
/ifl-ios-standards:enterprise-ios      # route enterprise concerns to the relevant chapter(s)
/ifl-ios-standards:boardy-new-module
/ifl-ios-standards:boardy-new-board
/ifl-ios-standards:boardy-review
# … boardy: :boardy-io-interface :boardy-communication :boardy-service-layer :boardy-plugin-composition :boardy-testing :boardy-refactor :boardy-troubleshoot :boardy-adopt
# … brain stages: :brain-design :brain-architect :brain-plan :brain-execute :brain-testing :brain-review
```

Or describe the iOS task and choose the matching skill family: `brain-*` for pattern-neutral flow,
`boardy-*` for Boardy/VIP projects, and `enterprise-ios` for Swift concurrency, SwiftUI production,
data lifecycle, security, privacy, accessibility/global readiness, observability, modern testing,
performance/resilience, or supply-chain/legal concerns. The enterprise router selects among the ten
focused chapters; their files remain the single source of detailed standards.

`brain-flow` uses provider-native planning, delegation, and checkpoints to execute one approved plan,
then runs one joined final AI consistency review over the complete result.

## How references resolve

Every reference inside agents/skills points at bundled content via `${CLAUDE_PLUGIN_ROOT}` (the
plugin's installed dir — substituted inline by Claude Code in skill + agent content). So the pack
is **self-contained and portable**: it works in any project once enabled, no file copying.

**Per-project values are NOT bundled** — scheme, simulator, module roots, build/test commands,
base branch, git remote, naming prefix, and ADR/decisions location live in the **consuming repo's
`CLAUDE.md`**. Copy a starter from `standards/templates/portable-claude/`. The multi-agent pipeline's
work-item workspace (in-repo under `docs/02-working-docs/work-items/` per the docs-organization process
standard) is **optional**, used only by the orchestrator pipeline.

## Install

See [INSTALL.md](INSTALL.md). One command (default = global):

```bash
scripts/install-claude.sh            # global (user scope) — all projects
scripts/install-claude.sh --scope=project --project=/path/to/repo
```

## Versioning

Both provider manifests mirror the upstream pack `VERSION` (currently `1.0.0-rc.1`). Bump on
content changes so installs pick up updates.
