# Changelog — `.ai/brain/`

The brain is the **pattern-neutral rulebook + pattern docs + examples** layer consumed by `.claude/rules/` and `.claude/project/` bindings.

This component follows [SemVer](https://semver.org/). Bumps are coordinated with `.ai/templates/portable-claude/CHANGELOG.md` because the template ships a snapshot of the brain.

- **Patch (x.y.Z)** — typo, link fix, clarification with no semantic change. Bindings inherit automatically.
- **Minor (x.Y.0)** — new rulebook chapter, new pattern doc, new example. Bindings must confirm at next review but auto-inherit.
- **Major (X.0.0)** — renamed/removed rulebook chapter, changed a hard rule, removed a pattern doc. Bindings must re-audit before bumping.

## [Unreleased]

_no changes yet_

## [0.1.0] — 2026-05-23

Initial versioned baseline. Captures the brain as it shipped with QuizCombatApp.

### Contents

- `QUICK_REF.md` — brain entry point, 6-step operating loop, 10 hard rules, routing table to 23 rulebook chapters.
- `rulebook/` — 23 chapters covering philosophy, engineering loop, tradeoff posture, plugin composition, agentic-coding discipline, naming, concurrency, and review.
- `patterns/` — VIP pattern guide with §9 Boardy integration.
- `examples/` — worked snippets cross-referenced from rulebook + patterns.

### Versioning policy

The brain is canonical EN. VI parity is tracked per file; absence of a VI sibling is not a SemVer event but is tracked as a release-gate blocker before any 1.0.0 cut.
