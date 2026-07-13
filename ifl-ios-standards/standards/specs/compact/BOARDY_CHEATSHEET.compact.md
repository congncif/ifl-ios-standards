# BOARDY_CHEATSHEET (compact)

Derived from the selected `boardy-vip` Canon Profile through `MICROBOARD_UI.md`, `IO_INTERFACE.md`,
and `COMMUNICATION.md`. This cheatsheet is routing/guidance only and cannot invent or weaken a Rule.
Load full specs only when the affected pattern needs them.

Last sync: 2026-07-13 for Standards 1.0 candidate.

## File layout per module

```
{ModuleRoot}/{Module}/               ← module root comes from CLAUDE.md / AGENTS.md bindings
├── IO/                              ← sources of the public "{Module}" Interface target
│   ├── {Module}ServiceMap.swift     ← public final class, single entry
│   └── {PublicBoard}/
│       ├── {PublicBoard}IOInterface.swift   ← BoardID + MainDestination typealias
│       ├── {PublicBoard}InOut.swift         ← Input/Output/Command/Action
│       └── ServiceMap+{PublicBoard}.swift   ← extension on {Module}ServiceMap
└── Sources/                         ← internal by default; Plugins/ has narrow App-boot export exception
    ├── Microboards/{Board}/         ← VIP folder + Board class
    ├── Services/                    ← UseCases + Service protocols
    ├── Plugins/                     ← ModulePlugin + minimum public LauncherPlugin construction surface
    └── ...
```

The consuming repository binds these two logical targets to CocoaPods, SwiftPM, Bazel, or a mixed
adapter. The source boundary is canonical; manifest filenames and dependency-sync commands are not.

## Naming

| Subject | Pattern | Example |
|---------|---------|---------|
| Module dir | `{Module}` | `Cart` |
| Interface (public) target | `{Module}` (sources under `IO/`) | `Cart` |
| Implementation target | `{Module}Plugins` (sources under `Sources/`; internal except narrow Plugins export zone) | `CartPlugins` |
| Public ServiceMap class | `{Module}ServiceMap` | `CartServiceMap` |
| Public ServiceMap accessor | `mod{Module}` | `mod.modCart` |
| Public BoardID | `pub.mod.{Module}.{Board}` | `pub.mod.Cart.Checkout` |
| Internal BoardID | `mod.{Module}.{Board}` | `mod.Cart.LineItem` |
| Public BoardID constant | `pub{Board}` | `.pubCheckout` |
| Internal BoardID constant | `mod{Board}` | `.modLineItem` |
| Public dest typealias | `{Board}MainDestination` | `CheckoutMainDestination` |
| Test method | `testScenarioExpectation` (camelCase) | `testDidBecomeActiveCallsLoadData` |

## IO files — minimal skeleton

```swift
// {Module}/IO/{Module}ServiceMap.swift
public final class CartServiceMap: ServiceMap {}
public extension ServiceMap {
    var modCart: CartServiceMap { link() }
}

// {Module}/IO/{Board}/{Board}IOInterface.swift
public extension BoardID {
    static let pubCheckout: BoardID = "pub.mod.Cart.Checkout"
}
public typealias CheckoutMainDestination = MainboardGenericDestination<
    CheckoutInput, CheckoutOutput, CheckoutCommand, CheckoutAction
>
extension MotherboardType where Self: FlowManageable {
    func ioCheckout(_ id: BoardID = .pubCheckout) -> CheckoutMainDestination {
        CheckoutMainDestination(destinationID: id, mainboard: self)
    }
}

// {Module}/IO/{Board}/{Board}InOut.swift
public struct CheckoutInput {
    public weak var context: UIViewController?           // weak!
    public let completion: (() -> Void)?
    public init(context: UIViewController? = nil, completion: (() -> Void)? = nil) {
        self.context = context; self.completion = completion
    }
}
public typealias CheckoutParameter = BlockTaskParameter<CheckoutInput, CheckoutOutput>
public enum CheckoutOutput { case completed(Result), cancelled }
public typealias CheckoutCommand = Void
public enum CheckoutAction: BoardFlowAction {}
```

Rules:
- `*ServiceMap` is `public final class` — single public entry.
- `context` is always `weak`.
- `Output = Void` / `Command = Void` typealias when no payload.
- Always ship the `BlockTaskParameter` typealias.

## Board class — UI Microboard skeleton

```swift
final class CheckoutBoard: ModernContinuableBoard,
    GuaranteedBoard, GuaranteedOutputSendingBoard,
    GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = CheckoutInput
    typealias OutputType = CheckoutOutput
    typealias FlowActionType = CheckoutAction
    typealias CommandType = CheckoutCommand

    private let builder: CheckoutBuildable
    private let completeBus = Bus<Bool>()

    init(identifier: BoardID, builder: CheckoutBuildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()                              // always last in init
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        let vc = component.userInterface
        watch(content: component.controller)         // 1
        motherboard.putIntoContext(vc)               // 2
        rootViewController.show(vc, sender: self)    // 3 — UIKit default; use a bound adapter or Composable when required
        completeBus.connect(target: self) { t, isDone in
            t.rootViewController.returnHere { [weak t] in t?.complete(isDone) }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

## Communication — direction matrix

| Mechanism | Direction | When |
|-----------|-----------|------|
| `sendOutput(_:)` → `.flow` | Board → direct parent Motherboard | Default child→parent result/event |
| `broadcastAction(_:)` → `FlowActionType` | Board → upstream ancestors | Signal concerns multiple ancestors may want |
| `.interaction.send(command:)` | Motherboard → active child / sibling | Push a command; sibling coordination within same Motherboard |
| `Bus<T>` | Board ↔ Controller | View / Interactor → Board events (delegates) and bus-driven Board → Controller side effects |

Rule of thumb: `sendOutput()` is default; `broadcastAction()` only when upstream ancestors should hear it; Command for the reverse direction.

## Activation, flow, command — call shapes

```swift
// Activate (with / without payload)
sm.modCartPlugins.ioCheckout.activation.activate(with: input)
sm.modCartPlugins.ioCheckout.activation.activate()

