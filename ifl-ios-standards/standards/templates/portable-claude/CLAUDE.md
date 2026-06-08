<!-- Created by claude-sonnet-4-6 on 2026-05-18 -->
<!-- template-version: 1.0.0 -->

# AGENTS.md — Project Constitution (Portable Template)

> **Purpose**: Drop-in per-session constitution for any modern modular iOS project that adopts the generic agentic baseline.
> **Twin file**: A copy of this file MAY also exist at the project root as `CLAUDE.md`. Both files have identical content — `CLAUDE.md` is provided for Claude-tooling discoverability; `AGENTS.md` is the universal cross-tool name. Keep them in sync.
> **Pairs with**: `.ai/brain/QUICK_REF.md` (routing index) + `.ai/brain/rulebook/*.md` (chapter files) + project bindings (see §5).
> **First-time setup**: see `.ai/SETUP.md` (one-shot procedure, not loaded per session).

---

## 0. Precondition Check (every session)

Before doing any work, verify the project has been bootstrapped:

1. Does `PROJECT_CONFIG.md` exist at the bindings root declared in §5?
2. Does `PROJECT_STRUCTURE.md` exist at the same root?

If either is missing → **stop**. Setup has not been run. Tell the user: *"Project bindings not found. Run the procedure in `.ai/SETUP.md` first."* Do not guess values, do not proceed with the task.

If both exist → continue normally.

---

## 1. Manifesto

We build modular iOS systems of explicit capabilities. Each capability has a stable interface, a clear owner, and a bounded implementation. Domain stays pure. Presentation stays humble. Infrastructure stays at the edge. Communication is contractual.

Default behavior: preserve the model, make the smallest correct change, verify with real signals.

---

## 2. Authority Order

When instructions conflict:

1. User's explicit current instruction.
2. This constitution.
3. Project bindings (see §5).
4. `.ai/brain/QUICK_REF.md` — generic agentic entry point.
5. `.ai/brain/rulebook/*.md` — generic rulebook chapters (load one file on demand via the routing table in `QUICK_REF.md`).
6. Existing code patterns in the target module.

Project bindings override the brain rulebook. The brain rulebook overrides nothing of bindings — it only fills gaps.

---

## 3. Mandatory Load Order

> **Context rule**: Reference rule files by plain path (no `@`-imports). The `@path` syntax auto-loads everything at session start and burns context. Use the Read tool on demand.

Before generating or reviewing code:

1. Read `.ai/brain/QUICK_REF.md` first — it is the routing index + hard rules.
2. Read project binding files listed in §5 when their domain applies.
3. Read one `.ai/brain/rulebook/*.md` chapter file selected from the routing table in `QUICK_REF.md`.
4. Read code in the target module last — preserve existing shape.

Load exactly the files needed. Do not pre-load speculatively.

---

## 4. Non-Negotiable Boundaries

(Mirrors `.ai/brain/rulebook/20-non-negotiable-rules.md`.)

1. Domain is pure Swift — no UIKit, no networking, no vendor SDKs, no Codable.
2. Dependencies point inward: Infrastructure → Business → Domain. Never reverse.
3. Consumers depend on contracts, not implementations.
4. No vendor types in public interfaces.
5. Views are humble. UI updates run on the main actor.
6. Concrete types instantiated only at composition roots.
7. One state, one writer.
8. No speculative abstraction. No unrelated changes.
9. No bypass of safety checks. Verify with real signals. Empty output ≠ success.
10. When in doubt, stop and ask.

---

## 5. Project Bindings

Project-specific values live **only** in binding files. This constitution and the brain rulebook stay portable.

**Default bindings root**: `.ai/rules/` (semantic: `.ai/` = AI knowledge, `.claude/` = Claude tool config). `SETUP.md` may set a different root — if so, update this section once.

Required (created by `.ai/SETUP.md`):

- `<BindingsRoot>/PROJECT_CONFIG.md` — workspace name, scheme, simulator/destination, build/test commands, paths, naming prefix.
- `<BindingsRoot>/PROJECT_STRUCTURE.md` — current modules, schemes, ownership topology. Update whenever modules change.

Optional:

- `<BindingsRoot>/QUICK_REF.md` — project-specific task → spec routing table.
- `<BindingsRoot>/REVIEWER_CHECKLIST.md` — project-specific review enforcement.
- Task-specific specs and example files under a project-specific specs root (declared in `PROJECT_CONFIG.md`).

When a generic rule needs a project value, resolve via the binding files. Never inline project values into this constitution or the brain rulebook.

---

## 6. Operating Discipline

- Treat empty or ambiguous verification output as failure.
- Stage commits by explicit reviewed file paths only. Avoid broad staging.
- Commit or push only after explicit user approval for the current phase.
- New source files carry a one-line authorship trace header per project convention (declared in `PROJECT_CONFIG.md`).
- AI workflow artifacts (plans, reports, brainstorms, reviews, scratch) live under a single project-local workspace declared in `PROJECT_CONFIG.md`, not scattered across `docs/` or `.claude/`.

---

*End. Keep this file short. Move detail into bindings or into the brain rulebook. Initial project setup is governed by `.ai/SETUP.md` (run once), not by this file.*
