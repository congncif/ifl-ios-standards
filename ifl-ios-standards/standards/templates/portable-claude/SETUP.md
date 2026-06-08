<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- template-version: 1.0.0 -->

# SETUP.md — One-Time Project Setup Playbook

> **Audience**: AI agent performing first-time bootstrap of this template in a fresh project.
> **Trigger**: User says *"setup project per `.ai/SETUP.md`"* (or equivalent) on a project that has root `AGENTS.md` / `CLAUDE.md` + `.ai/brain/` but lacks the binding files.
> **Install location**: this file lives at `.ai/SETUP.md` (NOT repo root), to keep the project root clean.
> **Goal**: Generate `PROJECT_CONFIG.md`, `PROJECT_STRUCTURE.md`, and (optionally) `QUICK_REF.md` by combining user input with project introspection. After this playbook completes, `CLAUDE.md` + brain + bindings form a complete agentic baseline.
> **Authority**: This file is a one-shot procedure. Once bindings exist, do not re-read SETUP.md per session.

---

## 1. Preconditions

Before starting, verify all three:

- [ ] `AGENTS.md` (and/or `CLAUDE.md` copy) exists at repo root.
- [ ] `.ai/brain/QUICK_REF.md` and `.ai/brain/rulebook/` (chapter files) exist.
- [ ] No `PROJECT_CONFIG.md` / `PROJECT_STRUCTURE.md` already present at the chosen bindings root (default: `.ai/rules/`, alternatives the user may prefer: `.claude/rules/` or `.config/`). If they exist, stop — setup has already been run.

If any precondition fails, stop and report what is missing.

---

## 2. Information Gathering (ask the user)

Ask **all** of these in one batch. Do not guess. Group as one structured question set; offer sensible defaults where possible.

### 2.1 Project identity
- **Project name** — human-readable, e.g. `Acme Banking iOS`.
- **Workspace or project file** — `*.xcworkspace` or `*.xcodeproj` filename at repo root.
- **Main app scheme** — primary buildable scheme.
- **Base git branch** — typically `main` or `master`.
- **Git remote name + URL** — typically `origin` + the GitHub/GitLab URL.

### 2.2 Build environment
- **Simulator / destination** — e.g. `iPhone 17` or `platform=iOS Simulator,name=iPhone 17`. Suggest discovering via `xcodebuild -showdestinations` if user is unsure.
- **Dependency manager** — CocoaPods / Swift Package Manager / Tuist / mixed.

### 2.3 Architecture choices
- **Presentation pattern** — MVVM / MVP / MVI / TCA / VIP / Boardy+VIP / custom. The brain rulebook stays pattern-neutral; the project picks one. **Recommended default: VIP** (`.ai/brain/patterns/VIP.md` — works with or without Boardy). If the project adopts VIP, surface that pattern guide in the project's `QUICK_REF.md` routing table.
- **Module-naming prefix** — empty or short prefix (e.g. `DAD`). Used in module/type naming patterns.
- **Module root path** — where module folders live, e.g. `submodules/`, `Modules/`, `Packages/`, or `none` (single-target app).
- **Bindings root path** — where `PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` should live. Default: `.ai/rules/`.
- **AI workspace root** — where plans/reports/scratch artifacts go. Default: `.superpowers/`.

### 2.4 Optional
- **Localization** — does the project use string-generation (SwiftGen, etc.)? If yes, capture the command.
- **Trace header convention** — required on new source files? Format?

If the user cannot answer an item, mark it `TBD` in the generated file and surface a final list of TBDs for follow-up.

---

## 3. Project Discovery (introspect the repo)

Run these read-only checks to confirm or supplement user answers. Use the Bash tool.

```bash
# Workspace / scheme discovery
ls *.xcworkspace *.xcodeproj 2>/dev/null
xcodebuild -workspace <Workspace> -list 2>/dev/null \
  || xcodebuild -project <Project> -list

# Module discovery
find <ModuleRoot> -maxdepth 2 -name "*.podspec" -print 2>/dev/null
find . -maxdepth 3 -name "Package.swift" -print

# Destinations
xcodebuild -workspace <Workspace> -scheme <MainScheme> -showdestinations 2>&1 \
  | grep "platform:iOS Simulator"

# Git remote
git remote -v
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null
```

Reconcile output with user answers. If a user-provided value conflicts with what `xcodebuild -list` reports, stop and ask.

---

## 4. Generate `PROJECT_CONFIG.md`

Path: `<BindingsRoot>/PROJECT_CONFIG.md` (default `.claude/project/PROJECT_CONFIG.md`).

Required sections (in order):

