<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Layering (inward policy, outward adapters)

> This spec is derived guidance for `CORE-DEP-001`…`003` and ADR-0002. Canon owns the
> obligation. Boardy examples apply only when the `boardy-vip` Profile is selected.

> Reference: *Modern large-scale iOS app development* — Domain-driven Layered pillar.
> Companion specs: `SERVICE_LAYER.md` (policy and service adapters), `VIP_COMPONENTS.md`
> (presentation-adapter detail), `compact/BOARDY_CHEATSHEET.compact.md` (Boardy profile guidance).

## When to use

When deciding which folder a new file belongs in, or auditing whether a feature module respects the dependency rule:

- New model / repository protocol / domain error → Domain layer.
- New use case / business orchestration policy → Application layer.
- New screen flow / Board / Presenter / rendering port → outward orchestration or presentation adapter.
- New REST client / Codable DTO / storage / SDK adapter / Builder struct / ViewController → Infrastructure & UI layer.
- Refactor adding a cross-module shared service → consult Cross-Module Layering rule.

## When NOT to use

- One-off scratch playground or sample project — layering overhead unwarranted.
- Pure SDK adapter pod that exposes a thin facade — no Domain layer required; the consuming module supplies it.
- App Core composition (`ServiceRegistry` wiring) — orchestration, not a feature module.

## Forces

- Inward-only dependencies stop Infra or orchestration changes (e.g. REST → GraphQL or Boardy → a
  coordinator) from rippling into Domain/Application policy.
- The Buildable **protocol** sits in the Boardy adapter contract surface so Board never knows the
  concrete Builder; concrete `{Board}Builder` lives at the outward composition root.
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
│   ├── Application/                     ← framework-neutral UseCase protocols + *UseCaseInteractor
│   ├── Infra/                           ← REST/Codable/storage/SDK adapters
│   └── Tracking/                        ← analytics adapters
└── Microboards/{Board}/
    ├── {Board}Board.swift               ← Boardy orchestration adapter
    ├── {Board}Interactor.swift          ← presentation/application adapter
    ├── {Board}Presenter.swift           ← presentation mapper
    ├── {Board}Protocols.swift           ← adapter contracts; declares Buildable protocol
    ├── {Board}ViewController.swift      ← Infra & UI
    └── {Board}Builder.swift             ← Infra & UI — composition root
```

## Naming

- Domain: `{Entity}` (struct), `{Entity}Repository` (protocol), `{Entity}QueryService` (protocol), `{Module}Error: Error` (enum).
- Application UseCase: protocol `{Action}UseCase` + concrete `{Action}UseCaseInteractor`.
- Boardy-profile Buildable: protocol `{Board}Buildable` in `{Board}Protocols.swift`.
- Infra: `REST{Entity}Service`, `{Entity}DTO` + `toDomain()`, `{Entity}MemoryStorageRepository`.
- Infra & UI composition: concrete `struct {Board}Builder: {Board}Buildable`.

## Communication

### The cake

```
┌────────────────────────────────────────────────────────────┐
│ Outward adapters + composition                             │
│   UIKit VCs, Storyboards, custom views                     │
│   REST clients, Codable DTOs, persistence, SDK adapters    │
│   optional Boardy shell + Presenter + {Board}Builder       │
│   concrete Builder wires adapters → Application            │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Application policy                                         │
│   UseCase protocols + UseCaseInteractor implementations    │
│   no Boardy, UIKit/SwiftUI, networking, persistence,       │
│   or utility-framework imports                             │
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

Dependency rule → arrows inward only. Domain imports nothing above; Application imports Domain and
inward-owned contracts; outward adapters may import Application/Domain plus their selected framework.

### Allowed dependencies (compile-time)

| From → To | Allowed |
|---|---|
| Domain → Foundation | ✅ |
| Domain → anything else | ❌ |
| Application → Domain | ✅ |
| Application → Boardy / UIKit / SwiftUI / SiFUtilities / Infra | ❌ |
| Application → outward capability | ✅ — through a protocol owned by Domain/Application |
| Boardy orchestration/presentation adapter → Application / Domain / Boardy | ✅ when `boardy-vip` applies |
| Board / Interactor / Presenter → Infra concrete types | ❌ — depend on inward-owned protocols |
| Declared outward Builder/composition root → Infra concrete types | ✅ — construct adapters and inject them behind inward-owned contracts |
| Infra → Domain (protocols + models) | ✅ |
| Infra → Application contract | ✅ when implementing an Application-owned port |
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

