# BROWNFIELD_MIGRATION — adopt Boardy+VIP into an existing iOS app

> **Purpose**: step-by-step procedure for moving a legacy UIKit (or mixed UIKit/SwiftUI) iOS app to the Boardy+VIP architecture this pack codifies. Optimized for incremental adoption — never big-bang.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a procedural runbook, same as `DECISION_TREES.md` / `ADOPTION.md`.
>
> **Read first**: `BOARDY_FOUNDATIONS.md`, `DECISION_TREES.md`, `ARCHITECTURE.md`.

---

## When this guide applies

You have an existing iOS app that:

- Is not built on Boardy yet (or uses Boardy ad-hoc without the IO/Plugins split).
- Has UIKit code, possibly mixed with SwiftUI, possibly with Storyboards/segues.
- Has feature code organized by file-type folders (`Views/`, `Controllers/`, `Services/`) rather than by feature module.
- You want to migrate without halting shipping.

If you're starting a greenfield app, use `GREENFIELD_SETUP.md` instead — it has the new-app version of the same phases (workspace shell → bootstrap → first module → app entry → CI → release).

---

## Preconditions — verify before starting

| Check | How |
|-------|-----|
| Git repo with clean working tree | `git status` — commit or stash before touching pack files |
| Dependency manager identified | Look for `Podfile` / `Package.swift` / `Project.swift` (Tuist) / `BUILD` (Bazel). Pack is CocoaPods-pinned today — see `PACKAGE_MANAGER.md` |
| Workspace builds green | `xcodebuild build ... | grep BUILD` — don't start migrating on a broken main |
| Boardy version pinned | The pack assumes the Boardy pin documented in `BOARDY_FOUNDATIONS.md`. If the project already uses a different Boardy version, decide upgrade-first vs adopt-at-current — *do not migrate while the pin is in flux* |
| Team alignment | The migration touches ownership boundaries. Confirm whoever maintains the legacy screens is aware before porting them |

If any check fails, stop and resolve first. Migrating onto an unstable base is the most common cause of "pack feels wrong" reports.

---

## Phase 0 — inventory + first-screen pick

Goal: pick exactly ONE screen to port first. The wrong first pick (too complex, too central, too coupled) will sour the team on the pack.

### Inventory

Walk the project and tag each screen / feature flow with three numbers:

| Dimension | Score 1 (good first pick) | Score 5 (avoid) |
|-----------|---------------------------|------------------|
| Fan-in    | One entry point | Many call sites across the app |
| Fan-out   | Calls 0–1 services | Calls 4+ services / SDKs / global state |
| Coupling  | No shared mutable state | Reads/writes `AppDelegate` / global singletons |

Total ≤ 5 → great first candidate. Total ≥ 10 → migrate this last.

### Best first-screen archetypes

- Settings sub-screens (low fan-in, mostly local state)
- One-off prompts/dialogs (rate-app, force-update banner) — port as `viewless` Board
- A self-contained onboarding step (e.g. "pick grade")
- A modal that returns one value (date picker wrapper, image picker delegate)

### Worst first-screen archetypes

- Home / Dashboard / Tab roots (high fan-in, often own navigation)
- Anything that owns `UINavigationController` for the rest of the app
- Anything with Storyboard segues to N other screens
- Login flow (high coupling to global auth state)

---

## Phase 1 — install the pack

```bash
# At repo root:
git submodule add <pack-remote> .standards
./.standards/bin/bootstrap.sh --remote=<pack-remote>
```

After bootstrap:

1. Open `.claude/project/PROJECT_CONFIG.md` — fill in `{ProjectName}`, `{Workspace}`, `{MainScheme}`, `{Simulator}`, `{Destination}`, etc.
2. If your modules don't live under `submodules/`, set `Module root` to the actual path.
3. Commit: pack content is symlinked from `.standards/` (default); a `--mode=copy` install is also supported if your CI can't follow symlinks.
4. Open `.claude/rules/QUICK_REF.md` — this is your daily routing entry-point.
5. Open `.ai/specs/DECISION_TREES.md` — the "which pattern do I need" navigator.

Verify:

```bash
./.standards/bin/audit-pack.sh
# Expect: spec_doc_lint OK
```

---

## Phase 2 — first module + first Board

Goal: prove the pack works in your project before touching more than one screen.

