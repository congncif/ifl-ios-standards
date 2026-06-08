<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Layering (Domain-Driven 3-Layer)

> Reference: *Modern large-scale iOS app development* — Domain-driven Layered pillar.
> Companion specs: `SERVICE_LAYER.md` (concrete service code), `VIP_COMPONENTS.md` (BA layer detail), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When deciding which folder a new file belongs in, or auditing whether a feature module respects the dependency rule:

- New model / repository protocol / domain error → Domain layer.
- New screen flow / use case / coordination Board → Business Application layer.
- New REST client / Codable DTO / storage / SDK adapter / Builder struct / ViewController → Infrastructure & UI layer.
- Refactor adding a cross-module shared service → consult Cross-Module Layering rule.

## When NOT to use

- One-off scratch playground or sample project — layering overhead unwarranted.
- Pure SDK adapter pod that exposes a thin facade — no Domain layer required; the consuming module supplies it.
- App Core composition (`ServiceRegistry` wiring) — orchestration, not a feature module.

## Forces

- Inward-only dependencies stop Infra changes (e.g. swapping REST → GraphQL) from rippling into Domain/BA.
- The Buildable **protocol** sits in BA so Board never knows the concrete Builder; concrete `{Board}Builder` lives in Infra & UI as the composition root.
- DTOs in Domain feel convenient (one type fewer) but couple wire format to business model — they belong in Infra.
- Shared deps (`sharedRepository`, `sharedTracker`) must be ModulePlugin stored properties so all Boards see one instance.
- Cross-module reuse goes through Interface Module (IO pod) or a `{Module}Core` protocol pod — never `{Module}Plugins`.

## Files

```
Sources/
├── Services/
│   ├── Domain/
│   │   ├── Models/                      ← value types + errors
│   │   ├── Repositories/                ← protocols
│   │   └── Services/                    ← non-repo Domain protocols
│   ├── Application/                     ← UseCase protocols + *UseCaseInteractor
│   ├── Infra/                           ← REST/Codable/storage/SDK adapters
│   └── Tracking/                        ← analytics adapters
└── Microboards/{Board}/
    ├── {Board}Board.swift               ← BA (Boardy)
    ├── {Board}Interactor.swift          ← BA
    ├── {Board}Presenter.swift           ← BA
    ├── {Board}Protocols.swift           ← BA — declares Buildable protocol
    ├── {Board}ViewController.swift      ← Infra & UI
    └── {Board}Builder.swift             ← Infra & UI — composition root
```

## Naming

- Domain: `{Entity}` (struct), `{Entity}Repository` (protocol), `{Entity}QueryService` (protocol), `{Module}Error: Error` (enum).
- BA UseCase: protocol `{Action}UseCase` + concrete `{Action}UseCaseInteractor`.
- BA Buildable: protocol `{Board}Buildable` in `{Board}Protocols.swift`.
- Infra: `REST{Entity}Service`, `{Entity}DTO` + `toDomain()`, `{Entity}MemoryStorageRepository`.
- Infra & UI composition: concrete `struct {Board}Builder: {Board}Buildable`.

## Communication

### The cake

```
┌────────────────────────────────────────────────────────────┐
│ Infrastructure & UI  (composition root)                    │
│   UIKit VCs, Storyboards, custom views                     │
│   REST clients, Codable DTOs, persistence, SDK adapters    │
│   {Board}Builder (concrete) — wires Infra → BA             │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Business Application (VIP + Boards)                        │
│   Microboards: Board / Interactor / Presenter              │
│   {Board}Buildable PROTOCOL (Board depends on this)        │
│   UseCase protocols + UseCaseInteractor implementations    │
│   Coordination (Flow / Viewless / Composable boards)       │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Domain                                                     │
│   Pure-Swift models, value objects, domain errors          │
│   Repository protocols, domain service protocols           │
│   No UIKit, no Boardy, no networking, no Codable           │
└────────────────────────────────────────────────────────────┘
```

Dependency rule → arrows inward only. Domain imports nothing above; BA imports Domain; Infra & UI imports both.

### Allowed dependencies (compile-time)

| From → To | Allowed |
|---|---|
| Domain → Foundation | ✅ |
| Domain → anything else | ❌ |
| BA → Domain | ✅ |
| BA → Boardy / SiFUtilities | ✅ |
| BA → Infra concrete types | ❌ — depend on Domain protocols |
| Infra → Domain (protocols + models) | ✅ |
| Infra → BA | ❌ |
| UI (VC) → Presenter / Interactor protocols | ✅ |
| UI → Domain models | ❌ — Presenter maps to ViewModels first |

### Composition root wiring

