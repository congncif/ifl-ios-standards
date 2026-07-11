# SPEC: Commit Workflow

> **CRITICAL RULE**: NEVER perform a Git mutation without current, object-scoped authority for that
> exact operation. Requirement/Plan approval, `AUTO_APPROVED`, auto mode, review approval, and test
> success grant no Git authority. Commit, branch, push, PR, tag, release, and history rewrite are
> separate operations.

The default trace unit is one reviewed and verified **semantic checkpoint** from the approved checkpoint
map. Under “commit by task” governance, that semantic checkpoint is the task; an internal work slice,
layer, file group, generated artifact, or evidence artifact is not a commit boundary.

## Git authority record

Before committing, record all of:

- grant source: explicit user instruction or a project policy the user placed in scope;
- operation: `commit` only, or an explicit list of additional separately authorized operations;
- repository/worktree and approved checkpoint IDs;
- allowed candidate-closure paths or reviewed candidate fingerprint;
- expected base/parent, or the approved parent chain for sequential checkpoint commits;
- cadence (`per-checkpoint` or scoped blanket), lifetime/expiry, and any message convention.

An AI gate cannot grant authority to itself. Ambiguous phrases, a different parent/tree, new paths,
corrective checkpoints, or material scope/contract/boundary changes require a new or amended record.

## Workflow Steps

### 1. Execute work slices
- Implement the approved slices inside the current semantic checkpoint.
- Run each applicable causal signal, including Tier-1 behavioral RED → GREEN.
- Do not commit, request approval, or run a full gate merely because a work slice ended.

### 2. Freeze and collect review (MANDATORY)
- Prospectively subsume or run the accumulated focused proof and complete the spec-sync audit,
  including any triggered source/spec updates in the same checkpoint.
- Freeze the candidate fingerprint and collect all findings from the approved, non-overlapping reviewer
  lanes before mutation.
- Deduplicate and disposition once. Apply only `ACCEPTED_CURRENT_SCOPE` findings in one remediation
  batch; then run affected proof and the owning gate after the final mutation. Confirmation is bounded
  to dispositions and changed surfaces.
- Ensure the to-be-staged candidate manifest byte-matches the reviewed/verified candidate fingerprint.
  The append-only work-item/audit ledger is excluded by default; if governance commits it, seal and
  bind its separate manifest in the same semantic-checkpoint commit without rerunning unrelated
  runtime proof or creating an evidence-only commit.

### 3. Approval check
- If no current Git authority record covers this exact commit, show the checkpoint outcome, candidate
  fingerprint, evidence, findings/dispositions, and spec-sync triggers, then wait for explicit authority.
- In `brain-flow`, an explicit instruction such as “commit after each task/checkpoint” may be recorded
  as scoped blanket commit authority. Plan approval alone is not enough. Do not ask again after routine
  work slices while the recorded scope and parent chain still match.
- Material scope, checkpoint-boundary, public-contract, authority, or risk-owner divergence invalidates
  the scoped approval and returns to the relevant gate.

### 4. Commit phase (ONLY after the approval check passes)
- In a Kernel-bound flow, a `ready_for_commit` directive is consumed only by
  `ifl-workflow commit-checkpoint --run-receipt <receipt> --checkpoint-id <id> --message <message>`.
  The command derives the reviewed literal path set and staged tree from authenticated checkpoint
  state. It accepts no caller path, directory, glob, or pathspec and never delegates `vcs.git-commit`
  to generic `authorize-effect`.
- If the product command does not exist yet, only an adapter explicitly declared by the approved Plan
  may bootstrap the same E2 contract: show `git status --short`, stage only the recorded literal paths,
  prove cached path/tree equality, commit, and record the typed-equivalent receipt. Never use
  `git add -A` or `git add .` for that adapter.
- Confirm the resulting staged/committed candidate manifest matches the reviewed/verified fingerprint
  and Git authority record. Staging and a byte-identical commit do not require another verification
  run. Record and show the commit result, then resume the same workflow through `resume`/`next`.

### 5. Push phase (ONLY after separate approval)
- Ask user if they want to push
- **WAIT for explicit approval**
- Push only the separately authorized current branch to the configured remote.

## What Counts as Approval

✅ **Commit-only authority when the immediate repository/checkpoint referent is unambiguous:**
- "commit this checkpoint"
- "looks good, commit CP-2"
- "commit after each approved checkpoint in this task"

✅ **Push-only authority:**
- "push the current branch" — authorizes no commit.

✅ **Combined authority only when both operations and object are explicit:**
- "commit CP-2 and push the current branch"

❌ **NOT approval:**
- "continue" (this means continue working, NOT commit)
- "approve" / "approved" without naming the Git operation
- `USER_APPROVED` / `AUTO_APPROVED` Plan Gate verdicts
- Silence
- User asking questions
- User reviewing code

## Red Flags - STOP and ASK

If you find yourself about to commit, check:
1. Is there a current commit-authority record from the user/project policy, not an AI gate?
2. Does repository, checkpoint, parent chain, operation, lifetime, and candidate closure still match?
3. Is the joined review verdict approved and every required owning-gate receipt current?
4. Does the staged candidate manifest byte-match the reviewed/verified fingerprint and allowed paths?

If ANY answer is NO → **DO NOT COMMIT**

## Exception

The ONLY exception to per-commit approval is an object-scoped blanket grant for a specific workflow,
for example: "commit each approved semantic checkpoint in this task on the current repository and
parent chain, limited to its reviewed candidate manifest."

Confirm or record its scope at the Requirement/Plan Gate. It never authorizes push, branch, PR, release,
history rewrite, corrective checkpoints, or unrelated files.

## Penalty for Violation

Violating this rule wastes the user's time and breaks trust. Always err on the side of asking for approval.
