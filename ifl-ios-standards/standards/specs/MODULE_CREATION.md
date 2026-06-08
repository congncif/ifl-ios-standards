<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Module Creation

> Reference: *Modern large-scale iOS app development* — Modular + Interface Module pillar.
> Companion specs: `IO_INTERFACE.md` (IO target layout), `PLUGINS_INTEGRATION.md` (LauncherPlugin wiring), `LAYERING.md` (folder split), `.claude/project/PROJECT_CONFIG.md` (project-specific values).

## When to use

When scaffolding a new top-level feature module. Specifically:

- New product area / domain → new module (`Profile`, `Payment`, `Onboarding`).
- Splitting a too-large module into sibling modules.
- Promoting a feature embedded in App Core into a reusable module.

## When NOT to use

- Adding a screen / Board to an existing module → just add files; no new podspec.
- One-off App Core composition file → belongs in App, not its own module.
- A pure SDK adapter shared across modules → may be a single-target pod, not the 2-target IO+Plugins split.
- A nested sub-feature of an existing module → keep inside; module placement rule forbids nesting.

## Forces

- 2-target split (IO public + Plugins internal) keeps cross-module imports honest — consumers import only `{ModuleName}` and physically cannot reach impl types.
- Podfile uses Ruby hash-rocket `:path =>` for local pods; keyword syntax (`path:`) is silently invalid in the Podfile DSL.
- `s.dependency` in podspec takes pod NAME only — never `:path`; path resolution is Podfile's job. Lint will reject `:path` there.
- `pod install` must run after any Podfile/podspec/source-files change; skipping it leaves Xcode blind to new files.
- `xcodebuild -quiet` hides errors and produces silent failures; filter with `grep -E` instead. Empty grep output ≠ success — it means the command crashed.
- `init-module.sh` default prefix is `DAD`; always pass PREFIX explicitly or omit cleanly to avoid misnaming.

## Files

Target layout produced by the init script (after rename of template defaults):

```
{ModuleRoot}/{ModuleName}/
├── {ModuleName}.podspec                        ← IO target podspec
├── {ModuleNamePlugins}.podspec                 ← Plugins target podspec
├── IO/
│   ├── {ModuleName}ServiceMap.swift            ← public IO ServiceMap class
│   └── {NoPrefixName}/                         ← one folder per public board
│       ├── {NoPrefixName}IOInterface.swift
│       ├── {NoPrefixName}InOut.swift
│       └── ServiceMap+{NoPrefixName}.swift
└── Sources/
    ├── Plugins/
    │   ├── {ModuleName}PluginsServiceMap.swift ← internal Plugins ServiceMap
    │   └── {NoPrefixName}ModulePlugin.swift    ← ModuleBuilderPlugin + LauncherPlugin
    ├── Shared/
    │   ├── Extensions/                         ← UIViewController++, UIView++
    │   └── UIComponents/                       ← Shared views/cells within module
    ├── Microboards/                            ← empty, ready for boards
    └── Services/                               ← see SERVICE_LAYER.md
        ├── Domain/{Models,Repositories,Services}/
        ├── Application/
        ├── Infra/
        └── Tracking/
```

Template emits `Sources/Components/` + `Sources/Integration/` — rename to `Sources/Plugins/`.

Module placement rule: every module sits directly under `{ModuleRoot}/{ModuleName}/` as a sibling. Never nest `{ModuleRoot}/{ModuleA}/{ModuleB}/`.

## Naming

| Concept | No Prefix | With Prefix `DAD` |
|---|---|---|
| Full module name | `Profile` | `DADProfile` |
| IO podspec | `Profile` | `DADProfile` |
| Plugins podspec | `ProfilePlugins` | `DADProfilePlugins` |
| No-prefix name (VIP classes) | `Profile` | `Profile` |
| IO ServiceMap class | `ProfileServiceMap` | `DADProfileServiceMap` |
| IO ServiceMap property | `modProfile` | `modDADProfile` |
| Plugins ServiceMap class | `ProfilePluginsServiceMap` | `DADProfilePluginsServiceMap` |
| Plugins ServiceMap property | `modProfilePlugins` | `modDADProfilePlugins` |

