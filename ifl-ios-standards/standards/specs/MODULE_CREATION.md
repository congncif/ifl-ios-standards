<!-- Retrofitted to SPEC_CONTRACT 12 sections on 2026-05-23 -->

# SPEC: Module Creation

> Companion specs: `IO_INTERFACE.md` (public IO), `PLUGINS_INTEGRATION.md` (composition),
> `LAYERING.md` (implementation folders), and the consuming repository's project bindings
> (module root, build system, commands, platform versions, naming, and app integration).

## When to use

Use this procedure when a product area needs an independently consumable Boardy+VIP module, or
when an approved refactor extracts one. The canonical module has two dependency surfaces:

- `{Module}`: the public IO contract.
- `{Module}Plugins`: the implementation and composition surface.

Adding a board to an existing module does not require a new module; use `MICROBOARD_UI.md` or
`MICROBOARD_NONUI.md` instead.

## When NOT to use

- A screen or coordinator belongs to an existing module.
- The code is an app-level composition root rather than a reusable feature.
- A small infrastructure adapter does not need the IO + Plugins split.
- The proposed module would be nested under another module. Feature modules remain siblings under
  the module root chosen by the consuming repository.

## Forces

- The IO/Plugins split prevents consumers from reaching implementation types.
- A portable standard cannot choose a module root, build system, target labels, deployment target,
  simulator, package manager, prefix, author, or dependency list for a consuming repository.
- A scaffolder can safely create a small compile-shaped starting point; it cannot infer product IO,
  domain behavior, dependencies, registration, app wiring, or useful tests.
- Generation must be additive. Existing destinations are a hard failure, never an overwrite or
  merge target.

## Files

A minimal module starts with this shape:

```text
{ModuleRoot}/{Module}/
├── IO/
│   └── {Module}ServiceMap.swift
└── Sources/
    └── Plugins/
        ├── {Module}PluginsServiceMap.swift
        └── {Module}ModulePlugin.swift
```

The bundled CLI deliberately emits no build-system, dependency, platform, package-manager, license,
or test configuration. The consuming repository decides whether it uses Bazel, CocoaPods, Swift
Package Manager, Xcode project targets, or another supported setup, and owns every label,
dependency, platform version, resource glob, and test target.

Boards add their public files under `IO/{Board}/` and implementation files under
`Sources/Microboards/{Board}/`. Service, shared UI, and resource folders are added only when the
module actually needs them; empty architecture folders are not a completion signal.

Do not generate a `Tests/` directory merely to satisfy a glob. In particular, an
`XCTAssertTrue(true)` test is not evidence and must not be retained. Add a test target and test files
when there is observable behavior to test.

## Naming

`{Module}` is the complete module name selected by the consuming repository. An organization prefix
is optional and must come from that repository's binding or an explicit user choice; the pack does
not supply one.

Public boards in the module use the canonical literal:

```swift
public extension BoardID {
    static let pub{Board}: BoardID = "pub.mod.{Module}.{Board}"
}
```

The IO target and its declarations are `public`. `Sources/**` declarations are `internal` by default.
`Sources/Plugins/**` is the sole implementation-side exception: types needed by app-level
`LauncherPlugin` composition may be `public`, but visibility is promoted only for that real consumer.

## Communication

### Run the bundled CLI

From the consuming repository root:

```bash
ifl-new-module <Module> --root=. --module-root=<repo-owned-module-root>
```

Current options are:

```text
ifl-new-module <Module>
  [--root=PATH]
  [--module-root=PATH]
  [--dry-run]
```

The module name must match `[A-Z][A-Za-z0-9]*`. `--root` defaults to the current directory. The
executable resolves the module root from `--module-root`, then the `Module root` row in `CLAUDE.md`,
then `AGENTS.md`; `.claude/project/PROJECT_CONFIG.md` remains a legacy binding source. It fails
instead of guessing when none resolves. The module root must be a repository-relative path token and
must not contain traversal components.

The command refuses to run when `{root}/{module-root}/{Module}` already exists. `--dry-run` prints the
destinations without writing them. A successful run creates a starting skeleton only; it does not
mean the module is integrated or behaviorally complete.

### Post-generation responsibilities

1. Add the generated sources to the build/package configuration using a current neighbouring module
   and the consuming repository's labels, dependencies, platform values, resources, and targets.
2. Define the real public IO. Keep it minimal and vendor-free.
3. Add boards with `ifl-new-board`, then register them in `{Module}ModulePlugin`.
4. Store shared repositories and other module-lifetime dependencies on the composition object; do
   not create them inside board-registration closures.
5. Wire the Plugins target at the app composition root. Other feature modules import `{Module}` IO,
   never `{Module}Plugins`.
6. Add real tests for real behavior. Remove any placeholder-only test emitted by an older scaffold
   version instead of treating it as coverage.

## Concurrency

Scaffolding is a one-shot filesystem operation. Run dependency or project-generation steps only
after the generated files and consuming-repository configuration agree. Runtime concurrency belongs
to the boards and services added later.

## Composition

- Cross-module consumers depend on `{Module}` only.
- The app composition root may import `{Module}Plugins` to construct and install public plugin types.
- Provider configuration and launcher inputs that must be public live under `Sources/Plugins/`, not
  in IO; they describe construction, not domain meaning.
- The generated `ModulePlugin` is intentionally incomplete. Board registration, dependencies, and
  shared object lifetimes are post-generation design decisions.

## Lifecycle

The scaffolder is not a migration or regeneration engine. Run it once for a new destination. After
creation, the files are normal repository-owned source files and evolve through ordinary changes.
Never rerun a scaffold over an existing module.

## Testing

Verification is proportional to the change:

- After an executable scaffold change, run one targeted native signal owned by the consuming
  repository (for example, the generated target's canonical build or a focused test with meaningful
  assertions). Do not hard-code that command in this pack.
- For documentation-only changes, do not run a build or test merely to manufacture evidence.
- A generated placeholder test is forbidden. Absence of behavior means no behavior test yet.
- Do not add verifier scripts, receipts, manifests, or custom workflow-state files. Report the
  command and observed result directly when an executable signal was required.

Structural checks after generation:

- [ ] Destination was new and is a sibling beneath the repository-owned module root.
- [ ] IO is public; `Sources/**` remains internal except justified `Sources/Plugins/**` exports.
- [ ] Generated sources were added to the consuming repository's build/package configuration.
- [ ] Other modules depend on IO, not Plugins.
- [ ] App composition and board registration are explicitly completed.
- [ ] Tests, when present, assert observable behavior rather than scaffold existence.

## Pitfalls

| Mistake | Correction |
|---|---|
| Inventing build values because the source scaffold emits none | Resolve every value from the consuming repository |
| Running against an existing destination | Stop; choose a new name or make an explicit hand-authored change |
| Exporting all implementation types | Keep `Sources/**` internal; promote only required `Sources/Plugins/**` composition types |
| Importing `{Module}Plugins` from another feature | Import `{Module}` IO only |
| Creating shared repositories in registration closures | Store them at module/plugin lifetime |
| Keeping `XCTAssertTrue(true)` to satisfy a test glob | Remove the fake test; add meaningful tests with behavior |
| Adding a universal build or simulator command here | Use the consuming repository's native command |
| Creating evidence sidecars for a scaffold | Use the repository's normal source and direct command output |

## References

- `IO_INTERFACE.md`
- `PLUGINS_INTEGRATION.md`
- `LAYERING.md`
- `SERVICE_LAYER.md`
- `CROSS_MODULE_DI.md`
- `compact/BOARDY_CHEATSHEET.compact.md`
- `QUICK_REF.md` §4 rules 1–3
