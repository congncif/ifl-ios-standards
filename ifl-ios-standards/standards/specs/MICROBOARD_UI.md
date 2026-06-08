<!-- Created by claude-opus-4-7 on 2026-05-09 -->
<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Microboard with UI (Full VIP Board)

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Template: `.ai/templates/module-template/Templates/Full UI Board.xctemplate/VIP`
> Companion specs: `VIP_COMPONENTS.md` (per-component rules), `EXAMPLES_VIP_BOARD.md` (full skeleton), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded cheatsheet).

## When to use

A feature that needs a `UIViewController` plus its Interactor + Presenter, presented through the motherboard's navigation context. Use when:

- The board owns a screen and that screen needs user-driven business logic (not a pure dumb VC).
- The board may emit a typed outcome to the caller (`OutputType`) and accept incoming commands (`CommandType`).
- The board may coordinate child boards via `registerFlows()`.

## When NOT to use

- The board has **no UI** → `MICROBOARD_NONUI.md` (decision tree: BlockTask / Viewless / Flow).
- The board is a parent that just hosts a tab bar / container → `COMPOSABLE_BOARD.md`.
- The "board" is really an entry-point screen already served by an existing VIP board — let that board coordinate via `registerFlows()` instead of wrapping it.

## Forces

- VIP separation costs 4–5 files per board; the payoff is testable Interactor + Presenter, swappable VC, and a clear public contract (IO).
- `ModernContinuableBoard` adds command + action machinery you'll pay for whether or not you use them — declare all four `Guaranteed*` conformances up-front rather than retrofitting.
- `watch(content:)` ties controller lifetime to the board; on the flip side, it means the board cannot keep the controller after `complete()`.

## Files

| Path | Role |
|------|------|
| `IO/{Board}/{Board}IOInterface.swift` | Public `BoardID` + factory typealias + motherboard extension |
| `IO/{Board}/{Board}InOut.swift` | `Input` / `Output` / `Command` / `Action` |
| `IO/{Board}/ServiceMap+{Board}.swift` | IO ServiceMap accessor |
| `Sources/Microboards/{Board}/{Board}Protocols.swift` | `Buildable`, `Controllable`, `Delegate` |
| `Sources/Microboards/{Board}/{Board}Board.swift` | The board class (see code below) |
| `Sources/Microboards/{Board}/{Board}Builder.swift` | DI for Interactor / Presenter / VC |
| `Sources/Microboards/{Board}/{Board}Interactor.swift` | Business logic + UseCase calls |
| `Sources/Microboards/{Board}/{Board}Presenter.swift` | Domain → ViewModel mapping |
| `Sources/Microboards/{Board}/{Board}ViewController.swift` | Programmatic VC, ViewModel rendering |
| `Sources/Microboards/{Board}/ServiceMap+{Board}.swift` | Plugins ServiceMap accessor |

## Naming

See `QUICK_REF.md` §2 (Module naming) and `BOARDY_CHEATSHEET.compact.md` Naming table. Quick rules:

- BoardID: public `"pub.mod.{Module}.{Board}"` / internal `"mod.{Module}.{Board}"`.
- VIP class names are **never** prefixed even when the module is prefixed (e.g. `DADProfile` module → `ProfileDetailBoard`, not `DADProfileDetailBoard`).

## Communication

```swift
final class {FeatureName}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType = {FeatureName}Input
    typealias OutputType = {FeatureName}Output
    typealias FlowActionType = {FeatureName}Action
    typealias CommandType = {FeatureName}Command

    private let builder: {FeatureName}Buildable
    private let completeBus = Bus<Bool>()

    init(identifier: BoardID, builder: {FeatureName}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)
        let viewController = component.userInterface

        watch(content: component.controller)
        motherboard.putIntoContext(viewController)
        rootViewController.show(viewController)

        completeBus.connect(target: self) { target, isDone in
            target.rootViewController.returnHere { [weak target] in
                target?.complete(isDone)
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {FeatureName}Board: {FeatureName}Delegate {
    func loadData() {}
    func close(_ isDone: Bool) { completeBus.transport(input: isDone) }
    func performCompletion(_ isDone: Bool) { completeBus.transport(input: isDone) }
}

private extension {FeatureName}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{ModuleName}Plugins
            .ioChildBoardA.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{ModuleName}Plugins
                        .ioChildBoardB.activation.activate()
                case .done:
                    target.completeBus.transport(input: true)
                }
            }
    }

    func complete(_ isDone: Bool) {
        sendOutput(isDone ? .done : .cancelled)
    }
}
```

