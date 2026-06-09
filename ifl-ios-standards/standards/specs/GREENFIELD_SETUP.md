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
- You want the standard wired in BEFORE writing the first feature, so feature work follows the pack's grain from the start.

If you have existing code to port, use `BROWNFIELD_MIGRATION.md` instead — the pacing, scoring, and adapter-VC bridge that guide describes do not apply here.

---

## How the standard is delivered

The Boardy+VIP standard (agents, skills, rulebook, specs, scaffolders) ships as the
**`ifl-ios-standards` plugin** — installed once per machine, available in every project. It is
**not** copied into your repo. Your repo carries only its own **bindings** in `CLAUDE.md` /
`AGENTS.md` (scheme, module roots, build commands, package manager, etc.). See
`${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/` for a copyable bindings starter.

---

## Preconditions — verify before starting

| Check | How |
|-------|-----|
| Repo initialized | `git init` (or clone empty remote) |
| Xcode + tooling installed | `xcode-select --print-path`, `xcodebuild -version` |
| Plugin runtime installed | `claude` CLI (Claude Code) and/or `codex` CLI on PATH |
| Dependency manager chosen | CocoaPods, Bazel (rules_xcodeproj), or SPM — see `PACKAGE_MANAGER.md`. Record it in `CLAUDE.md` from day one |
| Boardy version pinned | The pin documented in `BOARDY_FOUNDATIONS.md` — record it in your dependency manifest from day one |
| Naming decisions made | App name, bundle ID, optional module prefix (e.g. `DAD`), module-root convention (`Features/` for Bazel, `submodules/` or `Modules/` for CocoaPods). Pick before scaffolding — these are baked into build files/imports |

If any check fails, stop and resolve. Greenfield setup is forgiving but the first 30 minutes set conventions you'll fight to change later.

---

## Phase 0 — Xcode project shell

Goal: the smallest project that builds and launches, with NO feature code.

### CocoaPods / SPM
1. **Create Xcode workspace** (`{AppName}.xcworkspace`) at repo root (CocoaPods integrates with the workspace).
2. **Create App project inside it** (iOS → App; UIKit lifecycle recommended — SwiftUI is wireable via `UIHostingController` from a UI Board).
3. **Add the project to the workspace**, build + launch (Cmd-R → default Hello-World), commit the baseline.

### Bazel (rules_xcodeproj)
1. Set up `MODULE.bazel` + root `BUILD.bazel` with the app target.
2. Use a `rules_xcodeproj` `xcodeproj()` rule to generate the project (e.g. `bazel run //:xcodeproj`).
3. The generated `.xcodeproj` is build output — don't hand-edit. Commit the Bazel files.

### What NOT to do here
- Don't add features to the default `ViewController.swift` — it becomes the LauncherPlugin host in Phase 3.
- Don't add dependencies yet — wire them with the first module in Phase 2.
- Don't create feature folders ahead of time — the scaffolder enforces the canonical layout.

---

## Phase 1 — Install the standard + write bindings

Goal: install the plugin (machine-level) and declare this project's bindings (repo-level).

### Step 1a — install the plugin

```bash
# Claude Code
claude plugin marketplace add congncif/ifl-ios-standards
claude plugin install          ifl-ios-standards@ifl-ios-standards

# Codex
codex plugin marketplace add   congncif/ifl-ios-standards
codex plugin add               ifl-ios-standards@ifl-ios-standards
```

Verify: `claude plugin list` (or `codex plugin list`) shows `ifl-ios-standards`; the agents appear
in `/agents`; `/ifl-ios-standards:boardy-vip` resolves.

### Step 1b — write project bindings into CLAUDE.md / AGENTS.md

Project-specific values live in the repo's `CLAUDE.md` (twin `AGENTS.md`), NOT in plugin files.
Copy the relevant bits from `${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/` and fill in:

