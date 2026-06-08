<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Per-Activation Resource Management

> Companion specs: `MICROBOARD_NONUI.md` (Viewless Board), `COMMUNICATION.md` (Bus patterns + `complete()` semantics), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When a Board wraps a stateful external service that must be fresh per activation and kept alive until its operation completes:

- SDK delegates (ad network, payment provider, BLE peripheral).
- HTTP streams / sockets / long-poll handlers.
- Async operations whose lifetime exceeds `activate()` and whose callbacks must not pollute later activations.
- Any time you'd be tempted to store an NSObject delegate on the Board.

## When NOT to use

- The service is purely stateless (one function call, no delegate, no callback) → inject as a stateless factory and call it; no `attachObject` needed.
- The work is a one-shot async task with a typed result → use `BlockTaskBoard` in `MICROBOARD_NONUI.md` — its lifecycle is managed for you.
- The "service" is just a UseCase → it belongs in the Interactor, not on a wrapper Board.

## Forces

- Storing a stateful service on the Board is the most common Boardy bug: one service is shared across every activation; old callbacks land on new activations.
- `attachObject` solves lifetime but means `complete()` must be called **exactly when** the last attached operation ends — too early kills concurrent work, too late leaks.
- Concurrency guards are real shared state. Placing them on the Board re-introduces statefulness; the right home is the LauncherPlugin / ModulePlugin / Builder depending on the exclusion scope.

## Files

No new file shape — this spec governs how an existing Viewless / Flow / Block board is wired:

```
Sources/Microboards/{Board}/
├── {Board}Board.swift          ← stateless: factory + producer only
├── {Board}Builder.swift        ← injects guard + service factory into Controller
├── {Board}Controller.swift     ← owns per-activation service + guard interaction
└── ...
Sources/Plugins/{Module}LauncherPlugin.swift   ← optional: shared guard instance lives here
Sources/Plugins/{Module}ModulePlugin.swift      ← optional: narrower-scope guard lives here
```

## Naming

- Guard class: `{Domain}Guard` (e.g. `AdShowingGuard`, `PaymentInFlightGuard`).
- Factory: `{Service}Factory` returning a fresh `NSObject` instance per call.
- Routing delegate methods: one method per provider (e.g. `activateAdMobProvider(...)`, `activateUnityAdsProvider(...)`).

## Communication

```swift
// ❌ WRONG — service stored on Board
final class SomeBoard: ModernContinuableBoard, ... {
    private let service: SomeService     // shared across activations → callback pollution
    func activate(withGuaranteedInput input: InputType) {
        service.run(input.param) { [weak self] result in self?.sendOutput(result) }
    }
}

// ✅ CORRECT — service per activation, kept alive with attachObject
final class SomeBoard: ModernContinuableBoard, ... {
    private let factory: SomeServiceFactory

    init(identifier: BoardID, factory: SomeServiceFactory, producer: ActivatableBoardProducer) {
        self.factory = factory
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        let service = factory.makeService()      // fresh per activation
        attachObject(service)                    // alive until complete()
        service.run(input.param) { [weak self] result in
            self?.sendOutput(result)
            self?.complete()
        }
    }
}
```

When a Board routes between providers based on config, the Board must NOT branch on the config:

```swift
// Controller owns the config + the switch
final class SomeController: NSObject {
    private let config: SomeConfig
    weak var delegate: SomeControlDelegate?

    func start() {
        switch config {
        case .typeA(let p):       delegate?.activateTypeAProvider(param: p)
        case .typeB(let a, let b): delegate?.activateTypeBProvider(param1: a, param2: b)
        }
    }
}

// Board delegate methods are single ServiceMap calls — no switch
extension SomeBoard: SomeDelegate {
    func activateTypeAProvider(param: String) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioTypeAProvider.activation.activate(with: TypeAInput(param: param))
    }
    func activateTypeBProvider(param1: String, param2: String) {
        motherboard.serviceMap.mod{Module}Plugins
            .ioTypeBProvider.activation.activate(with: TypeBInput(p1: param1, p2: param2))
    }
    func finish() { sendOutput(()); complete() }
}
```

## Concurrency

Guards belong to a dedicated class and live at the narrowest scope that covers the required exclusion:

| Exclusion scope | Owner | Example |
|----|----|----|
| Whole module ("only one ad of any type") | `LauncherPlugin` stored property | `AdShowingGuard` shared across interstitial + reward |
| One `ServiceType` only | `ModulePlugin` case branch | guard created in `case .showInterstitialAd:` |
| One flow, never shared | Local in `build()` | guard for a single background task |