Prefix is optional — only use when explicitly specified. No-prefix name drives Swift VIP class names.

## Communication

### Step 1 — module name decision

| Scenario | Module name | No-prefix name |
|---|---|---|
| No prefix | `Profile` | `Profile` |
| With prefix `DAD` | `DADProfile` | `Profile` |
| With prefix `MOD` | `MODPayment` | `Payment` |

### Step 2 — create module directory

```bash
mkdir -p {ModuleRoot}/{ModuleName}
cd {ModuleRoot}/{ModuleName}
```

### Step 3 — run init script

```bash
# No prefix:
sh ../../scripts/init-module.sh Profile

# With explicit prefix:
sh ../../scripts/init-module.sh DADProfile DAD
```

### Step 4 — verify generated structure → see Files section. Rename `Components/`+`Integration/` → `Plugins/`.

### Step 5 — Podfile entries

```ruby
# Podfile — always use :path => (hash-rocket), NOT path: (keyword syntax)
pod '{ModuleName}',        :path => '{ModuleRoot}/{ModuleName}'
pod '{ModuleNamePlugins}', :path => '{ModuleRoot}/{ModuleName}'
```

### Step 5a — pod install

```bash
pod install
```

Trigger after: new module added, dep added/removed, `source_files`/`resources` glob changed, new `.swift` files created outside Xcode.

### Step 6 — xcodebuild workflow

```bash
# 1) list destinations
xcodebuild -workspace {Workspace} -list
xcodebuild build -workspace {Workspace} -scheme {MainScheme} -showdestinations

# 2) build filtered
xcodebuild build -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"

# 2) test filtered
xcodebuild test -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' 2>&1 \
  | grep -E "(error:|warning:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED|BUILD SUCCEEDED|BUILD FAILED)"
```

Empty output → command failed; re-run without grep. For error context: `2>&1 | grep -B 2 -A 5 "error:"`.

### Step 7 — wire LauncherPlugin

```swift
// AppEntry (SceneDelegate / AppDelegate)
import Boardy
import {ModuleNamePlugins}   // ← Plugins target, ONLY in app entry
import UIKit

func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = (scene as? UIWindowScene) else { return }
    let window = UIWindow(windowScene: windowScene); self.window = window

    PluginLauncher.with(options: .default)
        .install(launcherPlugin: {NoPrefixName}LauncherPlugin())
        .initialize()
        .launch(in: window) { motherboard in
            motherboard.serviceMap.mod{ModuleName}
                .io{EntryBoardName}.activation.activate(with: {EntryBoardName}Input())
        }
}
```

Add new module to existing PluginLauncher:

```swift
PluginLauncher.with(options: .default)
    .install(launcherPlugin: ExistingLauncherPlugin())
    .install(launcherPlugin: {NoPrefixName}LauncherPlugin())   // ← add here
    .initialize()
    .launch(in: window) { ... }
```

Rules → import `{ModuleNamePlugins}` ONLY in app entry; never from another module. Initial activation uses IO ServiceMap.

### podspec templates

```ruby
# {ModuleName}.podspec — IO
Pod::Spec.new do |s|
  s.name             = '{ModuleName}'
  s.version          = '0.1.0'
  s.summary          = '{ModuleName} interface module.'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'IO/**/*.swift'
  s.dependency 'Boardy'
end
```

```ruby
# {ModuleNamePlugins}.podspec — Plugins
Pod::Spec.new do |s|
  s.name             = '{ModuleNamePlugins}'
  s.version          = '0.1.0'
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/**/*.swift'
  s.resources        = 'Sources/Resources/**/*'
  s.dependency '{ModuleName}'
  s.dependency 'Boardy'
  s.dependency 'SiFUtilities'
end
```

`s.dependency` rule → NAME only. `s.dependency '{OtherModule}'` ✅. `s.dependency '{OtherModule}', :path => '.'` ❌.

