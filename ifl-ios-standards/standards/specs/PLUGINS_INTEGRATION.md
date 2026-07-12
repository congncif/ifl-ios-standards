<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Plugins & Global Integration

> Reference: *Modern large-scale iOS app development* — Plugin Architecture pillar.
> Companion specs: `ARCHITECTURE.md` §4 (runtime composition), `MODULE_CREATION.md` (module bootstrap), `IO_INTERFACE.md` (public IO shape), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When adding a new feature module to the app, or extending one with:

- A new public entry board (new `ServiceType` case in `ModulePlugin`).
- A new deep link / URL pattern (`URLOpenerPlugin`).
- New internal child boards that the module exposes through `internalContinuousRegistrations`.
- Wiring an existing module into the App Core via `ServiceRegistry`.

## When NOT to use

- Adding internal-only Boards that already have an existing `ModulePlugin` — just append a `BoardRegistration`; no plugin scaffolding needed.
- Cross-module service sharing — that goes through `CROSS_MODULE_DI.md` (Pattern A Boardy Board interface or Pattern B Resolver), not by adding another `LauncherPlugin`.
- Pure UI utility module (no Boardy entry, no deep links) — exposed by a regular pod with `public` API, no LauncherPlugin needed.

## Forces

- `URLOpenerPlugin` activates via `mod{Module}Plugins` (internal ServiceMap), not the IO ServiceMap — because the opener lives in `Sources/`. Forgetting this triggers a missing-registration crash.
- `ServiceType.allCases.map { ModulePlugin(service: $0) }` is the only sanctioned way to map public entry boards. Manual lists drift when a new case appears.
- Shared dependencies (`sharedRepository`, `sharedTracker`) live as **stored properties** on the plugin struct so they're one instance across all `BoardRegistration` closures. Locals inside the function create N copies.
- `internalContinuousRegistrations` uses the result builder; explicit `return [ ... ]` works but loses the syntactic guarantee that each entry is a `BoardRegistration` and not stray code.

## Files

```
{Module}Plugins/Sources/Plugins/
├── {Module}ModulePlugin.swift                     ← ServiceType enum + ModuleBuilderPlugin (internal)
├── {Module}URLOpenerPlugin.swift                  ← deep link handler (internal, optional)
├── {Module}LauncherPlugin.swift                   ← public LauncherPlugin export
└── {Module}{Feature}ProviderConfiguration.swift   ← public LauncherPlugin init args (optional)
```

`Sources/Plugins/**` is the pack's **narrow public-export zone** (`CORE-API-001`): LauncherPlugin and
only the construction wiring the App must pass at boot (provider configurations and init options)
may be public. Everything else under `Sources/` (Microboards, Services, Domain, and unrelated Plugin
helpers) stays internal. This exception does not permit feature-to-feature imports of another
`{Module}Plugins` target (`CORE-COMP-001`). See `IO_INTERFACE.md` §"Domain meaning vs construction wiring".

App Core:

```
App/
└── ServiceRegistry+Modules.swift  ← registers every LauncherPlugin
```

Internal BoardID declarations live with the Board:

```
{Module}Plugins/Sources/Microboards/{Board}/{Board}IOInterface.swift
```

NOT in `IO/`, NEVER `public`.

## Naming

- `{Module}ModulePlugin: ModuleBuilderPlugin` — internal struct.
- `enum ServiceType: CaseIterable` — one case per public entry board; case `default` for the primary.
- `{Module}URLOpenerPlugin: URLOpenerPathMatchingPlugin` — internal struct.
- `{Module}LauncherPlugin: LauncherPlugin` — **public** struct with `public init()`.
- Internal BoardID: `mod{Board}: BoardID = "mod.{Module}.{Board}"`.
- Public BoardID: `pub{PublicBoard}: BoardID = "pub.mod.{Module}.{PublicBoard}"` (in IO pod, see `IO_INTERFACE.md`).

## Communication

### `ModulePlugin` — ServiceType + build + registrations

