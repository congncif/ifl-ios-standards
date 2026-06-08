<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Context Navigation & Presentation Safety

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `COMMUNICATION.md` (Bus patterns), `MICROBOARD_UI.md` (Board lifecycle), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When wiring back navigation, multi-step return-to-anchor flows, or presenting alerts/modals from a Board. The four canonical cases:

1. Simple back: one step back in the nav stack from the current screen.
2. Targeted return: pop back to a specific destination after a multi-step flow.
3. Local rendering alert: alert/sheet whose data and lifecycle belong to one ViewController.
4. Out-of-scope alert/modal: presentation owned by another Board or crossing flow boundaries.

## When NOT to use

- Plain push/present of a child board with no return logic → see `MICROBOARD_UI.md` `rootViewController.show(...)`.
- Dismissing a modal that the same Board just presented → standard `dismiss(animated:)` on the presenter is fine; no bus needed.
- View ↔ Interactor ↔ Presenter dialog logic — those are VIP, see `VIP_COMPONENTS.md`.

## Forces

- `backToPrevious()` and `returnHere()` MUST land on the right ViewController. Calling either on `rootViewController` (the root context, not a screen) is the most common bug — silently no-ops or pops the wrong VC.
- Local-vs-out-of-scope alert split exists because cross-board presentation on a stale ViewController triggers the *"presenting from detached view controller"* warning and corrupts safe-area insets.
- Buses (instead of stored VC refs) keep Board decoupled from VC lifetime — pay the one `Bus<T>` per nav action.

## Files

This spec governs wiring inside existing Board files — no new files:

```
Sources/Microboards/{Board}/{Board}Board.swift       ← bus declarations + connect() + transport()
Sources/Microboards/{Board}/{Board}Protocols.swift   ← delegate methods that transport the bus
Sources/Microboards/{Board}/{Board}ViewController.swift ← local alert presentation only
```

## Naming

- `cancelBus: Bus<Void>` — simple back from current screen.
- `returnBus: Bus<Void>` — return to a specific destination after a flow.
- `confirmBus: Bus<Void>` — confirmation alert action.
- Each bus connects once in `activate()`, transports from a delegate method or `registerFlows()`.

## Communication

### Pattern 1 — Simple back (`backToPrevious`)

Bus connected to the **current** ViewController; transported when the delegate fires.

```swift
final class {Board}Board: ModernContinuableBoard, ... {
    private let cancelBus = Bus<Void>()

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)

        cancelBus.connect(target: component.userInterface) { vc in
            vc.backToPrevious()                  // ✅ current VC
        }

        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}

extension {Board}Board: {Board}Delegate {
    func cancel() {
        cancelBus.transport()
        sendOutput(.cancelled)
    }
}
```

### Pattern 2 — Targeted return (`returnHere`)

The **destination** (coordinator) declares `returnBus`, connects it to its own VC, and transports it from `registerFlows()` on child completion. Child boards send output only.

```swift
final class {Coordinator}Board: ModernContinuableBoard, ... {
    private let returnBus = Bus<Void>()

    func activate(withGuaranteedInput input: InputType) {
        let component = builder.build(withDelegate: self, input: input)

        returnBus.connect(target: component.userInterface) { vc in
            vc.returnHere()                      // ✅ destination VC
        }

        watch(content: component.controller)
        motherboard.putIntoContext(component.userInterface)
        rootViewController.show(component.userInterface)
    }
}

private extension {Coordinator}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildA.flow.addTarget(self) { target, output in
                switch output {
                case .next:
                    target.motherboard.serviceMap.mod{Module}Plugins
                        .ioChildB.activation.activate(with: ChildBInput(context: target.rootViewController))
                case .cancelled: break
                }
            }
        motherboard.serviceMap.mod{Module}Plugins
            .ioChildB.flow.addTarget(self) { target, output in
                switch output {
                case .completed: target.returnBus.transport()   // ✅ pop back to coordinator VC
                case .cancelled: break
                }
            }
    }
}

// Child just signals; never navigates directly
extension {ChildA}Board: {ChildA}Delegate {
    func proceed() { sendOutput(.next) }
}
```

### Pattern 3 — Local alert/sheet on the current VC