| Binding | Example |
|---------|---------|
| Project name | `MyApp` |
| Xcode project / workspace | `MyApp.xcworkspace` (CocoaPods) or generated `MyApp.xcodeproj` (Bazel) |
| Main scheme | `MyApp` (CocoaPods) or per-target (Bazel `xcodeproj()` rule) |
| Simulator | `iPhone 17` |
| Module root | `Features` (Bazel) or `submodules`/`Modules` (CocoaPods) — be consistent |
| Module prefix | `DAD` if used, else empty |
| Base branch / remote | `main` / `origin` |
| Dependency manager | CocoaPods / Bazel / SPM |
| Build/test command | the project's canonical command |

`Module root` is the most consequential — every `ifl-new-module` / `ifl-new-board` invocation reads
it from `CLAUDE.md`. Set it once, here, before scaffolding any module.

The multi-agent pipeline's handoff workspace (in-repo under `docs/02-working-docs/handoffs/` per
`${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`) is optional — only the
`ios-orchestrator` flow uses it.

---

## Phase 2 — first module + first Board

Goal: scaffold the first feature module + its first Board. Pick a small, self-contained feature — typically a launch screen, splash, or onboarding step.

### Step 2a — module

```bash
ifl-new-module Onboarding          # scaffolder on PATH when the plugin is enabled
# or: /ifl-ios-standards:new-module
```

Emits under `{ModuleRoot}/Onboarding/` (build file per your manager):
- **Bazel**: `BUILD.bazel` with two `swift_library` targets — `Onboarding` (glob `IO/**/*.swift`) + `OnboardingPlugins` (glob `Sources/**/*.swift`) + test/coverage targets.
- **CocoaPods**: `Onboarding.podspec` (IO) + `OnboardingPlugins.podspec` (Sources).
- `IO/OnboardingServiceMap.swift` (public), `Sources/Plugins/OnboardingPluginsServiceMap.swift` (internal), `Sources/Plugins/OnboardingModulePlugin.swift` (`ModuleBuilderPlugin` stub).

### Step 2b — first Board

Pick Board type via `DECISION_TREES.md` Tree §1. For a launch/splash screen, `ui` is typical.

```bash
ifl-new-board Onboarding Welcome ui
# or: /ifl-ios-standards:new-board
```

Emits the IO trio (`WelcomeIOInterface.swift`, `WelcomeInOut.swift`, `ServiceMap+Welcome.swift`) plus the per-type Sources skeleton (Board + Builder + Interactor + Presenter + ViewController + Protocols + `ServiceMap+`).

### Step 2c — wire dependencies

**Bazel** — globs auto-capture the new `.swift`; no per-board edit. Only edit `BUILD.bazel`
`PLUGINS_DEPENDENCIES` when a board imports a NEW cross-module IO target. Build:
```bash
bazel build //Features/Onboarding:OnboardingPlugins
```

**CocoaPods** — add both pods, then `pod install`:
```ruby
target '{AppName}' do
  pod 'Boardy', '<pinned-version>'
  pod 'Onboarding',        :path => 'submodules/Onboarding'
  pod 'OnboardingPlugins', :path => 'submodules/Onboarding'
end
```
`s.dependency` carries name only — never `:path =>`. Path resolution lives in the Podfile.

### Step 2d — fill in the Board

Scaffolded files contain `// TODO:` markers. Work in this order (see `/ifl-ios-standards:new-board` + `EXAMPLES_VIP_BOARD.md`):
1. `WelcomeInOut.swift` — `Input`/`Output`/`Command`/`Action`. Splash with no params: `Input` may be `Void` + `weak var context: UIViewController?`.
2. `WelcomeViewController.swift` — render methods (`Viewable`). Keep it dumb — zero logic.
3. `WelcomePresenter.swift` — map Domain → ViewModel.
4. `WelcomeInteractor.swift` — unidirectional flow root: VC → Interactor → UseCase → Presenter → VC.
5. `WelcomeBoard.swift` — wires Builder + Interactor + delegates. `registerFlows()` in `init`, never in `activate()`.
6. `WelcomeBuilder.swift` — the only place concrete dependencies get constructed.

