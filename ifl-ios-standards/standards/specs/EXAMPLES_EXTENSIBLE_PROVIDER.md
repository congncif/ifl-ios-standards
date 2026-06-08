<!-- Created by claude-opus-4-7 on 2026-05-23 -->
# EXAMPLES: Extensible Provider (multi-provider OCP)

End-to-end skeleton for the Open/Closed extensible-provider pattern. Two interchangeable provider SDKs (e.g. ad networks) sit behind a unified service-type BoardID. Adding a third provider requires NEW files only — zero edits to `ModulePlugin`, show-boards, or callers.

Companion spec: `EXTENSIBLE_PROVIDER.md`. Use with: `PER_ACTIVATION_RESOURCES.md` (per-activation lifecycle of the wrapped SDK service).

Placeholders: `{Feature}` = feature name (e.g. `Ads`), `{Module}` = module, `{TypeA}` / `{TypeB}` = service types (e.g. `Rewarded`, `Interstitial`), `{ProviderA}` / `{ProviderB}` = provider names (e.g. `Google`, `Meta`).

---

## 1. Layer 1 — public marker protocol

```swift
// {Module}Plugins/Sources/Plugins/{Feature}ProviderConfiguration.swift
import Boardy
import Foundation

// PUBLIC — the only type app-client code imports.
// Carries no behavior — pure type-safe token.
public protocol {Feature}ProviderConfiguration {}
```

---

## 2. Layer 2 — internal factory protocol

```swift
// same file
protocol Internal{Feature}ProviderConfiguration: {Feature}ProviderConfiguration {
    func setup()    // one-time SDK init; called once from launchSettings

    func make{TypeA}Board(
        identifier: BoardID,
        hostProvider: {Feature}HostProvider,
        producer: ActivatableBoardProducer
    ) -> any ActivatableBoard

    func make{TypeB}Board(
        identifier: BoardID,
        hostProvider: {Feature}HostProvider,
        producer: ActivatableBoardProducer
    ) -> any ActivatableBoard
}
```

> The factory protocol is `internal`. App clients can only see the marker; they cannot bypass the factory or instantiate provider boards directly.

---

## 3. Concrete provider configs (one file per provider)

```swift
// {Module}Plugins/Sources/Plugins/{ProviderA}ProviderConfiguration.swift
import {ProviderA}SDK            // ← SDK import isolated to THIS file
import Boardy

public struct {ProviderA}ProviderConfiguration: Internal{Feature}ProviderConfiguration {
    public let unitIDA: String
    public let unitIDB: String

    public init(unitIDA: String, unitIDB: String) {
        self.unitIDA = unitIDA
        self.unitIDB = unitIDB
    }

    func setup() {
        {ProviderA}SDK.initialize(/* … */)
    }

    func make{TypeA}Board(identifier: BoardID,
                          hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderA}{TypeA}ProviderBoard(
            identifier: identifier, unitID: unitIDA,
            hostProvider: hostProvider, producer: producer
        )
    }

    func make{TypeB}Board(identifier: BoardID,
                          hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderA}{TypeB}ProviderBoard(
            identifier: identifier, unitID: unitIDB,
            hostProvider: hostProvider, producer: producer
        )
    }
}
```

```swift
// {Module}Plugins/Sources/Plugins/{ProviderB}ProviderConfiguration.swift
import {ProviderB}SDK            // ← isolated SDK import
import Boardy

public struct {ProviderB}ProviderConfiguration: Internal{Feature}ProviderConfiguration {
    public let appID: String

    public init(appID: String) {
        self.appID = appID
    }

    func setup() {
        {ProviderB}SDK.start(appID: appID)
    }

    func make{TypeA}Board(identifier: BoardID,
                          hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderB}{TypeA}ProviderBoard(
            identifier: identifier, hostProvider: hostProvider, producer: producer
        )
    }

    func make{TypeB}Board(identifier: BoardID,
                          hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderB}{TypeB}ProviderBoard(
            identifier: identifier, hostProvider: hostProvider, producer: producer
        )
    }
}
```

> A `public struct` conforming to an `internal` protocol is fine — Swift allows it; the conformance is internal.

---

## 4. Unified BoardIDs (per service type, NOT per provider)