// Listen to output (in registerFlows, called from init)
sm.modCartPlugins.ioPayment.flow.addTarget(self) { t, output in
    switch output {
    case .completed: t.completeBus.transport(input: true)
    case .cancelled: t.completeBus.transport(input: false)
    }
}

// Push command into an active board
sm.modCartPlugins.ioPayment.interaction.send(command: .refresh)
```

Activation order inside `activate(...)`: `watch(content:)` → `putIntoContext(vc)` → `show(vc)` → `completeBus.connect(target:)` → `finishBus.deliver { ... }`.

## Hard rules

- **Humble View** (`UI-HUMBLE-001`…`004`): render display-ready state and forward typed intent.
  Branching on Presenter-encoded loading/content/empty/error state is valid. UX-local focus,
  highlight, gesture, animation, scroll, disclosure, geometry, and visual interpolation are valid.
  Raw/domain formatting, derived product or analytics meaning, business/navigation-policy decisions,
  business I/O, and dependency construction are not.
- UIKit consumes immutable state through a display port; SwiftUI consumes the same semantic state
  through a MainActor presentation store. SwiftUI `State` is UX-only (`UIKIT-RENDER-001`,
  `UI-ISOLATION-001`).
- `Sources/**` is internal except the minimum App boot construction surface in `Sources/Plugins/**`;
  another feature still never imports `{Module}Plugins` (`CORE-API-001`, `CORE-COMP-001`).
- UIKit `rootViewController.show(_:sender:)` is the dependency-free default. Use a project-approved
  navigation adapter only for behavior UIKit cannot express; use `COMPOSABLE_BOARD.md` for embedding.
- Omit custom `context:` on `show()` unless you need explicit control (target a specific VC instead of inferring from root, or pin lifecycle to a known UIViewController).
- `registerFlows()` last in `init`; never in `activate`.
- `context` in Input is `weak`; activation backedges are `weak`.
- `MainActor.run` for UI mutations from `Task`; never touch UIKit off-MainActor.
- `public init` on every public `Input` struct; private helper `complete(_:)` maps `Bool → sendOutput(_:)`.
- Test methods camelCase: `testScenarioExpectation`, not `test_<scenario>_<expectation>`.

## Checklist (paste into PR / review briefing)

- [ ] Board extends `ModernContinuableBoard`
- [ ] All 4 `Guaranteed*` conformances declared
- [ ] All 4 `typealias` declared
- [ ] `watch(content:)` + `putIntoContext` + `show` order
- [ ] `registerFlows()` in `init`, not `activate`
- [ ] `completeBus.connect` after `show`
- [ ] Board conforms to `{Board}Delegate`
- [ ] BoardID matches the public/internal naming rule
- [ ] `public init` on Input
- [ ] `BlockTaskParameter` typealias present
- [ ] Plugins target imports IO, never the other way
- [ ] No `import {OtherModule}Plugins` cross-module
- [ ] Views receive display-ready state; View conditionals are presentation-only and View-owned state is UX-local

## Full-spec routing (load only if needed)

| You're doing… | Full spec |
|----------------|-----------|
| New UI Microboard | `MICROBOARD_UI.md` |
| Non-UI / BlockTask / Viewless | `MICROBOARD_NONUI.md` |
| New IO target / public Board surface | `IO_INTERFACE.md` |
| Cross-board coordination edge cases | `COMMUNICATION.md` |
| VIP component placement (V/I/P/Builder) | `VIP_COMPONENTS.md` |
| Cross-module DI / ServiceMap composition | `CROSS_MODULE_DI.md` |
| Composable / Flow boards | `COMPOSABLE_BOARD.md` |
| Tests (mocks, stubs, structure) | `TESTING.md` |
| Reviewer rubric | `REVIEWER_CHECKLIST.md` |

## Anti-patterns (auto-blocker)

1. Raw/domain formatting or business/product/analytics decisions in a UIKit or SwiftUI View — Presenter prepares display-ready meaning; Interactor/UseCase owns business behavior.
2. Importing `*Plugins` from another module's `Sources/`.
3. Reflexively wrapping a regular pushed/presented Board screen in `UINavigationController` instead
   of using `show()`. Project-bound modal/container behavior and Composable surfaces are valid when
   their selected navigation pattern requires that wrapper.
4. `registerFlows()` inside `activate()` — re-registers on every activation.
5. Strong reference to `context` in `Input`.
6. Missing `public init()` on a public `Input` struct.
7. Storyboard `UIStoryboard` injection in `Builder`.