The composition root owns process-wide singletons and hands them to the Builder explicitly. Concrete
adapters never move inward merely because Boardy or another runtime registers the Builder.

### Cross-module layering

1. Owner exposes capability via Interface Module (`{Module}` / IO pod).
2. Consumers depend on `{Module}` (Interface), NEVER `{Module}Plugins`.
3. Cross-module activation: `motherboard.serviceMap.mod{Module}.io{Service}` (Pattern A, see `CROSS_MODULE_DI.md`).
4. Pure protocol sharing may add `{Module}Core` pod (Pattern B).

The Interface Module is the public capability surface consumers compile against. It exposes
inward-owned values/contracts and, only when a selected Profile owns the transport contract, that
Profile's public transport types (for example Boardy destinations under `boardy-vip`).

## Concurrency

- Domain value types are immutable → safe across actors.
- Application UseCases declare the isolation their policy requires and do not inherit Boardy's actor
  model merely from an adapter.
- Interactor/Presenter and rendering adapters typically run on MainActor. Infra callbacks cross into
  the actor required by the inward contract before presentation/UI delivery.
- Shared repositories accessed from multiple Boards → mark `@MainActor` or wrap in `actor` if mutation across Tasks expected.

## Composition

- Each Boardy Microboard composes vertically as an outward adapter: VC ← Builder ←
  Interactor/Presenter ← Application UseCase ← Domain protocol ← Infra adapter.
- Sideways composition across Boards goes through Flow/Composable Board adapters — not through
  Application policy or shared Infra.
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
- [ ] `Services/Application/` imports no Boardy, UIKit/SwiftUI, networking, persistence, or utility framework
- [ ] UseCase protocols live in `Services/Application/`; impls end with `UseCaseInteractor`
- [ ] Presenter is the only place constructing `{Board}ViewModel`
- [ ] Interactor `Presentable` surface accepts domain types only
- [ ] The declared concrete `{Board}Builder` composition root may construct Infra and composes it into
      UseCase → Presenter → Interactor; Board/Interactor/Presenter reference only inward contracts
- [ ] Shared deps (`sharedRepository`, `sharedTracker`) are stored properties on ModulePlugin
- [ ] Consumer modules import `{Module}` (Interface), never `{Module}Plugins` (Impl)

Per-layer unit tests:
- Domain: usually none unless logic in struct (custom Equatable/Hashable).
- Application UseCaseInteractor: fake Repository + fake Service → assert call order + errors.
- Presentation Interactor/Presenter: see `TESTING.md` for the standard mock surface.
- Infra REST: fake HTTPClient → assert endpoint + DTO mapping.

## Pitfalls

| Smell | Why it breaks layering | Fix |
|---|---|---|
| `Codable` on Domain model | Couples Domain to wire format | DTO in Infra + `.toDomain()` |
| `UIColor` in Domain model | Domain leaks into UIKit | Keep colors in Presenter / DesignSystem |
| Interactor receives `URLSession` | Skips UseCase + Repository | Inject UseCase that hides transport |
| Presenter calls `URLSession` | UI reaches into Infra | Route via Interactor + UseCase |
| VC constructs `ViewModel` | View has logic | Presenter builds VM; View renders |
| Application imports Boardy or SiFUtilities | Framework/runtime policy leaked inward | Move lifecycle/navigation/utility adaptation to the outward Boardy shell |
| `import {Module}Plugins` from another module | Impl leak | Depend on `{Module}` Interface |
| `sharedRepository` created inside `BoardRegistration` closure | New instance per build → lost state | Store on ModulePlugin |
| Board holds concrete `{Board}Builder` | Concrete leak into the orchestration adapter | Board holds `Buildable` protocol |

## References

- `SERVICE_LAYER.md` (concrete service code by layer)
- `VIP_COMPONENTS.md` (presentation-adapter detail)
- `CROSS_MODULE_DI.md` (cross-module layering)
- `IO_INTERFACE.md` (Interface Module shape)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 9, 10
