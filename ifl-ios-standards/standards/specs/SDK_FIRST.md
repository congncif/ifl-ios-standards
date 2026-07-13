<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: SDK-First (Platform-Native Dependency Standard)

> Reference: *Modern large-scale iOS app development* — SDK-first pillar.
> Companion specs: `LAYERING.md` (where adapters belong), `MODULE_CREATION.md` (podspec dependency rules), `IO_INTERFACE.md` (vendor-neutral surface), `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded).

## When to use

When evaluating a new dependency, infrastructure integration, or third-party framework. Specifically:

- Adding a pod / Swift Package to a podspec.
- Choosing between native API and a popular library (e.g. URLSession vs Alamofire).
- Introducing an analytics / push / persistence / image SDK.
- Reviewing a PR that imports a non-first-party module.

## When NOT to use

- A dependency already governed by the selected Profile and a current project policy binding does not
  need a fresh product-selection debate in every PR. Compatibility, security, ownership, and correct
  layer placement still apply when the dependency or its use changes.
- Pure-Swift utilities (small functions, value types) — write inline.
- Internal modules from this repo — they're not third-party.

## Forces

- Native SDKs are versioned with the platform → fewer breakage vectors, no migration tax.
- Third-party adoption costs accumulate: dual maintenance, build time, security surface, opaque bugs.
- Vendor types in Domain bind business rules to the vendor's API — refactor cost compounds.
- "Small helper" libraries (3-line shims, leftpad-class) deliver near-zero value vs writing local Swift.
- A Profile may select an orchestration framework such as Boardy at its adapter shell; that selection
  does not create a general vendor exception for Domain or Application code and does not pre-approve
  unrelated utility libraries.

## Files

Governance spec — no file shape produced. Affects:

```
{ModuleName}.podspec                       ← s.dependency entries
{ModuleNamePlugins}.podspec                ← s.dependency entries
{ModuleRoot}/{ModuleName}/Sources/Services/Infra/{Vendor}Adapter.swift   ← where adapters live
```

## Naming

- Adapter: `{Vendor}{Concern}Adapter` (e.g. `FirebaseAnalyticsAdapter`) — lives in `Sources/Services/Infra/` or `Sources/Services/Tracking/`.
- Domain protocol the adapter implements: `{Concern}Service` / `{Concern}Repository` (vendor-neutral).
- Imports: vendor `import` statements appear only in adapter files, never in Domain/Application policy.

## Communication

### Core rule

Prefer first-party platform SDKs and language-standard libraries before adding third-party deps. Use third-party only when it provides clear product or engineering value the built-in SDK cannot reasonably achieve.

### Decision order

1. Swift, Foundation, UIKit, Swift Concurrency, URLSession, Codable, XCTest, etc. — when sufficient.
2. Existing project-local abstractions already present in the app or module.
3. Add/keep a third-party dep ONLY when native is incomplete, risky, or materially more expensive.
4. Wrap third-party APIs at outward module boundaries — Domain and Application depend on inward-owned
   protocols, never vendor types.

### Allowed third-party criteria

A third-party dependency is a candidate for approval when at least one of these is true and project
policy accepts its ownership, maintenance, security, and compatibility posture:

- The selected Profile requires it at a declared outward adapter boundary (for example, Boardy in a
  `boardy-vip` orchestration/presentation shell).
- Infrastructure integration the platform SDK doesn't provide directly.
- Replaces substantial custom code with a stable, well-maintained implementation.
- Isolated behind Domain protocols or Infrastructure adapters.

### Layering rules

| Layer | Third-party rule |
|---|---|
| Domain | No third-party imports. Foundation only. |
| Application / business policy | No orchestration, UI, persistence, networking, or utility-framework imports; depend on inward-owned protocols (`CORE-DEP-002`). |
| Orchestration / presentation adapter | A selected Profile may use its framework here (for example Boardy), while depending inward on Application/Domain contracts. |
| Infrastructure & UI | Third-party SDKs allowed ONLY behind adapters, DTOs, repositories, services, UI components. |
| Interface Module | Minimal technology-neutral surface by default; framework types appear only when a selected Profile explicitly owns that public contract (for example Boardy IO under `boardy-vip`). |

### Dependency review checklist

- [ ] Native SDK alternative was checked
- [ ] Existing project abstraction was checked
- [ ] Dep does NOT leak into Domain models or repository protocols
- [ ] Dep does NOT force consumers to import Implementation Modules
- [ ] Public IO types remain stable and technology-neutral except for framework types explicitly owned
      by the selected public-contract Profile
- [ ] Podspec entry uses dep NAME only; local paths stay in Podfile
- [ ] Build impact and maintenance ownership acceptable

### Decision tree

```
Need new capability?
├── Native SDK suffices? → use it
├── Project-local abstraction exists? → reuse it
└── Need 3rd-party?
    ├── Meets ≥1 "allowed criteria"? → wrap in Infra adapter
    └── No                            → write local Swift
