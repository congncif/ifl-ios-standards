# BROWNFIELD_MIGRATION — adopt Standards 1.0 incrementally

Use this runbook for an existing UIKit, SwiftUI, mixed, RIBs, or earlier Boardy app. Migration is a
strangler process: move one complete semantic slice behind a stable typed boundary, cut traffic over,
and retain a slice-level rollback until the replacement is proven.

Read `ADOPTION.md`, `ARCHITECTURE.md`, `DECISION_TREES.md`, and `IO_INTERFACE.md` first.

---

## 1. Establish the baseline

Use the consuming repository's own configuration and commands to record:

- current dependency and Boardy pins;
- app composition entry point and navigation ownership;
- module/target graph, especially IO-to-implementation leaks;
- canonical build/test/launch signals and the last known-good revision;
- each candidate flow's entry points, outputs, data writes, external effects, and callers.

Choose a first slice with low fan-in, bounded dependencies, a visible outcome, and a reversible route.
Avoid the app root, authentication root, shared navigator, or a flow already scheduled for deletion.

A good slice is not merely one screen file. It includes the intent entering the feature, the business
behavior, its display/output, and the integration route needed to observe it.

---

## 2. Transition from 0.18.x

Treat 0.18.x as a working source architecture, not as scaffolding to regenerate wholesale.

1. Keep the app building on its existing pins while Standards 1.0 guidance is introduced.
2. Move project-specific values and commands into the consuming repository's `CLAUDE.md` /
   `AGENTS.md` and normal project configuration.
3. Inventory existing Boards as: conforming; public-boundary defect; View-ownership defect; or legacy
   feature without a Boardy boundary.
4. Preserve compatible public BoardIDs and `Input`/`Output`/`Command`/`Action` types. Change a public
   contract only for a product or architecture need, not to make the migration look uniform.
5. Replace old tool-specific process instructions with provider-native Brain Flow. Do not carry
   forward pack-owned verifier scripts, receipts/manifests, evidence ledgers, or custom runtime state.
6. Migrate and remove compatibility code slice by slice. Delete obsolete copied guidance only after
   all active references point at Standards 1.0.

Do not combine a Standards 1.0 adoption with an unrelated Boardy upgrade. If a pin must change, make
its compatibility and rollback a separately owned semantic task.

Scaffolder changes from 0.18.x apply only to new destinations; never regenerate an existing module:

- `ifl-new-module` now emits only the three IO/Plugins source-boundary files. It no longer writes
  organization-specific Bazel/CocoaPods settings, fixed platform values, coverage targets, or fake
  tests. Add the sources through the consuming repository's build/package configuration.
- Module root must resolve from `CLAUDE.md` / `AGENTS.md`, the legacy project binding, or an explicit
  `--module-root`; there is no guessed `Features` fallback. Obsolete author/email flags are removed.
- `ifl-new-board ... ui` selects UIKit; `... swiftui` selects the equivalent SwiftUI hosting adapter.
- `... blocktask` emits `BlockTaskParameter` IO and a `BlockTaskBoard` factory, not the old
  flow-shaped placeholder. Replace its fail-fast body with owned async behavior before activation.

---

## 3. Define the slice boundary and rollback

Before editing production code, write down:

- entry intent and caller;
- observable success, empty, loading, and failure behavior;
- typed public IO and owning module;
- dependencies and side effects;
- old route, new route, cutover mechanism, and removal condition;
- rollback action and any data compatibility constraint.

Prefer a route switch, composition choice, or feature flag already owned by the app. A compatibility
bridge belongs in implementation/composition, not public IO. Give it one owner and a deletion
condition.

Rollback restores the complete semantic slice to its previous route. Do not selectively revert only
the View, Interactor, or module wiring while leaving incompatible contracts or writes behind. For
schema or durable-data changes, define backward compatibility or explicit forward recovery before
cutover.

---

## 4. Migrate one slice

### A. Preserve or introduce typed IO

