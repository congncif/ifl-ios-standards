<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 14. Build & Scalability Rules

### 14.1 Build Time as a Constitutional Concern

A 10-minute build kills agent throughput and human flow. Build time is a property of the architecture:

- Interface modules keep compile graphs shallow
- Implementation modules rebuild independently
- Heavy dependencies sit at leaves of the graph, not the trunk
- Generated code is committed (not re-derived on every build) where it stabilizes the graph

### 14.2 Module Boundaries Drive Incrementality

Adding a module is cheap; merging modules is expensive. Default to splitting when a capability emerges.

Indicators a module should split:

- Compile time disproportionate to its size
- Multiple unrelated public types
- Different teams or owners
- Different release cadence
- Different dependency profiles

### 14.3 Avoid Trunk Dependencies

If a "Common" or "Utilities" module is imported by every feature, it becomes a global rebuild trigger. Decompose by *concept* (Networking, Persistence, Logging) so changes in one concept do not invalidate all features.

### 14.4 CI Hygiene

- Canonical build / test commands documented and stable
- Build output is parseable and filtered to actionable lines
- Treat warnings as signal; do not suppress them globally
- Fail loud, fail early

---

