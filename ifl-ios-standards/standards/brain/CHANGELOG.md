# Changelog — `standards/brain/`

The brain is the pattern-neutral rulebook and pattern layer consumed through plugin Skills and the
consuming repository's `CLAUDE.md` / `AGENTS.md` bindings.

This component follows SemVer. Product packaging may be a release candidate while this component's
contract remains at a stable major version.

- **Patch (x.y.Z)** — typo, link fix, clarification with no semantic change. Bindings inherit automatically.
- **Minor (x.Y.0)** — new rulebook chapter, new pattern doc, new example. Bindings must confirm at next review but auto-inherit.
- **Major (X.0.0)** — renamed/removed rulebook chapter, changed a hard rule, removed a pattern doc. Bindings must re-audit before bumping.

## [1.0.0] — 2026-07-13

- Established provider-native Brain Flow for co-working and auto modes.
- Replaced custom workflow state/evidence machinery with one approved plan, semantic task commits,
  and one joined final AI consistency review.
- Restricted TDD and runtime evidence to executable code and repository-owned commands.
- Added scoped local auto-commit authority and explicit external/history-effect approval boundaries.
- Synchronized the Boardy+VIP humble-View contract across UIKit and SwiftUI adapters.
- Added enterprise-iOS routing without duplicating chapter standards in the brain.

## [0.1.0] — 2026-05-23

Initial versioned baseline. Captures the brain as it shipped with QuizCombatApp.

### Contents

- `QUICK_REF.md` — brain entry point, 6-step operating loop, 10 hard rules, routing table to 23 rulebook chapters.
- `rulebook/` — 23 chapters covering philosophy, engineering loop, tradeoff posture, plugin composition, agentic-coding discipline, naming, concurrency, and review.
- `patterns/` — VIP pattern guide with §9 Boardy integration.
- `examples/` — worked snippets cross-referenced from rulebook + patterns.

### Versioning policy

The brain is canonical English. Translations may be maintained as derived artifacts but do not define
or weaken the normative contract.