The compact cheatsheet (`${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md`) has the file-by-file naming reference.

### Step 2e — verify the slice

Run the lint scripts (bundled at `${CLAUDE_PLUGIN_ROOT}/standards/scripts/`) against your module root, e.g.:
```bash
swift ${CLAUDE_PLUGIN_ROOT}/standards/scripts/io_visibility.swift Features/Onboarding
swift ${CLAUDE_PLUGIN_ROOT}/standards/scripts/forbidden_imports.swift Features/Onboarding
swift ${CLAUDE_PLUGIN_ROOT}/standards/scripts/boardid_naming.swift Features/Onboarding
```
Expect: IO public + Sources internal (except `Sources/Plugins/**`), no Domain leaks, `pub.mod.Onboarding.Welcome` matches the public BoardID pattern. Fix before adding a second Board — violations compound.

---

## Phase 3 — App entry wiring

Goal: replace the default Xcode-generated app shell with a Boardy LauncherPlugin host. The App becomes a thin shell that boots plugins; everything else lives in modules.

### Step 3a — strip the default scene
- SwiftUI lifecycle: remove `@main` from the default `App` struct, or convert to a UIKit `UIApplicationDelegateAdaptor`.
- UIKit lifecycle: open `SceneDelegate.swift` — this is where LauncherPlugins install.

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

rootMotherboard.serviceMap.modOnboarding.ioWelcome
    .activation
    .activate(with: WelcomeInput(context: rootVC))
```

### Step 3c — verify launch

Cmd-R. The Welcome Board should appear inside `rootVC`. If not, check (in order):
1. Dependencies — both `Onboarding` and `OnboardingPlugins` linked? (`pod install` run / Bazel target built?)
2. `installAllModules()` — is `OnboardingLauncherPlugin()` actually called?
3. `modOnboarding.ioWelcome` — resolves at compile time? If not, the IO ServiceMap accessor is missing (the scaffolder emits it; manual deletion breaks the chain).
4. Console — any `BoardID not registered` crash? Check `OnboardingModulePlugin.ServiceType` includes `.welcome` → `.pubWelcome`.

`TROUBLESHOOTING.md` §6 covers the common registration failures.

---

## Phase 4 — CI wiring

Goal: every PR runs the lint + build gate before merge. Standards atrophy fast without this.

### Minimal GitHub Actions workflow
```yaml
# .github/workflows/audit.yml
name: standards-audit
on: [pull_request]
jobs:
  audit:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install standard
        run: |
          claude plugin marketplace add congncif/ifl-ios-standards
          claude plugin install ifl-ios-standards@ifl-ios-standards
      - name: Lint modules
        run: |
          PLUGIN_ROOT="$(claude plugin root ifl-ios-standards 2>/dev/null || echo .)"
          swift "$PLUGIN_ROOT/standards/scripts/io_visibility.swift" Features
          swift "$PLUGIN_ROOT/standards/scripts/forbidden_imports.swift" Features
          swift "$PLUGIN_ROOT/standards/scripts/boardid_naming.swift" Features
      - name: Build
        run: bazel build //... # or: pod install && xcodebuild test ...
```
Mandatory: `macos-latest` (Linux has no Swift toolchain on PATH). Resolve the bundled lint scripts
from the installed plugin root, or vendor them under `tools/` if you prefer no network in CI.

### Optional — pre-commit hook
```bash
# .git/hooks/pre-commit (chmod +x) — run the project's lint + cheapest build check
```
Pre-commit hooks aren't versioned; use `husky` or document the install step if you want it on every machine.

---

## Phase 5 — release scaffold

Goal: minimum versioning + release wiring so the first ship is a known-good state.

### Required
- **`CHANGELOG.md`** at repo root — start with `## 0.1.0 — <today>` + the modules included.
- **App version + build** — `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`. Match `MARKETING_VERSION` to `CHANGELOG.md`.
- **`.gitignore`** — `*.xcuserstate`, `xcuserdata/`, `.DS_Store`; CocoaPods: `Pods/` (commit `Podfile.lock`); Bazel: `bazel-*` symlinks.
- Per docs-organization, project docs live under `docs/` (`01-living-docs`, `02-working-docs`, `03-release-docs`, `99-archive`) — release notes → `docs/03-release-docs/release-notes/`.

