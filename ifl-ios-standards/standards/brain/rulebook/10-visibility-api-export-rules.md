<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 10. Visibility & API Export Rules

### 10.1 Minimal Surface Doctrine

Every symbol's default visibility is **the lowest level that compiles**:

| Order of preference | Use when |
|---------------------|----------|
| `private` | Same file only |
| `fileprivate` | File only, multi-type |
| `internal` (default) | Same module |
| `public` | Cross-module consumer needs it |
| `open` | External subclassing intended (rare) |

### 10.2 Public API Mindset

Marking something `public` is **a commitment**: changes break consumers. Before promoting visibility:

- Is there a concrete consumer today? (Not "might need it later".)
- Can it be exposed via a protocol instead of a concrete type?
- Is the name something we are willing to keep for years?
- Does it leak implementation details (e.g., specific error cases, internal flags)?

### 10.3 Encapsulation Rules

- Public extensions on public types: allowed, but additive only
- Public extensions on third-party types: **never** in interface modules — pollutes consumers
- Public properties: prefer `let` or `private(set) var`
- Public initializers: explicit; do not rely on synthesized memberwise init for public types
- Public protocols: keep small; prefer many narrow protocols over one wide one

### 10.4 Testing Exposure

Do not loosen production visibility for tests. Options:

1. `@testable import` — covers most cases
2. Test-only modules / targets
3. Behavior tests through the public API surface (preferred where feasible)

If tests force you to promote production code to `public`, the design is leaky.

---

