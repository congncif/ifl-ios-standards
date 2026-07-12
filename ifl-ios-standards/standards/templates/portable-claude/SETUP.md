<!-- template-version: 2.4.0 -->
<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->

# SETUP.md — One-Time Project Setup Playbook

> **Audience**: AI agent performing first-time bootstrap of this template in a fresh project.
> **Trigger**: User says *"set up project bindings"* (or equivalent) on a project that has the
> `ifl-ios-standards` plugin installed + a root `CLAUDE.md` / `AGENTS.md`, but lacks the binding files.
> **Goal**: Generate `PROJECT_CONFIG.md`, `PROJECT_STRUCTURE.md`, and (optionally) `QUICK_REF.md` by
> combining user input with project introspection. After this playbook completes, the plugin
> standard + the project's bindings form a complete agentic baseline.
> **Authority**: This file is a one-shot procedure. Once bindings exist, do not re-read SETUP.md per session.

---

## 1. Preconditions

Before starting, verify:

- [ ] The `ifl-ios-standards` plugin is installed and enabled (`claude plugin list` / `codex plugin list` shows it; `/ifl-ios-standards:init` or a relevant `brain-*` / `boardy-*` skill resolves). The reusable rulebook + specs ship in the plugin at `${CLAUDE_PLUGIN_ROOT}/standards/`.
- [ ] A root `CLAUDE.md` (and/or twin `AGENTS.md`) exists — even a stub. Project bindings can live directly in it, or in separate files (this playbook generates the separate-file form).
- [ ] No `PROJECT_CONFIG.md` / `PROJECT_STRUCTURE.md` already present at the consuming repository's
  chosen bindings root. If they exist, stop — setup has already been run.

If any precondition fails, stop and report what is missing.

---

## 2. Information Gathering (ask the user)

Ask **all** of these in one batch. Do not guess. Group them as one structured question set and offer
only values already supported by repository evidence.

### 2.1 Project identity
- **Project name** — the repository's human-readable product/project name.
- **Workspace or project file** — `*.xcworkspace` or `*.xcodeproj` filename at repo root.
- **Main app scheme** — primary buildable scheme.
- **Base git branch** — resolve the repository's actual governed base branch.
- **Git remote name + URL** — resolve the repository's actual remote and URL.

### 2.2 Build environment
- **Simulator / destination** — the actual repository-supported destination; discover it with the
  repository's native tooling if the user is unsure.
- **Build/package system** — the actual system or combination used by the repository.
- **Canonical build and test commands** — copy from repository governance; do not synthesize a
  universal command.
- **CI/release owner and entry point** — record the repository/DevOps-owned configuration or command;
  the plugin does not provide a parallel CI path.

### 2.3 Architecture choices
- **Presentation pattern** — resolve the consuming repository's actual pattern. The plugin's rulebook
  stays pattern-neutral; if the project adopts Boardy+VIP, route through
  `/ifl-ios-standards:boardy-vip` and its current pattern guide.
- **Module-naming prefix** — the repository's bound prefix or an explicitly confirmed empty value.
- **Module root path** — one repository-relative path token where sibling module folders live, or the
  consuming repository's explicit single-target sentinel. Do not choose a default from the build system.
- **Bindings root path** — the repository-selected location for `PROJECT_CONFIG.md` and
  `PROJECT_STRUCTURE.md`.
- **Working-docs root** — the repository-selected location that follows
  `${CLAUDE_PLUGIN_ROOT}/standards/process/docs-organization.md`.
- **Brain-Flow mode** — `co-working` or `auto`; if the repository declares no default, co-working is
  the runtime fallback.
- **Git authority** — whether a scoped local auto-commit grant exists for semantic tasks, and its exact
  repository/worktree/branch scope. Record branch, amend/rewrite, push, PR, merge, tag, publish,
  install, and release authority separately; never infer them from auto mode or Plan approval.
- **Applicable enterprise concerns** — identify only the relevant chapters among Swift 6 concurrency,
  SwiftUI production, data lifecycle, mobile security, privacy/compliance, accessibility/global
  readiness, observability/operability, modern testing, performance/resilience, and supply-chain/legal.

### 2.4 Optional
- **Localization** — does the project use string-generation (SwiftGen, etc.)? If yes, capture the command.
- **Trace header convention** — required on new source files? Format?

If the user cannot answer an item, mark it `TBD` in the generated file and surface a final list of TBDs for follow-up.

---

## 3. Project Discovery (introspect the repo)

Use read-only repository inspection and the repository's native discovery tools to confirm user
answers. Resolve commands from existing project docs/configuration rather than copying commands from
this template. A typical discovery checklist is:

```bash
{WorkspaceOrProjectDiscoveryCommand}
{SchemeAndTargetInventoryCommand}
{ModuleInventoryCommand}
{DestinationDiscoveryCommand}
{RepositoryIdentityCommand}
```

Reconcile output with user answers. If the repository and a user-provided value conflict, stop and ask.
Do not install tools, regenerate projects, or mutate dependencies during discovery.

---

## 4. Generate `PROJECT_CONFIG.md`

Path: `<BindingsRoot>/PROJECT_CONFIG.md`.

Required sections (in order):

1. **Identity Configuration** — table: `{ProjectName}`, `{Workspace}`, `{MainScheme}`, `{ModulePrefix}`, `{BaseBranch}`, `{GitRemote}`, `{GitRemoteURL}`, `{Simulator}`, `{Destination}`.
2. **Project-Wide Path Configuration** — module root, bindings root, and working-docs root. The
   `Module root` value is one bare repository-relative token because the source scaffolders parse it.