Direction matrix:
- **Caller → Board**: `activate(withGuaranteedInput:)` from the motherboard factory.
- **Board → caller**: `sendOutput(_:)`.
- **Board → ViewController**: via watched controller's commands (`Bus<T>`), never direct retained refs.
- **ViewController → Board**: through `Delegate` (board conforms).
- **Board → Child board**: `serviceMap.mod{Module}Plugins.ioChild.activation.activate(...)`.
- **Child → parent**: `flow.addTarget` registered in `registerFlows()`.

## Concurrency

- All async UI updates inside the Presenter / VC wrap in `await MainActor.run { [weak self] in ... }`.
- `Bus<T>.transport(input:)` is synchronous; trigger from main when consumers touch UIKit.
- `watch(content:)` keeps the controller alive — do not also strongly retain it from a closure.

## Composition

- Registered in `{Module}ModulePlugin.internalContinuousRegistrations` (see `PLUGINS_INTEGRATION.md`).
- Builder is the DI seam: it receives the board (as `delegate`) and constructs Interactor + Presenter + VC, returning a component with `controller` + `userInterface`.
- Cross-module activation goes via `mod{Module}Plugins.io{Board}.activation` — never reach into another module's internals.

## Lifecycle

- `registerFlows()` always called from `init`, never `activate()` — flows must be ready before the first activation.
- Double-activation guard **only** when the board is explicitly single-session.
- `complete()` called at most once. For UI boards with a typed outcome it maps to `sendOutput`.
- `rootViewController.returnHere { ... }` is the only correct way to schedule `complete` after the user pops the screen.

## Testing

- `Interactor` tests are priority 1 — see `compact/TESTING.compact.md`.
- `Presenter` tests verify domain → ViewModel mapping.
- The Board class itself is rarely unit-tested directly; behavior is exercised through Interactor + integration if needed.
- Mock the `Delegate` and `Buildable`, not the whole board.

## Pitfalls

- ❌ Reaching for `UINavigationController` wrapping or `topPresentViewController` by reflex — `rootViewController.show(viewController)` is the **default**, not the only path. Custom navigation is allowed when SiFUtilities' `show(_:)` cannot express the requirement (e.g. specialized transitions, host-controlled containers) or when the Board is being **embedded** into a parent surface — in that case follow `COMPOSABLE_BOARD.md` instead of a bare `show()`.
- ❌ `registerFlows()` inside `activate()` — flows re-register every activation → stacked handlers.
- ❌ Holding the controller as a strong board property — defeats `watch(content:)` lifecycle.
- ❌ Calling `complete()` twice — raises an assertion.
- ❌ Forgetting `motherboard.putIntoContext(viewController)` before `show()` → navigation context misses the VC.

## References

- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded; file layout, naming, skeletons)
- `VIP_COMPONENTS.md` (Interactor / Presenter / VC per-component rules)
- `EXAMPLES_VIP_BOARD.md` (a complete worked example)
- `COMMUNICATION.md` (bus / flow / action / delegate channels)
- `PLUGINS_INTEGRATION.md` (registering this board with ModulePlugin)
- `QUICK_REF.md` §4 rules 5, 6, 7, 8, 12 (the rules this spec relies on)

## Checklist for UI Board

- [ ] Extends `ModernContinuableBoard`
- [ ] All 4 `Guaranteed*` protocol conformances declared
- [ ] `typealias` for all 4 type parameters (InputType, OutputType, FlowActionType, CommandType)
- [ ] Duplicate-activation guard omitted unless single-session
- [ ] `watch(content: component.controller)` called in `activate()`
- [ ] `motherboard.putIntoContext(viewController)` called before `show()`
- [ ] `rootViewController.show(viewController)` preferred — only deviate when SiFUtilities `show(_:)` cannot express the requirement, or when embedding into a `Composable` surface (then follow `COMPOSABLE_BOARD.md`)
- [ ] No custom `context:` on `show()` unless explicitly required (e.g. presenting on a specific VC instead of inferring from root, or pinning lifecycle to a known UIViewController) — keep the default path otherwise
- [ ] `completeBus` connected in `activate()` after `show()`
- [ ] `registerFlows()` called in `init`, not `activate()`
- [ ] Board conforms to `{Board}Delegate`
- [ ] Registered in `ModulePlugin`'s `internalContinuousRegistrations`
