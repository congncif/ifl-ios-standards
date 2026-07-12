# Process — Approval modes

Brain-Flow supports co-working and auto modes. Both modes use one approved plan, continuous execution,
and one final AI consistency review.

## Co-working

- Ask the user to approve requirements/Definition of Done and the complete plan.
- During execution, ask only for a material product decision, required external input, destructive
  scope change, or separately governed native operation.
- Do not create approval gates after every workstream, finding, test, or file group.

## Auto

- AI reviewers decide the requirement and plan gates.
- Continue through all approved workstreams without routine user interruption.
- Escalate only material ambiguity, a real blocker, an external hold, or missing authority that cannot
  be safely inferred.
- Auto mode never authorizes Git, publication, release, or other externally governed effects.

## Provider operation

Use Codex, Claude Code, or another host's native task/thread continuity, subagents, tools, and approval
mechanisms. Fall back to inline execution when a native delegation feature is unavailable and doing so
does not weaken the result. Do not require local provider profiles, smoke harnesses, canonical progress
schemas, receipts, or a custom workflow state engine.

## Git and external effects

Requirement approval, Plan approval, AI review, and commit cadence are engineering decisions only.
The consuming project's governance decides whether staging, committing, pushing, PR creation, tagging,
publishing, releasing, or another external effect needs explicit authority. Never infer one operation's
authority from another.
