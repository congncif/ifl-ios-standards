<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# EXAMPLES: Service Layer

UseCase + Repository patterns for the Application and Domain layers.
Placeholders: `{Action}` = verb phrase, `{Entity}` = domain entity, `{Result}` = return type.
Files live in `Sources/Services/`.

---

## UseCase

```swift
// Application/{Action}UseCase.swift
import Foundation

// Protocol (what the Interactor depends on)
protocol {Action}UseCase {
    func execute() async throws -> {Result}
}

// Implementation (suffix: UseCaseInteractor -- distinct from VIP Interactor)
final class {Action}UseCaseInteractor: {Action}UseCase {
    private let repository: {Entity}Repository

    init(repository: any {Entity}Repository) {
        self.repository = repository
    }

    func execute() async throws -> {Result} {
        guard let data = try await repository.fetch() else {
            throw {Module}Error.notFound
        }
        return data
    }
}
```

## UseCase with multiple methods

```swift
protocol {Feature}UseCase {
    func load() async -> {Entity}?
    func save(_ entity: {Entity}) async
    func submit() async throws
}

final class {Feature}UseCaseInteractor: {Feature}UseCase {
    private let repository: {Entity}Repository
    private let service: {Feature}Service

    init(repository: any {Entity}Repository, service: any {Feature}Service) {
        self.repository = repository; self.service = service
    }

    func load() async -> {Entity}? { await repository.fetch() }
    func save(_ entity: {Entity}) async { await repository.save(entity) }
    func submit() async throws {
        let items = await repository.fetchAll()
        try await service.submit(items)
    }
}
```

---

## Repository

```swift
// Domain/Repositories/{Entity}Repository.swift
// Pure Swift -- no UIKit, no Boardy, no Codable
protocol {Entity}Repository {
    func fetch() async throws -> {Entity}?
    func fetchAll() async -> [{Entity}]
    func save(_ entity: {Entity}) async
}
```

```swift
// Infra/{Entity}MemoryStorageRepository.swift
final class {Entity}MemoryStorageRepository: {Entity}Repository {
    private var stored: {Entity}?
    private var items: [{Entity}] = []

    func fetch() async throws -> {Entity}? { stored }
    func fetchAll() async -> [{Entity}] { items }
    func save(_ entity: {Entity}) async { stored = entity; items.append(entity) }
}
```

---

## Domain Model

```swift
// Domain/Models/{Entity}Models.swift
// Pure Swift value types -- no UIKit, no Boardy, no Codable
import Foundation

struct {Entity} {
    let id: String
    let name: String
    // Add domain fields here
}

enum {Module}Error: Error {
    case notFound
    case invalidInput
}
```

---

## REST Service (Infra)

```swift
// Infra/REST{Entity}Service.swift
final class REST{Entity}Service {
    let httpClient: HTTPClient
    init(httpClient: HTTPClient) { self.httpClient = httpClient }
}

// Infra/REST{Entity}Service+Query.swift
extension REST{Entity}Service: {Entity}QueryService {
    func fetch() async throws -> {Entity}? {
        let dto: {Entity}DTO = try await httpClient.request(endpoint: {Entity}Endpoints.get)
        return dto.toDomain()
    }
}
```