### Step 1 — Decide the module shape

Use Tree §1 in `DECISION_TREES.md`: typical answers per archetype:

| Archetype | Board type | Module |
|-----------|-----------|--------|
| Settings sub-screen | `ui` | `Settings` |
| Rate-app prompt | `viewless` | `AppRating` |
| Onboarding step | `ui` (if has screen) or `viewless` | `Onboarding` |
| Force-update banner | `flow` orchestrating a child `ui` Board | `AppUpdate` |

### Step 2 — Scaffold

```bash
./.standards/bin/new-module.sh <Module> --module-root=<your-module-root>
./.standards/bin/new-board.sh  <Module> <Board> <ui|viewless|flow|blocktask>
```

This produces:
- Two podspecs: `{Module}.podspec` (interface) + `{Module}Plugins.podspec` (impl).
- IO trio for the Board (`IO/{Board}/`).
- Sources skeleton for the chosen type (`Sources/Microboards/{Board}/`).
- `Sources/Plugins/{Module}ModulePlugin.swift` with a `ServiceType` enum + `build(motherboard:)` stub.

### Step 3 — Wire the podspecs

Add to `Podfile`:

```ruby
pod '{Module}',        :path => '{module-root}/{Module}'
pod '{Module}Plugins', :path => '{module-root}/{Module}'
```

Then `pod install`. If the build breaks, fix it before continuing — don't pile on more modules on a broken base.

### Step 4 — Port the legacy screen INTO the Board

The mechanical part:

| Legacy artifact | New home |
|-----------------|----------|
| `UIViewController` subclass body | `{Board}ViewController.swift` (keep view code intact at first) |
| Methods that fire actions ("user tapped X") | Extract to `{Board}Interactable` protocol; route via `interactor.didTapX(...)` |
| Methods that render state | Extract to `{Board}Viewable` protocol; render via `view.setState(...)` |
| Business logic in the VC | Move to `{Board}Interactor` |
| Network/service calls | Inject through Builder; call from Interactor |
| Navigation pushes | Become `sendOutput(...)` / `flowAction(...)` from the Board |

**Critical**: at this stage, do NOT also refactor the view code. Get the VIP cut working with the *same* views and *same* business logic — then optimize.

### Step 5 — Activate the Board from legacy code

Until the whole app is on Boardy, you need a bridge. Two options:

**Option A — Adapter VC (recommended first)**
Wrap activation in a free function returning a UIViewController:

```swift
// In your legacy navigation code:
let vc = AppDelegate.shared.serviceMap
    .mod{Module}Plugins
    .io{Board}
    .activation
    .makeAdapterViewController(with: {Board}Input(...))
navigationController.pushViewController(vc, animated: true)
```

This lets legacy `UINavigationController` keep ownership while the screen content runs through Boardy. See `EXAMPLES_VIP_BOARD.md` for the adapter pattern.

**Option B — Full motherboard activation**
Replace the legacy screen's host with a Boardy motherboard. Bigger lift; only do this once you have 3+ screens migrated and the legacy navigator is shrinking anyway.

### Step 6 — Verify

```bash
# Pack lints (run on your module root)
./.standards/bin/audit-pack.sh <module-root>

# Build
xcodebuild build ... | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"
```

Smoke-test the migrated screen end-to-end in the simulator before merging.

---

## Phase 3 — wire the LauncherPlugin

Once 1–2 modules exist, register them with the app's plugin host.

Find your app's plugin host (per `PROJECT_CONFIG.md` row "App plugin host" — typically `SceneDelegate.scene(_:willConnectTo:)` or `AppDelegate`).

```swift
let mainboard = FlowMotherboard(plugins: [
    {Module}LauncherPlugin(...),
    // future: AnotherModuleLauncherPlugin(...),
])
```

The `LauncherPlugin` for the module wires the `ModulePlugin` + any per-app-lifetime resources (analytics, repository singletons). See `EXAMPLES_PLUGIN.md`.

---

## Phase 4 — iterate

Now the boring part. For each subsequent screen:

1. Pick from inventory (lowest score first).
2. `new-board.sh` inside the module if it fits; else `new-module.sh` for a new module.
3. Port — same Phase 2 step 4 mechanics.
4. Update legacy callers to go through the new ServiceMap.
5. Delete the legacy code when no callers remain.
6. Run `audit-pack.sh <module-root>` before merge.

