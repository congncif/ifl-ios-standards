# GREENFIELD_SETUP — start a new iOS app on Boardy+VIP

> **Purpose**: step-by-step procedure for standing up a brand-new iOS app on this pack's Boardy+VIP architecture. Counterpart to `BROWNFIELD_MIGRATION.md` — that guide is for adopting the pack into a legacy codebase; this guide is for from-zero projects where you don't have legacy code pulling against you.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a procedural runbook, same as `DECISION_TREES.md` / `BROWNFIELD_MIGRATION.md`.
>
> **Read first**: `BOARDY_FOUNDATIONS.md`, `DECISION_TREES.md`, `ARCHITECTURE.md`.

---

## When this guide applies

You're standing up a NEW iOS app and intend to use this pack's architecture from day one:

- Empty repo (or a freshly-created Xcode project shell with nothing yet built).
- You've already decided on the architecture — no team-alignment phase needed.
- You want the pack wired in BEFORE writing the first feature, so feature work follows the pack's grain from the start.

If you have existing code to port, use `BROWNFIELD_MIGRATION.md` instead — the pacing, scoring, and adapter-VC bridge that guide describes do not apply here.

---

## Preconditions — verify before starting

| Check | How |
|-------|-----|
| Repo initialized | `git init` (or clone empty remote). Pack expects a git repo for `git submodule add` |
| Xcode + tooling installed | `xcode-select --print-path`, `xcodebuild -version`, `pod --version` |
| Dependency manager chosen | Pack is CocoaPods-pinned today — see `PACKAGE_MANAGER.md`. Confirm `pod` is on PATH |
| Boardy version pinned | The pack assumes the Boardy pin documented in `BOARDY_FOUNDATIONS.md` — record it in the new Podfile from day one |
| Naming decisions made | App name, bundle ID, optional module prefix (e.g. `DAD`), module-root convention (`submodules/` vs `Modules/`). Pick before scaffolding — these are baked into podspecs/imports |

If any check fails, stop and resolve. Greenfield setup is forgiving but the first 30 minutes set conventions you'll fight to change later.

---

## Phase 0 — Xcode project shell

Goal: create the smallest possible Xcode project that builds and launches, with NO feature code. Pack scaffolding will sit alongside this shell.

### Steps

1. **Create Xcode workspace**: `File → New → Workspace`, save as `{AppName}.xcworkspace` at repo root. The workspace is what CocoaPods integrates with — not a plain `.xcodeproj`.
2. **Create App project inside workspace**: `File → New → Project → iOS → App` (SwiftUI or UIKit lifecycle — UIKit recommended; SwiftUI is wireable via `UIHostingController` from a UI Board). Save as `{AppName}.xcodeproj` adjacent to the workspace.
3. **Add project to workspace**: drag the `.xcodeproj` into the workspace sidebar.
4. **Verify it builds + launches**: Cmd-R. You should see the default Hello-World screen. Commit this baseline before touching anything else.

### What NOT to do here

- Don't add features to the default `ViewController.swift` — it will be replaced with the LauncherPlugin host in Phase 3.
- Don't add Pods yet — `bootstrap.sh` will set up the Podfile in Phase 2.
- Don't create feature folders ahead of time — `new-module.sh` enforces the canonical layout.

---

## Phase 1 — Pack scaffold

Goal: clone the pack into `.standards/` as a submodule and install rules into `.claude/` + `.ai/`.

### Steps

```bash
# From repo root, with workspace baseline committed.
git submodule add <pack-remote> .standards
./.standards/bin/bootstrap.sh --remote=<pack-remote>
```

`bootstrap.sh` will:

1. Verify git repo state.
2. Run `install-rules.sh` (default `--mode=link` — symlinks the rulebook + agents + cheatsheets so pack version bumps propagate live).
3. Scaffold `.superpowers/{plans,specs,brainstorms,reports,reviews,scratch/_archive}/`.
4. Write starter `.claude/project/PROJECT_CONFIG.md` with `pack_version: X.Y.Z` row + `Module root` row + identity / path / tooling tables.
5. Print next-steps banner.

### Fill in PROJECT_CONFIG.md

Open `.claude/project/PROJECT_CONFIG.md` and replace the placeholders:

