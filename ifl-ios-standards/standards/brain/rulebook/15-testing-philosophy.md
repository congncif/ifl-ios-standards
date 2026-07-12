<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 15. Testing Philosophy

### 15.1 Test What Matters

Test the **behavior of business rules** and **boundaries between layers**. Do not test:

- Framework code (Apple already tests it)
- View rendering pixel-by-pixel (snapshot tests only when stability is worth the maintenance)
- Trivial property mappings without branching

### 15.2 Test Pyramid (iOS-pragmatic)

| Layer | Coverage goal | Tool |
|-------|---------------|------|
| Domain logic | High — pure functions are cheap to test | XCTest |
| Use cases | High — orchestration is where bugs hide | XCTest with protocol fakes |
| Presentation mapping | Medium — verifies what the view will see | XCTest |
| Infrastructure adapters | Targeted — test serialization, error paths | XCTest with stubbed transport |
| UI rendering | Low — only critical flows | XCUITest / snapshot |

### 15.3 Fakes Over Mocks

Prefer hand-written fakes that implement the protocol with simple in-memory behavior. Avoid mock frameworks that obscure intent and produce brittle tests.

### 15.4 Tests as Specifications

A good test reads as a specification of behavior. Name tests after the behavior under test, not the function under test:

```
✅ testSubmitsOrderWhenInventoryAvailable
❌ test_submitsOrder_whenInventoryAvailable
```

### 15.5 Test Independence

Each test:

- Sets up its own state
- Does not depend on test execution order
- Does not share mutable state with other tests
- Runs quickly enough to be run continuously

### 15.6 TDD and Evidence Boundary

Apply TDD only to executable code, proportionally to behavioral and regression risk. Documentation,
standards prose, metadata, documentation-only schemas, and templates require no TDD or runtime gate;
the approved plan's single final joined AI review evaluates their consistency.

Executable build and test evidence comes from observed commands using the consuming repository or
provider's native tooling with relevant context. Do not add plugin-owned verification scripts or
duplicate CI, nor process-only fixtures, checks, receipts, or evidence ledgers.

---