```swift
struct {Board}Builder: {Board}Buildable {
    let repository: {Entity}Repository           // shared, from ModulePlugin

    func build(...) -> {Board}Interface {
        let rest      = REST{Entity}Service(httpClient: HTTPClient.default)
        let useCase   = {Action}UseCaseInteractor(repository: repository, queryService: rest)
        let presenter = {Board}Presenter()
        let interactor = {Board}Interactor(presenter: presenter, input: input, useCase: useCase)
        // …wire delegates, return Interface
    }
}
```

ModulePlugin owns process-wide singletons; hands them to Builder via stored properties — never via closures captured inside `BoardRegistration`.

### Cross-module layering

1. Owner exposes capability via Interface Module (`{Module}` / IO pod).
2. Consumers depend on `{Module}` (Interface), NEVER `{Module}Plugins`.
3. Cross-module activation: `motherboard.serviceMap.mod{Module}.io{Service}` (Pattern A, see `CROSS_MODULE_DI.md`).
4. Pure protocol sharing may add `{Module}Core` pod (Pattern B).

Interface Module *is* the Domain protocol surface consumers compile against.

## Concurrency

- Domain value types are immutable → safe across actors.
- BA Interactor/Presenter typically MainActor; UseCase calls `async`.
- Infra REST callbacks land on arbitrary threads → MainActor hop before crossing back into BA / UI (see `MICROBOARD_NONUI.md` Concurrency).
- Shared repositories accessed from multiple Boards → mark `@MainActor` or wrap in `actor` if mutation across Tasks expected.

## Composition

- Each Microboard composes vertically: VC ← Builder (Infra & UI) ← Interactor (BA) ← UseCase (BA) ← Repository (Domain protocol) ← REST/Storage (Infra & UI).
- Sideways composition across Boards goes through Flow/Composable boards in BA — not through shared Infra.
- Cross-module composition flows through IO pod activations, keeping layer rule intact across module boundaries.

## Lifecycle

- Domain types — process lifetime; immutable values.
- Shared repositories / trackers — app lifetime (ModulePlugin stored properties).
- REST services — typically per-Builder call; cheap; HTTPClient inside is shared.
- UseCaseInteractor — per Builder call; rides Board's lifetime.
- Builder struct itself — value type, created at registration time; closures retain it.
- Composition root references (concrete `{Board}Builder`) are released when the Board completes.

## Testing

- [ ] No file under `Services/Domain/` imports `UIKit`, `Boardy`, or networking frameworks
- [ ] Repository protocols return Domain models, not DTOs
- [ ] DTOs are `Codable` and live in `Services/Infra/`
- [ ] DTOs expose `func toDomain() -> {Model}` (or initializer on the model)
- [ ] UseCase protocols live in `Services/Application/`; impls end with `UseCaseInteractor`
- [ ] Presenter is the only place constructing `{Board}ViewModel`
- [ ] Interactor `Presentable` surface accepts domain types only
- [ ] Concrete `{Board}Builder` composes Infra → UseCase → Presenter → Interactor and wires delegates; Board references only `Buildable`
- [ ] Shared deps (`sharedRepository`, `sharedTracker`) are stored properties on ModulePlugin
- [ ] Consumer modules import `{Module}` (Interface), never `{Module}Plugins` (Impl)

Per-layer unit tests:
- Domain: usually none unless logic in struct (custom Equatable/Hashable).
- BA UseCaseInteractor: fake Repository + fake Service → assert call order + errors.
- BA Interactor/Presenter: see `TESTING.md` for the standard mock surface.
- Infra REST: fake HTTPClient → assert endpoint + DTO mapping.

## Pitfalls

| Smell | Why it breaks layering | Fix |
|---|---|---|
| `Codable` on Domain model | Couples Domain to wire format | DTO in Infra + `.toDomain()` |
| `UIColor` in Domain model | Domain leaks into UIKit | Keep colors in Presenter / DesignSystem |
| Interactor receives `URLSession` | Skips UseCase + Repository | Inject UseCase that hides transport |
| Presenter calls `URLSession` | UI reaches into Infra | Route via Interactor + UseCase |
| VC constructs `ViewModel` | View has logic | Presenter builds VM; View renders |
| `import {Module}Plugins` from another module | Impl leak | Depend on `{Module}` Interface |
| `sharedRepository` created inside `BoardRegistration` closure | New instance per build → lost state | Store on ModulePlugin |
| Board holds concrete `{Board}Builder` | Concrete leak into BA | Board holds `Buildable` protocol |

## References

- `SERVICE_LAYER.md` (concrete service code by layer)
- `VIP_COMPONENTS.md` (BA layer in detail)
- `CROSS_MODULE_DI.md` (cross-module layering)
- `IO_INTERFACE.md` (Interface Module shape)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 9, 10