| Row | Example value |
|-----|---------------|
| Project name | `MyApp` |
| Workspace | `MyApp.xcworkspace` |
| Main scheme | `MyApp` |
| Simulator target | `iPhone 16 Pro` |
| Module root | `submodules` (or `Modules` — your call, just be consistent) |
| Module prefix | `DAD` if you use one, otherwise leave empty |
| Base branch | `main` |
| App entry file | `App/SceneDelegate.swift` (or `AppDelegate.swift` for older lifecycle) |

`Module root` is the most consequential — every `new-module.sh` / `new-board.sh` invocation reads this row. Change it once, here, before scaffolding any module.

### Verify audit clean

```bash
./.standards/bin/audit-pack.sh
```

Expected: `spec_doc_lint OK — 20 spec(s) conform`. Module-level lints (`forbidden_imports` / `io_visibility` / `boardid_naming`) skip until you pass a `<module-root>` — that's fine; no modules exist yet.

---

## Phase 2 — first module + first Board

Goal: scaffold the first feature module + its first Board using the pack's bin scripts. Pick a small, self-contained feature — typically a launch screen, splash, or onboarding step.

### Step 2a — module

```bash
./.standards/bin/new-module.sh Onboarding
```

Emits under `{ModuleRoot}/Onboarding/`:

- `Onboarding.podspec` (Interface target, `IO/**/*.swift`)
- `OnboardingPlugins.podspec` (Implementation target, `Sources/**/*.swift`)
- `IO/OnboardingServiceMap.swift` — public
- `Sources/Plugins/OnboardingPluginsServiceMap.swift` — internal
- `Sources/Plugins/OnboardingModulePlugin.swift` — `ModuleBuilderPlugin` stub with TODO markers

### Step 2b — first Board

Pick Board type via `DECISION_TREES.md` Tree §1. For a launch/splash screen, `ui` is typical.

```bash
./.standards/bin/new-board.sh Onboarding Welcome ui
```

Emits the IO trio (`WelcomeIOInterface.swift`, `WelcomeInOut.swift`, `ServiceMap+Welcome.swift`) plus per-type Sources skeleton (Board + Builder + Interactor + Presenter + ViewController + Protocols + `ServiceMap+`).

### Step 2c — Podfile wiring

```ruby
# Podfile at repo root
platform :ios, '15.0'
use_frameworks!

target '{AppName}' do
  pod 'Boardy', '<pinned-version>'
  pod 'Onboarding',        :path => 'submodules/Onboarding'
  pod 'OnboardingPlugins', :path => 'submodules/Onboarding'
end
```

`s.dependency` carries name only — never `:path =>`. Path resolution lives in the Podfile.

```bash
pod install
```

### Step 2d — fill in the Board

The scaffolded files contain `// TODO:` markers pointing at relevant `EXAMPLES_*.md` specs. Work through them in this order:

1. `WelcomeInOut.swift` — define `Input` / `Output` / `Command` / `Action`. For a splash with no params, `Input` may be `Void` + `weak var context: UIViewController?`.
2. `WelcomeViewController.swift` — render method calls (`Viewable` protocol). Keep it dumb — zero logic.
3. `WelcomePresenter.swift` — map Domain → ViewModel.
4. `WelcomeInteractor.swift` — the unidirectional flow root: VC → Interactor → UseCase → Presenter → VC.
5. `WelcomeBoard.swift` — Board wires Builder + Interactor + delegates. `registerFlows()` in `init`, never in `activate()`.
6. `WelcomeBuilder.swift` — the only place concrete dependencies get constructed.

Refer to `EXAMPLES_VIP_BOARD.md` for the worked skeleton. Most "first Board" mistakes come from putting Interactor logic in Board, or skipping the Presenter (mapping in the VC). The compact cheatsheet (`compact/BOARDY_CHEATSHEET.compact.md`) has the file-by-file naming reference always loaded.

### Step 2e — verify the slice

```bash
./.standards/bin/audit-pack.sh submodules
```

All 4 lints should be clean:

- `spec_doc_lint` — 20 specs conform.
- `forbidden_imports` — no Domain leaks.
- `io_visibility` — IO public, Sources internal (except `Sources/Plugins/**` allowed-public).
- `boardid_naming` — `pub.mod.Onboarding.Welcome` matches public pattern.

If any lint fails, fix before continuing — adding a second Board on top of a violation compounds the cleanup.

---

## Phase 3 — App entry wiring

Goal: replace the default Xcode-generated app shell with a Boardy LauncherPlugin host. The App becomes a thin shell that boots plugins; everything else is in modules.

