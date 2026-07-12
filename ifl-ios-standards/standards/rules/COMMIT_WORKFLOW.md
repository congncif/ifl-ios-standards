# SPEC: Commit Workflow

> **CRITICAL RULE**: NEVER perform a Git mutation without current, object-scoped authority for that
> exact operation. Requirement/Plan approval, `AUTO_APPROVED`, auto mode, review approval, and test
> success grant no Git authority. Commit, branch, push, PR, tag, release, and history rewrite are
> separate operations.

The default trace unit is one reviewed and verified **semantic checkpoint** from the approved checkpoint
map. Under “commit by task” governance, that semantic checkpoint is the task; an internal work slice,
layer, file group, generated artifact, or evidence artifact is not a commit boundary.

## Git authority record

Before any Git mutation, create one authority record and record all of:

- grant source: explicit user instruction or a project policy the user placed in scope;
- operation: exactly one native Git operation, such as `git.stage` or `git.commit`; one record never
  bundles operations and authority for either operation never implies the other;
- repository/worktree and approved checkpoint IDs;
- allowed candidate-closure paths or reviewed candidate fingerprint;
- expected base/parent, or the approved parent chain for sequential checkpoint commits;
- one-shot lifetime/expiry, consumption state, and any operation-specific convention.

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
- If the checkpoint requires staging and committing, show the checkpoint outcome, candidate
  fingerprint, evidence, findings/dispositions, and spec-sync triggers, then wait until distinct
  one-shot `git.stage` and `git.commit` authority records cover their exact objects. A request to commit
  does not authorize staging, and a request to stage does not authorize committing.
- Plan approval and workflow cadence are never standing Git authority. Each authority record is
  consumed by its one named native operation.
- Material scope, checkpoint-boundary, public-contract, authority, or risk-owner divergence invalidates
  the scoped approval and returns to the relevant gate.

### 4. Commit phase (ONLY after the approval check passes)
- Hold `ready_for_commit` as a resumable wait until the provider receives separate one-shot,
  object-scoped authority for `git.stage` and `git.commit`. Stage authority never implies commit
  authority, and neither operation is delegated through generic effect authorization.
- Under `git.stage` authority, show `git status --short`, stage only the reviewed literal paths, and
  prove cached path/tree equality. Never use `git add -A` or `git add .`.
- Under the distinct `git.commit` authority, commit the already-proven staged tree once and record the
  provider's native operation result.
- Confirm the resulting staged/committed candidate manifest matches the reviewed/verified fingerprint
  and Git authority record. Staging and a byte-identical commit do not require another verification
  run. Record and show the commit result, then resume the same workflow through `resume`/`next`.

### 5. Push phase (ONLY after separate approval)
- Ask user if they want to push
- **WAIT for explicit approval**
- Push only the separately authorized current branch to the configured remote.

## What Counts as Approval

✅ **Stage-only authority (record as one `git.stage` grant):**
- "stage the reviewed paths for CP-2"

✅ **Commit-only authority for an already-staged, proven tree (record as one `git.commit` grant):**
- "commit this checkpoint"
- "looks good, commit CP-2"

✅ **Push-only authority:**
- "push the current branch" — authorizes no commit.

✅ **One instruction may issue multiple grants only when each operation and object is explicit:**
- "stage and commit CP-2" — record and consume one `git.stage` grant, then one distinct `git.commit`
  grant.
- "commit CP-2 and push the current branch" — record distinct one-shot `git.commit` and `git.push`
  grants; it authorizes no staging.

❌ **NOT approval:**
- "continue" (this means continue working, NOT commit)
- "approve" / "approved" without naming the Git operation
- `USER_APPROVED` / `AUTO_APPROVED` Plan Gate verdicts
- Silence
- User asking questions
- User reviewing code

## Red Flags - STOP and ASK

If you find yourself about to commit, check:
1. Was the staged tree produced under a consumed one-shot `git.stage` record, and is there a distinct
   current one-shot `git.commit` record from the user/project policy, not an AI gate?
2. Does repository, checkpoint, parent chain, exact single operation, lifetime, and candidate closure
   still match each record?
3. Is the joined review verdict approved and every required owning-gate receipt current?
4. Does the staged candidate manifest byte-match the reviewed/verified fingerprint and allowed paths?

If ANY answer is NO → **DO NOT COMMIT**

## No standing-authority exception

Cadence instructions such as "commit after each checkpoint" describe desired workflow timing but do
not create reusable Git authority. Every mutation still consumes a distinct one-shot record naming
exactly one operation and object. There is no blanket, scoped-standing, or implied exception.

## Penalty for Violation

Violating this rule wastes the user's time and breaks trust. Always err on the side of asking for approval.
