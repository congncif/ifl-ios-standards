<!-- Created by sonnet on 2026-05-14 -->
<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Extensible Provider Architecture (OCP Pattern)

> Reference: Open/Closed Principle applied to Boardy+VIP plugin composition.
> Companion specs: `PER_ACTIVATION_RESOURCES.md` (per-activation lifecycle), `PLUGINS_INTEGRATION.md` (plugin wiring), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When a module must integrate multiple **interchangeable** external providers/frameworks (ad SDKs, payment gateways, analytics backends, map SDKs, auth frameworks) and:

- Adding a new provider should require **new files only** — no edits to `ModulePlugin`, show-boards, controllers, or callers.
- Each provider carries its own SDK-specific IDs / setup code, which must stay isolated from the rest of the module.
- The active provider is decided at app launch (passed via `LauncherPlugin.init`) and may switch by changing one call-site line.

## When NOT to use

- Only one provider exists, no second is planned → just inject directly via the existing `ModulePlugin`; don't pre-build OCP scaffolding speculatively.
- Provider switches at runtime per user action → keep OCP scaffolding for initial config but add a `Command` to the show-boards (or re-activate the module with a new config). See `COMMUNICATION.md` Command direction.
- Provider variations differ only by configuration values (not by SDK / behavior) → a single `*Configuration` struct with optional fields is simpler than two protocol layers.
- Module without external SDK at all → no OCP, no factory, just regular Boards.

## Forces

- Storing provider selection as a `public enum` (`.providerA`, `.providerB`) forces every `switch` site to update when a new case appears — violates OCP and tightly couples coordination logic to provider identity.
- Two-layer protocol pattern hides the factory behind an internal protocol, so external callers see only a marker; internal `ModulePlugin` resolves to factory methods. Cost: a force-cast (`as!`) in two spots, which is intentional — a non-conforming type would be a programming error.
- Provider boards take **all IDs at `init`** (factory-baked), not at `activate()`, so callers don't need to know provider specifics. The named `typealias {Type}ProviderInput = Void` keeps the `MainboardGenericDestination` contract intact while keeping the Board's runtime input empty.
- Unified `BoardID` per service type (e.g. `.modInterstitialAdProvider`) means show-boards activate one ID; the ModulePlugin decides which concrete provider sits behind it.

## Files

```
{Module}Plugins/Sources/Plugins/
├── {Feature}ProviderConfiguration.swift          ← public marker + internal factory protocols
├── {ProviderA}ProviderConfiguration.swift         ← public struct, internal factory conformance
├── {ProviderB}ProviderConfiguration.swift         ← public struct, internal factory conformance
└── {Feature}ModulePlugin.swift                    ← casts to internal factory, factory dispatch

{Module}Plugins/Sources/Microboards/
├── {TypeA}Provider/
│   ├── {TypeA}ProviderIOInterface.swift           ← unified BoardID + MainDestination
│   ├── {TypeA}ProviderInOut.swift                 ← typealias {TypeA}ProviderInput = Void
│   └── ServiceMap+{TypeA}Provider.swift
├── {TypeB}Provider/                              ← same structure
├── {ProviderA}{TypeA}Provider/{ProviderA}{TypeA}ProviderBoard.swift
├── {ProviderA}{TypeB}Provider/{ProviderA}{TypeB}ProviderBoard.swift
├── {ProviderB}{TypeA}Provider/{ProviderB}{TypeA}ProviderBoard.swift
└── {ProviderB}{TypeB}Provider/{ProviderB}{TypeB}ProviderBoard.swift
```

IO pod exposes nothing about specific providers — only unified service-type IOInterfaces.

### Why provider configurations live in `Sources/Plugins/`, not `IO/`

Provider configurations are **construction wiring**, not domain meaning. The Interface module exposes what the module DOES (board activations); it does NOT expose HOW the module is wired at App boot. The configuration is only ever passed to `{Feature}LauncherPlugin.init(providerConfiguration:)` — a registration-time concern that sits next to the LauncherPlugin itself.

