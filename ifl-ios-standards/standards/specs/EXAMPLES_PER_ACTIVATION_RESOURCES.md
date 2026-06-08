<!-- Created by claude-opus-4-7 on 2026-05-23 -->
# EXAMPLES: Per-Activation External Resources

End-to-end skeleton for a Board that owns an SDK / external service whose lifetime is exactly ONE activation. Pattern: factory-construct inside `activate(...)`, immediate `attachObject(...)`, `complete()` after the last callback. State that survives the activation lives in a separate Guard class.

Companion spec: `PER_ACTIVATION_RESOURCES.md`. Common use cases: ads SDKs, biometric prompts, file pickers, rewarded-video flows.

Placeholders: `{Name}` = Board name (e.g. `RewardedAd`), `{Module}` = module, `{Service}` = external service type (e.g. `RewardedAdService`).

---

## 1. The Board (factory + attachObject)

```swift
// Sources/Microboards/{Name}/{Name}Board.swift
import Boardy
import Foundation
import UIKit

final class {Name}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Name}Input
    typealias OutputType = {Name}Output
    typealias FlowActionType = {Name}Action
    typealias CommandType    = {Name}Command

    private let factory: {Service}Factory          // makes a fresh service per activation
    private let guardScope: {Name}Guard            // exclusion guard (see §3)

    init(identifier: BoardID,
         factory: {Service}Factory,
         guardScope: {Name}Guard,
         producer: ActivatableBoardProducer) {
        self.factory = factory
        self.guardScope = guardScope
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        // 1. Exclusion guard — bail out if another activation is already in flight.
        //    The guard's job is to prevent two concurrent SDK sessions from clobbering each other.
        guard guardScope.tryAcquire() else {
            sendOutput(.busy)
            complete()
            return
        }

        // 2. Per-activation construction. NEVER stored as a Board property.
        //    Stored properties would leak across activations and pollute callbacks
        //    from a previous run into a fresh one.
        let service = factory.makeService(unitID: input.unitID)

        // 3. attachObject ties the service's lifetime to the Board.
        //    Service must be NSObject (required by Boardy's Attachable conformance).
        //    On complete(), Boardy releases its strong ref so the service deallocates.
        attachObject(service)

        // 4. Drive the service. Wrap callbacks back onto MainActor before sendOutput/complete.
        service.run(parameter: input.parameter) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.guardScope.release()        // ALWAYS release BEFORE sendOutput/complete
                self.sendOutput(.completed(result))
                self.complete()
            }
        }
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand: CommandType) {}
}
```

---

## 2. The factory

```swift
// Sources/Microboards/{Name}/{Service}Factory.swift
import Foundation

protocol {Service}Factory {
    func makeService(unitID: String) -> {Service}
}

struct Default{Service}Factory: {Service}Factory {
    func makeService(unitID: String) -> {Service} {
        {Service}(unitID: unitID)          // fresh instance per call — no caching
    }
}
```

> Caching inside the factory defeats the per-activation invariant. If a service is genuinely shareable, it does not belong in this pattern — promote it to a regular dependency injection slot.

---

## 3. The Guard (exclusion scope)

```swift
// Placement depends on exclusion scope — see decision tree below.
import Foundation

public final class {Name}Guard {
    private let lock = NSLock()
    private var inFlight = false

    public init() {}

    public func tryAcquire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    public func release() {
        lock.lock(); defer { lock.unlock() }
        inFlight = false
    }
}
```

### Where to instantiate the Guard

```
Exclusion scope of the SDK
├── whole module (e.g. only one ad of any kind at a time)
│      → stored property on LauncherPlugin, shared via ModuleComponent.config
├── per ServiceType (e.g. one rewarded ad AND one interstitial in parallel)
│      → instantiated inside the relevant `case` branch of ModulePlugin
└── per flow (e.g. each Builder call needs its own guard)
       → local var inside Builder.build(...)
```

#### LauncherPlugin-scoped (whole module)

```swift
public final class {Module}LauncherPlugin: LauncherPlugin {
    private let sharedGuard = {Name}Guard()
    public init() {}

    public func prepareForLaunching() -> ModuleComponent {
        ModuleComponent(
            modulePlugins: [
                {Module}ModulePlugin(guardScope: sharedGuard)
            ],
            launchSettings: { _ in /* SDK init if any */ }
        )
    }
}
```

