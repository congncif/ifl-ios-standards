<!-- Created by claude-opus-4-7 on 2026-05-23 -->
# EXAMPLES: Barrier Board (gated activation)

End-to-end skeleton for the ActivationBarrier pattern: a "gated" Board defers its own activation to a "barrier" Board (e.g. authentication / consent / feature-eligibility check). The barrier Board runs its own UI/logic flow and emits a typed Output; the gated Board activates only on a "passed" result.

Companion spec: `ACTIVATION_BARRIER.md`. Cross-module dep: gated Plugins podspec must `s.dependency '{BarrierModule}'`.

Placeholders: `{Gated}` = gated Board name (e.g. `Checkout`), `{GatedModule}` = its module, `{Barrier}` = barrier Board name (e.g. `Login`), `{BarrierModule}` = barrier module.

---

## 1. Barrier Board (the gate)

```swift
// {BarrierModule}/Sources/Microboards/{Barrier}/{Barrier}Board.swift
import Boardy
import Foundation
import UIKit

// Typed Output enum — every exit path MUST sendOutput then complete().
public enum {Barrier}Result {
    case succeeded
    case skipped         // already passed (e.g. session already valid)
    case notEligible     // user is not allowed to proceed
    case failed(Error)
}

final class {Barrier}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Barrier}Input
    typealias OutputType = {Barrier}Result
    typealias FlowActionType = {Barrier}Action
    typealias CommandType    = {Barrier}Command

    private let builder: {Barrier}Buildable

    init(identifier: BoardID, builder: {Barrier}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        // Fast-path: already eligible — exit immediately.
        if input.session.isValid {
            sendOutput(.skipped)
            complete()
            return
        }

        let component = builder.build(withDelegate: self, input: input)
        attachObject(component.controller, context: input.context ?? rootViewController)
        rootViewController.show(component.viewController, sender: self)
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}

extension {Barrier}Board: {Barrier}Delegate {
    func finish(from controller: {Barrier}Controllable, result: {Barrier}Result) {
        // Every termination path goes through here. Never let the Board exit silently:
        // a barrier that fails to sendOutput leaves gated activations stuck forever.
        sendOutput(result)
        complete()
    }
}
```

> Round-trip identity filter (Controller → Board delegate → Bus → Controller) is omitted here for brevity — apply the standard pattern (see `EXAMPLES_VIEWLESS_BOARD.md`) if the barrier has child boards.

---

## 2. Gated Board (defers activation to the barrier)

```swift
// {GatedModule}/Sources/Microboards/{Gated}/{Gated}Board.swift
import Boardy
import Foundation
import UIKit

final class {Gated}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Gated}Input
    typealias OutputType = {Gated}Output
    typealias FlowActionType = {Gated}Action
    typealias CommandType    = {Gated}Command

    private let builder: {Gated}Buildable

    init(identifier: BoardID, builder: {Gated}Buildable, producer: ActivatableBoardProducer) {
        self.builder = builder
        super.init(identifier: identifier, boardProducer: producer)
        registerFlows()
    }

    // The gate — Boardy will call this BEFORE activate(withGuaranteedInput:).
    // Returning a non-nil ActivationBarrier causes Boardy to activate the barrier first
    // and feed its Output back through `flow.addTarget` on this Board.
    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? {
        motherboard.serviceMap.mod{BarrierModule}
            .io{Barrier}.activation.barrier(
                scope: .mainboard,                        // .mainboard = per-session; .application = global singleton
                with: {Barrier}Input(session: input.session)   // REQUIRED when InputType ≠ Void
            )
    }

    func activate(withGuaranteedInput input: InputType) {
        // Only reached if the barrier emitted .succeeded or .skipped (see registerFlows below).
        let component = builder.build(withDelegate: self, input: input)
        attachObject(component.controller, context: input.context ?? rootViewController)
        rootViewController.show(component.viewController, sender: self)
    }

    func interact(guaranteedCommand: CommandType) {}
}

extension {Gated}Board: {Gated}Delegate {
    func finish(from controller: {Gated}Controllable, output: {Gated}Output) {
        sendOutput(output)
        complete()
    }
}

private extension {Gated}Board {
    func registerFlows() {
        // Boardy delivers the barrier's Output through the gated Board's flow channel.
        // Inspect the typed result and decide whether to proceed.
        motherboard.serviceMap.mod{BarrierModule}
            .io{Barrier}.flow.addTarget(self) { target, result in
                switch result {
                case .succeeded, .skipped:
                    // Boardy continues to `activate(withGuaranteedInput:)` automatically when
                    // the barrier resolves positively — nothing to do here for the happy path.
                    break
                case .notEligible:
                    target.sendOutput(.cancelled(reason: .notEligible))
                    target.complete()
                case .failed(let error):
                    target.sendOutput(.cancelled(reason: .barrierFailed(error)))
                    target.complete()
                }
            }
    }
}
```