1. **Identity Configuration** — table: `{ProjectName}`, `{Workspace}`, `{MainScheme}`, `{ModulePrefix}`, `{BaseBranch}`, `{GitRemote}`, `{GitRemoteURL}`, `{Simulator}`, `{Destination}`.
2. **Project-Wide Path Configuration** — module root, bindings root, AI workspace root + subfolders (`plans/`, `specs/`, `brainstorms/`, `reports/`, `reviews/`, `scratch/`).
3. **Tooling Configuration** — dependency manager, interface/source globs, naming patterns, localization tool (if any).
4. **Build/Test/Debug Configuration** — canonical filtered `xcodebuild build` and `xcodebuild test` commands, plus an error-context command. Use grep-filtered output (`(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)` for build; `(error:|FAILED|PASSED|TEST SUCCEEDED|TEST FAILED)` for test). Forbid `-quiet` and `xcpretty -s`.
5. **Dependency / Project-Generation Configuration** — triggers that require regeneration (e.g., new module → `pod install`).
6. **AI Workflow Configuration** — table mapping artifact types to folders under AI workspace root.
7. **File Trace Header Configuration** — if user opted in.
8. **Git / Phase Workflow Configuration** — phase completion, commit approval, push approval, staging discipline.
9. **Placeholder Resolution Map** — single table resolving every `{Placeholder}` used by generic specs.
10. **Update Procedure** — one paragraph: when a value changes, update this file only; do not scatter values.

Style:
- Use Markdown tables for key/value rows.
- Use fenced code blocks for commands.
- Section headings: `## N. Title` numbered consecutively.
- Insert trace header on first line.

---

## 5. Generate `PROJECT_STRUCTURE.md`

Path: `<BindingsRoot>/PROJECT_STRUCTURE.md` (default `.claude/project/PROJECT_STRUCTURE.md`).

Required sections (in order):

1. **Project-Owned Scheme Inventory** — table: `Scheme`, `Purpose`, `Structure owner (path)`. Populate from `xcodebuild -list`. Filter out third-party CocoaPods schemes (Firebase, gRPC, etc.) — they should not appear here.
2. **Module Inventory** — table: `Module`, `Role`, `Interface target`, `Implementation target`. Populate from discovered modules.
3. **Synchronization Rules** — list events that require updating this file (module added/removed/renamed, scheme added/removed, ownership change).
4. **Verification Commands** — re-list the discovery commands so future agents can refresh inventory.

Style: same as PROJECT_CONFIG.md.

If the project is single-target (no modules), state that explicitly in the Module Inventory section and skip the row table.

---

## 6. Optional: Generate `QUICK_REF.md`

Skip by default. Generate only if the project will have ≥ 3 task-specific specs.

Path: `<BindingsRoot>/QUICK_REF.md`.

Required sections:

1. **Task → Spec Routing** — table mapping task categories to spec files.
2. **Project-specific naming conventions** — module names, file patterns, type-name patterns based on the chosen presentation pattern.
3. **Project-specific code patterns** — key code snippets the chosen pattern uses.
4. **Project-specific non-negotiable rules** — pattern-specific invariants that go beyond the generic brain rulebook.

If generated, list it as authority-step 3 in `CLAUDE.md` §2 of the target project (the template already does this).

---

## 7. Verify

After generating, run the canonical build command from the freshly written `PROJECT_CONFIG.md`. Report:

- Did the command resolve to a real workspace/scheme/destination?
- Did the build produce an explicit `** BUILD SUCCEEDED **`?
- If failed: list the first error and stop. Do not "fix" the project — bindings only describe reality; the project itself must build before setup is considered complete.

---

## 8. Completion Report

Produce a short report:

- Files created (paths).
- TBD values that the user still needs to fill in.
- Verification command run and its result.
- Suggested next step (e.g., "Start the first task by reading `CLAUDE.md`; the agent will route to `AGENTS.md` + bindings.").

Do not commit or push. Setup output stays unstaged until the user approves.

---

## 9. Self-Check (before reporting "setup complete")

- [ ] Root `AGENTS.md` / `CLAUDE.md` unchanged (this template doesn't edit it). Optionally update §5 if bindings root differs from the template default.
- [ ] `.ai/brain/` unchanged.
- [ ] `PROJECT_CONFIG.md` exists and contains every required section.
- [ ] `PROJECT_STRUCTURE.md` exists and reflects current schemes/modules.
- [ ] `QUICK_REF.md` exists only if the project actually needs it.
- [ ] Canonical build command verified against real signal.
- [ ] No project values scattered into `.ai/brain/` or root `AGENTS.md`/`CLAUDE.md` — bindings only.
- [ ] All generated files carry the trace header convention defined in `PROJECT_CONFIG.md`.

If all boxes check, report **setup complete**. Otherwise list the gap.

---

*End of one-time setup playbook. After completion, future sessions follow root `AGENTS.md`/`CLAUDE.md` → `.ai/brain/QUICK_REF.md` → bindings. SETUP.md is not loaded per session and may be deleted (or kept as historical record).*

## Reference samples

Worked examples of `PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` generated for a real Boardy+VIP project live in `.ai/templates/portable-claude/examples/` of the template repository. Use them as shape references — do NOT copy values literally; values are project-specific.
