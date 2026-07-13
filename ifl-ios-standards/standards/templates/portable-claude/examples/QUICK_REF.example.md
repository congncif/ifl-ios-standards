<!-- template-version: 2.4.0 -->

# QUICK_REF.example.md — placeholder-only Boardy+VIP shape reference

> **Pattern-specific.** Generate a project `QUICK_REF.md` only when the consuming repository uses
> Boardy+VIP and needs project-local routing beyond the plugin skills. Replace placeholders from the
> repository; do not invent module names, prefixes, paths, build labels, dependencies, commands, or
> platform values. For another presentation pattern, generate that pattern's own concise routing file.

---

# QUICK_REF — Project Task Routing (Boardy+VIP)

Read root `CLAUDE.md` / `AGENTS.md` for project bindings, then use the matching plugin router/skill.
Do not copy plugin rules into this file.

---

## 1. Task Routing

| Task | Route |
|------|-------|
| End-to-end delivery | `/ifl-ios-standards:brain-flow` |
| Boardy+VIP task selection | `/ifl-ios-standards:boardy-vip` |
| New module | `/ifl-ios-standards:boardy-new-module` |
| New UIKit or SwiftUI board | `/ifl-ios-standards:boardy-new-board` |
| IO / BoardID / InOut / ServiceMap | `/ifl-ios-standards:boardy-io-interface` |
| Board communication / buses / flows | `/ifl-ios-standards:boardy-communication` |
| Domain / use case / repository / infrastructure | `/ifl-ios-standards:boardy-service-layer` |
| Plugin and app composition | `/ifl-ios-standards:boardy-plugin-composition` |
| Tests | `/ifl-ios-standards:boardy-testing` |
| Review | `/ifl-ios-standards:boardy-review` |
| Refactor | `/ifl-ios-standards:boardy-refactor` |
| Troubleshoot | `/ifl-ios-standards:boardy-troubleshoot` |
| Adopt Standards 1.0 | `/ifl-ios-standards:boardy-adopt` |
| Enterprise iOS concern | `/ifl-ios-standards:enterprise-ios` |

The enterprise router covers ten chapters: Swift 6 concurrency, SwiftUI production, data lifecycle,
mobile security, privacy/compliance, accessibility/global readiness, observability/operability,
modern testing, performance/resilience, and supply-chain/legal. Load only chapters intersecting the
task; keep organization-specific thresholds, legal decisions, vendors, contacts, and risk acceptance
in consuming-project governance.

---

## 2. Non-UI Board Decision Order

1. If a VIP UI board already owns the entry, let it coordinate via `registerFlows()`; add no wrapper.
2. One async task with a per-activation result → BlockTask Board.
3. Coordinator retains a child output for a later step → Viewless Board.
4. Stateless routing, reused entry, or conditional gate → Flow Board.

---

## 3. Naming Formulas

| Concept | Formula |
|---------|---------|
| Complete module name | `{ModuleName}` from project/task binding; optional prefix is repository-owned |
| Public BoardID literal | `pub.mod.{ModuleName}.{BoardName}` |
| Board | `{BoardName}Board` |
| Builder | `{BoardName}Builder` |
| Interactor | `{BoardName}Interactor` |
| Presenter | `{BoardName}Presenter` |
| UIKit adapter | `{BoardName}ViewController` |
| SwiftUI adapter | `{BoardName}View` + `{BoardName}PresentationStore` + hosting controller |
| Use-case protocol | `{Action}UseCase` |
| Use-case implementation | `{Action}UseCaseInteractor` |

VIP class names do not inherit an optional organization module prefix. Resolve any real prefix from
project bindings; never manufacture one from an example.

---

## 4. Protocol Placement

| Protocol | Declaration owner | Typical conformer |
|----------|-------------------|-------------------|
| `{BoardName}Interactable` | View adapter file | Interactor |
| `{BoardName}Presentable` | Interactor file | Presenter |
| `{BoardName}Viewable` / display port | Presenter file | UIKit controller or MainActor SwiftUI store |
| `{BoardName}Controllable` | protocols file | Interactor or viewless controller |
| `{BoardName}ActionDelegate` | protocols file | Board |
| `{BoardName}ControlDelegate` | protocols file | Board |
| `{BoardName}UserInterface` | protocols file | View adapter |
| `{BoardName}Buildable` | protocols file | Builder |

