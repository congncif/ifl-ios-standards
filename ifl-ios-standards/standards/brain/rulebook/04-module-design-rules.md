<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 4. Module Design Rules

### 4.1 What a Module Is

A module is a unit with:

- **A name** — singular, descriptive, business-domain-oriented
- **A purpose** — one capability or one bounded context
- **A contract** — public interface, stable across implementation changes
- **An implementation** — hidden, replaceable
- **An owner** — a person, a team, or an agent role
- **A build target** — independently compilable

### 4.2 Module Types

| Type | Purpose | Examples |
|------|---------|----------|
| **Feature module** | A user-facing capability or business flow | Profile, Checkout, Onboarding |
| **Core module** | Cross-cutting domain or business primitive | Identity, Payments, Permissions |
| **Foundation module** | Platform abstractions: networking, persistence, logging | NetworkKit, Storage |
| **Design system module** | UI primitives, tokens, components | DesignSystem |
| **Shared contract module** | Pure protocols / models reused by multiple modules | *FeatureCore |

### 4.3 Splitting Rules

Split a module when:

- Two capabilities have independent release cadences
- Build time of one capability blocks the other unnecessarily
- Two capabilities have different consumers
- A capability is reused by ≥ 2 features

Do *not* split prematurely. Three similar files do not justify a new module.

### 4.4 Module Folder Skeleton (recommended default)

```
{ModuleRoot}/{Module}/
├── {Module}.podspec | Package.swift                  # contract package
├── {Module}Implementation.podspec | Implementation/  # implementation package
├── Interface/                                 # public contract files
│   ├── Models/
│   ├── Protocols/
│   └── Entry-points/
└── Sources/                                   # private implementation
    ├── Presentation/
    ├── BusinessApplication/
    │   ├── UseCases/
    │   └── Coordination/
    └── Infrastructure/
        ├── Network/
        ├── Persistence/
        └── Vendor adapters/
```

### 4.5 The Interface / Implementation Split

Every feature module ships two artifacts:

| Artifact | Visibility | Contains |
|----------|------------|----------|
| **Interface** | `public` | Protocols, models, identifiers, value types, entry-point contracts |
| **Implementation** | `internal` | Use cases, presentation, infrastructure, vendor wrappers, composition |

Consumers depend on the **Interface** only. Implementation is opaque.

This is the single most important rule for build scalability in modular iOS apps.

---

