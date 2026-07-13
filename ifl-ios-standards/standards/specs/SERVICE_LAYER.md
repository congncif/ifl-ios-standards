<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Service Layer (DDD)

> Derived guidance for `CORE-DEP-001`…`003` and ADR-0002. Canon owns the dependency obligation;
> Boardy examples apply only when the `boardy-vip` Profile is selected.
> Reference: *Modern large-scale iOS app development* — Domain-driven Layered pillar.
> Companion specs: `LAYERING.md` (3-layer dependency rule), `CROSS_MODULE_DI.md` (sharing across modules), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When adding domain logic, business operations, persistence, or networking inside a feature module's `Sources/Services/`. Specifically:

- New domain entity / aggregate / value object → `Domain/Models/`.
- Persistence or external API contract → `Domain/Repositories/` or `Domain/Services/`.
- Business operation chained across multiple services/repositories → `Application/{Action}UseCase`.
- HTTP / DB / in-memory backing of a Domain protocol → `Infra/`.

## When NOT to use

- VIP Interactor inside a Board — that is presentation logic, see `VIP_COMPONENTS.md`. The VIP Interactor *consumes* UseCases; it does not contain domain rules.
- Pure UI state container → `Presenter` / `ViewState`, not a UseCase.
- Cross-module shared service — expose an inward-owned contract through the Interface Module; a
  Boardy Board is one optional outward transport when that Profile applies.
- One-off helper used by exactly one Board with no domain meaning → just inline it.

## Forces

- Domain layer must stay framework-free (no UIKit / Boardy / Codable). Adding `Codable` directly to a Domain struct is the most common drift — keep DTOs in `Infra/`.
- UseCase protocols keep Application independent of its outward composition and tests; the concrete
  runtime or DI mechanism does not enter the Application import graph.
- Splitting `REST{Entity}Service` by protocol extension keeps one HTTP class but separates the concerns each Domain protocol cares about — easier to mock per concern in tests.
- Tracking is a parallel concern, not a UseCase — keep it out of the Domain → Application dependency chain.

## Files

```
Sources/Services/
├── Domain/
│   ├── Models/{Feature}Models.swift              ← pure Swift value types
│   ├── Repositories/{Entity}Repository.swift     ← protocol
│   └── Services/{Name}Service.swift              ← non-repository domain protocols
├── Application/
│   └── {Action}UseCase.swift                     ← protocol + *UseCaseInteractor
├── Infra/
│   ├── REST{Entity}Service.swift                 ← networking base
│   ├── REST{Entity}Service+{Concern}.swift       ← per-protocol extension
│   ├── {Entity}MemoryStorageRepository.swift
│   └── {Entity}DBRepository.swift
└── Tracking/
    ├── TrackingEvent+Extensions.swift
    └── {Module}AnalyticsTracker.swift
```

## Naming

- Models: `{Entity}` (struct), `{Aggregate}` (struct), `{Entity}Selection`, `{Module}Error: Error`.
- Repository: `{Entity}Repository` (protocol).
- Service protocols: `{Entity}QueryService`, `{Entity}SubmitService`, `{Entity}RewardService` — split by verb when one REST class hosts multiple concerns.
- UseCase: protocol `{Action}UseCase` + concrete `{Action}UseCaseInteractor`. The `Interactor` suffix is intentional — it is service-layer, not the VIP `Interactor`.
- Infra: `REST{Entity}Service`, `{Entity}MemoryStorageRepository`, `{Entity}DBRepository`.

## Communication

### Domain — Models (pure value types)

```swift
import Foundation   // URL/Date only

struct {Entity} {
    let id: String
    let name: String
    let imageURL: URL?
    let tags: [String]
}

struct {Aggregate} {
    let primary: {Entity}
    let related: [{Entity}]
    let metadata: {Metadata}?
}

struct {Entity}Selection: Hashable, Equatable {
    enum Action: String { case liked = "LIKE", disliked = "DISLIKE", neutral = "NEUTRAL" }
    let id: String
    let action: Action
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum {Module}Error: Error { case notFound, invalidInput }
```

