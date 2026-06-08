<!-- Created by claude-opus-4-7 on 2026-05-09 -->
# Boardy+VIP Rules Pack Adoption Guide

Use this checklist when installing the generic rules and agents into a new iOS project.

---

## 1. Copy Pack

- [ ] Copy `.ai/specs/` into the target project.
- [ ] Copy `@.claude/agents/` into the target project.
- [ ] Keep rule files generic; remove app names, domain names, concrete schemes, concrete simulators, and private URLs from copied docs.

---

## 2. Configure Project Values

- [ ] Fill `.claude/project/PROJECT_CONFIG.md`.
- [ ] Set `{ProjectName}`.
- [ ] Set `{Workspace}` or equivalent build container.
- [ ] Set `{MainScheme}`.
- [ ] Set `{ModuleRoot}` if modules do not live under `submodules/`.
- [ ] Set `{BaseBranch}` and `{GitRemote}`.
- [ ] Set `{Simulator}` and `{Destination}` after running destination discovery.
- [ ] Set app entry file / plugin host location.
- [ ] Set module prefix policy.
- [ ] Point to canonical build/test docs.

---

## 3. Update Project CLAUDE.md

- [ ] Require loading `.claude/rules/QUICK_REF.md` first.
- [ ] Route task-specific work through `.claude/rules/QUICK_REF.md`.
- [ ] Document project-only exceptions in `@CLAUDE.md`, not generic specs.
- [ ] Document package manager commands and build commands in project docs.
- [ ] Document commit/push policy.

---

## 4. Validate Runtime Architecture

- [ ] App has a plugin host that installs `LauncherPlugin`s before launching the first board.
- [ ] App has a `Motherboard` gateway and `BoardProducer` registry through Boardy.
- [ ] Each feature module has Interface Module and Implementation Module separation.
- [ ] Cross-module consumers import Interface Modules only.
- [ ] Implementation Modules are leaf nodes and not imported by other feature modules.

---

## 5. Validate Module Template

- [ ] Module template creates `{ModuleName}.podspec` or package target for Interface Module.
- [ ] Module template creates `{ModuleName}Plugins.podspec` or package target for Implementation Module.
- [ ] Interface target includes `IO/**/*.swift` only.
- [ ] Implementation target includes `Sources/**/*.swift` only.
- [ ] Local paths live in app-level dependency configuration, not target dependency declarations.
- [ ] New Swift files are included by package/project generation.

---

## 6. Validate First Module

- [ ] Create one small module using `.ai/specs/MODULE_CREATION.md`.
- [ ] Add one public board IO using `.ai/specs/IO_INTERFACE.md`.
- [ ] Add one UI board or BlockTask board.
- [ ] Register ModulePlugin and LauncherPlugin.
- [ ] Run dependency install/project generation if needed.
- [ ] Build target succeeds.

---

## 7. Validate Rules With Grep

Run equivalent checks for your project:

```bash
grep -RInE '{OldProjectName}|{OldWorkspace}|{OldScheme}|{OldSimulator}|{OldRemoteURL}' .claude/rules .claude/agents
```

- [ ] No old project tokens remain outside `.claude/project/PROJECT_CONFIG.md` or intentional project-local docs.
- [ ] `lastAvailableWatchedContent` does not appear as communication guidance.
- [ ] `git add -A` / `git add .` appears only as a warning, not as a recommended command.

---

## 8. Validate Agent Handoffs

- [ ] `ios-planner` writes phased plans only.
- [ ] `ios-orchestrator` coordinates and does not write production Swift itself.
- [ ] `ios-architect` creates IO contracts before implementation.
- [ ] `ios-coder` implements after IO exists.
- [ ] `ios-tester` reads `.claude/rules/QUICK_REF.md` and `.ai/specs/TESTING.md` before tests.
- [ ] `ios-reviewer` is read-only and uses `.ai/specs/REVIEWER_CHECKLIST.md`.

---

## 9. Acceptance

- [ ] `.claude/rules/QUICK_REF.md` routes every common task.
- [ ] `.ai/specs/ARCHITECTURE.md` explains the five pillars.
- [ ] `.ai/specs/SDK_FIRST.md` governs dependency choices.
- [ ] `.ai/specs/LAYERING.md` separates Domain, Business Application, and Infrastructure & UI.
- [ ] `.ai/specs/COMMUNICATION.md` preserves event-bus Board → Controller communication.
- [ ] `.ai/specs/REVIEWER_CHECKLIST.md` can review a PR without loading every spec.
- [ ] Project builds after first generated module or board.
