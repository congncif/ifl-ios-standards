---
name: brain-plan
description: >-
  Use when turning a design or architecture decision into an executable iOS implementation plan,
  especially when work spans multiple domains, modules, standards chapters, or agent assignments.
---

# Brain — Plan

Create one complete plan for the requested outcome. Read:

- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/18-decision-heuristics.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/PLAN_EXECUTION.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/approval-modes.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md`

## Plan shape

Include:

1. goal, scope, assumptions, risks, and measurable Definition of Done;
2. design/architecture decisions and affected public contracts;
3. dependency-ordered workstreams with shared-writer ownership;
4. bounded agent assignments and integration ownership;
5. executable-code test needs, with TDD only where behavior/risk warrants it;
6. semantic task boundaries for traceable commits;
7. one final AI consistency review over the completed plan.

Workstreams and slices organize execution; they are not review gates. Split by domain semantics, user
story, dependency, or impact—not by file count, layer, agent hop, finding, or arbitrary size target.
Keep coupled public contracts and their consumers in the same valid task boundary.

Do not plan verifier/lint/smoke scripts, RR/G gates, manifests, fingerprints, receipts, evidence
ledgers, or custom workflow state. Use provider-native task/thread management and keep plan progress in
the plan itself.

Get Plan approval before execution: human approval in co-working mode, independent read-only AI
approval in eligible auto mode. The plan author cannot approve its own non-trivial Plan Gate. Use the
operating model's rubric and ask the user only for material ambiguity, missing authority, or a real blocker.

When Boardy+VIP is bound, sequence work along its IO, implementation, composition, and test seams, but
do not turn each seam into an administrative checkpoint.
