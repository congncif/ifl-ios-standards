<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 8. Infrastructure Rules

### 8.1 Responsibilities

Infrastructure adapts external systems to domain protocols:

- Network clients
- Persistence stores
- Vendor SDK wrappers
- File system access
- Push notifications
- Analytics emitters

### 8.2 Adapter Pattern (canonical)

```swift
// Domain protocol
protocol UserRepository {
    func loadUser(id: UserID) async throws -> User
}

// Infrastructure adapter
final class RESTUserRepository: UserRepository {
    private let http: HTTPClient
    init(http: HTTPClient) { self.http = http }

    func loadUser(id: UserID) async throws -> User {
        let dto: UserDTO = try await http.get("/users/\(id.value)")
        return dto.toDomain()
    }
}

// DTO (Infrastructure only)
struct UserDTO: Codable {
    let id: String
    let name: String
    func toDomain() -> User { User(id: UserID(id), name: name) }
}
```

Domain never sees `UserDTO`. Infrastructure never returns DTOs to consumers.

### 8.3 Infrastructure Rules

- DTOs live exclusively in Infrastructure
- Each adapter conforms to one or more Domain protocols
- Adapters perform **transport, serialization, retry, caching** — not business decisions
- Vendor SDK imports are confined to adapter files

---

