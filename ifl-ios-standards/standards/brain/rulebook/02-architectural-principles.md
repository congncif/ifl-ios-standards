<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 2. Architectural Principles

### 2.1 Layered Dependency Direction

A modular iOS app organizes itself into three logical layers. Dependencies point **inward only**.

```
┌────────────────────────────────────────────────────────────┐
│ Infrastructure & UI                                        │
│   View layer · Persistence · Network · Vendor SDK adapters │
│   Composition roots (where concrete types are wired)       │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Business Application                                       │
│   Use cases · Orchestration · Presentation logic           │
│   Depends on Domain protocols only                         │
└──────────────────────────┬─────────────────────────────────┘
                           │ depends on
                           ▼
┌────────────────────────────────────────────────────────────┐
│ Domain                                                     │
│   Pure-Swift models · Value objects · Domain errors        │
│   Repository protocols · Domain service protocols          │
│   No UIKit, no networking, no Codable, no vendor types     │
└────────────────────────────────────────────────────────────┘
```

**Rule**: Domain never imports anything above it. Business Application imports Domain. Infrastructure & UI imports both, and is the *only* layer permitted to import vendor SDKs.

### 2.2 The Five Architectural Pillars

| Pillar | What it enforces |
|--------|------------------|
| **SDK-first** | Platform capabilities are the default. Third-party only when SDK is materially insufficient. |
| **Interface modules** | Each feature exposes a public *contract module* and hides a private *implementation module*. Consumers depend on contracts. |
| **Domain isolation** | Business rules live in pure Swift, free of frameworks. |
| **Humble UI** | View layer renders state and forwards events — it owns no business decisions. |
| **Explicit composition** | Concrete types meet at named composition roots, not through global singletons or hidden coupling. |

### 2.3 Anti-Architecture

Reject these patterns as constitutional violations:

- Singletons containing business logic
- Cross-layer reach-through (UI → Network skipping use case)
- Service locators inside domain code
- Vendor types in public contracts
- "Utility" modules that depend on everything
- "God" modules that own multiple unrelated capabilities
- Speculative abstraction for problems not yet observed

---

