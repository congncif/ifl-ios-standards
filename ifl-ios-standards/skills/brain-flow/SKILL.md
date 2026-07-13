---
name: brain-flow
description: >-
  Use when the user wants an iOS change or standards initiative taken end-to-end in co-working or
  auto mode, including requirements, design, planning, implementation, final review, and completion.
---

# Brain — Flow

Run one end-to-end flow using the provider's native task/thread, subagent, tool, and approval
capabilities. A provider-independent workflow kernel or state/evidence system may be considered only
through a separate approved work item backed by reproducible adopter evidence and an accepted ADR, as
required by shipped `standards/GOVERNANCE.md`. The repository-level `ROADMAP.md` supplies additional
non-normative intake guidance when working from the Standards source repository. Do not create a
kernel inside ordinary Brain-Flow delivery.

Read:

- `${CLAUDE_PLUGIN_ROOT}/standards/process/full-auto-operating-model.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/approval-modes.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/process/lean-verification.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/rules/COMMIT_WORKFLOW.md`
- `${CLAUDE_PLUGIN_ROOT}/standards/GOVERNANCE.md`

## 0. Bind mode, repository, and pattern

- Resolve mode, auto eligibility, preflight, authority matrix, and terminal boundary through
  `full-auto-operating-model.md`. Explicit `review with me` includes the user in final disposition.
- Use provider-native continuity and delegation. If a native feature is unavailable, continue inline
  when safe; an unavailable independent gate reviewer makes that auto gate ineligible.
- Read the consuming repository's `CLAUDE.md`/`AGENTS.md` bindings. Ask only for a missing value that
  would materially change the result.
- Detect Boardy+VIP or another bound pattern and forward relevant stages to its skills.
- When the task intersects enterprise iOS concerns, route through `enterprise-ios` and load only the
  applicable chapter(s) among the ten enterprise chapters. Those chapters apply and explain relevant
  Canon Rules; Canon owns normative obligations, so do not duplicate them in Brain-Flow artifacts.
- Use the approved plan checklist and provider-native task state for progress. Do not create canonical
  progress schemas, receipts, manifests, fingerprints, or evidence ledgers.
- On resume, rehydrate from the approved requirements/plan, last semantic commit, provider task state,
  current Git status, and allowed path boundary before writing.

## 1. Requirements and Definition of Done

Capture the goal, scope, exclusions, product/API/data/UI requirements, risks, assumptions, material
questions, and measurable Definition of Done.

- Co-working: obtain user approval.
- Auto: obtain one independent read-only AI requirement-gate decision; the requirements author cannot
  self-approve a non-trivial artifact.
- Both: ask the user when product intent, security, money, permissions, public behavior, or destructive
  scope is materially ambiguous.

## 2. Design and architecture

Use `brain-design` and `brain-architect`. Bind domain models, module boundaries, dependency direction,
public contracts, composition, migration constraints, and relevant ADRs. In Boardy+VIP mode, preserve
IO/implementation separation and the humble-View rule: Views render presenter-prepared values and may
hold only small UX-local state, never business decisions or untestable value computation.

## 3. One complete plan

Use `brain-plan` to create one plan for the whole objective. The plan contains dependency-ordered
workstreams, shared-writer ownership, bounded agent assignments, code-test needs, semantic commit
tasks, and one final AI consistency review.

Internal workstreams are not approval, review, or verification checkpoints. Do not plan RR/G gates,
verifier/lint/smoke scripts, manifests, hashes, receipts, or custom runtime state.

- Co-working: obtain one user Plan approval.
- Auto: obtain one independent read-only AI Plan-gate decision; the plan author cannot self-approve.

After approval, reopen the plan only for a material goal, scope, public-contract, architecture,
security, or authority change.

## 4. Execute continuously

Use `brain-execute` until the complete Definition of Done is implemented.

- Parallelize disjoint work; serialize shared writers through one integration owner.
- TDD applies to executable code where behavior/risk warrants it. It does not apply to standards text,
  templates, metadata, or documentation-only schemas.
- Use the consuming project's ordinary code tests when code changes. Do not ship plugin-owned
  verification scripts or duplicate CI; CI/release automation is outside the plugin boundary.
- Commit complete semantic tasks for traceability. If the user/project granted scoped auto-commit,
  stage and commit each conforming task without another prompt; otherwise obtain the required local
  Git authority. A commit does not trigger an intermediate consistency review.
- In auto mode, continue without routine questions. Escalate only material ambiguity, missing required
  authority, an external hold, or a real blocker.
- Classify failures and use the bounded retry/reassignment/inline/resume rules in the operating model;
  never repeat an unchanged failing action or create a checkpoint to recover.

## 5. One final AI consistency review

After every workstream is complete and committed when authorized, freeze writers and record exact
authority inputs, baseline SHA, candidate HEAD SHA, included tracked paths, and excluded unrelated
paths. Invoke `brain-review` exactly once over that frozen candidate. Review outputs and corrective
mutations are not part of the input candidate. Parallel specialist lanes inspect the same identity and
form one joined event.

Collect all findings before editing. Join and deduplicate them, then apply accepted in-scope findings
in one corrective batch. Do not schedule routine re-review, per-finding review, confirmation review,
or duplicate build/test runs. If the batch changes executable code, run only its smallest affected
signal. A correction that materially changes the approved goal, scope, public contract, architecture,
security, or authority starts a new plan rather than another loop inside this one.

## 6. Complete

Report:

- Definition-of-Done status;
- semantic tasks and important decisions completed;
- final AI review findings and dispositions;
- code tests actually run, if executable code changed;
- remaining blockers or explicitly deferred work;
- Git operations actually performed.

Never claim unrun tests, CI, publication, or release. Consume only the authority granted by the
project: scoped auto-commit may cover local stage+commit for semantic tasks, while branch changes,
amend/history rewrite, push, PR, merge, tag, publish, install, and release remain separate.
Engineering completion/release readiness is Brain-Flow's terminal state.

## Non-negotiable operating constraints

- one requirements decision, one plan decision, one completed plan, one final AI review;
- no packaged verifier/lint/smoke scripts;
- no per-checkpoint manifests, fingerprints, receipts, or evidence chains;
- no custom Kernel or provider-independent state engine without reproducible adopter evidence, a
  separately approved work item, and an accepted ADR under shipped governance;
- no execute → review → fix → re-review loop for small findings;
- no build/test for documentation-only work;
- no routine human interruption in auto mode.
