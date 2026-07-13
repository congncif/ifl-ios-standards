# SPEC: Commit workflow

Commit complete semantic tasks so reviewers can trace and revert meaningful outcomes. A semantic task
is a coherent domain/user-story/standards outcome from the approved plan—not a file, layer, agent
assignment, test, or individual finding.

## Cadence

1. Complete the semantic task and its applicable executable-code tests.
2. Inspect the task diff for scope and accidental changes; do not run a separate AI consistency review.
3. Resolve commit authority from the consuming project's governance. A scoped auto-commit grant is
   reused for every conforming semantic task; otherwise obtain per-operation authority.
4. Stage only the task's intended paths and commit once with a message describing the outcome.
5. Continue the same plan. The plan's single AI consistency review runs after every planned task is
   complete, over the full commit range and final working state.
6. Apply accepted final-review findings in one corrective batch and, when authorized, one traceable
   corrective commit. Do not schedule routine re-review.

## Authority boundary

Plan approval, auto mode, task completion, and tests are not Git authority by themselves. Authority has
two supported forms:

- **Per-operation:** ask for the exact local stage/commit when no broader project/user grant exists.
- **Scoped auto-commit:** an explicit user or project instruction such as “commit after each task”
  authorizes local `git.stage` and `git.commit` for every completed semantic task in the approved plan,
  repository, worktree, and branch. Auto mode consumes this grant without asking again and reports the
  resulting commit.

Scoped auto-commit never covers branch creation/switch, amend, history rewrite, push, PR, merge, tag,
publish, install, or release. Those remain distinct operations under project governance.

Before a Git mutation, resolve these facts from current state and the authority binding. In auto mode,
do not ask again when an existing scoped grant covers them:

- repository/worktree and branch;
- semantic task or corrective batch;
- intended paths and current parent;
- the exact native operation or matching scoped auto-commit grant;
- any message, remote, branch, or release constraint.

Do not use broad staging commands when unrelated changes exist. Never amend, rewrite history, push,
tag, publish, or release without authority for that exact action.

## No evidence machinery

Use normal Git status/diff/staged-diff inspection. Do not create candidate manifests, fingerprints,
receipts, hash chains, evidence-only commits, or a custom commit route. Such tooling belongs to the
post-1.0 backlog.
