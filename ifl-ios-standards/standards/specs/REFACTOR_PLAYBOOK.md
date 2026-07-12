# REFACTOR_PLAYBOOK — procedural runbook for restructuring modules and Boards

> **Purpose**: impact-first procedure for the five high-stakes structural refactors in a Boardy+VIP codebase — split a module, merge two modules, extract a Board, move a Board across modules, rename a public symbol. Each has a safe semantic sequence; doing it in the wrong order can leave callers broken, BoardIDs unreachable, or UIKit and SwiftUI adapters semantically inconsistent.
>
> **Not a pattern spec.** Exempt from the 12-section `SPEC_CONTRACT.md` template; this is a procedural runbook, same as `DECISION_TREES.md` / `BROWNFIELD_MIGRATION.md` / `GREENFIELD_SETUP.md` / `TROUBLESHOOTING.md` / `REVIEW_PLAYBOOK.md`.
>
> **Use this when**: you're about to change the shape of a module (boundary, name, Board location). **Don't use this for**: green-field design (use `DECISION_TREES.md` + pattern specs) or in-module non-structural changes (just edit the code).

---

## When this guide applies

You're about to perform one of these five refactors:

| Refactor | Trigger |
|----------|---------|
| **Split a module** | Module has grown to >8 Boards OR two clear independent feature sets share the module |
| **Merge two modules** | Two modules' Boards reach into each other so often that the boundary has become noise |
| **Extract a Board** | A Board has accumulated logic that's actually 2+ independent concerns; or a sub-flow is being reused from another Board |
| **Move a Board across modules** | A Board lives in the wrong module — its dependencies tell you so (it imports more from `{Other}` than its own module's Domain) |
| **Rename a public symbol** | Module name / BoardID / public Input/Output type needs a better name; the current one has drifted from what it does |

Each section below covers ONE of these. They're independent — read the section you need; skip the rest.

---

## Universal preconditions — map impact before ANY refactor

| Check | How |
|-------|-----|
| `git status` clean | Refactors generate large diffs; mix with feature work = unreviewable PR |
| Working tree builds + tests green | Don't refactor on top of failing tests; you won't know which failures the refactor introduced |
| Affected architecture rules understood | Know the dependency, visibility, humble-View, and BoardID constraints before moving code |
| Definition and all consumers mapped | Trace the symbol or Board from its definition through registrations, ServiceMap accessors, imports, build/package edges, tests, App composition, and runtime callers before editing |
| UI semantics frozen | If a UI Board or presentation seam moves, record its display-ready state and typed intents; UIKit and SwiftUI adapters must keep the same product semantics |
| Rollback boundary chosen | Define the last known working state and whether the slice rolls back by reverting, restoring an alias, or restoring the old registration/caller route |
| Confirm no in-flight PRs touch the same files | Merge conflicts on a refactor are painful; coordinate timing |
| Pack version pinned in `PROJECT_CONFIG.md` | If the pack itself just bumped, rebase the pack version first — don't conflate pack + refactor diffs |

If any check fails, stop and resolve. Refactors compound mistakes — the cleanup is exponentially more expensive than the prep.

### Standards 1.0 invariants to preserve

- Public BoardIDs use exactly `pub.mod.<Module>.<Board>`; internal BoardIDs use
  `mod.<Module>.<Board>`. A public literal change is a runtime contract change, not a file rename.
- `IO/**` exports public domain contracts. `Sources/**` remains internal except the minimum App-boot
  construction surface under `Sources/Plugins/**` (for example LauncherPlugin init arguments and
  provider configurations). That exception never permits sibling modules to import another module's
  Plugins target.
- UIKit and SwiftUI are equivalent humble rendering adapters. The Presenter or equivalent mapper owns
  display-ready product state and typed intents; Views own only rendering mechanics and transient UX-local
  state. A hosting or interoperability bridge must not reinterpret business, navigation, accessibility,
  analytics, or formatting semantics.

## Safe execution and verification contract

Plan the refactor as dependency-ordered **semantic slices**, not file moves or agent assignments. A slice
leaves one coherent contract usable: introduce a destination or compatibility bridge, move its definition
and registration, migrate all known callers, then remove the old route only after its impact set is empty.
Do not leave both registrations active unless the compatibility design explicitly requires that state.

For each slice:

1. Reconfirm the affected definitions, callers, package edges, registrations, tests, and UI adapters.
2. Make the smallest complete change that preserves the public/runtime contract or introduces the planned
   bridge before caller cutover.
3. Inspect the complete slice for dependency direction, visibility, BoardID ownership, lifecycle, and
   UIKit/SwiftUI semantic parity.
4. For executable changes, run the one consuming-repository native build/test signal assigned to that
   slice or distinct risk boundary. Read the command from the consuming repo's project instructions; this
   pack does not define a substitute command.
5. If the signal fails or the impact grows beyond the planned slice, stop, restore the chosen rollback
   boundary, and re-plan before continuing.

Do not build after every rename, move, or file edit. Do not repeat an unchanged green signal, create
plugin-owned verifier/lint/smoke scripts, or add receipts, evidence ledgers, manifests, fingerprints, and
custom workflow state. Documentation-only work has no runtime build/test gate; after all planned mutations,
it waits for the plan's one final joined AI consistency review. Executable changes keep their observed
consuming-repo signal and then join that same final review; the review is not a replacement for code tests.

---

## Refactor 1 — Split a module

Goal: take one module that's grown too large and split it into two coherent modules with their own IO + Plugins targets.

### Decide WHERE to cut

The cut line is the single most important decision. Pick badly and you'll do it again in 3 months.

| Good cut lines | Bad cut lines |
|----------------|---------------|
| Distinct user-visible features (e.g. "Onboarding" → "OnboardingProfile" + "OnboardingTutorial") | Arbitrary grouping by file count |
| Different lifecycles (one-time setup vs. recurring runtime) | Domain-then-Application-then-Infra horizontal slice ("layer modules") |
| Different ownership (different teams) | "Extract everything that imports SDK X" — that's an Infra concern, not a module split |
| Independent Board fan-in (no Boards in module A call into module B's planned Boards) | The cut leaves cross-deps in BOTH directions |

If two halves of the proposed split call each other ≥ 3 times after the cut, you don't have two modules — you have one module with bad internal naming. Rename internally instead.

### Mechanical sequence

1. **Create the new source boundary** with `ifl-new-module`:
   ```bash
   ifl-new-module OnboardingTutorial
   ```
   It emits the three canonical IO/Plugins source files and refuses an existing destination. Add
   those sources to the consuming repository's build/package configuration explicitly.

2. **Move Boards in dependency order**. For each Board to relocate, use Refactor 4 (Move a Board across modules) below. Keep each semantic slice coherent: destination contract and registration, Board implementation, all callers, and applicable tests move together. Commit only complete semantic tasks when separately authorized; a Board, file, or mechanical step is not automatically a commit or gate boundary.

3. **Decide cross-dependency direction**. After moves, at most one module depends on the other's IO
   target. If both require each other, back out the slice and choose a different cut.

4. **Update the repository-owned build/package graph**. Add the new IO and Plugins targets or
   source sets using current neighbouring configuration. Feature modules depend only on the other
   module's IO; only the app composition root may import Plugins.

5. **Update the app composition install list**:
   ```swift
   // App/ServiceRegistry+Modules.swift
   launcher.install(OnboardingTutorialLauncherPlugin())
   ```

6. **Run repository-owned dependency/project generation if required**, then run the split slice's
   owned native signal once. It should exercise activation from both sides and, for UI Boards, the
   affected UIKit and/or SwiftUI adapter semantics.

### Verification

- [ ] Both modules have distinct IO + Plugins build surfaces and ServiceMaps.
- [ ] Cross-dependencies are acyclic and target IO only.
- [ ] No public BoardID renamed (rename is a separate refactor — see Refactor 5).
- [ ] The one final joined AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] App still launches; first Board on each side activates without `BoardID not registered` crash.

### Rollback

If the split goes wrong (cross-deps become cyclic, or callers can't find symbols), roll back the current
semantic slice to its chosen working boundary before attempting a different cut:

1. Don't `git reset --hard` — you'll lose unrelated work.
2. Restore the last complete semantic boundary: revert complete refactor commits in reverse dependency
   order when they exist, or reverse the planned caller/registration/file changes without discarding
   unrelated edits.
3. Confirm the old registrations and callers are again coherent before re-cutting with a different line.

---

## Refactor 2 — Merge two modules

Goal: take two modules that have grown into each other and collapse them into one. Harder than splitting because every consumer's `import` must change.

### Confirm the merge is right

Merging modules is usually the wrong call. Before doing it:

- Resolve `{ModuleRoot}`, `{AppRoot}`, package manifests, and the native dependency-refresh command
  from the consuming repository's root `CLAUDE.md` or `AGENTS.md` before using any snippet below.
- Count cross-module calls: `git grep -E "mod{ModuleA}.io" {ModuleRoot}/{ModuleB}/` and vice versa. If <5 in EACH direction, the modules aren't really tangled — the cross-calls are intentional, leave them.
- Check ownership: if different teams own each module, the merge creates a new ownership conflict.
- Check Board fan-in: if `{ModuleA}` is consumed from multiple places but `{ModuleB}` is consumed only by `{ModuleA}`, the right refactor is "promote ModuleB's Boards into ModuleA's Sources/Microboards/" (Refactor 3 — Extract a Board, in reverse: absorb).

If ALL three checks favor merging, proceed.

### Mechanical sequence

Pick a survivor module (`{Keeper}`) and an absorbed module (`{Absorbed}`). The Keeper keeps its name; Absorbed disappears.

1. **Update every consumer's `import`**:
   ```bash
   git grep -l "import {Absorbed}" -- {ModuleRoot} {AppRoot} | xargs sed -i '' 's/import {Absorbed}/import {Keeper}/g'
   git grep -l "import {Absorbed}Plugins" -- {ModuleRoot} {AppRoot} | xargs sed -i '' 's/import {Absorbed}Plugins/import {Keeper}Plugins/g'
   ```
   Verify with `git grep "{Absorbed}"` — only the Absorbed module itself should match now.

2. **Update every consumer's ServiceMap accessor**:
   ```bash
   git grep -l "mod{Absorbed}\b" -- {ModuleRoot} {AppRoot} | xargs sed -i '' 's/mod{Absorbed}\b/mod{Keeper}/g'
   git grep -l "mod{Absorbed}Plugins\b" -- {ModuleRoot} {AppRoot} | xargs sed -i '' 's/mod{Absorbed}Plugins\b/mod{Keeper}Plugins/g'
   ```

3. **Update public BoardID literals**:
   ```bash
   git grep -l "pub\\.mod\\.{Absorbed}\\." -- {ModuleRoot} {AppRoot} | xargs sed -i '' 's/pub\\.mod\\.{Absorbed}\\./pub.mod.{Keeper}./g'
   ```
   Changing a raw BoardID is a breaking runtime change even when the source module disappears. Do it
   only as an explicitly declared breaking cutover with all callers migrated; otherwise retain each
   old raw ID and register it as a compatibility route to the Keeper implementation (see Refactor 5).

4. **Move source files**:
   ```bash
   git mv {ModuleRoot}/{Absorbed}/IO/*  {ModuleRoot}/{Keeper}/IO/
   git mv {ModuleRoot}/{Absorbed}/Sources/Microboards/*  {ModuleRoot}/{Keeper}/Sources/Microboards/
   git mv {ModuleRoot}/{Absorbed}/Sources/Services/*  {ModuleRoot}/{Keeper}/Sources/Services/
   ```
   Resolve filename collisions (rare — only if both modules had a `Welcome` Board) by renaming one.

5. **Merge ModulePlugin**: open `{Keeper}ModulePlugin.swift` and `{Absorbed}ModulePlugin.swift`. Combine the `ServiceType` enums (add Absorbed's cases to Keeper). Combine the registration lists. Delete `{Absorbed}ModulePlugin.swift`.

6. **Merge LauncherPlugin**: same — fold Absorbed's launch wiring into Keeper's. Delete `{Absorbed}LauncherPlugin.swift`.

7. **Delete the absorbed module directory**:
   ```bash
   git rm -rf {ModuleRoot}/{Absorbed}/
   ```

8. **Update the bound build/package manifests** — remove the Absorbed Interface and Implementation
   targets using the consuming repository's adapter. For a CocoaPods-bound project only, that means
   removing its two Podfile entries; SwiftPM, Bazel, and mixed projects use their native equivalent.

9. **Update App's `installAllModules()`** — remove `{Absorbed}LauncherPlugin()` install.

10. **Run the bound dependency refresh once, if the selected adapter requires one**.

11. **Run the merge slice's owned signal once** — use the consuming repository's native command after all executable cutover work is complete. It should exercise the flows that previously crossed the boundary.

### Verification

- [ ] `git grep "{Absorbed}"` returns nothing (other than the changelog entry documenting the merge).
- [ ] The one final joined AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] No `BoardID not registered` crashes on the formerly-cross-module flows.
- [ ] Module count under the bound `{ModuleRoot}` decreased by exactly one.

### Rollback

Merges are hard to roll back partially. Restore the pre-merge contract, registrations, package edges, and
callers as one coordinated rollback slice (or revert the complete merge commit when one exists). Do not
ship or continue from a half-merged state.

---

## Refactor 3 — Extract a Board

Goal: take a single Board that's doing too much (or has a reusable sub-flow) and pull part of it out into a new Board within the same module.

### Decide WHAT to extract

The unit of extraction is usually one of these:

- A **sub-flow** that takes its own Input and returns its own Output (e.g. "the ad-loading half" of a "show interstitial then continue" flow).
- A **state machine** that lives independently of the parent's UI (e.g. "the loading-with-retry coordinator").
- A **reusable activity** invoked from multiple parent Boards (in which case the new Board may end up promoted to module-public; see step 4 below).

Don't extract because the file is long. Long files with a single coherent responsibility are FINE.

### Mechanical sequence

1. **Decide the new Board's type** via `DECISION_TREES.md` Tree §1:
   - Sub-flow that returns a value → `viewless` or `flow` Board.
   - One async task then done → `blocktask`.
   - Has its own UI → `ui`.
   - Composable surface element → composable child of the existing surface.

2. **Decide visibility before creating files**:
   - **Internal-only** (called only inside this module): keep the contract under
     `Sources/Microboards/{NewBoard}/` with `mod.{Module}.{NewBoard}` and no `public` surface.
   - **Public** (a proven cross-module caller exists): place the contract under
     `IO/{NewBoard}/` with `pub.mod.{Module}.{NewBoard}`.
   - A hypothetical future caller is not evidence. When in doubt, start internal; promotion is
     additive, while demotion is breaking.

3. **Create the visibility-correct skeleton**:
   - Public Board: run `ifl-new-board {Module} {NewBoard} {type} --root=. --module-root={ModuleRoot}`.
   - Internal Board: create the type-specific implementation and internal IO directly under
     `Sources/Microboards/{NewBoard}/`; the current CLI deliberately emits public IO and must not be
     used and then partially deleted to simulate an internal Board.

4. **Move the extracted logic**:
   - Cut from old Board's Interactor (or Controller / BlockTask handler) → paste into new Board's Interactor.
   - Define `Input` for the new Board to mirror what the old Board was passing internally.
   - Define `Output` to carry whatever the old Board's caller path expected.

5. **Update the old Board** to activate the new Board:
   ```swift
   // In old Board's Interactor / Controller:
   motherboard.serviceMap.mod{Module}Plugins.io{NewBoard}.activation.activate(with: {NewBoard}Input(...))
   // Or, if new Board is public:
   motherboard.serviceMap.mod{Module}.io{NewBoard}.activation.activate(with: ...)
   ```

6. **Register the new Board** in `{Module}ModulePlugin`:
   - Add a `ServiceType` case (or, if internal, add to `internalContinuousRegistrations`).
   - For internal: no LauncherPlugin change needed.
   - For public: add the case to the LauncherPlugin's exposed map.

7. **Complete the extraction slice's executable coverage**. Add or update tests where the behavior and regression risk warrant them, then run the consuming repository's assigned native signal once for the complete slice. The new Board's behavior should be isolatable at the Interactor, use-case, or public seam; do not invent a plugin-side gate.

### Verification

- [ ] Old Board's file is now shorter and has a single clear responsibility.
- [ ] New Board activates from the old Board's flow without crashes.
- [ ] If new Board is internal, no `public` modifiers leaked out.
- [ ] If new Board is public, BoardID matches `pub.mod.{Module}.{NewBoard}`.
- [ ] Applicable executable behavior is covered at the cheapest meaningful seam and the slice's owned consuming-repo signal passed.

### Rollback

Extractions are usually safe to roll back while they are additive. Restore the old Board's behavior and
call route, then remove the new registration and files as one slice; revert the complete extraction commit
when one exists. If other call sites have already shipped against the new Board, preserve a bridge or
migrate those callers before removing it.

---

## Refactor 4 — Move a Board across modules

Goal: a Board lives in `{Source}` but really belongs in `{Destination}`. This is the most common Phase E refactor; it's the building block of Refactor 1 (Split a module).

### Confirm the move is right

- Count the Board's imports: if it imports more types from `{Destination}` (or `{Destination}Plugins`) than from `{Source}`, it's in the wrong place.
- Count callers: if every caller is in `{Destination}` or in App-boot code, move it.
- Check BoardID: if the Board is currently public (`pub.mod.{Source}.{Board}`), the move is a breaking rename — see "Public Board" below.

### Mechanical sequence — internal Board (lives in `Sources/Microboards/`)

Internal Boards have no cross-module callers by definition. The move is mechanical.

1. **`git mv`** the Board's files:
   ```bash
   git mv {ModuleRoot}/{Source}/Sources/Microboards/{Board}/ \
          {ModuleRoot}/{Destination}/Sources/Microboards/{Board}/
   ```

2. **Update the BoardID literal** inside `{Board}IOInterface.swift`:
   ```swift
   // before:
   static let mod{Board}: BoardID = "mod.{Source}.{Board}"
   // after:
   static let mod{Board}: BoardID = "mod.{Destination}.{Board}"
   ```

3. **Update `import` statements** in the moved files: anything that was `import {Source}` may need to become `import {Destination}` (if it referenced same-module types) or stay (if it referenced now-cross-module types).

4. **Move the registration**:
   - Cut the `BoardRegistration` from `{Source}ModulePlugin.internalContinuousRegistrations`.
   - Paste into `{Destination}ModulePlugin.internalContinuousRegistrations`.

5. **Update activation sites**: any call to `motherboard.serviceMap.mod{Source}Plugins.io{Board}` becomes `motherboard.serviceMap.mod{Destination}Plugins.io{Board}`. Use `git grep` to find every site:
   ```bash
   git grep "mod{Source}Plugins.io{Board}"
   ```

6. **Inspect every changed BoardID literal and caller** before completing the move, then run the move
   slice's assigned consuming-repo signal once if executable behavior changed.

### Mechanical sequence — public Board (lives in `IO/`)

Public Boards have external callers; the BoardID literal change is a runtime-breaking rename. Two options:

**Option A — declared breaking/coordinated cutover** (all runtime callers can migrate atomically):

1-6 same as internal-Board sequence, but ALSO update every cross-module caller's `import` + ServiceMap accessor (similar to Refactor 2 steps 1-2 scoped to this one Board).

7. Declare the breaking contract in the release/migration notes and run `git grep` for the OLD
   literal — it must return zero hits before completing the coordinated cutover.

**Option B — bridge alias** (callers are external — other repos, published SDKs, anything beyond your control):

1-4 as internal-Board sequence; ALSO preserve the old raw ID in `{Source}/IO/`:
   ```swift
   // {ModuleRoot}/{Source}/IO/{Board}/{Board}IOInterface.swift  (compatibility bridge)
   public extension BoardID {
       static let pub{Board}Legacy: BoardID = "pub.mod.{Source}.{Board}" // exact old raw ID
       static let pub{Board}: BoardID = "pub.mod.{Destination}.{Board}"
   }
   public typealias {Board}MainDestination = MainboardGenericDestination<...>
   // Keep the legacy accessor targeting .pub{Board}Legacy during the migration window.
   ```
5. Register **both** `.pub{Board}Legacy` and `.pub{Board}` to the same Destination builder/factory.
   A deprecated Swift alias that points only to the new literal is not a runtime bridge.
6. Document bridge ownership, migration telemetry/evidence, and removal policy in the module's
   compatibility notes. Remove the old registration only in a declared breaking release after callers migrate.

### Verification

- [ ] The old raw BoardID returns zero hits after declared Option A cutover, or remains in the
  Option B compatibility constant, accessor, and registration.
- [ ] The moved Board's literal matches its new home pattern.
- [ ] The move slice's owned signal activates the Board from a Destination-module caller.
- [ ] If public + Option A: the assigned signal covers every affected former Source-module caller path, or the plan names the distinct risk boundary and its owner.

### Rollback

Internal-Board moves are safe to reverse by restoring the old registration, callers, BoardID, and files as
one slice. Public Option A moves require the same coordinated caller rollback. A shipped Option B bridge is
already compatibility state: keep it active and plan its later removal rather than deleting it during an
incident.

---

## Refactor 5 — Rename a public symbol

Goal: rename a public BoardID, module name, or public Input/Output type to better describe what it is.

### Confirm the rename is worth it

Renames are EXPENSIVE and BREAKING. Before doing one:

- The current name is genuinely wrong or misleading, AND it confuses readers regularly.
- The new name is settled — no debate left, just the mechanical change.
- You've checked external callers (other repos, published SDKs) and have a migration plan for them.

If the rename is just "I like Y better than X", don't do it. Drift between name and reality is the threshold.

### Three flavors

| What's renamed | Breaking surface |
|---------------|-------------------|
| Module name (`{Old}` → `{New}`) | Every `import {Old}` + `import {Old}Plugins` + `mod{Old}` + `mod{Old}Plugins` + `pub.mod.{Old}.*` BoardID literal + native target/manifest entry + LauncherPlugin class name |
| Public BoardID (`pub.mod.{Module}.{OldBoard}` → `pub.mod.{Module}.{NewBoard}`) | The literal string itself + `pub{OldBoard}` constant + `io{OldBoard}` accessor + `{OldBoard}MainDestination` typealias |
| Public Input/Output type | Every consumer's reference to the type name; usually less impact since types are referenced by their MainDestination |

### Mechanical sequence — public BoardID rename (most common)

1. **Classify the rename before editing**:
   - **Swift constant only**: keep the old raw literal and add a deprecated Swift-name alias.
   - **Raw literal changes**: either declare a breaking coordinated cutover, or run both raw IDs as
     registered compatibility routes. A Swift alias alone cannot bridge Boardy's string registry.

2. **For a compatible raw-literal migration, retain and register both IDs**:
   ```swift
   public extension BoardID {
       static let pub{NewBoard}: BoardID = "pub.mod.{Module}.{NewBoard}"
       @available(*, deprecated, message: "Migrate to pub{NewBoard}")
       static let pub{OldBoard}: BoardID = "pub.mod.{Module}.{OldBoard}" // exact old raw ID
   }
   ```
   Register `.pub{OldBoard}` and `.pub{NewBoard}` to the same builder/factory for the documented
   migration window. Keep the old accessor targeting `.pub{OldBoard}`. If dual registration is not
   supported, the change is breaking and must be declared as such; do not claim compatibility.

3. **Rename the file**:
   ```bash
   git mv {ModuleRoot}/{Module}/IO/{OldBoard}/  {ModuleRoot}/{Module}/IO/{NewBoard}/
   git mv {ModuleRoot}/{Module}/IO/{NewBoard}/{OldBoard}IOInterface.swift  \
          {ModuleRoot}/{Module}/IO/{NewBoard}/{NewBoard}IOInterface.swift
   # repeat for InOut.swift and ServiceMap+{Board}.swift
   ```

4. **Update Swift identifiers** — `git grep` for `{OldBoard}` inside the module and rename:
   - Type names: `{OldBoard}Input` → `{NewBoard}Input`, etc.
   - Accessors: `io{OldBoard}` → `io{NewBoard}`.
   - Constants: `pub{OldBoard}` → `pub{NewBoard}`.

5. **Update controlled callers** in the same change. Uncontrolled callers remain on the registered
   old raw ID until the compatibility policy permits its removal.

6. **Update the ModulePlugin**: `ServiceType` case + identifier mapping.

7. **For external callers**: publish the migration and keep the old constant, raw-ID registration,
   and accessor for the governed deprecation window. Removal requires a declared breaking release;
   elapsed time alone does not prove that runtime callers migrated.

8. **Inspect the renamed public surface and every caller** before completing the rename, then run the
   rename slice's assigned consuming-repo signal once if executable behavior changed.

### Mechanical sequence — module rename

This is essentially Refactor 2 (Merge) where the absorbed module is "empty" and the keeper takes its
place. Steps 1-3 of Refactor 2 apply, scoped to the rename. Rename the native target and manifest
entries through the consuming repository's bound build/package adapter.

### Verification

- [ ] `git grep "{OldName}"` returns zero non-deprecated references (or only the bridge with `@available(*, deprecated)`).
- [ ] Every BoardID literal matches its owning module and visibility pattern.
- [ ] The rename slice's owned consuming-repo signal covers every affected public call path.

### Rollback

Before release, restore the prior public surface and all callers as one rollback slice (or revert the
complete rename commit). After release, keep or reintroduce the compatibility alias and roll forward with a
coordinated migration; never restore only the Swift name while leaving runtime literals or registrations on
the new contract.

---

## Common blockers + defusion

| Blocker | Fix |
|---------|-----|
| Native dependency refresh reports duplicate sources after move | The selected build/package adapter still references the old path. Update its source declaration. In a CocoaPods-bound repository this may be a podspec `source_files` entry; other adapters use their native manifest. |
| `BoardID not registered` after move (public Board) | `ModulePlugin`'s `ServiceType.identifier` switch still maps the old case to the old BoardID. Update both case names and the mapped identifier |
| Compile error: ambiguous type `Welcome` after merge | Both modules had a `Welcome` Board; the merge collided them. Rename one before completing the merge |
| Final review finds `import {Other}Plugins` after split | One module's Board now imports the other's Plugins target — should be IO. Either move the type to `{Other}/IO/` (if it's domain) or move the Board back to `{Other}` (if it needs construction wiring) |
| Final review finds `Sources-has-public` after extraction | Extracted Board's IO ended up in `Sources/Microboards/` but kept its `public` modifiers from when it was in `IO/`. Drop `public` for internal Boards; or move the IO trio to `{Module}/IO/{NewBoard}/` for public Boards |
| Renaming a Board breaks UI tests that match on accessibility identifiers | Accessibility IDs in some test setups use the Board name. Update test fixtures alongside the rename |

---

## Anti-patterns

- ❌ **Unbounded mass-rename** — changing names before mapping definitions, runtime literals, registrations, package edges, and callers hides real breakage. Keep a complete semantic task reviewable; file families are not artificial commit or gate boundaries.
- ❌ **Refactor + feature in the same PR** — reviewers can't distinguish rename noise from real changes. Land the refactor on its own; then the feature.
- ❌ **Executable refactor without an applicable owned signal** — choose the consuming repository's cheapest native build/test signal that can falsify the slice. Documentation-only changes wait for the final joined AI review instead of receiving fake runtime coverage.
- ❌ **Splitting because the directory is "too big"** — file count is a symptom, not a cause. Find the conceptual cut line; if there isn't one, the module is correctly sized.
- ❌ **Merging because two modules share a service** — extract the service to a third module instead. Merging is the wrong response to a shared dependency.
- ❌ **Renaming a public BoardID literal without a bridge** — external callers will hit `BoardID not registered` at runtime, silently. Always check for external callers; if any exist, bridge before removal.
- ❌ **"While I'm in here..." cleanup** — refactor is already high-stakes. Don't compound it with unrelated improvements. Open a separate PR for each.
- ❌ **Creating intermediate plugin gates between steps** — complete the semantic refactor, use its owned consuming-repo code signal, then include the full change in the plan's one final joined AI review.

---

## Per-refactor final-state checklist

Evaluate this once over the completed refactor candidate. These are final-state obligations, not per-step
gates, receipts, or requests to rerun unchanged signals.

### Split / Merge / Move
- [ ] The one final joined AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] Public domain contracts remain in `IO/**`; only the minimum App-boot construction surface is public under `Sources/Plugins/**`, and no sibling module imports Plugins.
- [ ] Cross-deps are acyclic in the consuming repository's native dependency graph; any
  manager-specific inspection command comes from project bindings.
- [ ] The assigned native signal covers launch/activation and the affected flows at the planned risk boundary.
- [ ] No leftover `import {Old}` / `mod{Old}` / `pub.mod.{Old}` references unless intentional (bridge alias).
- [ ] Affected UIKit and SwiftUI adapters still consume equivalent display-ready semantics and forward the same typed intents.

### Extract
- [ ] Applicable executable behavior is covered at the cheapest meaningful isolated seam.
- [ ] Old Board's responsibility statement is now shorter / clearer.
- [ ] New Board's visibility (internal vs. public) chosen deliberately, not by default.
- [ ] A UI extraction leaves formatting and product decisions in the Presenter/equivalent mapper, not either rendering adapter.

### Rename
- [ ] `git grep "{OldName}"` returns only deprecated-bridge references.
- [ ] External callers (if any) given a migration window via `@available(*, deprecated)`.
- [ ] BoardID literals match the contract for both old (bridge) and new constants.

---

## References

- `MODULE_CREATION.md` — what `ifl-new-module` produces; baseline for split + merge targets.
- `IO_INTERFACE.md` — public surface contract; touched by every public refactor.
- `IO_INTERFACE.md` §"Domain meaning vs construction wiring" — decides where to land a moved provider config.
- `DECISION_TREES.md` — pattern selection when extracting a Board (Tree §1) or deciding public vs internal (Tree §2) or cross-module dep direction (Tree §8).
- `TROUBLESHOOTING.md` — symptom → fix during refactor breakage (especially §1.5, §2.3, §6.2, §7.1).
- `REVIEW_PLAYBOOK.md` — review guidance for refactor PRs (cite the BoardID-rename template for breaking renames).
- `BROWNFIELD_MIGRATION.md` — when the refactor target is actually "adopt the pack into legacy code", that's a different problem.
- `COMMIT_WORKFLOW.md` — refactor commits often touch many files; respect the pack-side commit/push approval rules.