Aim for one screen per PR. Stack PRs against `main`; don't run a parallel "migration branch" that diverges for weeks.

---

## Common blockers and how to defuse them

| Blocker | Defusion |
|---------|----------|
| Storyboard segues | Replace the segue with a programmatic push/present from the Board's flow callback. Keep the storyboard for the VIEW XML only; load it via `UIStoryboard(name:bundle:).instantiateViewController(...)` inside the ViewController's setup |
| Global singletons read inside VC | Inject them through the Builder. Singleton stays — just stop touching it from the VC body |
| `UINavigationController` ownership | Until that screen migrates, keep the legacy navigator. The Board returns a `UIViewController` adapter; the legacy navigator pushes it |
| NSCoding-required objects | NSCoding survives. The pack only restructures *who calls whom*, not how objects serialize |
| Mixed UIKit + SwiftUI | SwiftUI views can live inside a `UIHostingController` returned by the Builder. The VIP cut sits *above* the hosting controller |
| Combine/RxSwift pipelines | Keep them inside the Interactor. The Board doesn't see them. Just be sure the `cancellables` / `disposeBag` releases when the Interactor releases (attachObject from the Board handles this) |
| Tests are coupled to the legacy VC | Add new tests at Interactor/Presenter level (see `TESTING.md`) and let the legacy tests die when the VC is deleted |

---

## Anti-patterns — what NOT to do

- **Don't big-bang.** Migrating all screens in one PR is the most common failure mode. Ship one screen, learn, then continue.
- **Don't refactor while porting.** Phase 2 step 4 is mechanical extraction. Refactoring the view code mid-port doubles the diff size and the review cost.
- **Don't create a "Common" module.** Cross-cutting types belong in the owning feature module's `IO/`. A `Common`/`Shared` sink module always grows into a god module. See `LAYERING.md` §Anti-patterns.
- **Don't import `{Other}Plugins` cross-module.** Lint blocks this; the Boundary is `{Other}` (IO target) only. See `forbidden_imports.swift` Rule 3.
- **Don't migrate the navigator first.** Migrating `AppDelegate` / root navigation early creates a chicken-and-egg between "Boardy works" and "every screen on Boardy". Let the navigator be the LAST migration.
- **Don't migrate code you're about to delete.** If a screen is scheduled for removal in the next quarter, leave it alone.
- **Don't migrate without a known target test.** If you can't smoke-test the migrated screen, you can't verify the port. Add a manual QA pass at minimum.

---

## Verification checklist (per migrated screen)

Before merging a port PR:

- [ ] `audit-pack.sh <module-root>` reports 0 violations for the touched module
- [ ] `xcodebuild build` reports `BUILD SUCCEEDED` for `{MainScheme}` AND the module's own scheme if one exists
- [ ] The migrated screen renders identically (or intentionally better) compared to pre-port
- [ ] All legacy entry points to the screen now go through `ServiceMap.mod{Module}Plugins.io{Board}` — no direct `{Board}ViewController()` calls
- [ ] If applicable: tests at Interactor / Presenter level for new logic
- [ ] PR description records "Migrated {Screen} from legacy {OldHost} to {Module}.{Board}" and lists deleted legacy files

---

## References

- `BOARDY_FOUNDATIONS.md` — mental model required before touching any Board code.
- `DECISION_TREES.md` — pick-a-pattern navigator. Tree §1 (Board type), §9 (brownfield first-step) most relevant here.
- `ADOPTION.md` — generic adoption checklist (covers greenfield too).
- `MODULE_CREATION.md`, `IO_INTERFACE.md` — module shape.
- `MICROBOARD_UI.md`, `MICROBOARD_NONUI.md` — Board shapes.
- `PLUGINS_INTEGRATION.md` — LauncherPlugin wiring.
- `EXAMPLES_VIP_BOARD.md`, `EXAMPLES_VIEWLESS_BOARD.md`, `EXAMPLES_NONUI_BOARDS.md` — code skeletons.
- `TESTING.md` — where to add tests during a port.
- `REVIEWER_CHECKLIST.md` — what reviewers look for on port PRs.
- `.claude/project/PROJECT_CONFIG.md` — project-specific values (workspace, module root, scheme).
