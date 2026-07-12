# GREENFIELD_SETUP — start an app on Standards 1.0

Use this runbook for a new iOS app with no legacy behavior to preserve. Establish one thin app shell
and one complete Boardy+VIP semantic slice before adding more features.

Read `ADOPTION.md`, `ARCHITECTURE.md`, `DECISION_TREES.md`, and `IO_INTERFACE.md` first.

---

## 1. Bind the repository

The consuming repository chooses and records:

- Xcode project/workspace or generated-project strategy;
- UIKit, SwiftUI, or mixed app entry lifecycle;
- package manager, Boardy/dependency pins, and module root;
- optional app/module type naming prefix; public BoardIDs always use the canonical
  `pub.mod.<Module>.<Board>` literal;
- app composition root and ownership of navigation;
- canonical generation, build, test, format, and launch commands;
- CI, release, security, and project-specific governance.

Put these values in `CLAUDE.md` / `AGENTS.md` and normal project configuration. Keep them out of the
generic pack. First make the repository's minimal app shell build and launch using its own commands.

---

## 2. Establish the architecture seams

Create only what the first feature needs:

1. a thin app composition root that installs feature implementations and activates the initial flow;
2. one feature IO target containing public BoardIDs and typed contracts;
3. one feature implementation target containing Board, VIP roles, providers, and adapters;
4. domain/application types that do not import Boardy, UIKit, SwiftUI, networking, or persistence;
5. dependency adapters composed at the implementation or app boundary.

Other features may depend on the IO target. They must not import the implementation/Plugins target.
The app shell coordinates composition and lifecycle; it does not become a home for feature policy.

---

## 3. Build the first semantic slice

Pick a small but complete launch, onboarding, or bounded feature behavior. Define:

- the user/system intent that enters;
- the typed `Input`, `Output`, `Command`, and `Action` needed at the public boundary;
- the success, loading, empty, and failure semantics;
- the dependencies and side effects;
- the parent flow that consumes the output.

Implement in this order:

1. public IO and module ownership;
2. domain/use-case behavior and dependency capabilities;
3. Interactor and Presenter/equivalent mapping;
4. display port and immutable display-ready semantic state;
5. UIKit or SwiftUI rendering adapter;
6. Board/Builder wiring and app composition;
7. activation from the real parent flow and typed output handling.

Do not create placeholder modules, a broad `Common` module, or every future plugin up front. Grow the
graph from real semantic ownership.

---

## 4. Choose rendering per Board

Boardy+VIP supports UIKit and SwiftUI as equivalent rendering adapters under one humble-View
contract. The app does not need one framework choice for every feature.

### UIKit adapter

The Presenter sends immutable display-ready state through a display port. The
`UIViewController` renders it and forwards typed intent.

### SwiftUI adapter

A MainActor presentation store conforms to the same display port and publishes the same semantic
state. The SwiftUI `View` observes it and forwards typed intent. `@State` is limited to transient
UX-local concerns such as focus, gesture/animation progress, disclosure, and scroll position.

### Shared rule

Equivalent domain input produces equivalent semantic display state. User-facing formatting, product
meaning, eligibility, pricing, retry, analytics, navigation policy, dependency construction, and
business data access remain outside both Views. Views may select presenter-encoded presentation cases
and perform geometry-only or visual interpolation calculations.

---

## 5. Prove the vertical slice

For executable code, use the repository's ordinary commands and focused runtime exercise to show:

- app composition resolves the feature implementation;
- the public BoardID and typed IO activate correctly;
- intent reaches the Interactor/use case and display-ready state reaches the adapter;
- the parent consumes typed output;
- success and relevant failure behavior are observable;
- module dependencies stop at the intended IO boundary.

Add tests where behavior or regression risk warrants them. The standard does not provide verifier,
lint, smoke, receipt, manifest, or duplicate CI machinery. Documentation-only work has no build/test
gate. CI remains wholly owned by the consuming repository.

---

## 6. Scale by semantic ownership

For each next feature:

1. decide whether it belongs in an existing module or owns a new public capability;
2. define typed IO before implementation;
3. add the smallest complete semantic slice;
4. compose concrete dependencies at the owning boundary;
5. choose UIKit or SwiftUI without changing the humble-View contract;
6. activate from a parent flow and consume typed output;
7. use repository-owned executable signals appropriate to the risk.

Extract shared capability interfaces only when multiple real consumers establish the ownership. Do
not use a `Common` module to bypass module design.

---

## 7. Brain Flow operation

Use provider-native Brain Flow in co-working mode for user-approved requirements and plan, or auto
mode for AI-owned gates with escalation only for material ambiguity, missing authority, or a real
blocker. Both modes use one complete plan, continuous execution, and one joined final AI consistency
review after the plan.

Use the approved plan or provider-native task state for progress. Do not add custom workflow runtime
state, per-step receipts/manifests, or tool-specific installation checks to the app.

---

## Greenfield completion checklist

- [ ] Repository bindings, project commands, dependency pins, and CI ownership are explicit.
- [ ] The app shell builds/launches and contains composition, not feature policy.
- [ ] The first feature has separate IO and implementation targets.
- [ ] Public BoardIDs and intent/output channels are typed.
- [ ] Domain/application policy is independent of UI and infrastructure frameworks.
- [ ] UIKit or SwiftUI renders display-ready state under the same humble-View contract.
- [ ] Formatting and business decisions are outside the View; View state is UX-local only.
- [ ] One real parent activates the slice and consumes its output.
- [ ] Executable checks use repository-owned commands; no parallel verifier or CI system exists.

## References

- `ADOPTION.md` — shared Standards 1.0 adoption contract.
- `BROWNFIELD_MIGRATION.md` — existing-app and 0.18.x transition.
- `ARCHITECTURE.md` — runtime and dependency model.
- `MODULE_CREATION.md`, `IO_INTERFACE.md` — module and contract shape.
- `MICROBOARD_UI.md` — UIKit/SwiftUI rendering adapters.
- `PLUGINS_INTEGRATION.md` — composition-root wiring.
- `process/lean-verification.md` — provider-native plan-scale execution.
