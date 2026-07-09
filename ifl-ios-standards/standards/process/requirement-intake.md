# Process — Requirement Intake Gate

**Trigger:** Stage 1 of `/ifl-ios-standards:brain-flow`, before design, architecture, planning, or
implementation begins.

The requirement intake gate prevents the pipeline from implementing a misunderstood request. It
turns the user's prompt, ticket, and supporting documents into a concise requirement summary, records
assumptions, and decides whether the pipeline can continue.

## 1. Requirement summary template

Produce this summary before moving past Stage 1:

```markdown
## Requirement summary

- Ticket/work item ID and title:
- Business/user goal:
- In scope:
- Out of scope:
- UI/design requirements:
- API/backend/data requirements:
- Source code areas likely affected:
- Risks and assumptions:
- Open questions:
```

Keep it concise. Prefer bullets over prose. If a field is not applicable, write `N/A` with a short
reason instead of omitting it.

## 2. Open question and proposal classification

Not every unknown should stop the pipeline. Classify each item:

| Class | Meaning | Required action |
|-------|---------|-----------------|
| Material requirement question | Affects business goal, scope, UX, API/data contract, security, money, permissions, or externally visible behavior. | Stop and ask the user. |
| Material proposal | The agent recommends changing or narrowing the user's intended requirement, or choosing between product-level alternatives. | Stop and ask the user. |
| Technical assumption | Internal implementation detail where project standards or existing code clearly determine the preferred answer. | Record the assumption; continue in auto mode. In co-working mode, mention it in the summary. |
| Non-blocking clarification | Useful context but not needed to implement the approved scope. | Record as an assumption or follow-up; do not block. |

After receiving answers or additional documents, reread the new context and update the summary before
continuing.

## 3. Gate behavior by mode

### Co-working mode

1. Present the requirement summary.
2. Present open questions and proposals, if any.
3. If any material item is unresolved, ask the smallest necessary question and stop.
4. Once material items are resolved, ask the user to confirm the summary before Design starts.
5. Write the approved summary to the task briefing/spec file.

### Auto mode

1. Present or record the requirement summary.
2. Spawn requirement gate reviewers/subagents when the work is non-trivial.
3. Continue only when the requirement gate verdict is `AUTO_APPROVED`.
4. Ask the user only for material ambiguity, material proposals, missing bindings, destructive or hard-to-reverse actions, standards conflicts, or blockers.
5. Write the approved summary and gate verdict to the task briefing/spec file.

Auto mode does not authorize guessing product intent. It authorizes applying project standards to
internal implementation choices.

## 4. Suggested auto reviewers

Use the smallest reviewer set that fits the task. For trivial/docs-only work, a single self-review may
be enough; for medium/large work, use independent subagents.

| Reviewer | Purpose |
|----------|---------|
| Requirement completeness reviewer | Checks every template field is present and meaningful. |
| Scope guard reviewer | Checks in-scope/out-of-scope are bounded and avoid drive-by work. |
| Product ambiguity reviewer | Looks for unresolved user-visible behavior, UX, API/data, or acceptance ambiguity. |
| Technical surface reviewer | Checks likely affected source areas are plausible and no obvious code area is missing. |
| Pattern binding reviewer | When a pattern is bound, checks the requirement maps cleanly to the pattern concepts and specs. |

## 5. Reviewer verdict format

```markdown
## Requirement review verdict

Reviewer: {role}
Verdict: APPROVED | CHANGES_REQUIRED | USER_INPUT_REQUIRED | BLOCKED

Findings:
- Severity: blocking | material | non-blocking
- Standard/rule:
- Finding:
- Required action:
```

`AUTO_APPROVED` requires:

- no `BLOCKED` verdict;
- no `USER_INPUT_REQUIRED` verdict;
- no unresolved material requirement ambiguity;
- all blocking standards satisfied;
- any non-blocking assumptions recorded in the briefing/spec.

## 6. Write the artifact

After approval, write the requirement summary to the task artifact. Preferred location for
brain-flow/orchestrator runs:

```text
docs/02-working-docs/handoffs/{task-slug}/briefing.md
```

If the consuming repo declares a different working-docs root, use that root. For long generated
artifacts, follow `process/long-document-writing.md`: create a skeleton first, append one major
section per chunk, and write final status after verification. In append-only handoff flows, do not edit
a prior summary; append `## Correction — Requirement summary` or `## Requirement summary v{n}`.

## Verification

This process is being followed when:

- the requirement summary exists before Design/Architect/Plan;
- material ambiguity is resolved by the user, not guessed;
- auto mode records reviewer verdicts or a justified self-review for trivial work;
- the approved summary is written to the task artifact.
