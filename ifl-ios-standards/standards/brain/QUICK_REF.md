<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- brain-version: 1.0.0 · last-updated: 2026-05-18 -->

# QUICK_REF.md — Brain Entry Point

> **Purpose**: Short, always-loaded entry point for AI coding agents.
> **Rulebook chapters**: `.ai/brain/rulebook/*.md` — load **one file on demand** via the routing table below.
> **Authority**: Canon Rules, Profiles, and accepted ADRs under `standards/canon/` are normative.
> Project bindings and user instructions select applicability and may add local constraints, but cannot
> silently weaken or contradict Canon; use the applicable Canon exception process for a deviation.
> This file and the rulebook are derived routing/guidance only. If they drift from Canon, Canon governs.

---

## 1. Operating Loop (every task)

1. **Understand** — boundary, layer, data flow, state owner, verification path.
2. **Locate** — smallest set of files the change requires.
3. **Preserve** — naming, layering, dependency direction, access modifiers.
4. **Implement** — minimum correct change. No drive-by edits.
5. **Verify** — for executable changes, use the smallest risk-relevant build, test, or runtime signal;
   documentation-only changes require no build/test gate.
6. **Report** — changed files, commands, results, remaining work.

Skipping understanding creates noise. Claiming an unobserved executable signal creates false confidence.

---

## 2. Canon-Linked Review Prompts

These prompts summarize frequently applicable Canon Rules and process guidance; they do not create
obligations. Apply the exact Rule statement, level, scope, Profile selection, and exception policy.

1. **Domain is pure Swift.** No UIKit, no networking, no vendor SDKs, no Codable.
2. **Dependencies point inward.** Infrastructure → Business → Domain. Never reverse.
3. **Consumers depend on contracts, not implementations.** Cross-module imports target interface modules only.
4. **No vendor types in public interfaces.** Wrap at Infrastructure boundary.
5. **Views are humble.** No business decisions in view code. UI updates on main actor.
6. **Concrete types instantiated only at composition roots.** Inner layers depend on protocols.
7. **One state, one writer.** No shared mutable state across boundaries.
8. **Smallest correct change.** No speculative abstraction, no unrelated cleanup.
9. **No bypass of applicable safety checks.** Hooks, signing, and required executable signals stay on.
10. **Escalate material ambiguity.** Do not silently choose a path that changes product intent,
    architecture, security, authority, or public behavior.

---

## 3. Routing Table (load one rulebook chapter on demand)

| Task / question | Load file(s) |
|----|----|
| Philosophy / engineering loop / tradeoffs | `rulebook/01-philosophy.md` |
| Architectural principles & pillars | `rulebook/02-architectural-principles.md` |
| Layer / dependency boundary | `rulebook/02-architectural-principles.md` + `rulebook/03-dependency-rules.md` |
| Third-party dependency decision | `rulebook/03-dependency-rules.md` + `rulebook/18-decision-heuristics.md` |
| New module / split decision | `rulebook/04-module-design-rules.md` + `rulebook/18-decision-heuristics.md` |
| Interface module hygiene | `rulebook/05-interface-module-rules.md` |
| Domain modeling (entities, values, errors) | `rulebook/06-domain-modeling-rules.md` |
| Use case / business logic | `rulebook/07-business-layer-rules.md` |
| Infrastructure / adapter / DTO | `rulebook/08-infrastructure-rules.md` |
| UI layer / view boundary | `rulebook/09-ui-layer-rules.md` |
| Visibility / `public` promotion | `rulebook/10-visibility-api-export-rules.md` + `rulebook/18-decision-heuristics.md` |
| State / concurrency / async | `rulebook/11-state-management-rules.md` |
| Plugin / composition root / DI | `rulebook/12-plugin-composition-rules.md` |
| Agentic discipline (read-before-write, etc.) | `rulebook/13-agentic-coding-rules.md` |
| Build time / scalability | `rulebook/14-build-scalability-rules.md` |
| Testing strategy | `rulebook/15-testing-philosophy.md` |
| Naming / folder placement | `rulebook/16-naming-organization-rules.md` + `rulebook/18-decision-heuristics.md` |
| Anti-pattern lookup | `rulebook/17-anti-patterns.md` |
| Pre-merge / pre-commit review | `rulebook/19-architecture-review-checklist.md` |
| Final non-negotiable reference | `rulebook/20-non-negotiable-rules.md` |
| Module skeleton template | `rulebook/A-module-skeleton.md` |
| Authoring conventions | `rulebook/B-authoring-conventions.md` |
| Verification commands | `rulebook/C-verification-commands.md` |

**Optional pattern guides** (load only if project adopted that pattern):

| Pattern | Load file |
|---------|-----------|
| VIP (View / Interactor / Presenter) — recommended default, with or without Boardy | `patterns/VIP.md` |

---

## 4. Pre-Completion Self-Review

Before reporting "done":

- [ ] Executable changes have the smallest risk-relevant signal required by the consuming repository
- [ ] Documentation-only changes did not receive a build/test gate merely for process confirmation
- [ ] Diff is line-by-line reviewed for unrelated changes
- [ ] No layer / dependency violations
- [ ] No new `public` surface without justification
- [ ] No third-party dependency added without §3.2 + §18.2 check
- [ ] No vendor types in contract modules
- [ ] Trace header on new files (per project binding)
- [ ] A complete plan receives one final joined AI consistency review, not per-task review loops
- [ ] Report states facts, not theater

---

## 5. Project Bindings

Project-specific values (workspace, scheme, simulator, paths, naming prefix) **never** live in this file or the rulebook. They live in binding files whose location is declared by the project's root `CLAUDE.md` / `AGENTS.md`.

Conventional bindings (resolve actual paths from project root constitution):

- `PROJECT_CONFIG.md` — workspace, scheme, destination, commands
- `PROJECT_STRUCTURE.md` — current modules, schemes, topology
- `QUICK_REF.md` — project-specific task → spec routing (optional)

When a project binds a pattern (e.g. Boardy+VIP), it may expose companion compact cheatsheets next to
its specs. They remain derived from the selected Canon Profile:

- `<specs>/compact/BOARDY_CHEATSHEET.compact.md` — pattern naming + skeletons
- `<specs>/compact/TESTING.compact.md` — mock + interactor-test skeletons
These compact files are loaded **by default** by their owning agents; the full specs they derive from are loaded only on demand.

If a binding file is missing for a value, **stop and ask** rather than guess. If bindings as a whole are missing, the project has not run its setup procedure — point the user there.

---

*End of entry point. Keep this file ≤ ~120 lines. Move detail to `rulebook/*.md` chapter files.*