### Step 3a — strip the default scene

If you have a SwiftUI lifecycle:
- Remove `@main` from the default `App` struct or convert it to a UIKit-style `UIApplicationDelegateAdaptor`.

If you have a UIKit lifecycle:
- Open `SceneDelegate.swift` — this is where you'll install LauncherPlugins.

### Step 3b — install LauncherPlugins

Create `App/ServiceRegistry+Modules.swift`:

```swift
import Boardy
import OnboardingPlugins
// import other LauncherPlugins as you add modules

extension PluginLauncher {
    static func installAllModules() -> PluginLauncher {
        let launcher = PluginLauncher()
        launcher.install(OnboardingLauncherPlugin())
        // launcher.install(NextModuleLauncherPlugin())
        return launcher
    }
}
```

In `SceneDelegate.scene(_:willConnectTo:options:)`:

```swift
let launcher = PluginLauncher.installAllModules()
let rootMotherboard = launcher.buildRootMotherboard(options: MainOptions(...))
let rootVC = UIViewController()
window?.rootViewController = rootVC
window?.makeKeyAndVisible()

// Activate the welcome Board as the launch experience.
rootMotherboard.serviceMap.modOnboarding.ioWelcome
    .activation
    .activate(with: WelcomeInput(context: rootVC))
```

### Step 3c — verify launch

Cmd-R. The Welcome Board should appear inside `rootVC`. If it doesn't, check (in order):

1. `Podfile` — both `Onboarding` and `OnboardingPlugins` listed? `pod install` run?
2. `installAllModules()` — is `OnboardingLauncherPlugin()` actually called?
3. `modOnboarding.ioWelcome` — does it resolve at compile time? If not, the IO ServiceMap accessor is missing (`new-module.sh` emits it; manual deletion breaks the chain).
4. Console — any `BoardID not registered` crash? Check `OnboardingModulePlugin.ServiceType` cases include `.welcome` → `.pubWelcome`.

`TROUBLESHOOTING.md` §6 covers the common registration failures.

---

## Phase 4 — CI wiring

Goal: every PR runs `audit-pack.sh` before merge. Pack rules atrophy fast without this.

### Minimal GitHub Actions workflow

```yaml
# .github/workflows/audit.yml
name: pack-audit
on: [pull_request]
jobs:
  audit:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true   # required — .standards is a submodule
      - name: Audit pack rules
        run: ./.standards/bin/audit-pack.sh submodules
```

Mandatory parts:

- `submodules: true` on checkout — without it `.standards/bin/audit-pack.sh` is missing.
- Pass `submodules` (your module-root) as the audit-pack argument — without it, module-level lints skip.
- Pin to `macos-latest` (or a specific macOS image) — Linux runners have no Swift toolchain on PATH by default.

### Optional — pre-commit hook

For faster local feedback:

```bash
# .git/hooks/pre-commit (chmod +x)
#!/usr/bin/env bash
set -euo pipefail
./.standards/bin/audit-pack.sh submodules
```

Note: pre-commit hooks aren't versioned in git. If you want this on every developer machine, use a tool like `husky` or document the install step in README.

---

## Phase 5 — release scaffold

Goal: minimum versioning + release wiring so the first ship is a known-good state.

### Required files

