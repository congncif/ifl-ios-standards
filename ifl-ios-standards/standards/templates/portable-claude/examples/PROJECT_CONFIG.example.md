<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->

# PROJECT_CONFIG.example.md — SHAPE REFERENCE

> ⚠️ **DO NOT COPY VALUES.** This file shows the *shape* of a real `PROJECT_CONFIG.md`. Fictional values use a generic example app (`ExampleApp` + modules `Auth`, `Profile`, `Catalog`, `Cart`, `Settings`). When SETUP.md generates the real file:
> - Replace every identity value (project name, workspace, URLs, simulator) with the user's actual answers.
> - Replace every module name with the project's real modules.
> - Keep the section order, table columns, command formats, and placeholder syntax intact.
> - Bindings root convention: `.claude/project/` (default). Bindings may instead live directly in the repo's `CLAUDE.md`/`AGENTS.md` — respect whichever the project chose.

---

# PROJECT_CONFIG — Project Configuration Contract

> **Purpose**: Single editable configuration contract for project-wide values. Generic doctrine, rules, examples, and agents read values from here instead of hard-coding project details.
>
> **How to customize**: keep this structure stable; update values inside tables/blocks. A copied rules pack should work in another project by replacing this file's values, not by rewriting the constitution or generic specs.
>
> **Boundary**: this file contains global configuration only. Current schemes, modules, module purposes, and topology inventory live in `<BindingsRoot>/PROJECT_STRUCTURE.md` and must be updated with code/PRD structure changes.
>
> **Precedence**: when this file conflicts with a generic rule or agent prompt, this file wins for project-specific configuration values.

---

## 1. Identity Configuration

| Key | Value |
|-----|-------|
| `{ProjectName}` | `ExampleApp` |
| `{Workspace}` | `ExampleApp.xcworkspace` |
| `{MainScheme}` | `ExampleApp` |
| `{ModulePrefix}` | *(none — modules use bare names; alternative: short prefix like `EXA`)* |
| `{BaseBranch}` | `main` |
| `{GitRemote}` | `origin` |
| `{GitRemoteURL}` | `https://github.com/example-org/ExampleApp.git` |
| `{Simulator}` | `iPhone 17` |
| `{Destination}` | `platform=iOS Simulator,name=iPhone 17` |

---

## 2. Project-Wide Path Configuration

| Concern | Value |
|---------|-------|
| Module root | `submodules/` *(CocoaPods; `Features/` for Bazel, `Packages/` for SPM)* |
| Project structure inventory | `<BindingsRoot>/PROJECT_STRUCTURE.md` |
| Working-docs root | `docs/02-working-docs/` *(per `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`)* |
| Plans root | `docs/02-working-docs/plans/` |
| Specs root | `docs/02-working-docs/specs/` |
| Research root | `docs/02-working-docs/research/` |
| Reports root | `docs/02-working-docs/reports/` |
| Work-items root | `docs/02-working-docs/work-items/` |
| Archive root | `docs/99-archive/` |

---

## 3. Tooling Configuration

| Concern | Value |
|---------|-------|
| Dependency manager | CocoaPods *(alternatives: Bazel + rules_xcodeproj, SwiftPM, Tuist, mixed — capture whichever the project uses)* |
| App dependency file | `Podfile` *(Bazel: `MODULE.bazel` / root `BUILD.bazel`)* |
| Module dependency files | `*.podspec` *(Bazel: `{ModuleRoot}/{ModuleName}/BUILD.bazel` with two `swift_library` targets)* |
| App plugin host | `SceneDelegate.scene(_:willConnectTo:options:)` *(or `AppDelegate` / `App.swift` for SwiftUI lifecycle)* |
| Interface source glob | `IO/**/*.swift` |
| Implementation source glob | `Sources/**/*.swift` |
| Interface target pattern | `{ModuleName}` |
| Implementation target pattern | `{ModuleName}Plugins` |
| Localization code generation | Run the project's chosen tool (e.g., `swiftgen`) already available on the machine; do not add a tool manager unless explicitly requested. |
| Localization config location | Each module owns its own `swiftgen.yml`; no root config for module strings. |
| Localization generated files | `{ModuleRoot}/{ModuleName}/Sources/Generated/{ModuleName}Strings.swift` |

---

## 4. Build/Test/Debug Configuration

### 4.1 Destination Discovery

Run destination discovery when `{Destination}` is stale or build output suggests unavailable simulator/device:

```bash
xcodebuild build -workspace {Workspace} -scheme {MainScheme} -showdestinations
```

### 4.2 Canonical Commands

Build any scheme with filtered output:

