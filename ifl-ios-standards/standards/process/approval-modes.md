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
- When the user/project has explicitly granted scoped auto-commit (for example, “commit after each
  task”), auto mode stages and commits each conforming semantic task without another prompt.
- Auto mode never infers branch, amend, history rewrite, push, PR, merge, tag, publication, install,
  release, or another externally governed effect from that local commit grant.

## Provider operation

Use Codex, Claude Code, or another host's native task/thread continuity, subagents, tools, and approval
mechanisms. Fall back to inline execution when a native delegation feature is unavailable and doing so
does not weaken the result. Do not require local provider profiles, smoke harnesses, canonical progress
schemas, receipts, or a custom workflow state engine.

## Git and external effects

Requirement approval, Plan approval, and AI review are engineering decisions only. The consuming
project's governance may provide per-operation Git authority or an explicit scoped auto-commit grant.
The latter covers only local stage+commit for completed semantic tasks inside its approved scope. Never
extend it to branch changes, amend/history rewrite, push, PR, merge, tag, publish, install, release, or
another external effect.
