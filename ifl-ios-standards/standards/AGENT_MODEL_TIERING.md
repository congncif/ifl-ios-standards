# Agent model tiering

> Combo aliases: `giao-su` = Opus class (judgement / orchestration / final review). `huy-diet` = Sonnet class (architecture / coding). `giup-viec` = Haiku class (lookup / triage / mechanical writes).

## Tier matrix

| Agent | Model alias | Why this tier |
|-------|-------------|---------------|
| `ios-orchestrator` | `combo-giao-su` | Irreversible decisions (branch/commit/PR), cross-hop arbitration, ambiguity resolution |
| `ios-planner` | `combo-giao-su` | PRD → phased plan; tradeoff judgement |
| `ios-reviewer` | `combo-giao-su` | Final correctness gate; must reason about logic, not text |
| `ios-architect` | `combo-huy-diet` | Designs IO contracts; structured but not open-ended |
| `ios-coder` | `combo-huy-diet` | Implements against a contract; long context, structured |
| `ios-tester` | `combo-giup-viec` | Mechanical: derive tests from implementation report + TESTING.compact |
| `ios-researcher` | `combo-giup-viec` | One-shot codegraph / find / grep; sole discovery-cache writer |
| `ios-review-triage` | `combo-giup-viec` | Surface-level diff nits (naming, whitespace, unused) before reviewer |
| `ios-doc-scribe` | `combo-giup-viec` | Append spec changelogs + ADR stubs from briefing reports |

## Superpowers verb → agent mapping

| Verb | Default agent | Notes |
|------|---------------|-------|
| `plan` | `ios-planner` | PRD path required |
| `architect` | `ios-architect` | After plan, before code |
| `code` | `ios-coder` | After architect contract |
| `test` | `ios-tester` | After coder implementation report |
| `triage` | `ios-review-triage` | Before reviewer, on `diff.patch` |
| `review` | `ios-reviewer` | After tests pass |
| `research` | `ios-researcher` | Any-hop: refresh discovery cache or one-shot lookup |
| `scribe` | `ios-doc-scribe` | Post-review, before PR open |
| `orchestrate` | `ios-orchestrator` | Wraps the whole pipeline |

## Rules

1. Never use a higher tier than required — wastes budget, no quality gain on mechanical tasks.
2. Never use a lower tier on irreversible decisions — branch/commit/PR mistakes can't be undone cheaply.
3. The orchestrator may temporarily promote a haiku agent (e.g. `ios-tester`) one tier up if the task scope explicitly flags `escalate: true` in the briefing meta block.
4. Model alias resolution is handled by the runtime — agents do not hard-code provider/model IDs.