Allowed when the message is pure rendering for the current screen (validation, confirmation tied to that screen's state). The VC presents itself.

```swift
private extension {Feature}ViewController {
    func presentValidationAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

### Pattern 4 — Out-of-scope alert/modal via top-presented chain

When another Board owns the message, or the current context might be stale/detached, present on `rootViewController.topPresentedViewController`.

```swift
extension {Board}Board: {Board}Delegate {
    func showConfirmation(message: String) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.confirmBus.transport()
        })
        rootViewController.topPresentedViewController.present(alert, animated: true)  // ✅ topmost
    }

    func showModal(with data: SomeData) {
        let modalVC = {Modal}ViewController(data: data)
        let nav = UINavigationController(rootViewController: modalVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        rootViewController.topPresentedViewController.present(nav, animated: true)
    }
}
```

Helper (add if not in SiFUtilities):

```swift
extension UIViewController {
    var topPresentedViewController: UIViewController {
        var top = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
```

### Channel decision

```
Back one step from current screen?          → cancelBus → vc.backToPrevious()
Return to a specific destination?           → destination's returnBus → vc.returnHere()
Alert/sheet owned by current VC?            → current VC presents itself
Alert/modal owned by Board / cross-flow?    → rootViewController.topPresentedViewController.present(...)
```

## Concurrency

- All bus consumers fire on the main thread; nav helpers (`backToPrevious`, `returnHere`, `present`) are MainActor-bound.
- `transport()` is synchronous — the nav call runs before `transport()` returns.
- If a delegate method receives results from a background `Task`, hop with `await MainActor.run { ... }` before `transport()`.

## Composition

- Pattern wires inside existing UI-Board files (`MICROBOARD_UI.md`). No new file shape.
- Coordinator + children registered in `ModulePlugin.internalContinuousRegistrations` (`PLUGINS_INTEGRATION.md`).
- `rootViewController` passed as context only when the child must present modals on top — see "Context passing" below.

### Context passing

```swift
// ✅ Pass current rootViewController as context when child may present modals
motherboard.serviceMap.mod{Module}Plugins
    .ioChild.activation.activate(with: ChildInput(data: data, context: rootViewController))
```

Do NOT pass context for simple stack pushes. Do NOT store input context on the Board for later use — capture in the closure or use the current `rootViewController` at call time.

## Lifecycle

- Bus connection order in `activate()`: build component → connect buses → `watch(content:)` → `putIntoContext` → `show`.
- Buses connected with `target: component.userInterface` capture the VC weakly — when the VC dies, the consumer no-ops.
- `cancelBus.transport()` MUST run before `sendOutput(.cancelled)` so the pop animation starts before the parent reacts.
- `returnBus` lives on the destination coordinator; transported when a *child* completes — never from the child itself.
- After `complete()` on the destination, `returnBus` is gone; do not transport.

## Testing

- Bus consumer: spin a fake VC conforming to the nav protocol; assert `backToPrevious` / `returnHere` invoked exactly once when bus fires.
- Coordinator integration: activate a fake child board with `.completed` output, assert coordinator's `returnBus` transports.
- Alert presenter selection: assert out-of-scope alerts call `topPresentedViewController.present`, not bare `rootViewController.present`.
- VC self-presented alert: standard ViewController unit test — present and assert the alert appears in `presentedViewController`.

## Pitfalls

- ❌ `rootViewController.backToPrevious()` / `rootViewController.returnHere()` → root context, not the screen. Wire a bus to the screen's VC.
- ❌ `rootViewController.present(alert, ...)` for cross-board alerts → may sit behind other VCs / detached warning. Use `topPresentedViewController`.
- ❌ `input.context?.present(alert, ...)` → context may be stale/dismissed.
- ❌ Child Board calling `backToPrevious` / `returnHere` for the coordinator → breaks the coordinator pattern. Child sends output; coordinator navigates.
- ❌ Routing every local-screen alert through the Board delegate → ceremony with no benefit. Let the VC present its own state-rendering alerts.
- ❌ Storing the VC reference on the Board for nav → use buses + `watch(content:)`.
- ❌ Transporting a bus from `init` or before `activate()` → fires into the void.
- ❌ Calling `cancelBus.transport()` AFTER `complete()` → board released; nothing fires.

## References

- `COMMUNICATION.md` (Bus patterns + `complete()` semantics)
- `MICROBOARD_UI.md` (where `show()`, `returnHere`, `backToPrevious` live)
- `MICROBOARD_NONUI.md` (Flow / Viewless coordinators)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 7, 8, 13
