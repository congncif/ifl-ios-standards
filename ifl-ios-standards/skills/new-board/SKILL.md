---
name: new-board
description: >-
  Use when adding a board to an existing Boardy+VIP iOS module — UI (VIP stack), viewless
  (controller-backed), flow, or blocktask. Triggers: "add a board", "new VIP screen",
  "new viewless/flow/blocktask board", "create a microboard".
---

# New board

## Pick the board type FIRST
Read `${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md`, then:
- **UI (VIP)** — has a screen → `${CLAUDE_PLUGIN_ROOT}/standards/specs/MICROBOARD_UI.md` + `VIP_COMPONENTS.md`
- **viewless / flow / blocktask** — no UI → `${CLAUDE_PLUGIN_ROOT}/standards/specs/MICROBOARD_NONUI.md` (read its decision tree first)

Non-UI decision tree (answer in order):
0. A VIP UI board already serves as entry? → let it coordinate via `registerFlows()`, no wrapper.
1. Single async task then done? → **BlockTask Board**
2. Coordinator that must remember a child's output for a later step? → **Viewless Board**
3. Pure pass-through routing / reused from many entry points / conditional gate? → **Flow Board**

## Scaffold it
```bash
ifl-new-board <Module> <Board> <ui|viewless|flow|blocktask> --root=.
```
Emits IO files (`{Board}IOInterface`, `{Board}InOut`, `ServiceMap+{Board}`) and the
`Sources/Microboards/{Board}/` VIP/controller files. **Bazel globs auto-capture** the new `.swift`
— no BUILD edit unless the board imports a new cross-module IO dependency.

## Then
1. Register `{Board}Board` in `{Module}ModulePlugin.swift` (`ServiceType` case + `build()`).
2. Fill the `// TODO` markers — see `${CLAUDE_PLUGIN_ROOT}/standards/specs/EXAMPLES.md` → matching `EXAMPLES_*.md`.
3. Protocol placement: see `/ifl-ios-standards:boardy-vip` §2 / QUICK_REF §3.
