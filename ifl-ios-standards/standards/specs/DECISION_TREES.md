# DECISION_TREES — pick the right pattern fast

> **Purpose**: high-traffic navigator across the spec set. Each tree maps "I have situation X" → "use pattern Y, see spec Z". Read this BEFORE picking a Board type, an ID prefix, a bus shape, or a resource scope.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a routing index, same as `CONVENTIONS.md` / `ADOPTION.md`.

---

## 1. Which Board type?

```
What does this Board produce or coordinate?
│
├─ Renders a UIKit screen or a SwiftUI screen hosted at the Boardy UIViewController boundary
│   → ui Board
│     Core: Board + Builder + Interactor + Presenter + Protocols
│     Adapter: UIKit ViewController OR SwiftUI View + MainActor store + hosting controller
│     Semantics: same Boardy+VIP flow and humble-View boundary for both adapters
│     Spec : MICROBOARD_UI.md
│     Example: EXAMPLES_VIP_BOARD.md
│
├─ Wraps an SDK / system flow that returns one event but has no first-party UI
│  (e.g. GameCenter login, SKStoreReviewController prompt, photo picker delegate)
│   → viewless Board
│     Files: Board + Builder + Controller + Protocols
│     Spec : MICROBOARD_NONUI.md  §"Viewless"
│     Example: EXAMPLES_VIEWLESS_BOARD.md
│     ⚠ Attach context = (1) input.context → (2) rootViewController → (3) Board (last resort)
│
├─ Orchestrates 2+ child Boards in sequence or fan-out
│   → flow Board
│     Files: Board only (no Builder / Controller)
│     Spec : MICROBOARD_NONUI.md  §"Flow"
│     Example: EXAMPLES_NONUI_BOARDS.md
│
├─ Single async operation that must complete before something else activates
│   → BlockTaskBoard with a per-activation parameter/factory
│     Spec : MICROBOARD_NONUI.md  §"BlockTask"
│     Use this when a *barrier* needs the work done — see Tree §3.
│     Example: EXAMPLES_NONUI_BOARDS.md
│
├─ Gate that prevents another Board from activating until a precondition is met
│   → barrier Board
│     Spec : ACTIVATION_BARRIER.md
│     Example: EXAMPLES_BARRIER_BOARD.md
│
└─ Container that hosts multiple sub-Boards as composable UI elements
    → composable Board
      Spec : COMPOSABLE_BOARD.md
      Example: EXAMPLES_COMPOSABLE_BOARD.md
      ⚠ Children must activate via composableBoard.serviceMap, NOT motherboard.serviceMap
```

The bundled `ifl-new-board` command scaffolds `ui`, `swiftui`, `viewless`, `flow`, and `blocktask`.
Barrier and composable boards require their owning specs rather than pretending another generated
shape is equivalent. The command is additive and refuses existing IO or implementation destinations.
`ui` selects UIKit and `swiftui` selects the hosting adapter; both preserve one Boardy+VIP and
humble-View architecture.

## 2. Public or internal BoardID?

```
Will any other module activate this Board?
│
├─ Yes → public BoardID
│   Declared in: {Module}/IO/{Board}/{Board}IOInterface.swift
│   Literal:    "pub.mod.{Module}.{Board}"
│   Const:      public extension BoardID { static let pub{Board}: BoardID = "…" }
│   Activation: through MainDestination on MotherboardType (ioX factory + ServiceMap)
│   Spec     : IO_INTERFACE.md, EXAMPLES_IO.md
│
└─ No → internal BoardID
    Declared in: {Module}/Sources/Microboards/{Board}/{Board}BoardIOInterface.swift
    Literal:    "mod.{Module}.{Board}"  (or  alias to .pub{Board} if the IO exists for tests)
    Const:      extension BoardID { static let mod{Board}Board: BoardID = … }
    Activation: only via {Module}PluginsServiceMap inside the same module
    Spec     : MICROBOARD_NONUI.md, CONVENTIONS.md
```

`ifl-new-board` currently creates public IO for every supported selector. If the board is genuinely
internal, hand-author the smaller internal surface or deliberately remove the public surface; do not
leave unused public IO by accident.

## 3. Communication channel — who talks to whom, how?

