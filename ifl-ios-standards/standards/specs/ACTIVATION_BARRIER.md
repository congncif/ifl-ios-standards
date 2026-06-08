<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Activation Barrier

> Reference: *Modern large-scale iOS app development* — Micro-services Composable pillar.
> Companion specs: `MICROBOARD_NONUI.md` (non-UI board variants), `PER_ACTIVATION_RESOURCES.md` (per-activation lifecycle), `COMMUNICATION.md` (`complete()` semantics), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When one board's activation must wait for another board to run first:

- Show an ad before a game session.
- Permission / consent check before opening a feature.
- Onboarding splash before the main flow.
- Paywall / subscription gate.
- Login wall before any protected screen.

## When NOT to use

- The gating logic is a synchronous predicate (feature flag, in-memory check) → branch inside the parent coordinator; no Boardy barrier needed.
- The gate must produce a value the gated Board consumes → `BarrierBoard` (typed) is for blocking-then-unblocking, not for piping data; use a parent coordinator that activates the producer first and passes its output as input.
- Chaining multiple barriers (A → B → C, all gating D) → not supported; promote to a Flow Board coordinator that orchestrates A, B, C explicitly.
- The "barrier" board never calls `complete()` → it cannot be a barrier; refactor it to terminate with `complete()` or use a different mechanism.

## Forces

- `complete()` defaults to `isDone: true`. There is no "block" signal — every `complete()` passes the gate. The barrier *runs* something; it doesn't conditionally veto.
- `.barrier(with:)` carries a typed input; `.barrier()` silently passes `Void`. Mismatched types fail the cast quietly and the barrier never activates — symptom is a hung gated Board.
- Scope `.application` shares one instance app-wide; `.mainboard` creates a fresh barrier per activation. Wrong scope = wrong lifecycle (e.g. ad shown once forever, or login wall persists state across users).
- Barrier output is a public contract when callers care about the outcome. Typed `Output` (enum) > `Void`.

## Files

This spec governs wiring inside existing Board files — no new file shape. Typical edits land in:

```
Sources/Microboards/{Gated}/{Gated}Board.swift       ← activationBarrier override
Sources/Microboards/{Barrier}/{Barrier}Board.swift   ← ensure every exit calls complete()
Sources/Microboards/{Barrier}/{Barrier}InOut.swift   ← typed Output enum if callers need result
```

If the barrier Board lives in another module:

```
{Gated}Plugins.podspec   ← s.dependency '{BarrierModule}'
{Gated}Board.swift       ← import {BarrierModule}
```

## Naming

- Gated Board: any UI / Viewless / Flow board.
- Barrier Board: any board that calls `complete()` at the end — typically a non-UI Show / Permission / Splash board.
- Output enum: `{Barrier}Result` — `.succeeded`, `.skipped`, `.notEligible`, `.failed` (project-tailor as needed).
- Input alias: `{Barrier}Input` — even when effectively `Void`, declare the named alias for type-contract alignment with `MainboardGenericDestination`.

## Communication

### Declaring the barrier on the gated Board

```swift
final class {Gated}Board: ModernContinuableBoard, GuaranteedBoard,
    GuaranteedOutputSendingBoard, GuaranteedActionSendingBoard, GuaranteedCommandBoard {

    func activate(withGuaranteedInput input: InputType) {
        // normal activation — runs only after barrier completes
    }

    func activationBarrier(withGuaranteedInput input: InputType) -> ActivationBarrier? {
        motherboard.serviceMap.mod{BarrierModule}
            .io{Barrier}
            .activation
            .barrier(scope: .mainboard, with: {Barrier}Input())   // ✅ typed input
    }

    func interact(guaranteedCommand _: CommandType) {}
}
```

### Scope choice

| Scope | Behavior | Use for |
|---|---|---|
| `.mainboard` | new `ActivatableBarrierBoard` per activation, self-destructs | per-session gates: ads, per-flow checks (default) |
| `.application` | one shared instance app-wide, reused forever | login wall, subscription gate, one-time onboarding |

### Input — `.barrier(with:)` vs `.barrier()`

```swift
// ✅ typed input — barrier activates properly
.barrier(scope: .mainboard, with: {Barrier}Input())

// ❌ when InputType ≠ Void → cast fails silently, barrier never runs
.barrier(scope: .mainboard)

// ✅ safe only when typealias {Barrier}Input = Void
.barrier(scope: .mainboard)
```

### Barrier Board exit — every path calls `complete()`

```swift
extension {Barrier}Board: {Barrier}Delegate {
    func finish(_ result: {Barrier}Result) {
        sendOutput(result)   // available to .flow listeners
        complete()           // ✅ always passes through, regardless of result
    }
}
```

