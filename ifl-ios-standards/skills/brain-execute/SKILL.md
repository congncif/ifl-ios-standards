---
name: brain-execute
description: >-
  Use when implementing an approved iOS plan or making an approved code or standards change in a
  Boardy or pattern-neutral project.
---

# Brain — Execute

Under Codex, `${CLAUDE_PLUGIN_ROOT}` is a path marker, not a required shell variable. Resolve it
against the installed plugin root that contains this skill's `skills/` directory. Claude Code expands
it normally.

Execute the approved plan continuously until its Definition of Done is complete or a real blocker
requires escalation. Read:

- `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md`

## Operating loop

For each work slice: **understand → locate → preserve → implement → code-test if applicable → record**.

- Keep changes inside the approved scope and preserve dependency direction and local conventions.
- Use TDD for executable code only when required by behavior or regression risk. Documentation,
  standards, templates, metadata, and documentation-only schemas do not need TDD.
- Parallelize disjoint writers; serialize shared files and vocabulary through one integration owner.
- Do not run a review, approval, full build, or verification cycle after each slice or finding.
- Do not add plugin-owned verifier/lint/smoke scripts or custom state/evidence machinery.
- Commit complete semantic tasks when separately authorized; never commit by file, finding, or agent
  assignment.
- Classify failures before retrying. Reassign a stalled disjoint lane or execute it inline, recover
  context from the approved plan/provider state/Git history, and escalate only the material blockers
  defined by the operating model.

After the last planned Task commit, freeze exact baseline/HEAD SHAs and included/excluded paths, then
hand that same candidate identity to one final AI consistency review.
Collect all findings before editing and apply accepted in-scope findings in one corrective batch. Do
not schedule routine re-review. A material scope, public-contract, architecture, or security change
reopens planning instead of starting an ad-hoc loop.

Report every Definition-of-Done item factually. Auto/Plan/review approval never grants Git authority;
stage, commit, push, tag, publish, and release only under their own project-governed authority.

When Boardy+VIP is bound, load the matching `boardy-*` skill for the change being implemented.
