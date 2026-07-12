# Process — Requirement Intake Gate

**Trigger:** Stage 1 of `/ifl-ios-standards:brain-flow`, before design, architecture, planning, or
implementation begins.

The requirement intake gate prevents the pipeline from implementing a misunderstood request. It
turns the user's prompt, ticket, and supporting documents into a concise requirement summary, records
assumptions, defines a Definition of Done checklist, and decides whether the pipeline can continue.

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
- Definition of Done:
  - [ ] {observable completion criterion}
```

Keep it concise. Prefer bullets over prose. If a field is not applicable, write `N/A` with a short
reason instead of omitting it. The Definition of Done checklist is the downstream agent loop goal:
every plan phase, execution loop, checkpoint, review, and final report maps back to these items until
each item is completed, explicitly deferred, or blocked with a reason.

### Ticket/work item ID generation

If the user provides a ticket/work item ID, preserve it. If not, generate one:

```text
<PROJECT-CODE>-NNNN
```

- `PROJECT-CODE` is the uppercase project-name abbreviation, unless a project binding declares an
  explicit code. Derive the abbreviation from project name words, e.g. `ifl-ios-standards` → `IIS`.
- `NNNN` is the next zero-padded auto-increment number found by scanning existing task artifacts for
  the same project code. If none exists, start at `0001`.
- The generated title should be a short kebab/title phrase derived from the user goal.

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

1. Present the requirement summary and Definition of Done checklist.
2. Present open questions and proposals, if any.
3. If any material item is unresolved, ask the smallest necessary question and stop.
4. Once material items are resolved, ask the user to confirm the summary and Definition of Done before
   Design starts.
5. After approval, ask whether downstream stages should continue in co-working mode or switch to auto
   mode until the Definition of Done is complete.
6. Write the approved summary, Definition of Done, and downstream mode choice to the task briefing/spec
   file.

### Auto mode

1. Present or record the requirement summary and Definition of Done checklist.
2. Spawn requirement gate reviewers/subagents when the work is non-trivial.
3. Continue only when the requirement gate verdict is `AUTO_APPROVED` and the Definition of Done is
   measurable enough to drive the loop.
4. Ask the user only for material ambiguity, material proposals, missing bindings, destructive or hard-to-reverse actions, standards conflicts, or blockers.
5. Write the approved summary, Definition of Done, downstream mode (`auto`), and gate verdict to the
   task briefing/spec file.

Auto mode does not authorize guessing product intent. It authorizes applying project standards to
internal implementation choices.

## 4. Suggested auto reviewers

Use the smallest reviewer set that fits the task. For trivial/docs-only work, a single self-review may
be enough; for medium/large work, use independent subagents.

| Reviewer | Purpose |
|----------|---------|
| Requirement completeness reviewer | Checks every template field is present and meaningful. |
| Scope guard reviewer | Checks in-scope/out-of-scope are bounded and avoid drive-by work. |
| DoD measurability reviewer | Checks each Definition of Done item is observable enough to drive the agent loop. |
| Product ambiguity reviewer | Looks for unresolved user-visible behavior, UX, API/data, or acceptance ambiguity. |
| Technical surface reviewer | Checks likely affected source areas are plausible and no obvious code area is missing. |
| Pattern binding reviewer | When a pattern is bound, checks the requirement maps cleanly to the pattern concepts and specs. |

## 5. Reviewer verdict format

```markdown
## Requirement review verdict

Reviewer: {role}
Verdict: APPROVED | AUTO_APPROVED | CHANGES_REQUIRED | USER_INPUT_REQUIRED | BLOCKED

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
- a measurable Definition of Done checklist exists;
- all blocking standards satisfied;
- any non-blocking assumptions recorded in the briefing/spec.

Use `APPROVED` only for an explicit human/co-working gate decision. Use `AUTO_APPROVED` only for an
auto-mode AI gate decision that satisfies every condition above; do not translate one token into the
other downstream.

## 6. Write the artifact

After approval, write the requirement summary to the work-item artifact folder. Preferred location for
brain-flow/orchestrator runs:

```text
docs/02-working-docs/work-items/<WORK-ITEM-ID>-<slug>/requirements.md
```

The same work-item folder may own only the durable files needed for this task:

```text
plan.md
review.md
final-report.md
```

If the consuming repo declares a different working-docs root, use that root. For long generated
artifacts, follow `process/long-document-writing.md`: split by durable purpose, write one coherent
major section at a time, and keep final status factual. Do not create per-stage reports, receipts,
manifests, or evidence files by default.

## Verification

This process is being followed when:

- the requirement summary exists before Design/Architect/Plan;
- material ambiguity is resolved by the user, not guessed;
- auto mode records reviewer verdicts or a justified self-review for trivial work;
- the approved summary is written to the work-item `requirements.md` artifact.
