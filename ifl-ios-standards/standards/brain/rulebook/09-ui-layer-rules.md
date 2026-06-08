<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# 9. UI Layer Rules

### 9.1 Humble View Principle

Views (UIKit or SwiftUI):

- **Render state** — receive an immutable view model and display it
- **Forward intents** — emit events when the user acts
- **Own zero business logic** — no branching on business conditions, no domain imports

If a view contains an `if-else` that depends on a business rule, the rule belongs in the business layer.

### 9.2 Presentation Pattern Agnosticism

This rulebook does **not** prescribe MVVM, MVP, MVI, TCA, or any other pattern. It prescribes the *properties* the chosen pattern must satisfy:

| Property | Why |
|----------|-----|
| View is replaceable without touching business logic | UIKit ↔ SwiftUI migration must be local |
| Business logic is testable without instantiating views | Test cost stays bounded |
| State flows in one direction | Predictability |
| The mapping from domain to view model has a single owner | Consistency |

Pick a pattern that satisfies these properties. Apply it consistently. Document it once.

### 9.3 SwiftUI vs UIKit

- Choose per screen, not per app. Mix freely.
- A `UIHostingController` is a legitimate composition seam.
- Avoid the temptation to abstract away the choice with a "universal" view protocol — it loses the benefits of both worlds.

### 9.4 UI–Business Boundary

The UI layer may import the business layer's *presentation contracts* (view model types, event types). It must **not** import use cases, repositories, or domain protocols directly. The business object adapts those for the view.

---

