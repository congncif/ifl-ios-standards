---
name: refactor
description: >-
  Use when performing a structural refactor on a Boardy+VIP codebase — splitting or merging a
  module, extracting or moving a board across modules, or renaming a public symbol. Triggers:
  "split this module", "merge modules", "extract a board", "move board to another module", "rename a public symbol".
---

# Structural refactor

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/REFACTOR_PLAYBOOK.md` — procedural runbook for the five structural refactors.

Each section gives: trigger → mechanical sequence → verification → rollback. Move-Board covers
Option A (coordinated cutover) vs Option B (bridge alias for public boards).

## Guardrails
- Public symbol renames ripple through IO consumers — find every importer of the IO target first.
- Moving a board changes its BoardID namespace (`pub.mod.{Module}.{Board}`) — update registrations + call sites.
- Run the project's build after each mechanical step (see the consuming repo's `CLAUDE.md` for the command).
- A structural refactor usually triggers spec-sync — see `${CLAUDE_PLUGIN_ROOT}/standards/rules/SPEC_SYNC.md`.