#### ModulePlugin-scoped (per ServiceType)

```swift
public final class {Module}ModulePlugin: ModulePlugin {
    private let rewardedGuard    = {Name}Guard()
    private let interstitialGuard = {Name}Guard()
    public init() {}

    public var continuousRegistrations: [BoardRegistration] {
        [
            BoardRegistration(.pub.mod.{Module}.RewardedAd)    { id, p in
                RewardedAdBoard(identifier: id, factory: …, guardScope: self.rewardedGuard,    producer: p)
            },
            BoardRegistration(.pub.mod.{Module}.InterstitialAd) { id, p in
                InterstitialAdBoard(identifier: id, factory: …, guardScope: self.interstitialGuard, producer: p)
            }
        ]
    }
}
```

#### Builder-scoped (per flow)

```swift
struct {Name}Builder: {Name}Buildable {
    func build(...) -> {Name}Interface {
        let localGuard = {Name}Guard()        // one per build() call
        // …
    }
}
```

---

## 4. Controller-owns-routing (when an SDK has multiple callback shapes)

If the SDK reports several events (loaded / shown / clicked / rewarded / dismissed), the Board MUST NOT contain a `switch` on event type. State lives in the Controller; the Board exposes one delegate method per outcome.

```swift
final class {Name}Controller: NSObject {
    weak var delegate: {Name}ControlDelegate?

    private let config: {Name}Input                // immutable config for this flow
    init(config: {Name}Input) { self.config = config }
}

extension {Name}Controller: {Name}Controllable {
    func sdkDidLoad()                   { delegate?.adLoaded(from: self) }
    func sdkDidShow()                   { delegate?.adShown(from: self) }
    func sdkDidReward(_ amount: Int)    { delegate?.adRewarded(from: self, amount: amount) }
    func sdkDidFail(_ error: Error)     { delegate?.adFailed(from: self, error: error) }
    func sdkDidDismiss()                { delegate?.adDismissed(from: self) }
}
```

In the Board's delegate conformance, each method is one ServiceMap call or one sendOutput — no branching:

```swift
extension {Name}Board: {Name}Delegate {
    func adRewarded(from c: {Name}Controllable, amount: Int) { sendOutput(.rewarded(amount)) }
    func adFailed(from c: {Name}Controllable, error: Error)  { sendOutput(.failed(error)); complete() }
    func adDismissed(from c: {Name}Controllable)             { complete() }
    // …
}
```

---

## Direction matrix

| Direction | Mechanism |
|---|---|
| Board → constructs service | `factory.makeService(...)` inside `activate(...)` (NEVER stored property) |
| Board → owns service lifetime | `attachObject(service)` immediately after construction |
| Service → callbacks → Board | Closure / NSObject delegate hop into the Controller (Controller routes via `delegate?.…(from: self)`) |
| Board → exclusion check | `guardScope.tryAcquire()` at top of `activate`, `guardScope.release()` BEFORE every exit |
| Board → finishes | `sendOutput(...)` then `complete()` after the LAST callback only |

## Pitfalls

- ❌ Stored `private let service: {Service}` on the Board → callbacks from activation N pollute activation N+1
- ❌ `attachObject` AFTER kicking off the SDK call → race: if the SDK returns synchronously the service may already be unreferenced
- ❌ `guardScope.release()` AFTER `sendOutput`/`complete()` → if the subscriber re-activates the same Board synchronously, the guard is still held and the re-activation reports `.busy`
- ❌ Guard placed at the wrong scope — e.g. whole-module guard when two ServiceTypes should be allowed in parallel → false `.busy` reports
- ❌ Service is not NSObject → `attachObject(_:)` fails to compile (Boardy's Attachable conformance requires NSObject)
- ❌ Switch on event type inside the Board → state belongs in the Controller (see §4)
- ❌ Forgetting to wrap SDK callbacks back onto MainActor before `sendOutput` → main-thread checker fires in the subscriber

## References

- `PER_ACTIVATION_RESOURCES.md` (full spec)
- `EXTENSIBLE_PROVIDER.md` (when the SDK comes from a pluggable provider)
- `MICROBOARD_NONUI.md` (most per-activation-resource boards are non-UI)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