3. **Tooling Configuration** — actual build/package system, source globs, target naming, localization,
   and app composition host, all copied from the consuming repository.
4. **Build/Test/Debug Configuration** — the repository's canonical commands and success signals.
   Do not manufacture commands, ship plugin-owned verifier/lint/smoke scripts, or duplicate CI.
5. **Dependency / Project-Generation Configuration** — the consuming repository's real triggers and
   actions. The source scaffolders do not edit build/package files or invoke these actions.
6. **Brain-Flow Configuration** — co-working/auto default, provider-native progress, one approved plan,
   one full-plan final AI review, and repository-owned executable tests/CI.
7. **File Trace Header Configuration** — if user opted in.
8. **Git Authority Configuration** — semantic task cadence, scoped local auto-commit or per-operation
   authority, separately scoped branch/amend/rewrite/push/PR/merge/tag/publish/install/release
   authority, and explicit-path staging discipline.
9. **Placeholder Resolution Map** — single table resolving every `{Placeholder}` used by generic specs.
10. **Update Procedure** — one paragraph: when a value changes, update this file only; do not scatter values.

Style:
- Use Markdown tables for key/value rows.
- Use fenced code blocks for commands.
- Section headings: `## N. Title` numbered consecutively.
- Insert trace header on first line.

---

## 5. Generate `PROJECT_STRUCTURE.md`

Path: `<BindingsRoot>/PROJECT_STRUCTURE.md`.

Required sections (in order):

1. **Project-Owned Scheme/Target Inventory** — table: `Scheme or target`, `Purpose`, `Structure owner
   (path)`. Populate from the repository's native inventory command and omit third-party entries.
2. **Module Inventory** — table: `Module`, `Role`, `Interface target`, `Implementation target`. Populate from discovered modules.
3. **Synchronization Rules** — list events that require updating this file (module added/removed/renamed, scheme added/removed, ownership change).
4. **Inventory Commands** — record the repository-owned discovery commands so future agents can
   refresh inventory.

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

## 7. Validate the bindings

Inspect the generated files against the repository and confirm:

- every required binding came from the user or repository evidence rather than an invented example;
- `Module root` is one repository-relative token and matches the real source location;
- build/test commands and CI ownership point to the consuming repository's existing paths;
- scaffolders are described as source-only and build-system-neutral;
- Brain Flow records co-working/auto behavior, scoped Git authority, and one full-plan final AI review;
- no provider profiles, verifier/lint/smoke scripts, receipts, manifests, fingerprints, evidence
  ledgers, or custom workflow-state files were introduced.

This setup changes documentation/bindings only, so do not run a build or test merely to manufacture
evidence. If the user separately asks for executable validation, use the consuming repository's
canonical command and report its direct result; do not create a plugin-owned check.

---

## 8. Completion Report

Produce a short report:

- Files created (paths).
- TBD values that the user still needs to fill in.
- Binding validation performed and, only if separately requested, any repository-owned command run.
- Suggested next step: start the first task from root `CLAUDE.md` / `AGENTS.md` and the generated bindings.

Apply the Git authority recorded in the project bindings. If an explicit scoped auto-commit grant
covers this setup task, stage only the generated binding paths and commit them without another prompt.
Otherwise leave them unstaged until local stage+commit authority is granted. Never infer or perform a
push from setup approval, auto mode, or local commit authority; push always requires separate authority.

---

## 9. Self-Check (before reporting "setup complete")

- [ ] Root `CLAUDE.md` / `AGENTS.md` carries the project's plugin pointer + bindings (or points at the separate binding files this playbook generated).
- [ ] The plugin standard (`${CLAUDE_PLUGIN_ROOT}/standards/`) is untouched — it's read-only, shared.
- [ ] `PROJECT_CONFIG.md` exists and contains every required section.
- [ ] `PROJECT_STRUCTURE.md` exists and reflects current schemes/modules.
- [ ] `QUICK_REF.md` exists only if the project actually needs it.
- [ ] Canonical build/test commands and CI ownership were copied from repository governance, not invented.
- [ ] No build or test was run solely for this documentation-only setup.
- [ ] Brain Flow mode, one-plan/one-final-review behavior, and scoped Git authority are explicit.
- [ ] Enterprise concerns route through `/ifl-ios-standards:enterprise-ios` without copying chapter rules.
- [ ] Scaffolders are recorded as source-only/build-system-neutral and module-root-bound.
- [ ] No verifier scripts, receipts, manifests, fingerprints, evidence ledgers, or custom state were added.
- [ ] No project values scattered into the plugin standard — bindings live in the repo only.
- [ ] All generated files carry the trace header convention defined in `PROJECT_CONFIG.md`.

If all boxes check, report **setup complete**. Otherwise list the gap.

---

*End of one-time setup playbook. After completion, future sessions follow root `CLAUDE.md`/`AGENTS.md` → the relevant `ifl-ios-standards` skill/spec/process docs (under `${CLAUDE_PLUGIN_ROOT}/standards/…`) → project bindings. SETUP.md is not loaded per session and may be deleted (or kept as historical record).*

## Reference samples

Worked examples of `PROJECT_CONFIG.md` and `PROJECT_STRUCTURE.md` live alongside this file in `${CLAUDE_PLUGIN_ROOT}/standards/templates/portable-claude/examples/`. Use them as shape references — do NOT copy values literally; values are project-specific.
