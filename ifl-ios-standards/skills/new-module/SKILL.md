---
name: new-module
description: >-
  Use when creating a new Boardy+VIP iOS module / Business Unit — scaffolding the two-target
  module (IO interface + Plugins implementation), its ServiceMap, ModulePlugin, and Bazel BUILD.
  Triggers: "new module", "create a feature module", "add a Business Unit", "scaffold a Boardy module".
---

# New Boardy+VIP module

## Read first
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/MODULE_CREATION.md` — full procedure.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md` — file layout + naming tables.
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md` §5 — canonical module skeleton, §2 — naming with optional prefix.

## Scaffold it
Run the bundled scaffolder (on PATH when this plugin is enabled):
```bash
ifl-new-module <ModuleName> --root=.
```
It emits `BUILD.bazel` (two `swift_library` targets globbing `IO/**` + `Sources/**`), podspec
fallbacks, `IO/{Module}ServiceMap.swift`, `Sources/Plugins/{Module}{PluginsServiceMap,ModulePlugin}.swift`,
and a `Tests/` stub. Module root defaults to the project's convention (see the consuming repo's `CLAUDE.md`).

## Then
1. Fill `PLUGINS_DEPENDENCIES` in the generated `BUILD.bazel` with real deps (copy from a neighbour module).
2. Add boards: `/ifl-ios-standards:new-board`.
3. Register each board in `{Module}ModulePlugin.swift` (`ServiceType` case + `build()`).
4. Verify per the project's build command (see its `CLAUDE.md`), e.g. `bazel build //<root>/<Module>:<Module>Plugins`.

## Hard rules that always apply
- IO target = `public`; `Sources/**` = `internal` (except `Sources/Plugins/**`).
- Never import another module's `{Name}Plugins` — only its IO.
- See `/ifl-ios-standards:boardy-vip` §2 for the full 14 rules.