Define `Input`, `Output`, `Command`, `Action`, display ports, and typed bus/delegate payloads at the
feature boundary. Keep the IO target public and minimal; keep concrete services, providers, adapters,
and Board construction in the implementation target. Other features import IO only.

Wrap legacy callbacks or routes behind an implementation adapter when needed. Do not expose strings,
dictionaries, `Any`, or legacy controller types as the new long-term contract.

### B. Move policy behind the boundary

Move business decisions into the Interactor/use case/domain path. Inject legacy services through
capability interfaces or implementation adapters. The Builder/composition root constructs concrete
dependencies; the View does not locate services or mutate shared business state.

### C. Apply one humble-View contract

The Presenter or equivalent mapper prepares display-ready semantic state, including user-facing
formatting. Views forward typed intent and render that state.

- **UIKit** — a `UIViewController` conforms to the display port and renders immutable state.
- **SwiftUI** — a MainActor presentation store conforms to the same display port; the `View` observes
  it and keeps `@State` limited to UX-local concerns.
- **Mixed UI** — adapt SwiftUI at the Boardy navigation boundary (for example with a hosting adapter)
  while retaining the same semantic state and intent types.

Views may select an already encoded presentation case and calculate geometry or visual interpolation.
They do not format raw/domain values, decide product policy, construct business dependencies, or turn
gesture details into untyped business events.

### D. Cut over one caller

Route one real legacy entry through the new IO. Translate the new output back to the old coordinator
only at the bridge while the surrounding flow remains legacy. Keep navigation ownership stable until
its own slice is migrated; do not make the root navigator the first conversion.

### E. Verify and retire

For executable changes, use the consuming repository's canonical checks plus a focused exercise of
the slice's entry, success, failure, output, and rollback route. Add code tests where behavior or risk
warrants them. Standards 1.0 does not supply a parallel verifier or CI gate.

After the new route is accepted and rollback conditions are met, remove dead callers, adapters, and
legacy implementation for that slice. Keep shared legacy infrastructure until its final consumer
moves.

---

## 5. Continue by dependency order

Migrate leaf flows before shared roots. A practical order is:

1. bounded modal/sub-screen;
2. feature-local services and child flows;
3. parent feature coordinator;
4. shared navigation and app composition root last.

Commit and release cadence are consuming-repository decisions. Keep each change reviewable and
reversible at a semantic boundary; do not maintain a long-lived all-or-nothing migration branch.

---

## 6. Brain Flow operation

Use provider-native Brain Flow in co-working mode when the team wants requirements and plan approval,
or auto mode when AI may make those gates. Both modes plan all semantic slices and their rollback,
execute continuously, and use one joined final AI consistency review for the complete plan.

Track progress in the approved plan or provider-native task state. Do not create migration receipts,
manifests, fingerprints, custom state machines, or per-slice review gates. The repository owns build,
test, configuration, CI, rollout, and operational observation.

---

## Slice completion checklist

- [ ] Entry, outcome, side effects, cutover, and rollback are explicit.
- [ ] Public IO and BoardIDs remain typed and intentionally compatible.
- [ ] Cross-module consumers import IO, never Plugins/implementation.
- [ ] UIKit/SwiftUI adapters render the same display-ready semantic state.
- [ ] Formatting and business decisions are outside the View; View state is UX-local only.
- [ ] One real caller uses the new route and the old path remains safely reversible until retirement.
- [ ] Repository-owned executable checks cover the risk; no pack-owned verifier or duplicate CI was
      introduced.
- [ ] Legacy code is removed only when no caller or rollback obligation still needs it.

## References

- `ADOPTION.md` — shared Standards 1.0 adoption contract.
- `GREENFIELD_SETUP.md` — new-app counterpart.
- `MICROBOARD_UI.md` — UIKit/SwiftUI adapter contract.
- `MODULE_CREATION.md`, `IO_INTERFACE.md` — module and public boundary shape.
- `COMMUNICATION.md`, `BUS_PATTERNS.md` — typed cross-board communication.
- `REFACTOR_PLAYBOOK.md` — structural moves after behavior is stable.
- `process/lean-verification.md` — semantic tasks and one final review.
