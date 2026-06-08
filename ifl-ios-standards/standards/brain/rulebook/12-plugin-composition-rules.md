<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 12. Plugin & Composition Rules

### 12.1 Composition Root Pattern

Concrete types are instantiated **only at composition roots**:

- The app's `@main` entry / launcher
- Per-module registration entry points
- Per-screen builders / factories

Inner layers reference only protocols. The composition root is the **single place** where "the wiring" lives.

### 12.2 Plugin Architecture

For runtime composability:

- Each feature module exposes a **registration entry point** that the app composes at launch
- Registration is **declarative** ("here is my capability") not **imperative** ("call me to install yourself everywhere")
- Capabilities are looked up by **identifier** at runtime — not by class reference
- Features may be enabled, disabled, or replaced without touching consumers

### 12.3 Service Registry

A shared registry (passed via DI, not a global):

- Maps `Identifier → Capability factory`
- Returns capabilities behind protocols
- Allows feature toggles, A/B variants, and test doubles to substitute at the registry level

### 12.4 Composable Business Capabilities

Each capability is:

- **Independently activatable** — has a clear entry point with explicit input and output
- **Lifecycle-explicit** — start, complete, release are observable
- **Replaceable** — alternative implementations conform to the same contract
- **Loosely connected** — communicates with siblings through declared channels (events, callbacks), not by mutual reference

---