Rules: structs only, enums for typed states, `Hashable`/`Equatable` when needed, error types live in Domain. No `Codable`, no UIKit, no Boardy.

### Domain — Repository / Service protocols

```swift
protocol {Entity}Repository {
    func save(_ aggregate: {Aggregate}) async
    func getPrimary() async -> {Entity}?
    func saveSelection(_ selection: {Entity}Selection) async
    func getSelections() async -> [{Entity}Submission]
    func getRelated() async -> [{Entity}]
    func getMetadata() async -> {Metadata}?
}

protocol {Entity}QueryService  { func get{Aggregate}() async throws -> {Aggregate}? }
protocol {Entity}SubmitService { func submit(_ submissions: [{Entity}Submission]) async throws }
protocol {Entity}RewardService { func claimReward() async throws -> {Entity}Reward }
```

### Application — UseCase (protocol + Interactor)

```swift
protocol Load{Aggregate}UseCase {
    func load() async throws
}

final class Load{Aggregate}UseCaseInteractor: Load{Aggregate}UseCase {
    let queryService: {Entity}QueryService
    let repository: {Entity}Repository

    init(repository: any {Entity}Repository, queryService: any {Entity}QueryService) {
        self.queryService = queryService; self.repository = repository
    }

    func load() async throws {
        if let aggregate = try await queryService.get{Aggregate}() {
            await repository.save(aggregate)
        } else {
            throw {Module}Error.notFound
        }
    }
}
```

Multi-method UseCase (state-aware) follows the same shape — one protocol, one `*UseCaseInteractor`.

### Infra — Memory repository

```swift
final class {Entity}MemoryStorageRepository: {Entity}Repository {
    private var aggregate: {Aggregate}?
    private var selections: [{Entity}Selection] = []

    func save(_ a: {Aggregate}) async { aggregate = a }
    func getPrimary() async -> {Entity}? { aggregate?.primary }
    func saveSelection(_ s: {Entity}Selection) async {
        selections.removeAll { $0.id == s.id }
        selections.append(s)
    }
    func getSelections() async -> [{Entity}Submission] {
        guard let related = aggregate?.related else { return [] }
        return selections.compactMap { sel in
            guard let e = related.first(where: { $0.id == sel.id }) else { return nil }
            return {Entity}Submission(selection: sel, code: e.id, tags: e.tags)
        }
    }
    func getRelated() async -> [{Entity}] { aggregate?.related ?? [] }
    func getMetadata() async -> {Metadata}? { aggregate?.metadata }
}
```

### Infra — REST service split by concern

```swift
final class REST{Entity}Service {
    let httpClient: HTTPClient
    init(httpClient: HTTPClient) { self.httpClient = httpClient }
}

extension REST{Entity}Service: {Entity}QueryService {
    func get{Aggregate}() async throws -> {Aggregate}? {
        let dto: {Aggregate}DTO = try await httpClient.request(endpoint: {Entity}Endpoints.get)
        return dto.toDomain()
    }
}

extension REST{Entity}Service: {Entity}SubmitService {
    func submit(_ submissions: [{Entity}Submission]) async throws {
        let req = {Entity}SubmitRequest(submissions: submissions)
        try await httpClient.request(endpoint: {Entity}Endpoints.submit(req))
    }
}
```

DTO conversion (`dto.toDomain()`) lives in Infra — Domain never imports Codable types.

### Tracking — parallel concern

```swift
extension TrackingEvent {
    static func {feature}Started(id: String) -> TrackingEvent {
        TrackingEvent(name: "{feature}_started", parameters: ["id": id])
    }
}

final class {Module}AnalyticsTracker: ExternalTrackerProtocol {
    func track(_ event: TrackingEvent) { /* wrap Firebase / internal SDK */ }
}
```

## Concurrency