```swift
// {Module}/Sources/IOInterfaces/BoardID+{Module}.swift
import Boardy

public extension BoardID {
    // ✅ unified — provider is implementation detail
    static let mod{TypeA}Provider: BoardID = "mod.{Module}.{TypeA}Provider"
    static let mod{TypeB}Provider: BoardID = "mod.{Module}.{TypeB}Provider"
}
```

❌ Do NOT do `modProviderA{TypeA}` / `modProviderB{TypeA}` — grows quadratically, leaks provider identity to callers.

---

## 5. Service-type InOut (named alias, never raw Void)

```swift
// {Module}Plugins/Sources/Microboards/{TypeA}Provider/{TypeA}ProviderInOut.swift
import Foundation

typealias {TypeA}ProviderInput   = Void                 // ← alias lives HERE, not on the Board
typealias {TypeA}ProviderOutput  = {TypeA}ProviderResult
typealias {TypeA}ProviderCommand = Void

enum {TypeA}ProviderAction: BoardFlowAction {}

public enum {TypeA}ProviderResult {
    case loaded
    case rewarded(amount: Int)
    case failed(Error)
}
```

> Why named alias? `MainboardGenericDestination<{TypeA}ProviderInput, …>` must align with the Board's `typealias InputType = …`. Writing `typealias InputType = Void` directly breaks the alignment.

---

## 6. Provider Board — IDs baked in at `init`

```swift
// {Module}Plugins/Sources/Microboards/{ProviderA}{TypeA}Provider/{ProviderA}{TypeA}ProviderBoard.swift
import Boardy
import Foundation
import {ProviderA}SDK

final class {ProviderA}{TypeA}ProviderBoard: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType      = {TypeA}ProviderInput        // ✅ named alias, NEVER Void directly
    typealias OutputType     = {TypeA}ProviderOutput
    typealias FlowActionType = {TypeA}ProviderAction
    typealias CommandType    = {TypeA}ProviderCommand

    private let unitID: String                              // baked in by factory at init time
    private let hostProvider: {Feature}HostProvider

    init(identifier: BoardID, unitID: String,
         hostProvider: {Feature}HostProvider,
         producer: ActivatableBoardProducer) {
        self.unitID = unitID
        self.hostProvider = hostProvider
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: {TypeA}ProviderInput) {
        // Per-activation service construction + attachObject — see EXAMPLES_PER_ACTIVATION_RESOURCES.md
        let service = {ProviderA}{TypeA}Service(hostProvider: hostProvider)
        attachObject(service)
        service.run(unitID: unitID) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.sendOutput(result)
                self?.complete()
            }
        }
    }

    func activationBarrier(withGuaranteedInput _: {TypeA}ProviderInput) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: {TypeA}ProviderCommand) {}
}
```

> Callers know nothing about `unitID` or `{ProviderA}SDK` — they activate `.mod{TypeA}Provider` with `Void`.

---

## 7. ModulePlugin — factory dispatch (no switch on provider)

```swift
// {Module}Plugins/Sources/Plugins/{Feature}ModulePlugin.swift
import Boardy

public final class {Feature}ModulePlugin: ModulePlugin {
    public enum ServiceType: CaseIterable { case {typeA}, {typeB} }

    private let service: ServiceType
    private let providerConfiguration: {Feature}ProviderConfiguration
    private let hostProvider: {Feature}HostProvider

    init(service: ServiceType,
         providerConfiguration: {Feature}ProviderConfiguration,
         hostProvider: {Feature}HostProvider) {
        self.service = service
        self.providerConfiguration = providerConfiguration
        self.hostProvider = hostProvider
    }

    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        // swiftlint:disable:next force_cast
        let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration
        let host = hostProvider

        switch service {
        case .{typeA}:
            return [
                BoardRegistration(.mod{TypeA}Provider) { id in
                    internalConfig.make{TypeA}Board(identifier: id, hostProvider: host, producer: producer)
                }
            ]
        case .{typeB}:
            return [
                BoardRegistration(.mod{TypeB}Provider) { id in
                    internalConfig.make{TypeB}Board(identifier: id, hostProvider: host, producer: producer)
                }
            ]
        }
    }
}
```

> The `switch` is over `ServiceType` (closed set), NOT over provider (open set). Adding a new provider does not touch this file.

