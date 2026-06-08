# Changelog — `portable-claude` template

The portable-claude template is a **drop-in install** of the Boardy+VIP agent team + rules + brain snapshot for a new (or existing) project.

This template follows [SemVer](https://semver.org/). The version is **bumped in lockstep** with `.ai/brain/CHANGELOG.md` because the template embeds (or pins) a brain snapshot.

- **Patch (x.y.Z)** — typo, link fix, README clarification with no semantic change.
- **Minor (x.Y.0)** — new agent, new rule file, new setup step. Adopters confirm at next semi-annual review.
- **Major (X.0.0)** — removed/renamed agent, breaking change to setup contract, brain major bump. Adopters re-audit + re-run setup.

## [Unreleased]

_no changes yet_

## [0.1.0] — 2026-05-23

Initial versioned baseline. Captures the template as it shipped with QuizCombatApp.

### Contents

- `README.md` — install instructions + when-to-use rules.
- `SETUP.md` — one-time setup playbook (preconditions, info gathering, project discovery, generate PROJECT_CONFIG/STRUCTURE/QUICK_REF, verify, completion report).
- `AGENTS.md` — portable constitution (precondition check, authority order, mandatory load order, non-negotiable boundaries).
- `CLAUDE.md` — top-level pointer consumed by Claude Code.
- `QUICK_REF.md` — generic Boardy+VIP cheatsheet (project-agnostic, no QuizCombat-specific paths).

### Versioning policy

- Pinned brain version is declared in `SETUP.md` step 0 ("Preconditions"). Adopters MUST verify the pinned brain version matches the live `.ai/brain/VERSION` before running setup, otherwise the brain has drifted and setup is unsafe.
- Adopter projects record the template version they installed in their `.claude/project/PROJECT_CONFIG.md` (new field `template_version`). When a new major template ships, adopters can audit their bindings against the new contract.
