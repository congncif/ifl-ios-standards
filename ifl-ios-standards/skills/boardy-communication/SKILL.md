---
name: boardy-communication
description: >-
  Use when wiring board-to-board communication in Boardy+VIP — event buses, flows,
  finishBus, addTarget callbacks, or context navigation (backToPrevious / returnHere).
  Triggers: "board communication", "bus pattern", "flow between boards", "navigate back / context".
---

# Board communication / buses / flows / context navigation

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md` — bus shapes (first).
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/COMMUNICATION.md` — edge cases + full reference.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/BUS_PATTERNS.md` — bus catalogue.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/CONTEXT_NAVIGATION.md` — backToPrevious / returnHere.

## Invariants
- All Board→Controller communication uses **event buses**, never retrieved controller references (rule 8).
- `registerFlows()` runs in the Board's `init`, never in `activate()` (rule 7).
- Bus **identity-filter** applies only to round-trips (Controller→Board delegate→Bus→Controller):
  payload carries the source Controller; subscriber `guard target === source`. Board-originated
  buses use plain `Bus<Void>` + weak `bus.connect(target:)` — never fabricate a source via `attachedObject(_:)`.
- `complete()` at most once, after streams released (rule 12).

## Subagent dispatch

Keep a bounded communication change inline. When separate ownership helps, route existing bus/lifecycle
facts to `ifl-ios-standards:ios-researcher`, public communication contracts to
`ifl-ios-standards:ios-architect`, approved wiring to `ifl-ios-standards:ios-coder`, and observable
event/lifecycle behavior to `ifl-ios-standards:ios-tester`. Use read-only
`ifl-ios-standards:ios-reviewer` only for an independent audit. Codex maps the same bounded
responsibilities to provider-native generic subagents; continue inline when delegation is unavailable.