```swift
import Boardy
import Foundation
import {Module}

struct {Module}ModulePlugin: ModuleBuilderPlugin {

    enum ServiceType: CaseIterable {
        case `default`
        // case secondaryBoard

        var identifier: BoardID {
            switch self {
            case .default: .pub{PublicBoard}
            }
        }
    }

    // Shared deps — stored properties → single instance per ModulePlugin instance
    let sharedRepository = {SomeRepository}()
    let sharedTracker = {TrackerService}()

    let service: ServiceType
    var identifier: BoardID { service.identifier }

    func build(
        with identifier: BoardID,
        sharedComponent: any SharedValueComponent,
        internalContinuousProducer: any ActivatableBoardProducer
    ) -> any ActivatableBoard {
        switch service {
        case .default:
            {EntryCoordinator}Board(identifier: identifier, producer: internalContinuousProducer)
        }
    }

    func internalContinuousRegistrations(
        sharedComponent: any SharedValueComponent,
        producer: any ActivatableBoardProducer
    ) -> [BoardRegistration] {
        BoardRegistration(.mod{InternalA}) { id in
            {InternalA}Board(
                identifier: id,
                builder: {InternalA}Builder(repository: sharedRepository, tracker: sharedTracker),
                producer: producer
            )
        }
        BoardRegistration(.mod{InternalB}) { id in
            {InternalB}Board(
                identifier: id,
                builder: {InternalB}Builder(tracker: sharedTracker),
                producer: producer
            )
        }
        BoardRegistration(.mod{InternalC}) { id in
            {InternalC}Board(
                identifier: id,
                builder: {InternalC}Builder(repository: sharedRepository, tracker: sharedTracker),
                producer: producer
            )
        }
    }
}
```

Result-builder syntax — no `return`, no `[ ... ]`:

```swift
// ✅ correct
func internalContinuousRegistrations(...) -> [BoardRegistration] {
    BoardRegistration(.modA) { id in A(identifier: id, ...) }
    BoardRegistration(.modB) { id in B(identifier: id, ...) }
}

// ❌ wrong (works, but loses the result-builder guarantee)
func internalContinuousRegistrations(...) -> [BoardRegistration] {
    return [ BoardRegistration(...), BoardRegistration(...) ]
}
```

Registration shape patterns:

```swift
// Coordinator (no Builder)
BoardRegistration(.modCoordinator) { id in
    CoordinatorBoard(identifier: id, producer: producer)
}

// UI / Viewless board (Builder injects shared deps)
BoardRegistration(.modScreen) { id in
    ScreenBoard(
        identifier: id,
        builder: ScreenBuilder(repository: sharedRepository, tracker: sharedTracker),
        producer: producer
    )
}

// BlockTask factory
BoardRegistration(.modTask) { id in
    {Task}BoardFactory.make(identifier: id /*, deps */)
}
```

### `URLOpenerPlugin` — deep link handler

```swift
struct {Module}URLOpenerPlugin: URLOpenerPathMatchingPlugin {
    var matchingPath: String { "/{module-path}" }

    func mainboard(_ mainboard: any FlowMotherboard, openURLWithParameters parameters: [String: String]) {
        let input = {PublicBoard}Input(completion: nil /* parse from parameters */)
        mainboard.serviceMap.mod{Module}Plugins                  // ← Plugins ServiceMap, NOT IO
            .io{EntryCoordinator}.activation.activate(with: input)
    }
}
```

### `LauncherPlugin` — public export

```swift
public struct {Module}LauncherPlugin: LauncherPlugin {
    public init() { /**/ }

    public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
        ModuleComponent(
            modulePlugins: {Module}ModulePlugin.ServiceType.allCases.map {
                {Module}ModulePlugin(service: $0)
            },
            urlOpenerPlugins: [ {Module}URLOpenerPlugin() ]
        )
    }
}
```

For `launchSettings:` (Resolver DI registration), see `CROSS_MODULE_DI.md` Pattern B.

### App Core registration

```swift
extension ServiceRegistry {
    static func registerAllModules() -> ServiceRegistry {
        ServiceRegistry {
            {Module}LauncherPlugin()
            OtherModuleLauncherPlugin()
        }
    }
}
```

## Concurrency

- Plugin code runs on the main thread during `PluginLauncher.initialize()` / `.launch()`.
- `internalContinuousRegistrations` produces *closures* — those closures execute later when a Board is activated; they may run on any thread the activation chain hops through. Capture shared deps by value (struct stored property) or `[hostProvider]` capture lists, not by reference to mutable state.
- `URLOpenerPlugin.mainboard(_:openURLWithParameters:)` runs on main; the activation it triggers follows Boardy's normal concurrency rules.

## Composition