- **`CHANGELOG.md`** at repo root — track app version. Start with `## 0.1.0 — <today>` and the modules included.
- **App version + build** — Xcode `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `Info.plist` or `xcconfig`. Match `MARKETING_VERSION` to your `CHANGELOG.md` entries.
- **`.gitignore`** — include `*.xcuserstate`, `xcuserdata/`, `*.swp`, `.DS_Store`, `Pods/` (yes, gitignore Pods; lockfile-only is the convention).
- **`Podfile.lock`** — DO commit. Reproducible installs require it.

### Optional but recommended

- `fastlane` or equivalent for TestFlight uploads.
- A `make` / `just` target that runs `pod install && audit-pack.sh submodules && xcodebuild test` as the canonical "is this branch healthy" command.

---

## Iterate

Once Phase 0-5 are done, every new feature follows the same loop:

1. `./.standards/bin/new-module.sh {Module}` (if new feature warrants its own module).
2. `./.standards/bin/new-board.sh {Module} {Board} {ui|viewless|flow|blocktask}`.
3. Add the module's pods to `Podfile` + `pod install`.
4. Add `{Module}LauncherPlugin()` to `installAllModules()`.
5. Wire activation from the parent flow (Board → child Board via `motherboard.serviceMap.mod{Module}.io{Board}.activation.activate(with:)`).
6. `./.standards/bin/audit-pack.sh submodules` before commit.
7. Open PR — CI runs the audit again.

`DECISION_TREES.md` is the navigator when you're unsure which Board type / channel / scope fits. `TROUBLESHOOTING.md` is the navigator when something doesn't work.

---

## Common blockers + defusion

| Blocker | Fix |
|---------|-----|
| `pod install` succeeds but Xcode shows the new module's files as red | Close + reopen `.xcworkspace`. Xcode caches the file index across `pod install` runs |
| LauncherPlugin compile error: "Module not found" | `Onboarding` (IO target) imports cleanly; `OnboardingPlugins` may not. Check `App` target's "Frameworks, Libraries, and Embedded Content" includes both pods |
| `audit-pack.sh` fails on `spec_doc_lint` with no pack changes | You're running pack version X but CI checks against pack version Y. Pin `pack_version` in `PROJECT_CONFIG.md` and re-run `install-rules.sh` to sync |
| `installAllModules()` order seems to matter — boards activate in wrong order | LauncherPlugin install order does NOT determine activation order. Use parent Boards' `registerFlows()` to sequence activations. If you find yourself relying on install order, you're missing a parent Board |
| First Board's ViewController shows but VIP cycle (VC → Interactor → Presenter → VC) doesn't trigger | Builder didn't wire the delegates. `WelcomeBuilder` must set `vc.interactor = interactor`, `interactor.presenter = presenter`, `presenter.view = vc` (all weak refs as appropriate). `new-board.sh ui` emits TODO markers at each wiring point |

---

## Anti-patterns

- ❌ **Big-bang shell** — don't try to wire every module's LauncherPlugin in Phase 3. Start with one, add the rest as you scaffold them.
- ❌ **App-level Common module** — resist creating an `App` or `Common` module that everything depends on. The pack assumes acyclic cross-module deps; a Common module becomes a god dependency.
- ❌ **Skipping the IO/Plugins split for "simple" modules** — the split is the pack's whole point. Modules without the split don't get the pack's leverage and must be re-scaffolded later.
- ❌ **Storyboards** — pack has no support for Storyboard segues. Programmatic VC + Board everywhere. If your team requires Storyboards, the pack is the wrong choice.
- ❌ **Hand-writing the first module without `new-module.sh`** — you WILL miss a file (typically the IO ServiceMap or its accessor) and spend an hour diagnosing a missing-symbol compile error.
- ❌ **Wiring App business logic into `SceneDelegate`** — SceneDelegate hosts the LauncherPlugin install + root activation, nothing else. Everything else lives in modules.

---

## Per-step verification checklist

Tick before moving to the next phase:

- [ ] Phase 0 — Xcode workspace + project build + launch (default Hello-World visible).
- [ ] Phase 1 — `bootstrap.sh` exit 0; `.claude/` + `.ai/` populated; `PROJECT_CONFIG.md` filled in.
- [ ] Phase 2 — `new-module.sh` emits 5 files; `new-board.sh` emits the IO trio + Sources skeleton; Podfile updated; `pod install` succeeds; `audit-pack.sh submodules` clean.
- [ ] Phase 3 — App launches; first Board renders; no `BoardID not registered` crash; `ServiceRegistry+Modules.swift` exists.
- [ ] Phase 4 — CI workflow exists; first PR run is green.
- [ ] Phase 5 — `CHANGELOG.md` initialized; `Info.plist` versions set; `.gitignore` + `Podfile.lock` committed.

---

## References

- `BROWNFIELD_MIGRATION.md` — counterpart for adopting the pack into existing projects.
- `DECISION_TREES.md` — pattern selection (Board type, BoardID prefix, bus shape, scope).
- `TROUBLESHOOTING.md` — symptom → fix navigator.
- `ARCHITECTURE.md` — runtime composition + plugin host model.
- `BOARDY_FOUNDATIONS.md` — mental model + Boardy pin.
- `MODULE_CREATION.md` — what `new-module.sh` emits and why.
- `PLUGINS_INTEGRATION.md` — ModulePlugin + LauncherPlugin wiring.
- `PACKAGE_MANAGER.md` — current CocoaPods pin + future-manager ADR slots.
