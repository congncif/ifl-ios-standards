<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Cross-Module Service Sharing

> Reference: *Modern large-scale iOS app development* — Module + Resolver pillars.
> Companion specs: `LAYERING.md` (3-layer rule), `PLUGINS_INTEGRATION.md` (plugin registration), `IO_INTERFACE.md` (public IO shape), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When a service (UseCase / Repository / domain operation) implemented in one feature module must be consumed by code in **another** feature module. Two sanctioned patterns:

- **Pattern A — Boardy Board Interface** (default, preferred): owner wraps the service in a `BlockTaskBoard`; client activates it through `motherboard.serviceMap`.
- **Pattern B — Resolver DI** (secondary): owner registers a protocol in Resolver; client injects via `@LazyInjected` local var. Reserve for stateless utilities or when the team explicitly chooses DI.

## When NOT to use

- Service consumed inside a single module → keep internal; inject as stored property on the `ModulePlugin`. No IO shell needed.
- Library / pure utility module (no business logic) → can be imported directly by any module; exempt from the no-Plugins-dep rule.
- View-Interactor-Presenter wiring inside one Board → not a cross-module concern; see `VIP_COMPONENTS.md`.
- One-off async work for a single Board → `BlockTaskBoard` locally, no IO export.

## Forces

- **Core rule** (`CORE-COMP-001`, `CORE-API-001`): never make `{Client}Plugins` depend on
  `{Owner}Plugins`. Feature implementation pods are leaves from another feature's perspective.
  Cross-module sharing always goes through either (a) the public IO pod, or (b) a `{Feature}Core`
  protocol pod plus Resolver. The public LauncherPlugin construction surface in
  `Sources/Plugins/**` is for App boot only; it is not a feature dependency escape hatch.
- Pattern A is Boardy-native — observability, lifecycle, `complete()` semantics are uniform. Cost: one `BlockTaskBoard` + IO files per shared service.
- Pattern B is leaner per call site but introduces a second DI mechanism. `@LazyInjected` MUST be a local var inside `internalContinuousRegistrations` — stored on a `struct` plugin it mutates and resolves before `launchSettings` runs.
- Putting a service in `sharedComponent` and reaching across modules to read it = forbidden; that channel is for owner-internal sharing only.

## Files

### Pattern A — owner side

```
{Feature}/IO/{Service}/                          (public)
├── {Service}IOInterface.swift   ← pub{Service} BoardID + MainDestination + MotherboardType ext
├── {Service}InOut.swift         ← public Input / Output / Command / Action
└── ServiceMap+{Service}.swift   ← {Feature}ServiceMap.io{Service}

{Feature}Plugins/Sources/Microboards/{Service}/  (internal)
└── {Service}Board.swift         ← BlockTaskBoard or VIP, calls UseCaseInteractor

{Feature}Plugins/Sources/Plugins/
└── {Feature}ModulePlugin.swift  ← registers .mod{Service} in internalContinuousRegistrations
```

### Pattern A — client side

```
{Client}Plugins/Sources/Microboards/{Client}Flow/
└── {Client}FlowBoard.swift      ← registerFlows() activates motherboard.serviceMap.mod{Feature}.io{Service}
{Client}Plugins.podspec          ← s.dependency '{Feature}'  (IO pod only, NEVER '{Feature}Plugins')
```

### Pattern B

```
{Feature}Core/                        (new pure-protocol pod)
├── {Feature}Core.podspec             ← source_files = 'Core/**/*.swift', no deps
└── Core/{Action}UseCase.swift        ← public protocol only

{Feature}Plugins/Sources/Plugins/
├── Resolver+{Feature}Services.swift  ← Resolver.register{Feature}Services()
└── {Feature}LauncherPlugin.swift     ← launchSettings: { _ in Resolver.register…() }

{Client}Plugins/Sources/Plugins/
└── {Client}ModulePlugin.swift        ← @LazyInjected var (local), inside func
```

## Naming

- Service Board: `{Service}Board` in `{Feature}Plugins/Sources/Microboards/{Service}/`.
- Public BoardID: `pub{Service}: BoardID = "pub.mod.{Feature}.{Service}"`.
- Public destination: `{Service}MainDestination`.
- ServiceMap entry: `io{Service}` on `{Feature}ServiceMap` (Pattern A).
- Core pod: `{Feature}Core`; protocol: `{Action}UseCase`; implementation: `{Action}UseCaseInteractor`.

## Communication

### Pattern A — service Board (owner)