```

## Concurrency

- Native APIs (Swift Concurrency, URLSession async) keep Application contracts independent of the
  selected orchestration adapter.
- Vendor SDKs often use callback-on-arbitrary-thread → the adapter must cross the actor boundary
  required by its inward contract before publishing to presentation/UI. Boardy-specific MainActor
  behavior applies only when the `boardy-vip` Profile is selected.
- Adapter is the concurrency boundary as well as the API boundary.

## Composition

- Vendor adapter conforms to an inward-owned protocol → Application UseCase depends on that protocol → swapping vendors changes only the adapter.
- Multiple vendors for one concern (analytics A + B) → either one adapter calling both, or `EXTENSIBLE_PROVIDER.md` pattern when interchangeable at launch.
- Adapter lives in Infra; if cross-module needed, expose Domain protocol via IO pod (Pattern A/B in `CROSS_MODULE_DI.md`).

## Lifecycle

- SDK init (e.g. `Firebase.configure()`) → at the consuming app's declared launch/composition root,
  exactly once. With `boardy-vip`, that may be the `LauncherPlugin.prepareForLaunching`
  `launchSettings:` block; non-Boardy projects use their bound application lifecycle owner.
- Adapter instance — typically app-lifetime under the declared composition owner. With `boardy-vip`,
  that may be a stored `ModulePlugin` dependency or an explicitly activation-scoped adapter.
- Vendor session/handle objects — owned by adapter; not exposed to Domain/Application.
- Replacing a vendor → change the Infra adapter only; Domain/Application and technology-neutral IO
  remain unchanged. A Profile-owned framework contract changes only through that Profile's governance.

## Testing

- Domain layer test: grep for `import Alamofire|GoogleSignIn|Firebase…` etc. under `Sources/Services/Domain/` — must be empty.
- Application layer: imports of Boardy, UIKit, networking, persistence, and vendor/utility frameworks
  under `Sources/Services/Application/` must be empty.
- Adapter: unit test with vendor SDK in test mode OR with vendor mocked at adapter boundary; assert Domain protocol contract upheld.
- IO surface: ordinary vendor imports must be zero. Permit only framework imports explicitly owned by
  the selected public-contract Profile, such as Boardy in Boardy IO.
- Podspec lint: `s.dependency` lines have no `:path` modifier (see `MODULE_CREATION.md`).
- Final architecture review: confirm Domain and Application policy contain no vendor imports; Profile
  frameworks are confined to their declared outward adapters.

## Pitfalls

| Smell | Fix |
|---|---|
| Adding a library for a small helper | Write local Swift |
| Domain imports vendor SDK | Move vendor type to Infra; map to Domain model |
| Public IO exposes SDK-specific DTO | Expose plain Swift input/output |
| Feature module imports another module's Plugins target | Depend on Interface Module only |
| ViewController directly calls analytics / network SDK | Route View → Interactor → UseCase → Domain protocol → Infra adapter |
| Multiple vendors duplicated across modules | One shared adapter behind one Domain protocol; expose via IO |
| Vendor callback fires on an arbitrary thread and crosses its contract unsafely | Cross to the actor declared by the inward contract inside the adapter |
| `s.dependency '{Vendor}', :path => '.'` in podspec | NAME only; paths belong in Podfile |

## References

- `LAYERING.md` (where adapters belong)
- `MODULE_CREATION.md` (podspec dependency rules)
- `IO_INTERFACE.md` (vendor-neutral public surface)
- `SERVICE_LAYER.md` (adapter/Infra patterns)
- `EXTENSIBLE_PROVIDER.md` (multiple interchangeable SDKs)
- `CROSS_MODULE_DI.md` (sharing Domain protocols across modules)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rule 1