Although the marker protocol and concrete config structs are `public` (the App must construct them), they belong under `Sources/Plugins/` — the pack's public-export zone for LauncherPlugin construction inputs. The `io_visibility` lint allows `public` symbols under `Sources/Plugins/**` for exactly this reason. See `IO_INTERFACE.md` §"Domain meaning vs construction wiring".

Self-test: "Does a client module call this to USE the feature, or does App call this to BOOT the feature?"
- IO/: `motherboard.io{Feature}.show(...)` → USE → domain
- Sources/Plugins/: `{Feature}LauncherPlugin(providerConfiguration: AdMobProviderConfiguration(...))` → BOOT → construction

## Naming

- Public marker protocol: `{Feature}ProviderConfiguration` (no methods).
- Internal factory protocol: `Internal{Feature}ProviderConfiguration: {Feature}ProviderConfiguration`.
- Concrete config: `public struct {ProviderX}ProviderConfiguration: Internal{Feature}ProviderConfiguration`.
- Unified service BoardID: `mod{TypeA}Provider`, `mod{TypeB}Provider` (NOT `modProviderA{TypeA}`).
- Concrete board: `{ProviderX}{TypeA}ProviderBoard`.
- Service-type input/output aliases: `{TypeA}ProviderInput = Void`, `{TypeA}ProviderOutput = Provider{TypeA}Result`.

## Communication

### Layer 1 — public marker protocol

```swift
// Sources/Plugins/{Feature}ProviderConfiguration.swift
public protocol {Feature}ProviderConfiguration {}
```

The only type the app client imports. Carries no behavior — a type-safe token.

### Layer 2 — internal factory protocol

```swift
// same file
protocol Internal{Feature}ProviderConfiguration: {Feature}ProviderConfiguration {
    func setup()   // one-time SDK init, called from launchSettings

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

### Concrete provider config

```swift
// Sources/Plugins/{ProviderName}ProviderConfiguration.swift
import {ProviderSDK}   // SDK import isolated here

public struct {ProviderName}ProviderConfiguration: Internal{Feature}ProviderConfiguration {
    public let adUnitID: String
    public let rewardUnitID: String

    public init(adUnitID: String, rewardUnitID: String) {
        self.adUnitID = adUnitID; self.rewardUnitID = rewardUnitID
    }

    func setup() { {ProviderSDK}.initialize(...) }

    func make{TypeA}Board(identifier: BoardID, hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderName}{TypeA}Board(identifier: identifier, unitID: adUnitID,
                                   hostProvider: hostProvider, producer: producer)
    }

    func make{TypeB}Board(identifier: BoardID, hostProvider: {Feature}HostProvider,
                          producer: ActivatableBoardProducer) -> any ActivatableBoard {
        {ProviderName}{TypeB}Board(identifier: identifier, unitID: rewardUnitID,
                                   hostProvider: hostProvider, producer: producer)
    }
}
```

A `public struct` can conform to an `internal` protocol — Swift permits this; the conformance itself is internal.

### Provider Board — IDs baked in, named-alias input

```swift
// {Type}ProviderInOut.swift  ← alias HERE, not on the Board
typealias {Type}ProviderInput = Void
typealias {Type}ProviderOutput = Provider{Type}Result
typealias {Type}ProviderCommand = Void
enum {Type}ProviderAction: BoardFlowAction {}
```

```swift
// {Provider}{Type}ProviderBoard.swift
final class {Provider}{Type}ProviderBoard: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Type}ProviderInput     // ✅ named alias, NEVER Void directly
    typealias OutputType = {Type}ProviderOutput
    typealias FlowActionType = {Type}ProviderAction
    typealias CommandType    = {Type}ProviderCommand

    private let unitID: String
    private let hostProvider: {Feature}HostProvider

    init(identifier: BoardID, unitID: String,
         hostProvider: {Feature}HostProvider, producer: ActivatableBoardProducer) {
        self.unitID = unitID; self.hostProvider = hostProvider
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: {Type}ProviderInput) {
        let service = {Provider}{Type}Service(hostProvider: hostProvider)
        attachObject(service)
        service.run(unitID: unitID) { [weak self] result in
            self?.sendOutput(result); self?.complete()
        }
    }

    func activationBarrier(withGuaranteedInput _: {Type}ProviderInput) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: {Type}ProviderCommand) {}
}
```

Why named alias and not `typealias InputType = Void`? Because `MainboardGenericDestination<{Type}ProviderInput, ...>` in the IOInterface MUST match the Board's `InputType`. Referencing the alias keeps the contract aligned even when `Void` is the effective payload.

### Unified BoardIDs

```swift
// ✅ unified — provider is implementation detail
extension BoardID {
    static let mod{TypeA}Provider: BoardID = "mod.{Module}.{TypeA}Provider"
    static let mod{TypeB}Provider: BoardID = "mod.{Module}.{TypeB}Provider"
}