```
Source → Destination
│
├─ Board → Controller / Interactor
│   → Bus<T> connected to the weak target; do not retrieve or retain controller references
│     Spec: MICROBOARD_UI.md, MICROBOARD_NONUI.md, BUS_PATTERNS.md
│
├─ Interactor / Controller → Board
│   → delegate protocol ({Board}ControlDelegate) — weak ref, set in Builder
│     Spec: MICROBOARD_UI.md, MICROBOARD_NONUI.md
│
├─ ViewController → Board  (user action, ui only)
│   → delegate protocol ({Board}ActionDelegate) — weak ref, set in Builder
│     Spec: MICROBOARD_UI.md
│
├─ Board → child Board                (same motherboard scope)
│   → motherboard.serviceMap.mod{ChildModule}Plugins.io{Child}.activation.activate(with:)
│     Spec: PLUGINS_INTEGRATION.md, CROSS_MODULE_DI.md
│
├─ Board → child Board                (composable parent scope)
│   → composableBoard.serviceMap.io{Child}.activation.activate(with:)
│     ⚠ Do NOT use motherboard.serviceMap — child must inherit composable lifecycle
│     Spec: COMPOSABLE_BOARD.md
│
├─ child Board → parent Board         (flow callback)
│   → child Output emitted via sendOutput(_:); parent registers
│     motherboard.serviceMap.mod{ChildModule}Plugins.io{Child}.flow.addTarget(self) { … }
│     Spec: BUS_PATTERNS.md §Board-originated, EXAMPLES_NONUI_BOARDS.md
│
└─ Controller ↔ Board (round-trip async, same identity)
    → identity-filtered Bus — see Tree §4
```

## 4. Bus shape — which `Bus<T>` pattern?

```
Is the bus payload tied to a specific Controller instance?
│
├─ Yes — Controller calls Board, Board fans out to SDK, SDK fires back, only THAT
│   Controller should receive it (round-trip)
│   → identity-filtered Bus<(source: Controller, payload: T)>
│     Subscriber:  bus.connect(target: someAnchor) { _, msg in
│                      guard msg.source === currentController else { return }
│                      currentController.didReceive(msg.payload)
│                  }
│     ⚠ Closing over a local controller variable is NOT an identity filter
│     Spec: BUS_PATTERNS.md §Round-trip identity-filtered
│
└─ No — Board emits one signal, Controller listens for it (lifecycle ≠ identity)
    → plain Bus<T> with bus.connect(target: controller)
      (weak binding via target; controller release stops delivery)
      Spec: BUS_PATTERNS.md §Board-originated
      ⚠ Never attachedObject(_:) just to fabricate a source identity
```

## 5. Per-activation resource — where does it live?

A resource that exists only for the duration of one activation (timer, GameCenter request, in-flight URLSession task).

```
What's the scope of "one activation"?
│
├─ One per Module lifetime, shared across activations
│   → LauncherPlugin
│     Spec: PLUGINS_INTEGRATION.md §LauncherPlugin
│     Example: EXAMPLES_PLUGIN.md
│
├─ One per Builder invocation (rare — usually means "per UI screen instance")
│   → ModulePlugin factory + Builder property
│     Spec: PER_ACTIVATION_RESOURCES.md §ModulePlugin scope
│     Example: EXAMPLES_PER_ACTIVATION_RESOURCES.md
│
└─ One per Board activate(_:) call — must die when complete() fires
    → Guard class created in activate(_:), retained via attachObject
      Spec: PER_ACTIVATION_RESOURCES.md §Guard scope (deepest scope)
      Example: EXAMPLES_PER_ACTIVATION_RESOURCES.md
```

## 6. Attach context — which `AnyObject` owns the Controller?

```
Which existing object should own the Controller's attached lifetime?
│
├─ An explicit owner was passed in input
│   → input.context  (highest priority)
│
├─ No explicit owner, but the flow belongs to the root UI lifetime
│   → rootViewController
│
└─ No suitable owner exists
    → Board context  (last resort; release with complete()/detachObject)
      ⚠ Board lifecycle remains independent of Controller lifecycle
      Spec: MICROBOARD_NONUI.md §Attach context
```

