---
name: boardy-new-module
description: >-
  Use when creating a new Boardy+VIP iOS module / Business Unit — scaffolding the two-target
  module (public IO + Plugins implementation), its ServiceMaps, and ModulePlugin composition seam.
  Triggers: "new module", "create a feature module", "add a Business Unit", "scaffold a Boardy module".
---

# New Boardy+VIP module

## Read first

- `${CLAUDE_PLUGIN_ROOT}/standards/specs/MODULE_CREATION.md` — CLI contract, safe generation,
  post-generation ownership, and verification scope.
- `${CLAUDE_PLUGIN_ROOT}/standards/specs/compact/BOARDY_CHEATSHEET.compact.md` — layout and naming.
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/QUICK_REF.md` §5 — module skeleton; §2 — optional naming prefix.

## Scaffold safely

Resolve the module root from the consuming repository, then run:

```bash
ifl-new-module <Module> --root=. --module-root=<repo-owned-module-root>
```

The optional flag is `--dry-run`. The module name must match `[A-Z][A-Za-z0-9]*`. The command
refuses an existing module destination; never bypass that protection or use the scaffolder as an
overwrite/merge tool.

`--root` defaults to the current directory. The executable resolves `Module root` from `CLAUDE.md`,
then `AGENTS.md`, with `.claude/project/PROJECT_CONFIG.md` retained only as a legacy binding source.
It fails instead of guessing when no binding resolves. Pass `--module-root` explicitly in that case.
Build labels, dependencies, deployment versions, package-manager values, prefixes, destinations,
and commands remain owned by the consuming repository.

The scaffold is deliberately incomplete: public `IO/`, internal `Sources/**`, and the Plugins
composition seam are starting structure only. `Sources/Plugins/**` may expose the narrow public types
needed by app-level launcher composition; other `Sources/**` declarations remain internal.

## Post-generation responsibilities

1. Add the generated source boundary to the repository's build/package configuration using current
   neighbouring targets and repository bindings.
2. Define minimal, vendor-free public IO.
3. Add boards with `/ifl-ios-standards:boardy-new-board` and register each in
   `{Module}ModulePlugin` (`ServiceType` + `build`).
4. Keep shared repositories at module/plugin lifetime, outside registration closures.
5. Wire public Plugins composition types only at the app composition root. Feature modules import
   `{Module}` IO, never `{Module}Plugins`.
6. Add tests only for observable behavior. Remove placeholder-only tests such as
   `XCTAssertTrue(true)` rather than treating them as coverage.

## Verification

- If executable scaffold output changes, run one targeted native signal selected from the consuming
  repository's bindings. Do not hard-code a universal Bazel or Xcode command here.
- Documentation-only changes require no build or test.
- Do not create verifier scripts, receipts, manifests, or custom workflow-state files. Report the
  direct command and observed result when a signal is required.

## Hard rules

- Public BoardIDs use `pub.mod.<Module>.<Board>`.
- IO declarations are public. `Sources/**` is internal except justified public
  `Sources/Plugins/**` composition types.
- The generator must fail on an existing destination.
- Scaffolders are thin: product behavior, dependencies, app wiring, and meaningful tests remain
  post-generation work.
- See `/ifl-ios-standards:boardy-vip` §2 for the full rule set.