```swift
final class {Service}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    typealias InputType  = {Service}Input
    typealias OutputType = {Service}Output
    typealias FlowActionType = {Service}Action
    typealias CommandType = {Service}Command

    private let useCase: {Service}UseCaseType   // internal protocol

    init(identifier: BoardID, useCase: {Service}UseCaseType, producer: ActivatableBoardProducer) {
        self.useCase = useCase
        super.init(identifier: identifier, boardProducer: producer)
    }

    func activate(withGuaranteedInput input: InputType) {
        Task { [weak self] in
            let result = await self?.useCase.execute(input)
            await MainActor.run { [weak self] in
                guard let result else { return }
                self?.sendOutput(result)
                self?.complete()
            }
        }
    }

    func activationBarrier(withGuaranteedInput _: InputType) -> ActivationBarrier? { nil }
    func interact(guaranteedCommand _: CommandType) {}
}
```

Public IO shells follow `IO_INTERFACE.md` — `pub{Service}`, `MainDestination`, `ServiceMap+`.

Owner `ModulePlugin.internalContinuousRegistrations`:

```swift
BoardRegistration(.mod{Service}) { [self] id in
    {Service}Board(
        identifier: id,
        useCase: {Service}UseCaseInteractor(repository: sharedRepository),
        producer: producer
    )
}
```

### Pattern A — client activation (two options)

**Option A — FlowBoard activates directly** (FlowBoard owns the decision):

```swift
extension {Client}FlowBoard: {Client}FlowDelegate {
    func perform{Service}(value: SomeType) {
        motherboard.serviceMap.mod{Feature}
            .io{Service}.activation
            .activate(with: {Service}Input(value: value))
    }
}

private extension {Client}FlowBoard {
    func registerFlows() {
        motherboard.serviceMap.mod{Feature}
            .io{Service}.flow.addTarget(self) { target, output in
                switch output {
                case .success: target.serviceDidCompleteBus.transport()
                case .failure: break
                }
            }
    }
}
```

**Option B — VIP Interactor signals via FlowAction** (Interactor must trigger, but cannot import owner):

```swift
// {Client}ResultInOut.swift
public enum {Client}ResultAction: BoardFlowAction {
    case perform{Service}(value: SomeType)
}

// Interactor — zero owner imports, signals intent only
func userDidLoadResult(input: {Client}ResultInput) {
    delegate?.perform{Service}(value: input.value)   // via Controllable
    presenter.presentResult(input: input)
}

// {Client}FlowBoard.registerFlows() catches and routes
motherboard.serviceMap.mod{Client}Plugins
    .io{Client}Result.flow.addTarget(self) { target, action in
        switch action {
        case .perform{Service}(let value):
            target.motherboard.serviceMap.mod{Feature}
                .io{Service}.activation.activate(with: {Service}Input(value: value))
        }
    }
```

### Pattern B — Resolver DI

```swift
// {Feature}Core/Core/{Action}UseCase.swift
public protocol {Action}UseCase {
    func execute(...) async
}

// {Feature}Plugins/Sources/Plugins/Resolver+{Feature}Services.swift
public extension Resolver {
    static func register{Feature}Services() {
        register({Action}UseCase.self) {
            {Action}UseCaseInteractor(repository: {Entity}Repository())
        }
        .scope(.application)
    }
}

// {Feature}LauncherPlugin
public func prepareForLaunching(withOptions options: MainOptions) -> ModuleComponent {
    ModuleComponent(
        modulePlugins: {Feature}ModulePlugin.ServiceType.allCases.map {
            {Feature}ModulePlugin(service: $0)
        },
        launchSettings: { _ in Resolver.register{Feature}Services() }
    )
}

// Client ModulePlugin — @LazyInjected MUST be local var
func internalContinuousRegistrations(
    sharedComponent: any SharedValueComponent,
    producer: any ActivatableBoardProducer
) -> [BoardRegistration] {
    @LazyInjected var {action}UseCase: {Action}UseCase
    return [
        BoardRegistration(.mod{Board}) { id in
            {Board}Board(
                identifier: id,
                builder: {Board}Builder({action}UseCase: {action}UseCase),
                producer: producer
            )
        }
    ]
}
```

### Decision tree

```
Service used by > 1 module?
  NO  → keep internal (ModulePlugin stored property)
  YES → Pattern A (Boardy Board Interface)
        unless pure stateless utility AND team picks DI explicitly → Pattern B
```

## Concurrency