---

## 3. Scope choice (`.mainboard` vs `.application`)

```swift
// .mainboard — barrier resolved once per mainboard lifetime (default).
//   Use for per-session gates: login flow inside a logged-out session.
.barrier(scope: .mainboard, with: {Barrier}Input(...))

// .application — barrier resolved once per app process; shared across all mainboards.
//   Use for one-time consent screens, app-update prompts, ATT permission.
.barrier(scope: .application, with: {Barrier}Input(...))
```

Decision rule:

```
Does the barrier outcome differ across mainboards (e.g. different user sessions)?
├── YES → .mainboard
└── NO  → .application
```

---

## 4. ModulePlugin (barrier side)

```swift
// {BarrierModule}/Sources/{BarrierModule}ModulePlugin.swift
import Boardy

public final class {BarrierModule}ModulePlugin: ModulePlugin {
    public init() {}

    public var continuousRegistrations: [BoardRegistration] {
        [
            BoardRegistration(.pub.mod.{BarrierModule}IO.{Barrier}) { id in
                {Barrier}Board(
                    identifier: id,
                    builder: {Barrier}Builder(/* deps */),
                    producer: $0
                )
            }
        ]
    }
}
```

---

## 5. Cross-module wiring (gated podspec)

```ruby
# {GatedModule}/{GatedModule}Plugins.podspec
Pod::Spec.new do |s|
  s.name = '{GatedModule}Plugins'
  # ...
  s.dependency 'Boardy'
  s.dependency '{GatedModule}'           # own IO target
  s.dependency '{BarrierModule}'         # barrier IO target — required for .barrier(...) call
end
```

---

## Direction matrix

| Direction | Mechanism |
|---|---|
| Gated declares gate | `func activationBarrier(...) -> ActivationBarrier?` returns `.barrier(scope:, with:)` |
| Boardy → activates barrier | Automatic, before gated Board's `activate(...)` |
| Barrier → reports result | `sendOutput(result)` + `complete()` on every exit path |
| Gated ← barrier result | `motherboard.serviceMap.mod{BarrierModule}.io{Barrier}.flow.addTarget(self)` |
| Gated proceeds | Boardy calls `activate(withGuaranteedInput:)` automatically on `.succeeded` / `.skipped` |
| Gated cancels | On `.notEligible` / `.failed`, gated Board calls `sendOutput(.cancelled)` + `complete()` itself |

## Pitfalls

- ❌ `.barrier()` (no `with:`) when `InputType ≠ Void` → casts Void silently; barrier activates with garbage input or hangs
- ❌ Barrier exit path that forgets `sendOutput` + `complete()` → gated activations stuck forever; investigate every `return` and `catch` branch
- ❌ Mixing `.mainboard` and `.application` scope for the same barrier across the codebase → unpredictable cache behavior
- ❌ Gated Board does eligibility check itself inside `activate(...)` instead of declaring `activationBarrier(...)` → barrier never runs; barrier UI never appears
- ❌ Using untyped `OutputType = Bool` for barrier result → loses the `notEligible` vs `failed` distinction the gated Board needs to route on

## References

- `ACTIVATION_BARRIER.md` (full spec)
- `MICROBOARD_UI.md` / `MICROBOARD_NONUI.md` (barrier Board can be either)
- `COMMUNICATION.md` (`complete()` at-most-once semantics)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