```
App Core (ServiceRegistry)
    │
    └── registers ──► {Module}LauncherPlugin (public)
                          │
                  ┌───────┴───────┐
                  ▼               ▼
         {Module}ModulePlugin  {Module}URLOpenerPlugin
              │
         ServiceType.allCases  → one plugin instance per case
```

Cross-module sharing — see `CROSS_MODULE_DI.md`. The plugin scaffolding here is internal to the module; cross-module activation goes through the IO pod's `MainboardGenericDestination`.

Module-level extensions:
- Multiple `LauncherPlugin`s in `ServiceRegistry` compose freely; ordering matters only for `launchSettings:` side-effects (e.g. Resolver registration before resolution).
- A single module can ship more than one `LauncherPlugin` (rare — typically when one feature wraps two unrelated entry surfaces).

## Lifecycle

- `LauncherPlugin.prepareForLaunching(...)` runs once at app boot, returning a `ModuleComponent`.
- Each `ModulePlugin` instance (one per `ServiceType` case) lives for the app's lifetime.
- `internalContinuousRegistrations` runs once; the produced closures are reused on every Board activation matching that `BoardID`.
- `URLOpenerPlugin` instances live for the app's lifetime; `mainboard(_:openURLWithParameters:)` is called per inbound URL.
- Stored shared deps (`sharedRepository`, `sharedTracker`) live for the app's lifetime — singletons by convention.
- No `complete()` semantics at the plugin level; lifecycle is handled per-Board (see `COMMUNICATION.md` Lifecycle).

## Access modifier table

| Element | Access | Reason |
|---|---|---|
| `{Module}LauncherPlugin` struct | `public` | called from App Core |
| `{Module}LauncherPlugin.init` | `public` | instantiated externally |
| `{Module}ModulePlugin` struct | `internal` | only used by LauncherPlugin |
| `ServiceType` enum | `internal` | nested in ModulePlugin |
| `{Module}URLOpenerPlugin` struct | `internal` | only used by LauncherPlugin |
| `sharedRepository`, `sharedTracker` | `internal` | plugin-level shared deps |
| `mod{Internal}` BoardID | `internal` | implementation detail |

Public construction types in `Sources/Plugins/**` are justified individually by an App boot call
site. A type used only by ModulePlugin, a Board, a service, or another feature remains internal.

## Testing

- `ModulePlugin` integration: instantiate, call `internalContinuousRegistrations`, assert the produced `BoardRegistration` array contains expected IDs.
- `URLOpenerPlugin`: spin a fake `FlowMotherboard`; assert the activation hits the expected `BoardID` with parsed parameters.
- `LauncherPlugin.prepareForLaunching`: assert `modulePlugins.count == ServiceType.allCases.count` and `urlOpenerPlugins` contains expected entries.
- Shared dep wiring: assert the same `sharedRepository` instance is captured by multiple `BoardRegistration` closures (identity check).
- App Core: smoke test that `ServiceRegistry.registerAllModules()` returns a registry containing every expected `LauncherPlugin`.

## Pitfalls

- ❌ `URLOpenerPlugin` activating via `mod{Module}` (public ServiceMap) → no registration; crashes. Always `mod{Module}Plugins`.
- ❌ Shared deps as locals inside `internalContinuousRegistrations` → new instance per call; breaks shared-state assumptions.
- ❌ `return [ BoardRegistration(...) ]` style → works but skips the result builder; reviewer can't enforce shape.
- ❌ Missing `ServiceType.allCases.map { ... }` in `LauncherPlugin` → only one entry board registers even when there are multiple cases.
- ❌ `LauncherPlugin` left `internal` or with `internal init` → App Core can't construct it; compile error from the wrong layer.
- ❌ Internal BoardID declared in IO pod → leaks an internal name to consumers; declare it next to the Board in `Sources/Microboards/`.
- ❌ Mutating shared dep from inside a `BoardRegistration` closure → closures may run on any thread; treat shared deps as effectively immutable or thread-safe.
- ❌ Reaching across modules by importing another module's `ModulePlugin` → forbidden; use `CROSS_MODULE_DI.md`.

## References

- `ARCHITECTURE.md` (runtime composition)
- `MODULE_CREATION.md` (creating a new module)
- `IO_INTERFACE.md` (public IO pod the LauncherPlugin exposes)
- `CROSS_MODULE_DI.md` (cross-module wiring through IO or Resolver)
- `EXTENSIBLE_PROVIDER.md` (provider-pluggable variant of ModulePlugin)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 1, 2, 3, 4
