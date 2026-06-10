---
name: brain-execute
description: >-
  Use when implementing an approved plan or making a code change — the 6-step operating loop,
  smallest correct change, real verification signal. Pattern-neutral: applies to any iOS project,
  Boardy or not. Triggers: "implement this", "execute the plan", "make the change", "code it up".
---

# Brain — Execute (operating loop, verify, report)

Pattern-neutral execution stage of the brain rulebook. Runs an approved plan from
`/ifl-ios-standards:brain-plan`, or applies the loop directly for small standalone changes.

## Read
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/QUICK_REF.md` — §1 operating loop, §2 the 10 hard rules, §4 pre-completion self-review.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/13-agentic-coding-rules.md` — read-before-write, local reasoning.
- `${CLAUDE_PLUGIN_ROOT}/standards/brain/rulebook/C-verification-commands.md` — canonical verification commands (resolve actual values from project bindings).
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md` — checkpoint cadence (verify at phase boundaries, not per task).

## The loop (every task)
1. **Understand** → 2. **Locate** → 3. **Preserve** → 4. **Implement** → 5. **Verify** → 6. **Report**.
Skipping understanding → noise. Skipping verification → lies. Empty output ≠ success.

## Guardrails
- Smallest correct change. No drive-by edits, no speculative abstraction (hard rule 8).
- Preserve naming, layering, dependency direction, access modifiers of surrounding code.
- Verify with real signal at phase boundaries; full build + suite once before "done".
- Run the §4 pre-completion self-review before reporting.

## Pattern hook
Project's `CLAUDE.md` binds Boardy+VIP → load the matching task skill for the change at hand:
`/ifl-ios-standards:boardy-new-module`, `:boardy-new-board`, `:boardy-io-interface`,
`:boardy-communication`, `:boardy-service-layer`, `:boardy-plugin-composition`.