- Pattern A `activate` typically wraps async work in `Task { ... await MainActor.run { ... } }`. `sendOutput` + `complete()` MUST run on MainActor.
- Pattern B `@LazyInjected` resolves on first access; the resolver itself is thread-safe but the resolved instance's contract dictates threading. Default to consuming UseCases via `await` inside `Task`.
- Pattern A inherits `BlockTaskBoard.executingType` semantics (`.concurrent` vs `.flow`) — see `MICROBOARD_NONUI.md`.

## Composition

### Pattern A dependency graph

```
{Client}Plugins.podspec
  s.dependency '{Feature}'           ← public IO pod only
  NO s.dependency '{Feature}Plugins' ← FORBIDDEN

{Feature}Plugins.podspec
  s.dependency '{Feature}'           ← own IO pod (for BoardID, Input/Output)
```

App-entry composes: `PluginLauncher` runs each `LauncherPlugin.prepareForLaunching`; owner's `{Service}Board` registers under `pub{Service}` BoardID; client reaches it via `motherboard.serviceMap.mod{Feature}.io{Service}`.

### Pattern B dependency graph

```
{Feature}Core.podspec        no deps                  (pure protocols)
{Feature}Plugins.podspec     s.dependency '{Feature}Core' + 'Resolver'
{Client}Plugins.podspec      s.dependency '{Feature}Core' + 'Resolver'
```

Execution order:

```
PluginLauncher.initialize()
  └ generateMainboard()
      ├ loadPluginsIfNeeded()         (1) internalContinuousRegistrations runs
      │                                   @LazyInjected closures captured (NOT resolved)
      └ customLaunchSettings           (2) Resolver.register…() runs
PluginLauncher.launch() → activate    (3) @LazyInjected resolves on first access
```

(3) is guaranteed after (2). `@Injected` (eager) would resolve at (1) and crash — use `@LazyInjected`.

### Scope guidelines (Resolver)

| Scope | Use when |
|-------|----------|
| `.application` | Stateless use cases, persistent repositories (default) |
| `.unique` | New instance per resolution (rare) |
| `.cached` | Shared within a logical named scope |

## Lifecycle

- Pattern A `{Service}Board` is `BlockTaskBoard`-like: framework auto-completes; calling `complete()` manually breaks per-task routing — only call manually if implementing a Continuable variant.
- Pattern A client owns the `flow.addTarget`; the listener stays for the lifetime of the client motherboard.
- Pattern B `@LazyInjected` instance lives for the Resolver scope (`.application` = process lifetime). Don't hold the resolved value across `Builder.build(...)` calls — re-`@LazyInjected` per registration call.
- Stored `@LazyInjected` on a struct plugin is a bug — Swift mutating semantics + premature resolution. Always local var inside the function.

## Testing

- Pattern A unit: test `{Service}UseCaseInteractor` directly. Board itself: integration via fake motherboard asserting one activation → one output.
- Pattern A client: integration test that registers a fake `{Service}Board` under `pub{Service}` and asserts the client's `flow.addTarget` reacts.
- Pattern B: register fakes via `Resolver.register({Action}UseCase.self) { FakeUseCase() }.scope(.unique)` in `setUp`; clear between tests with `Resolver.root.reset()`.
- Both patterns: assert MainActor hop happens for any UI-touching consumer.

## Pitfalls

- ❌ `s.dependency '{Owner}Plugins'` from `{Client}Plugins` — implementation pods MUST be leaves.
- ❌ Storing `@LazyInjected` on `ModulePlugin` struct → resolves before `Resolver.register…()` runs, crashes.
- ❌ Using `@Injected` (eager) on a cross-module service → same premature-resolution crash.
- ❌ Reaching into another module's `sharedComponent` to grab its UseCase → out-of-band, breaks encapsulation; use IO or Resolver.
- ❌ Client Interactor importing the owner module — Interactor must signal intent via `FlowAction` / `Controllable`; FlowBoard does the cross-module call.
- ❌ Pattern A `{Service}Board` calling `sendOutput` from a background thread → race with main-thread Motherboard updates. Always `await MainActor.run { ... }`.
- ❌ Forgetting `pod install` after adding `s.dependency` or creating `{Feature}Core` → cryptic missing-symbol error.
- ❌ Pattern A IO files left `internal` → consuming module can't see them; IO MUST be `public`.

## References

- `LAYERING.md` (3-layer module rule)
- `PLUGINS_INTEGRATION.md` (LauncherPlugin / ModulePlugin shapes)
- `IO_INTERFACE.md` (public IO pod structure)
- `MICROBOARD_NONUI.md` (`BlockTaskBoard` variant for service wrap)
- `SERVICE_LAYER.md` (UseCase / Repository conventions)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 1, 2, 6, 9