```bash
xcodebuild build -workspace {Workspace} -scheme {Scheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Build main app with filtered output:

```bash
xcodebuild build -workspace {Workspace} -scheme {MainScheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)"
```

Test any scheme with filtered output:

```bash
xcodebuild test -workspace {Workspace} -scheme {Scheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -E "(error:|warning:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED|BUILD SUCCEEDED|BUILD FAILED)"
```

Get error context after failed build:

```bash
xcodebuild build -workspace {Workspace} -scheme {Scheme} \
  -destination '{Destination}' \
  -derivedDataPath DerivedData 2>&1 \
  | grep -B 2 -A 5 "error:"
```

### 4.3 Verification Rules

| Rule | Detail |
|------|--------|
| No quiet build | Never use `-quiet`; it hides errors and causes misleading silent failures. |
| No silent pretty output | Never use `xcpretty -s`; it can suppress critical lines. |
| Empty grep output | Treat as failure, not success. Re-run without grep and report the real issue. |
| Build success | Requires explicit `** BUILD SUCCEEDED **`. |
| Test success | Requires explicit `** TEST SUCCEEDED **` or all tests `PASSED`, with no `error:` lines. |
| Destination validity | Use a real device from `-showdestinations`; stale device names mislead. |

---

## 5. Dependency/Project Generation Configuration

| Trigger | Required action |
|---------|-----------------|
| New module | Add Podfile entries, then run `pod install`. |
| New pod dependency | Update podspec/Podfile, then run `pod install`. |
| Removed pod dependency | Update podspec/Podfile, then run `pod install`. |
| Changed `source_files` or `resources` glob | Run `pod install`. |
| New Swift files created outside Xcode project generation | Run `pod install` if CocoaPods/project generation must refresh file membership. |
| Updated `Localizable.strings` in a module | Run `swiftgen config run --config swiftgen.yml` from that module directory. |
| Added or changed a module `swiftgen.yml` | Run `swiftgen config run --config swiftgen.yml` from that module directory and commit generated Swift. |

Podfile local path syntax:

```ruby
pod '{ModuleName}',        :path => 'submodules/{ModuleName}'
pod '{ModuleName}Plugins', :path => 'submodules/{ModuleName}'
```

Podspec dependency syntax:

```ruby
s.dependency '{DependencyName}'
```

Never add local `:path` hints to `s.dependency`; local paths belong in the app-level dependency configuration.

---

## 6. AI Workflow Configuration

All AI workflow artifacts live in-repo under the `docs/` tree, per
`${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`.

| Artifact type | Location |
|---------------|----------|
| Plans | `docs/02-working-docs/plans/` |
| Specs | `docs/02-working-docs/specs/` |
| Research / spikes | `docs/02-working-docs/research/` |
| Reports | `docs/02-working-docs/reports/` |
| Work-item briefings | `docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/handoffs/` |
| Living docs (PRD, architecture, ADR) | `docs/01-living-docs/…` |
| Superseded / archived | `docs/99-archive/<original-bucket>/` |

Rules:

- Place AI workflow artifacts under the repo `docs/` tree (in-repo, version-controlled, classified) — never in machine-global locations (`~/.claude/`, OS temp).
- Do not scatter docs at the repo root or under `.claude/` (reserve `.claude/` for tool config only).
- Working docs are date-prefixed: `YYYY-MM-DD-<topic>.md`. Living docs use stable kebab names. ADRs: `NNNN-kebab-title.md`.

---

## 7. File Trace Header Configuration

Every new Swift source, spec, plan, report, or workflow artifact starts with a trace header.

Swift/source variant:

```swift
// Created by <ai-model-id> on <YYYY-MM-DD>
```

Markdown variant:

```markdown
<!-- Created by <ai-model-id> on <YYYY-MM-DD> -->
```

Use the model ID that creates the file. Do not edit the header on later revisions.

---

## 8. Git Authority / Checkpoint Workflow Configuration

| Rule | Binding |
|------|---------|
| Trace boundary | One complete semantic task per commit by default; final AI review covers the full plan. |
| Plan vs Git authority | Plan approval alone grants no Git operation; bind per-operation or scoped auto-commit authority explicitly. |
| Commit authority | `scoped-auto-commit` may authorize local stage+commit after every semantic task in the approved plan/repo/branch; otherwise use per-operation authority. |
| Other Git operations | Branch, amend/history rewrite, push, PR, merge, tag, publish, install, and release remain separate. |
| Staging | Stage explicit intended paths only; avoid broad staging. |
| Target remote/base | `{GitRemote}` / `{BaseBranch}`; never infer the push branch from the base branch. |

---

## 9. Placeholder Resolution Map

| Placeholder | Resolution |
|-------------|------------|
| `{ProjectName}` | `ExampleApp` |
| `{Workspace}` | `ExampleApp.xcworkspace` |
| `{MainScheme}` | `ExampleApp` |
| `{Scheme}` | Bound per task; use `{MainScheme}` unless a module scheme is specified. Current scheme inventory lives in `<BindingsRoot>/PROJECT_STRUCTURE.md`. |
| `{Simulator}` | `iPhone 17` |
| `{Destination}` | `platform=iOS Simulator,name=iPhone 17` |
| `{BaseBranch}` | `main` |
| `{GitRemote}` | `origin` |
| `{GitRemoteURL}` | `https://github.com/example-org/ExampleApp.git` |
| `{ModuleName}` | Bound per task. Current module inventory lives in `<BindingsRoot>/PROJECT_STRUCTURE.md`. |
| `{ModulePluginsName}` | `{ModuleName}Plugins` |
| `{NoPrefixName}` | Same as `{ModuleName}` because this example uses no default prefix. |
| `{ModuleRoot}` | `submodules/` *(Bazel: `Features/`)* |
| `{ProjectStructure}` | `<BindingsRoot>/PROJECT_STRUCTURE.md` |
| `{WorkingDocsRoot}` | `docs/02-working-docs/` |

---

## 10. Update Procedure

When a project-wide configuration value changes:

1. Update the relevant row or command block in this file.
2. Do not edit root `AGENTS.md` / `CLAUDE.md` for project-local values.
3. Do not scatter the value across generic specs, examples, or agents.
4. If a generic rule needs a new project-wide configuration binding, add a row or section here using the existing structure.

When schemes, modules, module purposes, or topology change, update `<BindingsRoot>/PROJECT_STRUCTURE.md` in the same change set.