// ❌ provider-per-id — grows quadratically
extension BoardID {
    static let modProviderA{TypeA}: BoardID = ...
    static let modProviderA{TypeB}: BoardID = ...
    static let modProviderB{TypeA}: BoardID = ...
}
```

### `ModulePlugin` — factory dispatch (no switch)

```swift
func internalContinuousRegistrations(
    sharedComponent: any SharedValueComponent,
    producer: any ActivatableBoardProducer
) -> [BoardRegistration] {
    // swiftlint:disable:next force_cast
    let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration

    BoardRegistration(.mod{TypeA}Provider) { [hostProvider] id in
        internalConfig.make{TypeA}Board(identifier: id, hostProvider: hostProvider, producer: producer)
    }
    BoardRegistration(.mod{TypeB}Provider) { [hostProvider] id in
        internalConfig.make{TypeB}Board(identifier: id, hostProvider: hostProvider, producer: producer)
    }
}
```

Why `as!`? The internal protocol is `internal`; only module-provided concrete structs conform. A wrong-type value at runtime is a programming error — crash loudly; do not silently `return []`.

### `LauncherPlugin` — public API

```swift
public struct {Feature}LauncherPlugin: LauncherPlugin {
    private let providerConfiguration: {Feature}ProviderConfiguration
    private let hostProvider: {Feature}HostProvider

    public init(providerConfiguration: {Feature}ProviderConfiguration /*, …*/) {
        self.providerConfiguration = providerConfiguration
        self.hostProvider = {Feature}DefaultHostProvider()
    }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        let hostProvider = self.hostProvider
        // swiftlint:disable:next force_cast
        let internalConfig = providerConfiguration as! Internal{Feature}ProviderConfiguration
        return ModuleComponent(
            modulePlugins: {Feature}ModulePlugin.ServiceType.allCases.map {
                {Feature}ModulePlugin(service: $0, providerConfiguration: providerConfiguration,
                                      hostProvider: hostProvider)
            },
            launchSettings: { _ in internalConfig.setup() }
        )
    }
}
```

App-client call site:

```swift
PluginLauncher.with(options: .default)
    .install(launcherPlugin: {Feature}LauncherPlugin(
        providerConfiguration: {ProviderA}ProviderConfiguration(
            adUnitID: "ca-app-pub-xxx", rewardUnitID: "ca-app-pub-yyy"
        )
    ))
    .initialize()
```

Switching providers = change the concrete config struct at the call site — nothing else.

### Decision tree

```
Need interchangeable external providers/frameworks?
├── Decided at app launch / compile time → Two-Layer Protocol Pattern (this spec)
└── Switches at runtime (user picks)     → keep two-layer for init,
                                            add Command on provider boards OR re-activate module

Provider has SDK-specific IDs?
├── YES → bake into board init params; InOut typealias Input = Void
└── NO  → same pattern, fewer fields