### Typed barrier Output (when callers care)

```swift
// {Barrier}InOut.swift
public typealias {Barrier}Output = {Barrier}Result
public enum {Barrier}Result {
    case succeeded
    case skipped
    case notEligible
    case failed
}
```

All Controller exit paths route through `delegate?.finish(_ result:)` so the Board can `sendOutput(result)` before `complete()`.

### Listening to barrier output from a parent coordinator

```swift
private extension {Coordinator}Board {
    func registerFlows() {
        motherboard.serviceMap.mod{BarrierModule}Plugins
            .io{Barrier}.flow.addTarget(self) { target, result in
                switch result {
                case .succeeded: target.recordSuccess()
                default: break
                }
            }
        motherboard.serviceMap.mod{Module}Plugins
            .io{Gated}.flow.addTarget(self) { target, output in
                target.handleGatedOutput(output)
            }
    }
}
```

### Decision tree

```
Need Board A to run before Board B?
├── A calls complete() on every exit path?
│   YES → set B.activationBarrier → ioA.activation.barrier(scope:, with:)
│   NO  → refactor A to call complete(), or use a Flow Board coordinator
│
Shared app-wide (login / subscription gate)?
├── YES → scope: .application
└── NO  → scope: .mainboard  (default)
```

## Concurrency

- `activationBarrier(withGuaranteedInput:)` is called by the framework on the main thread, just before the Board's `activate` would run.
- The barrier Board itself runs on the main actor; its `complete()` triggers the gated Board's `activate` synchronously on main.
- If the barrier wraps an async SDK callback, hop to MainActor before `sendOutput` + `complete()` (see `PER_ACTIVATION_RESOURCES.md`).
- Multiple gated Boards with `scope: .application` share one barrier instance — its state must be thread-safe or strictly main-actor-bound.

## Composition

- Cross-module dependency: gated Plugins podspec adds `s.dependency '{BarrierModule}'`; gated Board file adds `import {BarrierModule}`.
- The barrier IOInterface lives in the barrier owner's IO pod (`IO_INTERFACE.md`).
- Chaining barriers is unsupported — use a Flow Board coordinator that activates A, then B, then C, then the final target Board explicitly.

## Lifecycle

- `.mainboard` scope: barrier Board is instantiated per activation; `complete()` releases it.
- `.application` scope: one barrier instance survives the app; `complete()` resets its session-internal state but doesn't release the instance.
- Gated Board's `activate` runs exactly once per `activationBarrier` cycle — after `complete()`.
- Double-`complete()` raises an assertion (see `COMMUNICATION.md` Lifecycle).
- Barrier Board MUST `sendOutput(...)` BEFORE `complete()` if callers listen to `.flow`.

## Testing

- Barrier Board: standard board test surface — assert every exit path emits `sendOutput` then `complete()`.
- Gated Board: integration test that registers a fake barrier under the same `BoardID` and asserts gated `activate` runs after fake barrier's `complete()`.
- Flow handler on parent coordinator: integration test asserts barrier-result-dependent reactions fire.
- Scope behavior: identity test — activate two gated Boards with `.application` scope; assert the same barrier instance is used; with `.mainboard` scope, assert different instances.
- `.barrier(with:)` vs `.barrier()`: regression test asserting non-Void InputType requires `.barrier(with:)`.

## Pitfalls

- ❌ `.barrier()` with non-Void `InputType` → `()` cast fails silently; gated Board hangs forever.
- ❌ `scope: .application` for per-session gates → state leaks across sessions.
- ❌ Barrier Board with an exit path that skips `complete()` → gated Board never activates; user-facing hang.
- ❌ Chained barriers (`activationBarrier` on the barrier itself) → unsupported; promote to Flow Board coordinator.
- ❌ Registering barrier `.flow` listener inside `activate()` → `registerFlows()` must run from `init`; otherwise stacked handlers per activation.
- ❌ Using barrier to *produce* data the gated Board needs → barrier is a gate, not a pipe. Coordinate via parent Flow Board passing the producer's output as input.
- ❌ Forgetting `s.dependency '{BarrierModule}'` when barrier lives in another module → compile error or missing-registration crash.
- ❌ Double-`complete()` from two SDK callback paths → assertion; coalesce paths.

## References

- `MICROBOARD_NONUI.md` (`BarrierBoard` and surrounding non-UI variants)
- `COMMUNICATION.md` (`complete()` semantics + flow listeners)
- `PER_ACTIVATION_RESOURCES.md` (`attachObject` + concurrency for barrier services)
- `IO_INTERFACE.md` (barrier Output typing in the IO pod)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rule 14