```swift
final class SomeOperationGuard {
    private var isRunning = false
    private let lock = NSLock()

    func tryAcquire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !isRunning else { return false }
        isRunning = true; return true
    }
    func release() {
        lock.lock(); defer { lock.unlock() }
        isRunning = false
    }
}

// Controller uses the guard — Board never sees it
final class SomeController: NSObject {
    private let operationGuard: SomeOperationGuard
    func start() {
        guard operationGuard.tryAcquire() else {
            input.completion?(.skipped); delegate?.finish(); return
        }
    }
    func didComplete(result: SomeResult) {
        operationGuard.release()      // every termination path must release before delegate?.finish()
        input.completion?(result); delegate?.finish()
    }
}
```

MainActor: the service's completion callback may fire on a background thread — hop to MainActor before calling `sendOutput` / `complete`.

## Composition

```swift
// Whole-module guard wired in LauncherPlugin
public struct SomeLauncherPlugin: LauncherPlugin {
    private let operationGuard = SomeOperationGuard()
    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: SomeModulePlugin.ServiceType.allCases.map {
                SomeModulePlugin(service: $0, operationGuard: operationGuard)
            }
        )
    }
}

// Per-flow guard wired in ModulePlugin.build()
func build(with identifier: BoardID, ...) -> any ActivatableBoard {
    switch service {
    case .specificFlow:
        let opGuard = SomeOperationGuard()
        return SpecificFlowBoard(
            identifier: identifier,
            builder: SpecificFlowBuilder(operationGuard: opGuard),
            producer: internalContinuousProducer
        )
    case .otherFlow:
        return OtherFlowBoard(identifier: identifier, producer: internalContinuousProducer)
    }
}
```

The guard is injected into the **Controller** via Builder — never the Board.

## Lifecycle

- `attachObject(service)` ties the service's lifetime to the Board.
- `complete()` releases the Board from the Motherboard and all `attachObject`-ed objects.
- For a single attached service: call `complete()` in that service's completion callback.
- For multiple concurrent tasks attached to the same Board: call `complete()` only after the LAST task finishes. Premature `complete()` releases attached objects mid-flight.
- Guard `.release()` must run on every termination path (success, error, cancellation) BEFORE `delegate?.finish()` — otherwise the guard stays acquired forever after a failure.

## Testing

- Test the guard class in isolation: lock contention, `tryAcquire` reject, `release` re-arms.
- Controller tests inject a mock `Guard` recording `tryAcquire` / `release` calls; assert release fires on every path.
- Service factory: assert a fresh instance per `makeService()` call.
- Board itself: rarely tested directly — exercised through Controller tests.

## Pitfalls

- ❌ Storing the service as a Board property → callbacks from old activations pollute later ones.
- ❌ Calling `complete()` once per task when the Board attaches several concurrent tasks → premature release.
- ❌ Guard placed on the Board as `private var isRunning` → re-introduces Board statefulness and races on concurrent activations.
- ❌ Guard placed on `LauncherPlugin` when only one flow needs it → unnecessarily coupled to unrelated flows.
- ❌ Guard `.release()` after `delegate?.finish()` → if `finish()` itself errors, release never runs.
- ❌ Board branching on config inside its delegate method → routing logic leaks out of Controller.
- ❌ `attachObject(_:)` on a non-`NSObject` → `Attachable` requires `NSObject`.

## References

- `MICROBOARD_NONUI.md` (Viewless Board — the typical host pattern)
- `COMMUNICATION.md` (`complete()` semantics + bus patterns)
- `PLUGINS_INTEGRATION.md` (where LauncherPlugin lives)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 8, 12, 13

## Decision tree

```
Service has state (delegate / completion closure)?
  YES → create per activation inside activate(); attachObject(service); complete() after last task finishes.
  NO  → inject as stateless factory; call directly; no attachObject.

Board routes to different providers based on config?
  YES → config → Controller via Builder; protocol splits per provider; Board delegate methods = single ServiceMap call.

Board needs a concurrency guard?
  YES → dedicated guard class; placement by exclusion scope (LauncherPlugin / ModulePlugin / Builder); injected into Controller.
```

## Checklist

- [ ] No per-activation service stored as Board property
- [ ] Service created inside `activate()` and `attachObject(service)` called immediately
- [ ] `complete()` called only after ALL attached work is done
- [ ] Routing config injected into Controller via Builder, not stored on Board
- [ ] Guard is a dedicated class; placement matches the required exclusion scope
- [ ] `tryAcquire()` at Controller start; `release()` on every termination path BEFORE `delegate?.finish()`
- [ ] Protocol split per concrete provider when routing varies
- [ ] `NSObject` conformance on any object passed to `attachObject`