Provider boards share Input/Output contract?
├── YES → unified BoardIDs (per service type)
└── NO  → split service types, each with their own unified ID
```

## Concurrency

- `setup()` runs once in `launchSettings: { _ in ... }` on the main thread during `PluginLauncher.initialize()`.
- Provider Board `activate(withGuaranteedInput:)` runs on main; the wrapped SDK service may dispatch callbacks on any thread — wrap in `await MainActor.run { ... }` before `sendOutput` + `complete()` (see `PER_ACTIVATION_RESOURCES.md`).
- `as!` cast happens once per `ModulePlugin` instance creation; cost is negligible. The cast is NOT thread-sensitive.
- `hostProvider` captured by value (struct stored property) into each `BoardRegistration` closure; safe to share across activations.

## Composition

```
App client
   └ {Feature}LauncherPlugin(providerConfiguration: {ProviderA}ProviderConfiguration(...))
        │
        └ prepareForLaunching → ModuleComponent
             ├ modulePlugins: ServiceType.allCases.map { {Feature}ModulePlugin(...) }
             │    └ internalContinuousRegistrations (as! Internal…) → factory.make…Board(...)
             │           └ {ProviderA}{Type}ProviderBoard (unitID baked in at init)
             └ launchSettings: { _ in internalConfig.setup() }
```

Composes with `PLUGINS_INTEGRATION.md` (regular LauncherPlugin shape) and `CROSS_MODULE_DI.md` (if the unified service-type IOInterface is consumed cross-module).

## Lifecycle

- `setup()` — once per app launch; SDKs initialized exactly once.
- `ModulePlugin` instances — app lifetime (one per `ServiceType` case).
- Provider config struct — app lifetime; immutable value type.
- Provider Board instances — per activation; `complete()` releases the Board and attached SDK service.
- `attachObject(service)` ties SDK delegate lifetime to the Board; `complete()` after the SDK callback fires.
- Switching providers requires app relaunch (the config is constructor-injected). For mid-session switching, see decision tree (Command pattern + re-activation).

## Testing

- Internal factory: test each concrete `{ProviderX}ProviderConfiguration.make{Type}Board` returns a Board with expected `BoardID` and `unitID`.
- `ModulePlugin`: pass a fake `Internal{Feature}ProviderConfiguration` (test-internal struct); assert factory methods invoked with the unified BoardIDs.
- Provider Board: standard Board test surface — assert `activate` produces a service that emits `sendOutput` + `complete()` after callback.
- LauncherPlugin: assert `setup()` runs exactly once when `prepareForLaunching` is invoked; assert `modulePlugins.count == ServiceType.allCases.count`.
- Force cast: write a negative test that constructs an outside `public struct: {Feature}ProviderConfiguration` (without internal conformance) and asserts the `as!` traps — documents the contract.

## Pitfalls

- ❌ Public `enum {Feature}ProviderConfiguration` in IO → every new provider edits the enum and every switch. Use the marker protocol.
- ❌ Provider-specific BoardIDs (`modProviderA{TypeA}`) → grows quadratically and leaks provider identity. Use unified IDs.
- ❌ `typealias InputType = Void` directly on the Board → breaks alignment with `MainboardGenericDestination<…InputType…>`. Always go through the named `{Type}ProviderInput` alias.
- ❌ `setup()` called inside `internalContinuousRegistrations` → may run multiple times. It belongs in `launchSettings: { _ in ... }`.
- ❌ Storing SDK identifiers on the Board at `activate(...)` time → callers would need to know provider details. Bake IDs into `init` via the factory.
- ❌ `guard let internalConfig = ... as? ... else { return [] }` → silently registers nothing on a wrong type; produces a baffling missing-registration crash. Use `as!`; a wrong-type value is a bug.
- ❌ Importing SDK headers (`import GoogleMobileAds`) from outside the concrete config or provider Board → the isolation point of the pattern. Imports stay in the provider files.
- ❌ Caller activating a provider-specific BoardID → defeats unification. Activate `.mod{Type}Provider` only.

## References

- `PER_ACTIVATION_RESOURCES.md` (`attachObject` + guard placement for per-activation SDK services)
- `PLUGINS_INTEGRATION.md` (regular ModulePlugin / LauncherPlugin shape)
- `IO_INTERFACE.md` (unified service-type IOInterface)
- `CROSS_MODULE_DI.md` (sharing the unified service-type IOInterface across modules)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 1, 4, 8
