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

- Pre-existing architecture pins — Boardy + SiFUtilities are already approved; no re-evaluation each PR.
- Pure-Swift utilities (small functions, value types) — write inline.
- Internal modules from this repo — they're not third-party.

## Forces

- Native SDKs are versioned with the platform → fewer breakage vectors, no migration tax.
- Third-party adoption costs accumulate: dual maintenance, build time, security surface, opaque bugs.
- Vendor types in Domain bind business rules to the vendor's API — refactor cost compounds.
- "Small helper" libraries (3-line shims, leftpad-class) deliver near-zero value vs writing local Swift.
- Boardy + SiFUtilities are exceptions (architecture contract); other deps must justify themselves.

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
- Imports: vendor `import` statements appear ONLY in adapter file(s), never in Domain / BA.

## Communication

### Core rule

Prefer first-party platform SDKs and language-standard libraries before adding third-party deps. Use third-party only when it provides clear product or engineering value the built-in SDK cannot reasonably achieve.

### Decision order

1. Swift, Foundation, UIKit, Swift Concurrency, URLSession, Codable, XCTest, etc. — when sufficient.
2. Existing project-local abstractions already present in the app or module.
3. Add/keep a third-party dep ONLY when native is incomplete, risky, or materially more expensive.
4. Wrap third-party APIs at module boundaries — Domain + BA depend on Domain protocols, never vendor types.

### Allowed third-party criteria

A third-party dep is acceptable when ≥1 of:

- Already part of the architecture contract (Boardy, SiFUtilities).
- Infrastructure integration the platform SDK doesn't provide directly.
- Replaces substantial custom code with a stable, well-maintained implementation.
- Isolated behind Domain protocols or Infrastructure adapters.

### Layering rules

| Layer | Third-party rule |
|---|---|
| Domain | No third-party imports. Foundation only. |
| Business Application | Avoid third-party except already-approved architecture primitives (Boardy). |
| Infrastructure & UI | Third-party SDKs allowed ONLY behind adapters, DTOs, repositories, services, UI components. |
| Interface Module | Minimal surface — plain Swift types + Boardy IO contracts only. |

### Dependency review checklist

- [ ] Native SDK alternative was checked
- [ ] Existing project abstraction was checked
- [ ] Dep does NOT leak into Domain models or repository protocols
- [ ] Dep does NOT force consumers to import Implementation Modules
- [ ] Public IO types remain stable and vendor-neutral
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

- Native APIs (Swift Concurrency, URLSession async) compose cleanly with Boardy's MainActor model.
- Vendor SDKs often use callback-on-arbitrary-thread → adapter MUST hop to MainActor before crossing into BA / UI (see `MICROBOARD_NONUI.md` Concurrency).
- Adapter is the concurrency boundary as well as the API boundary.

## Composition

- Vendor adapter conforms to Domain protocol → BA UseCase depends on protocol → swapping vendors = swap adapter, no BA churn.
- Multiple vendors for one concern (analytics A + B) → either one adapter calling both, or `EXTENSIBLE_PROVIDER.md` pattern when interchangeable at launch.
- Adapter lives in Infra; if cross-module needed, expose Domain protocol via IO pod (Pattern A/B in `CROSS_MODULE_DI.md`).

## Lifecycle

- SDK init (e.g. `Firebase.configure()`) → in `LauncherPlugin.prepareForLaunching` `launchSettings:` block, runs once.
- Adapter instance — typically app-lifetime (shared on ModulePlugin) or per-Board depending on statefulness.
- Vendor session/handle objects — owned by adapter; not exposed to BA.
- Replacing a vendor → bump Infra adapter only; Domain + BA + IO unchanged.

## Testing

- Domain layer test: grep for `import Alamofire|GoogleSignIn|Firebase…` etc. under `Sources/Services/Domain/` — must be empty.
- BA layer: same grep across `Sources/Microboards/` excluding ViewController-only vendor UI components — should be near-empty.
- Adapter: unit test with vendor SDK in test mode OR with vendor mocked at adapter boundary; assert Domain protocol contract upheld.
- IO surface: visually scan `IO/**/*.swift` for vendor imports — must be zero.
- Podspec lint: `s.dependency` lines have no `:path` modifier (see `MODULE_CREATION.md`).
- Architecture lint (planned `forbidden_imports.swift`): codify Domain/BA vendor-import bans.

## Pitfalls

| Smell | Fix |
|---|---|
| Adding a library for a small helper | Write local Swift |
| Domain imports vendor SDK | Move vendor type to Infra; map to Domain model |
| Public IO exposes SDK-specific DTO | Expose plain Swift input/output |
| Feature module imports another module's Plugins target | Depend on Interface Module only |
| ViewController directly calls analytics / network SDK | Route View → Interactor → UseCase → Domain protocol → Infra adapter |
| Multiple vendors duplicated across modules | One shared adapter behind one Domain protocol; expose via IO |
| Vendor callback fires on background thread, results published as-is | MainActor hop inside adapter before crossing into BA |
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
