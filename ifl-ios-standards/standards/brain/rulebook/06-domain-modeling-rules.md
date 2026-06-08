<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 6. Domain Modeling Rules

### 6.1 Purity Rules

Domain layer:

- Imports **Foundation only** (for `URL`, `Date`, `UUID`)
- Contains **no UIKit, no Combine, no vendor SDKs, no Codable**
- Uses **value types** (`struct`, `enum`) by default; classes only when identity is intrinsic
- Defines **errors as enums conforming to `Error`**
- Functions are **pure** where possible

### 6.2 Ubiquitous Language

Names in Domain mirror the business vocabulary. If product calls it a "draft", the model is `Draft`, not `PendingDocument`. Avoid technical infixes (`...Manager`, `...Helper`, `...Service` for value types).

### 6.3 Modeling Building Blocks

| Building block | Use when |
|----------------|----------|
| **Value object** | Identity-less concept (`Money`, `EmailAddress`, `Coordinate`) |
| **Entity** | Identity matters (`User`, `Order`) |
| **Domain error** | Distinct failure modes the business cares about |
| **Repository protocol** | Persistence-shaped capability the business depends on |
| **Domain service protocol** | Stateless business operation needing collaboration |
| **Use case** | A unit of business intent the application performs |

### 6.4 Domain Anti-Patterns

| Smell | Fix |
|-------|-----|
| `Codable` on domain model | Add a DTO at Infrastructure; map to/from domain |
| `UIColor` in domain | Move to presentation layer |
| Repository returning DTOs | Repository must speak in domain models |
| Domain method that calls `URLSession` | Inject a repository protocol; implementation handles transport |

---

