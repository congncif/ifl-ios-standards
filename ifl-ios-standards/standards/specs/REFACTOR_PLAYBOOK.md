# REFACTOR_PLAYBOOK — procedural runbook for restructuring modules and Boards

> **Purpose**: step-by-step procedure for the five high-stakes structural refactors in a Boardy+VIP codebase — split a module, merge two modules, extract a Board, move a Board across modules, rename a public symbol. Each has a known mechanical sequence; doing them in the wrong order silently leaves callers broken or BoardIDs unreachable.
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

## Universal preconditions — verify before ANY refactor

| Check | How |
|-------|-----|
| `git status` clean | Refactors generate large diffs; mix with feature work = unreviewable PR |
| Working tree builds + tests green | Don't refactor on top of failing tests; you won't know which failures the refactor introduced |
| Affected architecture rules understood | Know the dependency, visibility, and BoardID constraints before moving code |
| Identify ALL callers of the surface you're about to change | `git grep` for the public BoardID literal, the IO ServiceMap accessor, the module name in imports |
| Confirm no in-flight PRs touch the same files | Merge conflicts on a refactor are painful; coordinate timing |
| Pack version pinned in `PROJECT_CONFIG.md` | If the pack itself just bumped, rebase the pack version first — don't conflate pack + refactor diffs |

If any check fails, stop and resolve. Refactors compound mistakes — the cleanup is exponentially more expensive than the prep.

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

1. **Create the new module** with `new-module.sh`:
   ```bash
   ifl-new-module OnboardingTutorial
   ```
   Emits the canonical 5-file skeleton. Don't hand-create — you'll miss the ServiceMap accessor or the podspec naming.

2. **Move Boards one at a time**. For each Board to relocate, use Refactor 4 (Move a Board across modules) below. Do NOT batch — one Board per commit. Reason: each move is reviewable; a multi-Board move is a flood of renamed-import noise that hides real mistakes.

3. **Decide cross-deps direction**. After moves, ONE of the two modules will end up depending on the other (via `s.dependency '{Other}'`). If BOTH need to depend on each other, you cut wrong — back out and re-cut.

4. **Update podspecs**:
   - Old module's `*.podspec`: remove `source_files` references that no longer exist.
   - New module's `*.podspec`: add cross-dep on old module via `s.dependency '{OldModule}'` (IO target only, never `{OldModule}Plugins`).

5. **Update Podfile** in the App + any other consumer:
   ```ruby
   pod 'OnboardingTutorial',        :path => 'submodules/OnboardingTutorial'
   pod 'OnboardingTutorialPlugins', :path => 'submodules/OnboardingTutorial'
   ```

6. **Update LauncherPlugin install list**:
   ```swift
   // App/ServiceRegistry+Modules.swift
   launcher.install(OnboardingTutorialLauncherPlugin())
   ```

7. **Run `pod install`** — this regenerates the workspace's Pods project.

8. **Build + smoke-test** — at minimum, activate one Board from each side of the split and confirm it renders.

### Verification

- [ ] Both modules have IO + Plugins podspecs + ServiceMaps.
- [ ] Cross-deps acyclic: `grep -E "s\\.dependency '{(Old|New)Module}'" submodules/*/*.podspec` shows at most one direction.
- [ ] No public BoardID renamed (rename is a separate refactor — see Refactor 5).
- [ ] The final AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] App still launches; first Board on each side activates without `BoardID not registered` crash.

### Rollback