- All repository / service / UseCase methods are `async`. Don't add throwing-only sync signatures unless wrapping a strictly synchronous source.
- Domain types are immutable value types — safe to pass across actors.
- In-memory repository methods touch shared mutable state; mark them `@MainActor` or wrap with an `actor` if accessed from multiple Tasks concurrently. For most app flows running through a single VIP Interactor on MainActor, plain `async` methods suffice.
- REST services typically suspend on the network; final continuation thread is HTTPClient-dependent — UseCase callers must hop to MainActor before publishing UI-bound results (see `MICROBOARD_NONUI.md` Concurrency).
- Tracking calls are fire-and-forget; don't `await` them inside critical paths.

## Composition

- VIP Interactor depends on `{Action}UseCase` (protocol) — never on `{Action}UseCaseInteractor` directly.
- UseCase depends on Repository / Service (protocols). Concrete Infra is injected by Builder.
- Builder wiring shape:

```swift
// Builder receives shared repository from ModulePlugin, instantiates infra + UseCase
struct {Board}Builder: {Board}Buildable {
    let repository: {Entity}Repository           // shared, from ModulePlugin
    let httpClient: HTTPClient                   // shared, from ModulePlugin

    func build(withDelegate delegate: {Board}ActionDelegate?, input: {Board}Input)
    -> {Board}Component {
        let rest = REST{Entity}Service(httpClient: httpClient)
        let loadUseCase = Load{Aggregate}UseCaseInteractor(repository: repository, queryService: rest)
        let interactor = {Board}Interactor(loadUseCase: loadUseCase, presenter: ...)
        ...
    }
}
```

- Cross-module sharing — see `CROSS_MODULE_DI.md`. Never expose a `*UseCaseInteractor` directly to
  another module; expose an Interface Module contract and choose a Boardy or non-Boardy adapter at the edge.

## Lifecycle

- Domain types — process lifetime; immutable.
- Shared repositories — one instance per `ModulePlugin` (stored property), shared across all Boards of that module.
- REST services — typically created per Builder call; cheap to instantiate, the HTTPClient inside is shared.
- UseCaseInteractors — created by an outward composition root and live as long as their consuming flow.
- No `complete()`, `attachObject`, UIKit, SwiftUI, or Boardy semantics at this layer; the selected
  orchestration adapter owns that lifecycle outside Application.

## Testing

- UseCaseInteractor: inject fake Repository + fake Service; assert call sequence + thrown errors. Highest-value tests.
- Repository (memory): unit tests with concrete instance; assert state across save/get sequences.
- REST service: inject a mock HTTPClient that returns canned DTOs; assert endpoint + parameters + DTO→Domain mapping.
- Tracking: assert events emitted via a recording `ExternalTrackerProtocol` fake.
- Domain Models: usually no tests — they're plain structs. Test only if they carry non-trivial logic (e.g. hashing semantics, custom Equatable).

## Pitfalls

- ❌ Adding `Codable` to a Domain `struct` → couples Domain to wire format. Keep DTOs in Infra and convert.
- ❌ UseCase importing UIKit / Boardy → wrong layer. Move presentation concerns to Presenter; activation concerns to the Board.
- ❌ Builder instantiating a `UseCaseInteractor` whose protocol the VIP Interactor doesn't depend on → dead wiring; remove or move usage into the Interactor.
- ❌ Repository protocol returning `Result<T, Error>` from `async` → conflates sync error model with async; use `async throws` and let UseCase / Interactor decide error policy.
- ❌ Splitting one REST class into per-protocol classes when they share endpoints/auth → forces duplicated HTTPClient wiring. Extensions on one class is the canonical pattern.
- ❌ Storing `*UseCaseInteractor` directly on a VIP Interactor instead of the protocol → blocks fakes in tests.
- ❌ Putting Tracking inside a UseCase → makes the UseCase impure and entangles analytics with business logic. Track from the Interactor or a `TrackingPlugin` Board.

## References

- `LAYERING.md` (3-layer dependency rule)
- `VIP_COMPONENTS.md` (how the VIP Interactor consumes UseCases)
- `CROSS_MODULE_DI.md` (sharing services across modules)
- `PLUGINS_INTEGRATION.md` (where shared repositories live)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 9, 10
