# ADOPTION — bring Standards 1.0 into an iOS repository

Use this guide to bind the generic Boardy+VIP standard to a consuming repository. Use
`GREENFIELD_SETUP.md` for a new app and `BROWNFIELD_MIGRATION.md` for an existing app, including an
app already using the 0.18.x pack.

The standard is provider-neutral. The consuming repository owns its project files, dependency pins,
build and test commands, configuration, CI, release policy, and exceptions.

---

## Adoption contract

Every adopted slice preserves these boundaries:

1. **Module boundary** — public IO and implementation remain separate. A feature imports another
   feature's IO target, never its Plugins/implementation target.
2. **Typed intent** — `Input`, `Output`, `Command`, `Action`, display ports, delegates, and typed buses
   carry intent. Do not replace them with string routes, dictionaries, notifications, or untyped
   callback payloads.
3. **One humble-View contract** — a Presenter or equivalent mapper prepares immutable, display-ready
   semantic state. UIKit and SwiftUI are rendering adapters over that state, not owners of product
   policy.
4. **View ownership** — a View may render presenter-encoded state and own transient UX-local state
   such as focus, selection highlight, gesture progress, disclosure, animation, and scroll position.
   Formatting raw/domain values, deriving product meaning, eligibility, pricing, retry, analytics, or
   navigation policy stays outside the View.
5. **Dependency direction** — domain and application policy remain independent of Boardy, UIKit,
   SwiftUI, networking, and persistence. Concrete dependencies are composed at an implementation or
   app composition boundary.

UIKit and SwiftUI may coexist board by board. Equivalent domain input must produce equivalent
semantic display state in either adapter.

---

## Bind the consuming repository

Record project-specific values in the repository's `CLAUDE.md` / `AGENTS.md` and ordinary project
configuration:

- workspace or project, schemes/targets, destinations, and module roots;
- package manager and dependency pins;
- naming prefix, app composition entry point, base branch, and remote;
- canonical build, test, format, generation, and launch commands;
- CI/release ownership and project-specific architecture exceptions.

Do not put those values in this pack. Do not make the pack invent a second command layer or CI policy.

---

## Adopt by semantic slice

A semantic slice is one complete observable behavior: one intent enters, policy runs, display and/or
output is produced, and ownership is clear. A file, layer, agent assignment, or generated artifact is
not a slice.

For each slice:

1. Describe its current entry, user-visible behavior, outputs, dependencies, and failure behavior.
2. Define the public typed IO and module ownership before changing implementation.
3. Choose a UIKit or SwiftUI rendering adapter and keep the shared humble-View contract.
4. Compose the implementation behind the IO boundary.
5. Route one real caller through the new slice while retaining a practical rollback path.
6. For executable changes, run the consuming repository's ordinary commands appropriate to the
   risk. Documentation-only changes do not require a build or test gate.
7. Remove the replaced path only after callers and outputs have moved and rollback conditions are
   satisfied.

Brownfield work uses a strangler migration: legacy and Standards 1.0 paths coexist only as long as a
specific slice needs the bridge. Greenfield work starts with one vertical slice and grows by the same
contract.

---

## Delivery mode

Use provider-native Brain Flow in either mode:

- **Co-working** — the user approves requirements and the complete plan before continuous execution.
- **Auto** — AI makes those gates and asks the user only for material ambiguity, missing authority, or
  a real blocker.

Both modes use the provider's native task/thread, delegation, approval, and continuity features. Keep
progress in the approved plan or provider-native task state, then perform one final joined AI
consistency review after the complete plan.

Do not add verifier/lint/smoke scripts to this pack, receipt or manifest systems, fingerprints,
evidence ledgers, custom workflow kernels, or provider-independent runtime state. The consuming
repository's existing commands and CI remain the executable signal.

---

## Adoption is complete when

- [ ] Project bindings and canonical commands live in the consuming repository.
- [ ] Each migrated or new feature exposes typed IO and hides implementation.
- [ ] Cross-feature imports stop at IO targets.
- [ ] UIKit and SwiftUI Views receive display-ready state and forward typed intent.
- [ ] Business formatting and decisions remain outside Views; View-owned state is UX-local only.
- [ ] Every brownfield slice has an explicit cutover and rollback decision.
- [ ] Executable changes were checked with repository-owned signals; docs-only work did not invent a
      build/test gate.
- [ ] No obsolete tool-specific adoption process or parallel workflow-state system remains active.

## References

- `BROWNFIELD_MIGRATION.md` — strangler migration and 0.18.x transition.
- `GREENFIELD_SETUP.md` — first vertical slice in a new app.
- `ARCHITECTURE.md` — runtime composition and humble-View rules.
- `IO_INTERFACE.md` — public typed contracts.
- `MICROBOARD_UI.md` — UIKit/SwiftUI rendering adapters.
- `LAYERING.md` — dependency direction and module ownership.
- `process/lean-verification.md` — provider-native plan-scale execution.