> Why `as!` and not `as?`? The factory protocol is `internal`; only the module's own concrete configs can conform. A wrong-type value at runtime is a programming error — crash loudly. `as?` + `return []` produces a baffling missing-registration crash later.

---

## 8. LauncherPlugin — public API + one-time setup

```swift
// {Module}Plugins/Sources/Plugins/{Feature}LauncherPlugin.swift
import Boardy

public struct {Feature}LauncherPlugin: LauncherPlugin {
    private let providerConfiguration: {Feature}ProviderConfiguration
    private let hostProvider: {Feature}HostProvider

    public init(providerConfiguration: {Feature}ProviderConfiguration) {
        self.providerConfiguration = providerConfiguration
        self.hostProvider = {Feature}DefaultHostProvider()
    }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        let host = hostProvider
        // swiftlint:disable:next force_cast
        let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration

        return ModuleComponent(
            modulePlugins: {Feature}ModulePlugin.ServiceType.allCases.map { service in
                {Feature}ModulePlugin(
                    service: service,
                    providerConfiguration: providerConfiguration,
                    hostProvider: host
                )
            },
            launchSettings: { _ in
                internalConfig.setup()                        // ← single call site for SDK init
            }
        )
    }
}
```

---

## 9. App-client call site (provider selection)

```swift
// App/AppDelegate.swift or composition root
PluginLauncher.with(options: .default)
    .install(launcherPlugin: {Feature}LauncherPlugin(
        providerConfiguration: {ProviderA}ProviderConfiguration(   // ← change THIS line to switch provider
            unitIDA: "id-a-xxx", unitIDB: "id-b-yyy"
        )
    ))
    .initialize()
```

Switching to provider B = swap one expression:

```swift
providerConfiguration: {ProviderB}ProviderConfiguration(appID: "appid-zzz")
```

Adding provider C = new files only:
1. New `{ProviderC}ProviderConfiguration.swift`
2. New `{ProviderC}{TypeA}ProviderBoard.swift` + `{ProviderC}{TypeB}ProviderBoard.swift`
3. Change the one line at the call site.

No edits to `ModulePlugin`, `LauncherPlugin`, IO interfaces, callers, or other providers.

---

## Direction matrix

| Direction | Mechanism |
|---|---|
| Caller → activates service | `motherboard.serviceMap.mod{Module}.io{TypeA}Provider.activation.activate()` (unified ID) |
| ModulePlugin → resolves to concrete Board | Factory dispatch via `internalConfig.make{Type}Board(...)` |
| LauncherPlugin → initializes SDK | `internalConfig.setup()` inside `launchSettings: { _ in … }` |
| Provider Board → receives IDs | At `init(...)` via factory closure (NOT at `activate(...)`) |
| App client → selects provider | One line at composition root: pass concrete `{ProviderX}ProviderConfiguration` |
| Adding new provider | NEW files only — zero edits to existing |

## Pitfalls

- ❌ Public `enum {Feature}ProviderConfiguration { case providerA, providerB }` → every `switch` site updates on each new provider. Use marker protocol.
- ❌ `modProviderA{TypeA}` BoardIDs → grows quadratically, leaks provider identity to callers. Unified IDs only.
- ❌ `typealias InputType = Void` directly on the Board → breaks `MainboardGenericDestination<…>` contract. Always use named alias.
- ❌ `setup()` called inside `internalContinuousRegistrations` → may run multiple times. Belongs in `launchSettings: { _ in … }`.
- ❌ Storing SDK IDs on the Board at `activate(...)` time → callers would need to know provider details. Bake into `init` via factory.
- ❌ `guard let internalConfig = ... as? ... else { return [] }` → silently registers nothing on wrong type. Use `as!`; wrong type is a bug.
- ❌ Importing `{ProviderA}SDK` outside the concrete config or provider Board files → defeats isolation point of the pattern.
- ❌ Caller activating a provider-specific BoardID → defeats unification. `.mod{TypeA}Provider` only.

## References

- `EXTENSIBLE_PROVIDER.md` (full spec)
- `PER_ACTIVATION_RESOURCES.md` (per-activation SDK service lifecycle — Section 6 above uses this pattern)
- `EXAMPLES_PER_ACTIVATION_RESOURCES.md` (per-activation example file)
- `PLUGINS_INTEGRATION.md` (regular LauncherPlugin / ModulePlugin shape)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
