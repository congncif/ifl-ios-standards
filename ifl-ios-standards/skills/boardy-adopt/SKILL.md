---
name: boardy-adopt
description: >-
  Use when bringing the Boardy+VIP standard into a project — migrating an existing UIKit/RIBs
  codebase incrementally, or standing up a new app greenfield on the pattern. Triggers: "adopt
  Boardy", "migrate to VIP", "brownfield migration", "greenfield setup", "introduce the standard".
---

# Adopt the Boardy+VIP standard

## Read by scenario
- Existing app (incremental) → `${CLAUDE_PLUGIN_ROOT}/standards/specs/BROWNFIELD_MIGRATION.md`
- New app from scratch → `${CLAUDE_PLUGIN_ROOT}/standards/specs/GREENFIELD_SETUP.md`
- General adoption overview → `${CLAUDE_PLUGIN_ROOT}/standards/specs/ADOPTION.md`
- Architecture context → `${CLAUDE_PLUGIN_ROOT}/standards/specs/ARCHITECTURE.md`

## Project setup that stays in the consuming repo
This pack ships the **generic** standard only. Per-project values (scheme, simulator, module
roots, build/test commands, base branch, git remote, naming prefix, ADR/decisions location) go in
the consuming repo's `CLAUDE.md`. A copyable starter lives at
`${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/` — copy the relevant bits into your
`CLAUDE.md`, fill in the values.

The multi-agent pipeline's handoff workspace (in-repo under `docs/02-working-docs/handoffs/` per
`${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`) is **optional** — used only by the
delegated `ios-orchestrator` flow.

## First module
Once `CLAUDE.md` is wired, scaffold with `/ifl-ios-standards:boardy-new-module`.
