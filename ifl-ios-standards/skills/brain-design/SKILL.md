---
name: brain-design
description: >-
  Use when designing the shape of a change before writing code — domain modeling (entities,
  value types, errors), module boundaries and split decisions, use-case design. Pattern-neutral:
  applies to any iOS project, Boardy or not. Triggers: "design this feature", "model the domain",
  "should this be a new module", "shape the use cases".
---

# Brain — Design (domain, modules, use cases)

Pattern-neutral design stage of the brain rulebook. Loads only the chapters this stage needs.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/04-module-design-rules.md` — what a module is, split boundaries.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/06-domain-modeling-rules.md` — pure entities, value types, domain errors.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/07-business-layer-rules.md` — use cases as capability units.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/18-decision-heuristics.md` — "new module?", "new dependency?", "promote to public?" decision trees.

## Output of this stage
A short design note (inline or in the plan doc): domain types + invariants, module placement
(existing vs new, with the §18.1 heuristic applied), use-case list with inputs/outputs, and any
open questions. No code yet.

## Guardrails
- Domain stays pure Swift — no UIKit, no networking, no vendor SDKs, no Codable (hard rule 1).
- Prefer extending an existing module over creating one; justify a new module against §18.1.
- Smallest correct design — no speculative abstraction.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → also consult `/ifl-ios-standards:boardy-vip` (router) and
`${CLAUDE_PLUGIN_ROOT}/standards/specs/DECISION_TREES.md` for Board-type / ID-prefix / bus-shape choices.