Use the current plugin cheatsheet/spec as authority when it differs from this shape reference.

---

## 5. UIKit / SwiftUI Humble-View Contract

The Presenter prepares one immutable, display-ready semantic state for both frameworks.

- A View may branch on a Presenter-encoded loading/content/empty/error phase.
- A View may own focus, highlight, gesture, animation, scroll, disclosure, geometry, and visual
  interpolation state.
- A View never formats raw/domain dates, currency, quantities, labels, or errors; derives product or
  analytics meaning; chooses eligibility, pricing, retry, CTA, or business navigation; performs
  business I/O; or constructs business dependencies.
- UIKit renders through a display port and forwards typed intent.
- SwiftUI observes a MainActor presentation store conforming to the same semantic display port;
  `@State` remains UX-only.
- Identical domain input yields equivalent semantic display state for UIKit and SwiftUI. Layout and
  framework-local interaction mechanics may differ.
- Boardy still composes a `UIViewController` navigation surface; SwiftUI adapts at that boundary.

---

## 6. Core Boardy+VIP Rules

1. Flow is View → Interactor → UseCase → Presenter → View. Pure navigation intent may go directly
   from View to the Board action delegate.
2. IO declarations are public and vendor-free. `Sources/**` is internal except the minimum justified
   app-composition surface under `Sources/Plugins/**`.
3. Feature consumers import another module's public IO contract, never its Plugins implementation.
4. Presenter view, Interactor delegate, and View action delegate references are weak.
5. Call `registerFlows()` in Board initialization, never activation.
6. Add a double-activation guard only for an explicitly single-session Board.
7. Board-to-controller communication uses event buses, not a retrieved controller reference.
8. Keep shared repositories at module/plugin lifetime, outside registration closures.
9. Call `complete()` at most once and only after owned streams/observers are released; a BlockTask
   Board does not call it manually.
10. UI/presentation mutation runs on the declared MainActor boundary.

---

## 7. Source-Only Scaffold Shape

`ifl-new-module` emits the minimal source boundary under the repository-owned module root:

```text
{ModuleRoot}/{ModuleName}/
├── IO/
│   └── {ModuleName}ServiceMap.swift
└── Sources/
    └── Plugins/
        ├── {ModuleName}PluginsServiceMap.swift
        └── {ModuleName}ModulePlugin.swift
```

`ifl-new-board` adds public files under `IO/{BoardName}/` and implementation files under
`Sources/Microboards/{BoardName}/`. Its selectors are `ui`, `swiftui`, `viewless`, `flow`, and
`blocktask`.

Both scaffolders are additive and fail on existing destinations. They resolve the module root from
root `CLAUDE.md`, then `AGENTS.md`, unless an explicit `--module-root` is supplied. They emit no
build/package files, target labels, dependencies, platform/deployment values, resources, tests,
commands, or CI. The consuming repository integrates generated sources and adds tests only for real
observable behavior.

---

## 8. Provider-Native Delivery

- Canon Rules/Profiles and accepted ADRs are normative; this quick reference is optional routing
  guidance for a project that selected Boardy+VIP.
- Brain Flow supports co-working and auto mode with one requirements decision and one plan decision.
  Co-working includes human product, architecture, policy, plan, and finding-disposition decisions.
- After eligibility and authority preflight, auto mode proceeds without routine wait/confirm/ask
  pauses and interrupts only for a material blocker defined in `PROJECT_CONFIG.md`.
- Execute the complete approved plan before exactly one joined final AI consistency review.
- Resume/handoff location and final finding disposition authority come from `PROJECT_CONFIG.md`.
- Scoped auto-commit may authorize local stage+commit for conforming semantic tasks only; all other
  Git/external effects remain separately governed.
- Full-auto ends at engineering completion and release readiness; it never implies push, tag,
  publish, install, release, or production rollout.
- Use repository-owned code tests and CI. Do not add verifier/lint/smoke scripts, receipts, manifests,
  fingerprints, evidence ledgers, custom workflow state, or per-workstream review gates.
