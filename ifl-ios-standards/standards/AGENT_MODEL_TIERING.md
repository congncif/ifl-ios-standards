# Agent model tiering

Model names express reasoning classes, not provider-specific IDs. Runtime providers resolve the
available equivalent and preserve role responsibilities across resume/handoff.

The tables use Claude's `ios-*` IDs as role labels. Codex maps those responsibilities onto
provider-native generic subagents through bounded assignments and inline fallback; the table does not
require provider-specific custom profile IDs.

## Tier matrix

| Agent | Model alias | Why this tier |
|-------|-------------|---------------|
| `ios-orchestrator` | `opus` | Cross-workstream integration, recovery, authority boundaries, and joined disposition |
| `ios-planner` | `opus` | One complete dependency-ordered plan and material tradeoff judgement |
| `ios-reviewer` | `opus` | Independent Requirement/Plan gates and principal final architecture/behavior review |
| `ios-architect` | `sonnet` | Designs selected-Profile contracts and dependency boundaries |
| `ios-coder` | `sonnet` | Implements bounded executable or standards changes with repository context |
| `ios-tester` | `sonnet` | Designs causal, risk-based tests and interprets executable results |
| `ios-researcher` | `haiku` | One bounded structural or textual lookup with source-cited facts |
| `ios-review-triage` | `haiku` | Concurrent mechanical consistency lane in the joined final review |
| `ios-doc-scribe` | `haiku` | Bounded mechanical documentation updates from approved facts |

## Superpowers verb → agent mapping

| Verb | Default agent | Notes |
|------|---------------|-------|
| `plan` | `ios-planner` | Produces one plan; an independent reviewer decides the gate |
| `architect` | `ios-architect` | Selected-Profile contract or boundary assignment |
| `code` | `ios-coder` | Bounded implementation from the approved plan |
| `test` | `ios-tester` | Risk-relevant executable behavior assignment |
| `triage` | `ios-review-triage` | Concurrent lane in the one joined final review |
| `review` | `ios-reviewer` | Independent gate assignment or principal final-review lane |
| `research` | `ios-researcher` | One bounded lookup at any plan stage |
| `scribe` | `ios-doc-scribe` | Bounded durable documentation assignment |
| `orchestrate` | `ios-orchestrator` | Owns provider-native continuity and plan integration |

## Rules

1. Select the lowest reasoning tier that can safely own the assigned judgement; runtime availability may
   substitute an equivalent or stronger model.
2. Model tier never grants repository or external authority. Semantic task commits occur only under an
   explicit per-operation or scoped auto-commit grant; push, PR, merge, tag, publish, install, and
   release remain separate.
3. Track assignments and resume/handoff with provider-native task/thread state and the approved plan.
   If delegation is unavailable, the orchestrator may execute a bounded assignment inline.
4. Requirement and Plan gates use an independent reviewer who did not author the artifact. Execution
   then follows one approved plan continuously.
5. After all planned mutations, the principal and mechanical lanes inspect the same frozen candidate
   as exactly one joined final review. Findings are joined once and corrected in at most one batch;
   routine re-review is prohibited.
6. The workflow ends at engineering completion and release readiness. External release operations are
   never implied by a role, model, gate, test, or final-review result.
