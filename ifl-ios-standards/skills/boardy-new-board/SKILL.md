---
name: boardy-new-board
description: >-
  Use when adding a board to an existing Boardy+VIP iOS module — UI (UIKit or SwiftUI adapter),
  viewless, flow, or blocktask. Triggers: "add a board", "new VIP screen",
  "new viewless/flow/blocktask board", "create a microboard".
---

# New board

## Pick the board type first

Read `${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md`, then:

- **UI (VIP)** — a screen rendered by UIKit or SwiftUI → `MICROBOARD_UI.md` + `VIP_COMPONENTS.md`.
  Both adapters preserve the same Board → Interactor → Presenter → humble-View semantics.
- **Viewless / flow / blocktask** — no first-party UI → `MICROBOARD_NONUI.md`.

For non-UI boards, answer in order:

1. A VIP UI board already serves as entry → let it coordinate in `registerFlows()`; no wrapper.
2. One async task with a per-activation result → `BlockTaskBoard`.
3. Coordinator must retain a child's output for a later step → Viewless Board.
4. Stateless routing, reused entry, or conditional gate → Flow Board.

## Scaffold safely

```bash
ifl-new-board <Module> <Board> <ui|swiftui|viewless|flow|blocktask> \
  --root=. --module-root=<repo-owned-module-root>
```

The command also accepts `--dry-run`. Module and Board names must match `[A-Z][A-Za-z0-9]*`. The module
must already exist. The command refuses to write when either the public IO destination or the
implementation destination exists; never bypass that protection.

It emits public IO (`{Board}IOInterface`, `{Board}InOut`, `ServiceMap+{Board}`) and a
type-specific starter under `Sources/Microboards/{Board}/`. The public BoardID literal is exactly
`pub.mod.<Module>.<Board>`; implementation code aliases it rather than creating another public
identity. Build globs may discover the files, but all target labels, dependencies, module roots,
project wiring, platform values, destinations, and commands remain consuming-repository values.

The `ui` selector emits the UIKit adapter. The `swiftui` selector emits the same Boardy+VIP core with
a MainActor presentation store, SwiftUI humble View, and hosting controller at the Boardy navigation
boundary. The `blocktask` selector emits `BlockTaskParameter` IO and a fail-fast
`BlockTaskBoard` factory that must be completed with project behavior before activation.

## Post-generation responsibilities

1. Replace placeholder InOut types and TODOs with the real contract and behavior.
2. Register the Board in `{Module}ModulePlugin` (`ServiceType` + `build`).
3. Reconcile new cross-module IO dependencies with the consuming repository's native build setup.
4. For Viewless, choose attachment ownership explicitly: input context → root context → board context.
5. For UI, choose UIKit or SwiftUI without moving product decisions or formatting into the View.
6. Add meaningful tests for observable behavior; do not add or retain fake scaffold tests.

## Verification

- An executable scaffold change gets one targeted native signal from the consuming repository.
- Documentation-only changes get no build or test.
- Do not create verifier scripts, receipts, manifests, or custom workflow-state files. Report direct
  native results when a signal is required.

## Hard rules

- Public BoardID: `pub.mod.<Module>.<Board>`.
- IO is public; `Sources/**` is internal except justified public `Sources/Plugins/**` composition
  types.
- UIKit and SwiftUI are adapters over the same Boardy+VIP and humble-View semantics.
- Scaffolders are thin and additive; generated output is not completed product behavior.
- Protocol placement follows `/ifl-ios-standards:boardy-vip` §2 / QUICK_REF §3.
