<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 5. Interface Module Rules

### 5.1 Purpose

Interface modules:

- Define stable contracts between modules
- Decouple compile-time dependencies
- Allow implementation replacement without consumer recompilation
- Enable parallel team and agent work

### 5.2 What Belongs in an Interface

| Belongs | Does Not Belong |
|---------|-----------------|
| Public protocols | Concrete classes |
| Value types (`struct`, `enum`) | Reference types with behavior |
| Pure Swift only | UIKit / SwiftUI / vendor SDK imports |
| Stable IDs and identifiers | Internal implementation details |
| Entry-point declarations | Internal helpers |
| Domain models (when shared) | DTOs, parsers, serializers |

### 5.3 Stability Discipline

A contract module changes when *capability changes*, not when *implementation changes*. Breaking a contract triggers downstream rebuilds and code review across consuming modules — treat it like a public API release.

Each contract change must answer:

- Who consumes this contract today?
- Will the change require source changes in any consumer?
- Can the change be additive instead of breaking?

### 5.4 Interface Hygiene Checklist

- [ ] No `internal`-leaking types accidentally `public`
- [ ] No vendor SDK types in any public signature
- [ ] No reference to implementation modules
- [ ] No transitive heavy imports (keeps compile time low)
- [ ] Naming is business-oriented, not implementation-oriented (`UserProfileRepository`, not `RealmUserDAO`)

---