### Optional
- `fastlane` (or equivalent) for TestFlight uploads.
- A `make`/`just` target that runs lint + build + test as the canonical "is this branch healthy" command.

---

## Iterate

Every new feature follows the same loop:
1. `ifl-new-module {Module}` (if the feature warrants its own module).
2. `ifl-new-board {Module} {Board} {ui|viewless|flow|blocktask}`.
3. Wire dependencies (Bazel: usually nothing — globs; CocoaPods: add pods + `pod install`).
4. Add `{Module}LauncherPlugin()` to `installAllModules()`.
5. Wire activation from the parent flow (Board → child Board via `motherboard.serviceMap.mod{Module}.io{Board}.activation.activate(with:)`).
6. Run the lint + build gate before commit.
7. Open PR — CI runs the gate again.

`DECISION_TREES.md` is the navigator when unsure which Board type / channel / scope fits.
`TROUBLESHOOTING.md` is the navigator when something doesn't work.

---

## Anti-patterns

- ❌ **Big-bang shell** — don't wire every module's LauncherPlugin in Phase 3. Start with one, add the rest as you scaffold.
- ❌ **App-level Common module** — resist an `App`/`Common` module everything depends on. The pack assumes acyclic cross-module deps; a Common module becomes a god dependency.
- ❌ **Skipping the IO/Plugins split for "simple" modules** — the split is the whole point. Modules without it must be re-scaffolded later.
- ❌ **Storyboards** — no Storyboard-segue support. Programmatic VC + Board everywhere.
- ❌ **Hand-writing the first module without the scaffolder** — you WILL miss a file (typically the IO ServiceMap or its accessor) and chase a missing-symbol error.
- ❌ **App business logic in `SceneDelegate`** — it hosts the LauncherPlugin install + root activation, nothing else.

---

## Per-step verification checklist

- [ ] Phase 0 — Xcode project builds + launches (default Hello-World visible).
- [ ] Phase 1 — plugin installed (`plugin list` shows it, `/agents` lists ios-*); `CLAUDE.md` bindings filled in.
- [ ] Phase 2 — scaffolder emits module + board files; deps wired; module builds; lints clean.
- [ ] Phase 3 — App launches; first Board renders; no `BoardID not registered`; `ServiceRegistry+Modules.swift` exists.
- [ ] Phase 4 — CI workflow exists; first PR run green.
- [ ] Phase 5 — `CHANGELOG.md` initialized; versions set; `.gitignore` committed; `docs/` tree seeded.

---

## References

- `BROWNFIELD_MIGRATION.md` — counterpart for adopting the pack into existing projects.
- `DECISION_TREES.md` — pattern selection (Board type, BoardID prefix, bus shape, scope).
- `TROUBLESHOOTING.md` — symptom → fix navigator.
- `ARCHITECTURE.md` — runtime composition + plugin host model.
- `BOARDY_FOUNDATIONS.md` — mental model + Boardy pin.
- `MODULE_CREATION.md` — what the scaffolder emits and why.
- `PLUGINS_INTEGRATION.md` — ModulePlugin + LauncherPlugin wiring.
- `PACKAGE_MANAGER.md` — dependency-manager options (CocoaPods / Bazel / SPM).
- `process/docs-organization.md` — where docs/plans/handoffs live.
- `process/lean-verification.md` — TDD tiers + checkpoint verification cadence.
