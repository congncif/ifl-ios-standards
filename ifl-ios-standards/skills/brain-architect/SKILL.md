---
name: brain-architect
description: >-
  Use when deciding architecture — layer boundaries and dependency direction, interface/contract
  modules, visibility and public API surface, composition root / DI wiring. Pattern-neutral:
  applies to any iOS project, Boardy or not. Triggers: "which layer does this go in", "can A
  import B", "should this be public", "where do I wire dependencies", "interface module hygiene".
---

# Brain — Architect (layers, dependencies, contracts, composition)

Under Codex, `${CLAUDE_PLUGIN_ROOT}` is a path marker, not a required shell variable. Resolve it
against the installed plugin root that contains this skill's `skills/` directory. Claude Code expands
it normally.

Pattern-neutral architecture stage of the brain rulebook. Loads only the chapters this stage needs.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/02-architectural-principles.md` — layers, inward dependency direction.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/03-dependency-rules.md` — compile-time dependency matrix, third-party policy.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/05-interface-module-rules.md` — contract module hygiene.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/10-visibility-api-export-rules.md` — minimal `public` surface doctrine.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/12-plugin-composition-rules.md` — composition root, DI wiring.

## Output of this stage
An architectural contract: layer assignment per new type, allowed import list, contract-module
additions (protocols only), visibility decisions with justification, and the composition-root
wiring point. Feeds `/ifl-ios-standards:brain-plan`.

## Guardrails
- Dependencies point inward: Infrastructure → Business → Domain. Never reverse (hard rule 2).
- Consumers import contracts, not implementations (hard rule 3). No vendor types in public interfaces (hard rule 4).
- Concrete types instantiated only at composition roots (hard rule 6).
- New `public` symbol needs a named external consumer — otherwise stay `internal`.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → also consult `/ifl-ios-standards:boardy-vip` (router) and
`${CLAUDE_PLUGIN_ROOT}/standards/specs/LAYERING.md`, `CROSS_MODULE_DI.md` for the concrete IO/Plugins split.
