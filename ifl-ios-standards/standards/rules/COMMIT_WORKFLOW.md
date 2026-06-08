# SPEC: Commit Workflow

> **CRITICAL RULE**: NEVER commit or push to git without explicit user approval.

## Workflow Steps

### 1. Implementation Phase
- Write code
- Fix issues
- Run builds and tests
- Verify everything works

### 2. Review Phase (MANDATORY)
- Run spec-sync audit per `${CLAUDE_PLUGIN_ROOT}/standards/rules/SPEC_SYNC.md` (Sync Detection Checklist + Pre-Completion Self-Audit); stage any triggered spec updates in the same change set
- Show user what was changed
- Explain the changes, including which SPEC_SYNC checklist rows fired (or "no sync triggers fired")
- **WAIT for explicit approval from user**
- Do NOT proceed to commit without approval

### 3. Commit Phase (ONLY after approval)
- Show status: `git status --short`
- Stage only reviewed, relevant files by explicit path (avoid `git add -A` / `git add .` unless the user explicitly approves broad staging)
- Show staged status: `git status --short`
- Create commit with descriptive message
- Show commit result to user

### 4. Push Phase (ONLY after approval)
- Ask user if they want to push
- **WAIT for explicit approval**
- Push to the project's configured remote/branch (defined in the consuming repo's `CLAUDE.md`): `git push {GitRemote} {BaseBranch}`

## What Counts as Approval

✅ **Valid approval phrases:**
- "commit it"
- "commit and push"
- "push to git"
- "looks good, commit"
- "approve"
- "ok to commit"

❌ **NOT approval:**
- "continue" (this means continue working, NOT commit)
- Silence
- User asking questions
- User reviewing code

## Red Flags - STOP and ASK

If you find yourself about to commit, ask:
1. Did the user explicitly say to commit?
2. Did the user review the changes?
3. Did the user approve?

If ANY answer is NO → **DO NOT COMMIT**

## Exception

The ONLY exception is if the user has given blanket approval for a specific workflow, such as:
- "commit after each phase"
- "auto-commit when tests pass"

Even then, confirm this approval at the start of the session.

## Penalty for Violation

Violating this rule wastes the user's time and breaks trust. Always err on the side of asking for approval.
