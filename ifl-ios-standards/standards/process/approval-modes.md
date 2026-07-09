# Process — Brain Flow Approval Modes

**Trigger:** `/ifl-ios-standards:brain-flow` Stage 1 Requirement Intake Gate and Stage 4 Plan Gate.

Brain flow supports two approval modes. Both modes require clear requirements, an approved plan,
checkpoint verification, and factual reporting. They differ only in who normally approves the gates.

## 1. Modes

### Co-working mode

Use when the user wants to collaborate at decision points.

- Stage 1: user confirms the requirement summary before Design starts.
- Stage 4: user approves the implementation plan before Execute starts.
- The agent may propose defaults, but waits at the gate.

### Auto mode

Use when the user asks for end-to-end automation or the project binding selects automation.

- Stage 1: AI requirement reviewers approve the requirement summary.
- Stage 4: AI plan reviewers approve the implementation plan.
- The agent continues through the pipeline until completion unless escalation rules require user input.

Auto mode gives AI authority to resolve implementation details using standards and existing code. It
does **not** give AI authority to invent product intent.

## 2. Gate verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| `USER_APPROVED` | Human approved the gate in co-working mode. | Continue. |
| `AUTO_APPROVED` | AI reviewers approved the gate in auto mode. | Continue. |
| `CHANGES_REQUIRED` | Gate artifact is fixable without user decision. | Revise and rerun the gate review. |
| `USER_INPUT_REQUIRED` | A material ambiguity/proposal/blocker requires user input. | Ask the smallest necessary question and stop. |
| `BLOCKED` | Cannot proceed safely. | Stop and report blocker. |

## 3. Escalation rules for auto mode

Ask the user when any of these is true:

- business/user goal is unclear;
- in-scope/out-of-scope is ambiguous;
- multiple valid UI/UX behaviors exist and the choice affects users;
- API/data contract changes affect consumers or persisted data;
- money, auth, permissions, transaction boundaries, security, or data integrity semantics are involved and not specified;
- implementation requires destructive or hard-to-reverse action;
- required project binding value is missing;
- standards conflict and no precedence rule resolves the conflict;
- checkpoint failures imply the approved requirement or plan must change;
- a reviewer returns `USER_INPUT_REQUIRED` or `BLOCKED`.

Do **not** ask the user when:

- the choice is an internal implementation detail;
- standards clearly prefer one option;
- file placement is determined by project structure;
- naming follows existing convention;
- test checkpoint level is clear from the risk tier;
- the bound pattern maps the change unambiguously.

## 4. Gate reviewer contract

Reviewers must return structured findings:

```markdown
## {Requirement|Plan} review verdict

Reviewer: {role}
Verdict: APPROVED | CHANGES_REQUIRED | USER_INPUT_REQUIRED | BLOCKED

Findings:
- Severity: blocking | material | non-blocking
- Standard/rule:
- Finding:
- Required action:
```

The orchestrating agent aggregates reviewer outputs:

- any `BLOCKED` → gate verdict `BLOCKED`;
- any `USER_INPUT_REQUIRED` → gate verdict `USER_INPUT_REQUIRED`;
- only `CHANGES_REQUIRED` or lower → revise and rerun if the changes are within approved scope;
- all `APPROVED`, or only non-blocking findings explicitly recorded/deferred → `AUTO_APPROVED`.

## 5. Audit trail

Record the gate result in the task artifact. For long artifacts, follow
`process/long-document-writing.md` and append gate records as separate chunks:

```markdown
## Requirement gate
- Mode:
- Verdict:
- Reviewer(s):
- User confirmation, if any:
- Assumptions accepted:
- Open questions resolved:

## Plan gate
- Mode:
- Verdict:
- Reviewer(s):
- User approval, if any:
- Findings resolved:
- Deferred non-blocking work:
```

In append-only flows, never edit an earlier gate record. Append a correction section instead.
