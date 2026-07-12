# SPEC: Provider-native briefing and handoff

Use the host provider's native task/thread and subagent mechanisms. The approved plan is the shared
engineering contract; do not build an additional workflow state machine.

## Briefing

For a large task, give every specialist the smallest complete context:

- goal and relevant Definition-of-Done items;
- approved design/architecture decisions;
- exact assignment and permitted product paths;
- required source/spec inputs;
- dependencies and shared-writer owner;
- expected output and applicable executable-code tests;
- material questions that must return to the orchestrator.

Do not copy the full conversation, duplicate the plan, or create an immutable assignment/evidence
ledger. Provider-native messages and the plan checklist are sufficient.

## Assignment contract

Use this shape:

```text
ROLE: {specialist}
GOAL: {one bounded outcome}
PLAN: {path or concise approved-plan reference}
INPUTS: {exact files/symbols/specs}
ALLOWED WRITES: {exact paths or disjoint directory boundary}
DEPENDENCIES: {completed prerequisite or none}
OUTPUT: {changed paths and concise factual summary}
TESTS: {code-only command/predicate or not applicable}
ESCALATE: {material question/blocker conditions}
```

An assignment must be independently writable. If two agents would edit one file or shared vocabulary,
serialize them through one integration owner. Research assignments are read-only and return cited
facts, not design decisions.

## Return contract

Return one of:

- `COMPLETED` — assigned outcome finished, with changed paths and tests actually run;
- `USER_INPUT_REQUIRED` — one material decision the agent cannot safely infer;
- `BLOCKED` — one evidenced hard dependency or unavailable capability;
- `LOOKUP_REQUIRED` — one exact structural/factual question for a research assignment.

Do not create per-assignment receipt files, digests, manifests, fingerprints, verification reports, or
custom status schemas. The orchestrator updates the plan checklist from the returned result.

## Execution and review cadence

- Complete all plan workstreams before consistency review.
- Commit complete semantic tasks when separately authorized; assignments and work slices are not commit
  boundaries by themselves.
- After the final planned mutation, dispatch read-only specialist lanes over the same complete branch
  diff. They form one final AI review event.
- Collect all findings before mutation, join and deduplicate once, and assign one corrective batch.
- Do not issue confirmation lanes or routine re-review. Material contract/scope change reopens planning
  as a new plan.

## Authority

The plan and handoff authorize engineering work only. Git stage/commit/push, PR creation, tagging,
publishing, releasing, and other external effects follow the consuming project's authority model.
Never infer one operation's authority from another or from auto mode.