## 7. Extensible provider — when?

```
Does this Board need to swap implementations per-build / per-tenant / per-feature-flag?
(e.g. AdProvider = AdMob vs MAX vs none; Auth = Apple vs Google vs Firebase)
│
├─ No → just write the Board directly. No marker protocol.
│
└─ Yes
    → Extensible Provider pattern (OCP-style)
      Files: public marker protocol (Sources/Plugins/) +
             internal factory protocol (Sources/Plugins/) +
             concrete provider configs (one per impl, Sources/Plugins/) +
             provider Board with named-alias Input (Sources/Microboards/) +
             ModulePlugin factory dispatch (Sources/Plugins/) +
             LauncherPlugin one-line provider switch (Sources/Plugins/)
      Spec: EXTENSIBLE_PROVIDER.md
      Example: EXAMPLES_EXTENSIBLE_PROVIDER.md
      ⚠ Provider configurations are CONSTRUCTION WIRING, not domain meaning.
        They sit next to {Feature}LauncherPlugin under Sources/Plugins/ — the
        pack's public-export zone for LauncherPlugin construction inputs.
        Putting them in IO/ confuses domain (what the module DOES) with
        boot-time wiring (HOW the App constructs the module).
        See IO_INTERFACE.md §"Domain meaning vs construction wiring".
```

## 8. Cross-module dependency — IO or Plugins?

```
Direction of need
│
├─ I want to activate another module's public Board
│   → import {OtherModule}
│     podspec: s.dependency '{OtherModule}'   (not {OtherModule}Plugins)
│     Reason: Plugins is implementation; IO target is the supported seam
│     Spec: CROSS_MODULE_DI.md, IO_INTERFACE.md
│
├─ I want to call a domain service (UseCase, repository)
│   → put it in the OWNER module's IO/ if it's a public surface,
│     else import it via the {OtherModule}Plugins boundary ONLY from app target
│     Spec: SERVICE_LAYER.md, LAYERING.md
│
└─ I want to share types between modules but no Board needed
    → minimal IO surface in owning module; both consumers depend on it
      Avoid creating a "Common" sink module — see LAYERING.md §Anti-patterns
```

Any `Sources/**` import of `{OtherModule}Plugins` is a hard violation.

## 9. Migration: brownfield project — where to start?

Brief pointer (full guide: `BROWNFIELD_MIGRATION.md`):

```
Existing screen with UIKit-only code, no Boardy
│
├─ Read ADOPTION.md
├─ Pick one self-contained screen (low fan-in, low fan-out)
├─ Resolve the module root and build values from the consuming repository
├─ ifl-new-module {ModuleName} --root=. --module-root={ModuleRoot}
├─ ifl-new-board {ModuleName} {Screen} <ui|swiftui> --root=. --module-root={ModuleRoot}
├─ Keep the generated Interactor + Presenter boundary for either adapter
├─ Wire LauncherPlugin in AppDelegate/SceneDelegate
└─ Iterate: next screen, this time using the ServiceMap you just established
```

Scaffold generation never chooses repository-specific dependencies, target labels, project wiring,
deployment values, simulator destinations, or verification commands. Reconcile those after
generation. Do not create fake placeholder tests. Executable scaffold changes get one targeted
native signal from the consuming repository; documentation-only changes get no build/test. Neither
path needs verifier scripts, receipts, manifests, or custom workflow-state files.

## References

- `BOARDY_FOUNDATIONS.md` — read this BEFORE any of the trees above. Five non-negotiables: Board owns Controller (one-way), Board lifecycle ≠ Controller lifecycle, attach context is AnyObject, `watch(content:)` is lifecycle-only, `complete()` at-most-once.
- `ARCHITECTURE.md` — 30,000-ft view of the layering + Boardy mental model.
- `CONVENTIONS.md` — file/naming conventions referenced by every tree above.
- `QUICK_REF.md` — single-page reference for IDs, factories, ServiceMap link patterns.
- `compact/BOARDY_CHEATSHEET.compact.md` — board-type column table in 1 page.
- `REVIEWER_CHECKLIST.md` — what to check in PR review (this spec is the *forward* path; reviewer checklist is the *backward* check).
