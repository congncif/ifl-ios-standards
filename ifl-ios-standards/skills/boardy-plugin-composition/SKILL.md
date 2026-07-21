---
name: boardy-plugin-composition
description: >-
  Use when composing Boardy boards into the app — LauncherPlugin / ModuleBuilderPlugin
  registration, ComposableBoard / TabBar containers, interchangeable providers / extensible
  backends, or gating a board behind an activation barrier. Triggers: "register plugin",
  "ComposableBoard", "TabBar", "extensible provider", "activation barrier".
---

# Plugin composition / containers / providers / barriers

## Read by sub-topic
- Plugin / LauncherPlugin registration → `${CLAUDE_PLUGIN_ROOT}/standards/specs/PLUGINS_INTEGRATION.md` + `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_PLUGIN.md`
- ComposableBoard / TabBar / multi-board container → `${CLAUDE_PLUGIN_ROOT}/standards/specs/COMPOSABLE_BOARD.md` + `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_COMPOSABLE_BOARD.md`
- Interchangeable providers / extensible backend → `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXTENSIBLE_PROVIDER.md` + `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_EXTENSIBLE_PROVIDER.md`
- Gate activation behind another board → `${CLAUDE_PLUGIN_ROOT}/standards/specs/ACTIVATION_BARRIER.md` + `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES_BARRIER_BOARD.md`
- Per-activation services / concurrency guard → `${CLAUDE_PLUGIN_ROOT}/standards/specs/PER_ACTIVATION_RESOURCES.md`

## Invariants
- `Sources/Plugins/**` may be `public` for LauncherPlugin construction wiring (rule 3).
- Register boards in `{Module}ModulePlugin.swift` (`ServiceType` case → BoardID + `build(motherboard:)`).
- `sharedRepository` stored on the ModulePlugin (rule 10).

## Subagent dispatch

Keep a bounded composition change inline. When separate ownership helps, route composition roots,
providers, containers, and barriers to `ifl-ios-standards:ios-architect`, approved wiring to
`ifl-ios-standards:ios-coder`, activation/composition behavior to `ifl-ios-standards:ios-tester`, and
an independent architecture audit to read-only `ifl-ios-standards:ios-reviewer`. Use
`ifl-ios-standards:ios-researcher` only for a bounded lookup. Codex maps the same responsibilities to
provider-native generic subagents; continue inline when delegation is unavailable.
