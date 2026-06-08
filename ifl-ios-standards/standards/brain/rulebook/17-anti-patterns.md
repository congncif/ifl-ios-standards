<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.1 · last-updated: 2026-05-23 -->

# 17. Anti-Patterns

### 17.1 Architectural Anti-Patterns

| Anti-pattern | Why it breaks the system | Replacement |
|--------------|--------------------------|-------------|
| God module | Owns multiple capabilities, becomes a merge magnet | Split by capability |
| Utility module imported by everyone | Triggers global rebuilds; hides taxonomies | Decompose by concept |
| Singleton with business state | Hidden coupling, untestable, lifecycle-fragile | Owned component, DI |
| Service locator in business code | Hidden dependencies | Constructor injection |
| Domain importing UIKit | Couples business to UI framework | Move UI types to presentation |
| Codable on domain models | Couples domain to serialization | DTO + mapper |
| Implementation module imported across features | Breaks interface boundary | Depend on contract module |
| Vendor type in public interface | Couples consumers to vendor | Wrap in plain Swift type |
| Public extension on third-party type in interface | Pollutes consumer namespace | Keep extension internal |

### 17.2 Code-Smell Anti-Patterns

| Smell | Fix |
|-------|-----|
| 500-line file with mixed responsibilities | Split by responsibility |
| `Manager` / `Helper` / `Util` class names | Rename for actual responsibility, or delete |
| Identical code in three feature modules | Extract to shared module |
| Optional everywhere "just in case" | Model the actual states |
| `try?` swallowing errors silently | Handle or propagate |
| `// TODO:` without ticket reference | File a ticket or delete the comment |
| Commented-out code | Delete; trust version control |

### 17.3 Boardy Lifecycle & Communication Anti-Patterns

| Anti-pattern | Why it breaks the system | Replacement |
|--------------|--------------------------|-------------|
| Storing Controller as a Board stored property | Re-activation creates a new Controller; the old reference collides with the new one on every bus fire | `attachObject(controller, context:)` + bus-based communication |
| Binding Board lifecycle to Controller (e.g. `complete()` when a context VC dies) | Reverses ownership — Board outlives or pre-dates Controller, never the other way around | Board owns Controller; pick the right attach context (input → root → board) |
| `attachObject(controller)` with no `context:` when a natural owner exists | Controller's lifetime drifts onto Board's; easy to leak across re-activations | Priority 1 — explicit `input.context`; Priority 2 — `rootViewController`; Board context is last resort |
| `Bus<Void>` + `guard target === component.controller` captured from `activate()` scope | The closed-over local is per-*activation*, not per-*event* — a stale source still passes the guard | Carry the source in the bus payload: `Bus<{Name}Controllable>` + `guard target === source` |
| `attachedObject(_:)` to fabricate a "source" for a Board-originated bus | That's a retrieved controller reference — explicitly forbidden | Plain `Bus<Void>`; rely on `bus.connect(target:)`'s weak binding |
| `watch(content:)` retrieval used as a Board → Controller communication path | `watch` is a lifecycle marker, not a channel | Bus<T> for all Board → Controller side-effects |
| Two exit paths each calling `complete()` | Double-`complete()` raises an assertion | Converge exits through one `Bus<Result>` consumed once |
| Treating context type as `UIViewController` only | Misses non-VC anchors (session managers, coordinators) | Attach context is `AnyObject` — UIViewController is the common case, not the constraint |
| Reaching for `UINavigationController` wrapping or `topPresentViewController` by reflex | Bypasses the project's navigation default for no reason | `rootViewController.show(_:)` first; deviate only for SiFUtilities-unsupported transitions or Composable embedding |

### 17.4 Process Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| "I'll add an abstraction now in case we need it" | Add it when the second concrete need arrives |
| "Let me also clean up while I'm here" | Open a separate task |
| "Tests are slow, I'll add them later" | Tests written later get written never |
| "This worked locally, ship it" | Verify in CI before merging |
| "The build looks fine" (empty grep output) | Empty output is failure, not success |

---