If the split goes wrong (cross-deps become cyclic, or callers can't find symbols):

1. Don't `git reset --hard` — you'll lose mid-flight work in unrelated files.
2. `git revert {commit}` the new-module commit + each move commit, in reverse order.
3. Re-cut from scratch with a different cut line.

---

## Refactor 2 — Merge two modules

Goal: take two modules that have grown into each other and collapse them into one. Harder than splitting because every consumer's `import` must change.

### Confirm the merge is right

Merging modules is usually the wrong call. Before doing it:

- Count cross-module calls: `git grep -E "mod{ModuleA}.io" submodules/{ModuleB}/` and vice versa. If <5 in EACH direction, the modules aren't really tangled — the cross-calls are intentional, leave them.
- Check ownership: if different teams own each module, the merge creates a new ownership conflict.
- Check Board fan-in: if `{ModuleA}` is consumed from multiple places but `{ModuleB}` is consumed only by `{ModuleA}`, the right refactor is "promote ModuleB's Boards into ModuleA's Sources/Microboards/" (Refactor 3 — Extract a Board, in reverse: absorb).

If ALL three checks favor merging, proceed.

### Mechanical sequence

Pick a survivor module (`{Keeper}`) and an absorbed module (`{Absorbed}`). The Keeper keeps its name; Absorbed disappears.

1. **Update every consumer's `import`**:
   ```bash
   git grep -l "import {Absorbed}" -- submodules App | xargs sed -i '' 's/import {Absorbed}/import {Keeper}/g'
   git grep -l "import {Absorbed}Plugins" -- submodules App | xargs sed -i '' 's/import {Absorbed}Plugins/import {Keeper}Plugins/g'
   ```
   Verify with `git grep "{Absorbed}"` — only the Absorbed module itself should match now.

2. **Update every consumer's ServiceMap accessor**:
   ```bash
   git grep -l "mod{Absorbed}\b" -- submodules App | xargs sed -i '' 's/mod{Absorbed}\b/mod{Keeper}/g'
   git grep -l "mod{Absorbed}Plugins\b" -- submodules App | xargs sed -i '' 's/mod{Absorbed}Plugins\b/mod{Keeper}Plugins/g'
   ```

3. **Update public BoardID literals**:
   ```bash
   git grep -l "pub\\.mod\\.{Absorbed}\\." -- submodules App | xargs sed -i '' 's/pub\\.mod\\.{Absorbed}\\./pub.mod.{Keeper}./g'
   ```
   Note: this WILL break any external runtime caller using the old literal — but Absorbed is going away, so by definition there are no surviving external callers if all consumer-side changes above succeeded. If you can't be sure, add a literal alias as a bridge (see Refactor 5).

4. **Move source files**:
   ```bash
   git mv submodules/{Absorbed}/IO/*  submodules/{Keeper}/IO/
   git mv submodules/{Absorbed}/Sources/Microboards/*  submodules/{Keeper}/Sources/Microboards/
   git mv submodules/{Absorbed}/Sources/Services/*  submodules/{Keeper}/Sources/Services/
   ```
   Resolve filename collisions (rare — only if both modules had a `Welcome` Board) by renaming one.

5. **Merge ModulePlugin**: open `{Keeper}ModulePlugin.swift` and `{Absorbed}ModulePlugin.swift`. Combine the `ServiceType` enums (add Absorbed's cases to Keeper). Combine the registration lists. Delete `{Absorbed}ModulePlugin.swift`.

6. **Merge LauncherPlugin**: same — fold Absorbed's launch wiring into Keeper's. Delete `{Absorbed}LauncherPlugin.swift`.

7. **Delete the absorbed module directory**:
   ```bash
   git rm -rf submodules/{Absorbed}/
   ```

8. **Update Podfile** — remove `pod '{Absorbed}'` and `pod '{Absorbed}Plugins'`.

9. **Update App's `installAllModules()`** — remove `{Absorbed}LauncherPlugin()` install.

10. **Run `pod install`**.

11. **Build + smoke-test** — every flow that previously crossed the boundary should still work, now via in-module calls.

### Verification

- [ ] `git grep "{Absorbed}"` returns nothing (other than the changelog entry documenting the merge).
- [ ] The final AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] No `BoardID not registered` crashes on the formerly-cross-module flows.
- [ ] Module count in `submodules/` decreased by exactly one.

### Rollback

Merges are HARD to roll back partially. Either complete it or revert the entire branch. Don't ship a half-merged state.

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

2. **Generate the skeleton**:
   ```bash
   ifl-new-board {Module} {NewBoard} {type}
   ```

3. **Move the extracted logic**:
   - Cut from old Board's Interactor (or Controller / BlockTask handler) → paste into new Board's Interactor.
   - Define `Input` for the new Board to mirror what the old Board was passing internally.
   - Define `Output` to carry whatever the old Board's caller path expected.

4. **Decide visibility**:
   - **Internal-only** (called by only one Board in this module): keep new Board's IO under `Sources/Microboards/{NewBoard}/`; internal BoardID `mod.{Module}.{NewBoard}`.
   - **Cross-module candidate** (might be called from outside this module): promote IO to `{Module}/IO/{NewBoard}/`; public BoardID `pub.mod.{Module}.{NewBoard}`.
   - When in doubt, start internal. Promoting later is easy; demoting later is a breaking change.

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

7. **Test both Boards independently**. The new Board should be testable in isolation; that's the point of the extraction.

### Verification

- [ ] Old Board's file is now shorter and has a single clear responsibility.
- [ ] New Board activates from the old Board's flow without crashes.
- [ ] If new Board is internal, no `public` modifiers leaked out.
- [ ] If new Board is public, BoardID matches `pub.mod.{Module}.{NewBoard}`.
- [ ] Old Board's tests still pass; new Board has its own tests at Interactor level.

### Rollback

Extractions are usually safe to roll back — they're additive. `git revert` the extraction commit; the old Board returns to its original state. If you've already shipped activations via the new Board from OTHER call sites, you can't roll back without converting those too.

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
   git mv submodules/{Source}/Sources/Microboards/{Board}/ \
          submodules/{Destination}/Sources/Microboards/{Board}/
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

6. **Inspect every changed BoardID literal and caller** before completing the move.

### Mechanical sequence — public Board (lives in `IO/`)

Public Boards have external callers; the BoardID literal change is a runtime-breaking rename. Two options:

**Option A — coordinated cutover** (callers are all in your repo and you can change them in the same PR):

1-6 same as internal-Board sequence, but ALSO update every cross-module caller's `import` + ServiceMap accessor (similar to Refactor 2 steps 1-2 scoped to this one Board).

7. Run `git grep` for the OLD literal — must return zero hits before commit.

**Option B — bridge alias** (callers are external — other repos, published SDKs, anything beyond your control):

1-4 as internal-Board sequence; ALSO add a literal alias in `{Source}/IO/`:
   ```swift
   // submodules/{Source}/IO/{Board}/{Board}IOInterface.swift  (keep this file as a bridge)
   public extension BoardID {
       static let pub{Board}: BoardID = "pub.mod.{Destination}.{Board}"
   }
   public typealias {Board}MainDestination = MainboardGenericDestination<...>
   // ... keep the old surface, point its accessors at the new ID literal
   ```
5. Document the bridge in the module's README; plan removal after callers migrate.

### Verification

- [ ] `git grep "{Board}"` (the literal old BoardID) returns zero (Option A) or only the bridge alias (Option B).
- [ ] The moved Board's literal matches its new home pattern.
- [ ] Smoke test: activate the Board from a Destination-module caller; observe it works.
- [ ] If public + Option A: smoke test from every (former Source-module, now Destination-module) caller path.

### Rollback

Internal-Board moves are safe to revert. Public-Board moves with Option A are safe if you catch the issue before merge. Public-Board moves with Option B that have already shipped require removing the bridge in a future release; rollback is a separate refactor at that point.

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
| Module name (`{Old}` → `{New}`) | Every `import {Old}` + `import {Old}Plugins` + `mod{Old}` + `mod{Old}Plugins` + `pub.mod.{Old}.*` BoardID literal + podspec name + Podfile entry + LauncherPlugin class name |
| Public BoardID (`pub.mod.{Module}.{OldBoard}` → `pub.mod.{Module}.{NewBoard}`) | The literal string itself + `pub{OldBoard}` constant + `io{OldBoard}` accessor + `{OldBoard}MainDestination` typealias |
| Public Input/Output type | Every consumer's reference to the type name; usually less impact since types are referenced by their MainDestination |

### Mechanical sequence — public BoardID rename (most common)

1. **Don't immediately delete the old literal**. Instead, add an alias:
   ```swift
   public extension BoardID {
       static let pub{NewBoard}: BoardID = "pub.mod.{Module}.{NewBoard}"
       @available(*, deprecated, renamed: "pub{NewBoard}")
       static let pub{OldBoard}: BoardID = .pub{NewBoard}   // alias, same literal value? NO — this is for the Swift name, the literal IS changing
   }
   ```
   Two cases:
   - **Same literal, only Swift constant renamed**: the literal stays `"pub.mod.{Module}.{OldBoard}"`; only `pub{OldBoard}` → `pub{NewBoard}` in Swift. Add `@available(*, deprecated, renamed:)` to keep callers compiling but warned. This is a NIT-level rename and usually not worth doing as a dedicated refactor.
   - **Literal changes too**: this is the breaking case. The bridge alias keeps callers' Swift code compiling but the literal value changes — meaning Boardy's runtime registry now keys on the new string. If callers ever pass the literal directly (not via the constant) they're broken at runtime. Search for direct-literal usage: `git grep '"pub\\.mod\\.{Module}\\.{OldBoard}"'` — if any matches, those must be updated in lockstep.

2. **Update the IOInterface** to the new literal:
   ```swift
   public extension BoardID {
       static let pub{NewBoard}: BoardID = "pub.mod.{Module}.{NewBoard}"
   }
   ```

3. **Rename the file**:
   ```bash
   git mv submodules/{Module}/IO/{OldBoard}/  submodules/{Module}/IO/{NewBoard}/
   git mv submodules/{Module}/IO/{NewBoard}/{OldBoard}IOInterface.swift  \
          submodules/{Module}/IO/{NewBoard}/{NewBoard}IOInterface.swift
   # repeat for InOut.swift and ServiceMap+{Board}.swift
   ```

4. **Update Swift identifiers** — `git grep` for `{OldBoard}` inside the module and rename:
   - Type names: `{OldBoard}Input` → `{NewBoard}Input`, etc.
   - Accessors: `io{OldBoard}` → `io{NewBoard}`.
   - Constants: `pub{OldBoard}` → `pub{NewBoard}`.

5. **Update callers** in the same PR (zero external-caller assumption — if you can't make this assumption, you need a bridge release; see step 7).

6. **Update the ModulePlugin**: `ServiceType` case + identifier mapping.

7. **For external callers (different repos / published SDKs)**: ship the new constant alongside the old one for one release. Mark old as `@available(*, deprecated)`. Remove in the next major version.

8. **Inspect the renamed public surface and every caller** before completing the rename.

### Mechanical sequence — module rename

This is essentially Refactor 2 (Merge) where the absorbed module is "empty" and the keeper takes its place. Steps 1-3 of Refactor 2 apply, scoped to the rename. Also rename the podspec file: `git mv {Old}.podspec {New}.podspec`.

### Verification

- [ ] `git grep "{OldName}"` returns zero non-deprecated references (or only the bridge with `@available(*, deprecated)`).
- [ ] Every BoardID literal matches its owning module and visibility pattern.
- [ ] Smoke test every former call site.

### Rollback

If the rename is caught pre-merge: `git revert` the rename commit. Post-merge: you can roll forward to re-rename, but you can't safely roll back without a coordinated revert across every caller.

---

## Common blockers + defusion

| Blocker | Fix |
|---------|-----|
| `pod install` fails with "duplicate symbol" after move | Old podspec still references the moved file. Update `source_files` glob in the source module's podspec (typically `'IO/**/*.swift'` + `'Sources/**/*.swift'` doesn't need changing, but explicit-file podspecs do) |
| `BoardID not registered` after move (public Board) | `ModulePlugin`'s `ServiceType.identifier` switch still maps the old case to the old BoardID. Update both case names and the mapped identifier |
| Compile error: ambiguous type `Welcome` after merge | Both modules had a `Welcome` Board; the merge collided them. Rename one before completing the merge |
| Final review finds `import {Other}Plugins` after split | One module's Board now imports the other's Plugins target — should be IO. Either move the type to `{Other}/IO/` (if it's domain) or move the Board back to `{Other}` (if it needs construction wiring) |
| Final review finds `Sources-has-public` after extraction | Extracted Board's IO ended up in `Sources/Microboards/` but kept its `public` modifiers from when it was in `IO/`. Drop `public` for internal Boards; or move the IO trio to `{Module}/IO/{NewBoard}/` for public Boards |
| Renaming a Board breaks UI tests that match on accessibility identifiers | Accessibility IDs in some test setups use the Board name. Update test fixtures alongside the rename |

---

## Anti-patterns

- ❌ **Mass-rename in a single commit** — even with a clean rename, the diff is unreviewable. One refactor = one commit, ideally one PR per file family.
- ❌ **Refactor + feature in the same PR** — reviewers can't distinguish rename noise from real changes. Land the refactor on its own; then the feature.
- ❌ **Refactor without test coverage** — if the touched paths aren't exercised by tests, the refactor's correctness is unverified. Add tests first, then refactor.
- ❌ **Splitting because the directory is "too big"** — file count is a symptom, not a cause. Find the conceptual cut line; if there isn't one, the module is correctly sized.
- ❌ **Merging because two modules share a service** — extract the service to a third module instead. Merging is the wrong response to a shared dependency.
- ❌ **Renaming a public BoardID literal without a bridge** — external callers will hit `BoardID not registered` at runtime, silently. Always check for external callers; if any exist, bridge before removal.
- ❌ **"While I'm in here..." cleanup** — refactor is already high-stakes. Don't compound it with unrelated improvements. Open a separate PR for each.
- ❌ **Creating intermediate plugin gates between steps** — complete the semantic refactor, use its code tests, then include the full change in the plan's one final AI review.

---

## Per-refactor verification checklist

Tick before opening the PR:

### Split / Merge / Move
- [ ] The final AI review finds no dependency, visibility, or BoardID contract violation.
- [ ] Cross-deps acyclic (`grep -E "s\\.dependency" submodules/*/*.podspec` review).
- [ ] App launches; affected flows smoke-tested.
- [ ] No leftover `import {Old}` / `mod{Old}` / `pub.mod.{Old}` references unless intentional (bridge alias).

### Extract
- [ ] Both Boards have isolated tests.
- [ ] Old Board's responsibility statement is now shorter / clearer.
- [ ] New Board's visibility (internal vs. public) chosen deliberately, not by default.

### Rename
- [ ] `git grep "{OldName}"` returns only deprecated-bridge references.
- [ ] External callers (if any) given a migration window via `@available(*, deprecated)`.
- [ ] BoardID literals match the contract for both old (bridge) and new constants.

---

## References

- `MODULE_CREATION.md` — what `new-module.sh` produces; baseline for split + merge targets.
- `IO_INTERFACE.md` — public surface contract; touched by every public refactor.
- `IO_INTERFACE.md` §"Domain meaning vs construction wiring" — decides where to land a moved provider config.
- `DECISION_TREES.md` — pattern selection when extracting a Board (Tree §1) or deciding public vs internal (Tree §2) or cross-module dep direction (Tree §8).
- `TROUBLESHOOTING.md` — symptom → fix during refactor breakage (especially §1.5, §2.3, §6.2, §7.1).
- `REVIEW_PLAYBOOK.md` — review guidance for refactor PRs (cite the BoardID-rename template for breaking renames).
- `BROWNFIELD_MIGRATION.md` — when the refactor target is actually "adopt the pack into legacy code", that's a different problem.
- `COMMIT_WORKFLOW.md` — refactor commits often touch many files; respect the pack-side commit/push approval rules.