### init-module.sh reference

Script at `scripts/init-module.sh`:
1. Clones template repo (`{ModuleTemplateURL}` from PROJECT_CONFIG).
2. Replaces `__DAD__` → `{ModuleName}`.
3. Replaces `___VARIABLE_moduleName___` → `{NoPrefixName}`.
4. Sets ServiceMap properties `mod{ModuleName}` + `mod{ModuleNamePlugins}`.
5. Renames files.

## Concurrency

- Module creation is a one-shot scaffolding action; no runtime concurrency concerns at this layer.
- `pod install`, `xcodebuild`, `init-module.sh` are synchronous CLI steps; run sequentially, not in parallel.

## Composition

- Sibling modules compose via `ServiceRegistry`-registered `LauncherPlugin`s (see `PLUGINS_INTEGRATION.md`).
- Cross-module wiring through IO pod only (see `CROSS_MODULE_DI.md`).
- Module's own internal layering follows `LAYERING.md` (Domain / BA / Infra & UI).

## Lifecycle

- IO target — public ABI; bump podspec version when changing it (consumer-visible break).
- Plugins target — implementation; version-bump for `s.dependency` changes only.
- `init-module.sh` is a one-time bootstrap; subsequent file additions don't re-run it.
- `pod install` rebuilds the Pods project deterministically; no per-developer state.

## Testing

Verification after scaffold:

- [ ] `{ModuleRoot}/{ModuleName}/` sits as a sibling, not nested in another module
- [ ] Both podspecs present (`{ModuleName}.podspec` + `{ModuleNamePlugins}.podspec`)
- [ ] IO folder contains `{ModuleName}ServiceMap.swift` + at least one entry-board folder
- [ ] Sources folder contains `Plugins/`, `Shared/`, `Microboards/`, `Services/`
- [ ] No `Components/` or `Integration/` remain after rename step
- [ ] Podfile entries use `:path =>` not `path:`
- [ ] `s.dependency` lines have no `:path` modifier
- [ ] `pod install` exits 0 and updates `Podfile.lock`
- [ ] `xcodebuild -showdestinations` lists the workspace
- [ ] Filtered build prints `** BUILD SUCCEEDED **`
- [ ] App entry imports `{ModuleNamePlugins}` and installs `{NoPrefixName}LauncherPlugin()`
- [ ] No other module imports `{ModuleNamePlugins}`

## Pitfalls

| Mistake | Fix |
|---|---|
| Importing `{ModuleNamePlugins}` from another module | Import `{ModuleName}` (IO) only |
| Making internal boards `public` | Internal boards live in Sources; no `public` |
| Forgetting `public init() { /**/ }` on LauncherPlugin | Always add it |
| `sharedRepository` created inside `build()` / `BoardRegistration` | Declare as stored property on `ModulePlugin` |
| `path:` keyword in Podfile | Use `:path =>` hash-rocket |
| `s.dependency '{X}', :path => '.'` | NAME only — drop `:path` |
| Skipping `pod install` after Podfile change | Always re-run; Xcode won't see new files |
| `xcodebuild ... -quiet` | Hides errors; use `grep -E` filter instead |
| Empty grep output treated as success | Re-run without grep — likely a silent crash |
| Nesting `{ModuleA}/{ModuleB}/` | Place as siblings under `{ModuleRoot}/` |
| Running init-module.sh without PREFIX when one exists | Pass PREFIX explicitly to avoid `DAD` default |

## References

- `IO_INTERFACE.md` (IO target detail)
- `PLUGINS_INTEGRATION.md` (LauncherPlugin + ModulePlugin)
- `LAYERING.md` (folder responsibility)
- `SERVICE_LAYER.md` (Services/ folder split)
- `CROSS_MODULE_DI.md` (cross-module wiring)
- `.claude/project/PROJECT_CONFIG.md` (workspace / scheme / destination)
- `compact/BOARDY_CHEATSHEET.compact.md` (always-loaded)
- `QUICK_REF.md` §4 rules 1, 2, 3
