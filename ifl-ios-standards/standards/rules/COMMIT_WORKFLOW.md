# SPEC: Commit workflow

Commit complete semantic tasks so reviewers can trace and revert meaningful outcomes. A semantic task
is a coherent domain/user-story/standards outcome from the approved plan—not a file, layer, agent
assignment, test, or individual finding.

## Cadence

1. Complete the semantic task and its applicable executable-code tests.
2. Inspect the task diff for scope and accidental changes; do not run a separate AI consistency review.
3. Obtain the authority required by the consuming project's governance.
4. Stage only the task's intended paths and commit once with a message describing the outcome.
5. Continue the same plan. The plan's single AI consistency review runs after every planned task is
   complete, over the full commit range and final working state.
6. Apply accepted final-review findings in one corrective batch and, when authorized, one traceable
   corrective commit. Do not schedule routine re-review.

## Authority boundary

Plan approval, auto mode, task completion, tests, review, and commit cadence are not Git authority.
When project governance requires explicit approval, treat `git.stage`, `git.commit`, `git.push`, PR,
tag, publish, release, and history rewrite as distinct native operations. One operation never implies
another.

Before a Git mutation, confirm:

- repository/worktree and branch;
- semantic task or corrective batch;
- intended paths and current parent;
- the exact native operation being authorized;
- any message, remote, branch, or release constraint.

Do not use broad staging commands when unrelated changes exist. Never amend, rewrite history, push,
tag, publish, or release without authority for that exact action.

## No evidence machinery

Use normal Git status/diff/staged-diff inspection. Do not create candidate manifests, fingerprints,
receipts, hash chains, evidence-only commits, or a custom commit route. Such tooling belongs to the
post-1.0 backlog.
