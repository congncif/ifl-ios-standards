<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 7. Business Layer Rules

### 7.1 Use Cases as Capability Units

Each business intent is a **use case**:

- One protocol per intent (`SubmitOrderUseCase`, `LoadProfileUseCase`)
- One implementation behind the protocol
- Depends on **repository / domain-service protocols only** — never on concrete infrastructure
- Returns **domain models or domain errors**, never DTOs

### 7.2 Orchestration vs. Decision

The business layer:

- **Orchestrates** which use cases run, in which order, in response to which intents
- **Decides** flow based on use case outcomes
- **Maps** domain output to presentation input (often via a dedicated mapper)

It does **not**:

- Touch the network directly
- Touch persistence directly
- Construct or know about View components
- Embed vendor SDK calls

### 7.3 State Ownership

For every piece of state, ask: **who owns it?**

- **Session state** (per-screen, per-flow) → owned by the screen's business owner
- **Shared cross-screen state** → owned by an explicit shared component injected at composition root
- **Process-wide cached state** → owned by a singleton living at the composition root, accessed only via protocol

Avoid:

- Global mutable singletons of business data
- Ambient state in static properties
- "Manager" classes that hold state for unrelated capabilities

### 7.4 Presentation Mapping is Single-Source

The transformation from domain data to display data has **exactly one owner per screen**. That owner produces an immutable view model. The view renders the view model and nothing else.

---

