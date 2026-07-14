# Plan — IIS-0009 RC4 Claude local-provider qualification

## Meta

- Created: 2026-07-14
- Mode: auto
- Requirements: `requirements.md`
- Immutable candidate: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Integration owner: primary agent; exactly one provider writer per isolated fixture

## Execution strategy

- Commit this approved requirements/plan pair as one planning baseline.
- Create one fresh detached exact-candidate clone and expose only its `ifl-ios-standards/` subtree via
  `--plugin-dir`; make that candidate clone read-only before provider execution.
- Create fresh isolated clones from the existing exact Q2, Q4, and Q6 prepared baselines. Remove remote
  push surfaces from the new fixtures and use neutral local branch names.
- Run one non-persistent Claude CLI session per fixture with an empty row-owned `CLAUDE_CONFIG_DIR`, no
  settings sources, neutral inline settings, and a strict empty MCP configuration. Each row invokes
  exact RC4 Brain Flow, owns only its fixture, commits semantically, and reports observed result.
- Q2 is documentation/binding-only and receives no artificial executable signal. Q4/Q6 each receive at
  most one final focused Bazel signal after the full code change.
- Retain Q1/Q3/Q5 without rerun. Join all six dispositions once after provider writers stop, allow at
  most one reporting-only correction batch, and do not repeat review or unchanged signals.
- Stage Standards paths explicitly and commit by semantic task. Never stage `.superpowers/`.

## Task 1 — Approve plan and prepare exact isolated inputs

**Outcome:** one approved boundary, exact read-only RC4, and three clean one-writer fixtures.

**Status:** PENDING

- Obtain one independent combined requirements/plan gate.
- Commit only this work item's `requirements.md` and `plan.md`.
- Create the exact candidate clone at `/private/tmp/iis0009-rc4-candidate`, detach at `f7cd2cf…`, verify
  `ifl-ios-standards/VERSION` is `1.0.0-rc.4`, and make it read-only.
- Create Q2 at `/private/tmp/iis0009-q2-migration` from `8af9959…`, Q4 at
  `/private/tmp/iis0009-q4-enterprise` from `6296c18…`, and Q6 at
  `/private/tmp/iis0009-q6-enterprise` from `6296c18…`.
- Remove each new fixture's remote, create its row branch, and confirm exact baseline plus clean state.

**Commit:** `docs: plan RC4 Claude local qualification`

## Task 2 — Execute Claude Q2, Q4, and Q6

**Outcome:** each remaining Claude row has one provider-native exact-candidate result.

**Status:** PENDING

- Launch one Claude CLI process per fixture with exact RC4 `--plugin-dir`, an empty row-owned
  `CLAUDE_CONFIG_DIR`, non-persistent print mode, `--setting-sources ""`, neutral inline settings with
  no enabled plugin, a strict empty MCP configuration, bypass-permission mode, and no auth gate.
- Treat tracked `.claude/**` in Q2 only as migration input. Do not load it as runtime settings, and do
  not load any user/project/local plugin, hook, workflow, or MCP outside exact RC4.
- Require the first task action to invoke `/ifl-ios-standards:brain-flow` and confirm RC4 from the
  plugin `VERSION` file.
- Give each process only its fixed row task and scoped fixture/commit authority. Prohibit remote/release
  operations, persistent config/install changes, unrelated path access, raw transcript persistence, and
  extra test loops.
- When all processes finish, inspect their candidate confirmation, skill routing, changed paths,
  semantic commits, final signal where applicable, worktree cleanliness, findings, and final response.
- Write one `qualification-claude.md` using neutral fixture aliases and factual command/result summaries;
  do not copy protected source or raw transcripts into the Standards repository.

**Commit:** `docs: record RC4 Claude local qualification`

## Task 3 — Run one joined review and close release readiness

**Outcome:** one deduplicated Q1-Q6 matrix and the next accountable promotion boundary.

**Status:** PENDING

- Freeze the planning and Claude-result commits plus exact fixture heads.
- Run one independent joined AI review across candidate identity, provider fidelity, architecture,
  fixture privacy, signals, semantic history, authority, severity, retained Codex rows, and release
  claims.
- Apply at most one consolidated reporting correction batch; do not rerun provider or executable
  signals and do not run a second review.
- Write `review.md`, `qualification.md`, and `final-report.md`; update DoD/task statuses truthfully.
- If all six rows pass with no open P0/P1, hand off to RC feedback/sign-offs without performing any
  external release operation. Otherwise keep RC4 not qualified and name the exact remaining owner.

**Commit:** `docs: close RC4 Claude local qualification`

## Plan Gate

- Mode: auto
- Gate owner: independent AI reviewer not authoring these documents
- Rubric: exact candidate/provider fidelity, local-model boundary, fixture privacy, no provider
  substitution, one-signal/one-review cadence, semantic commit scope, truthful release status, and no
  hidden tooling or external authority
- Verdict: AUTO_APPROVED after retaining one material amendment: isolate every row from tracked Q2 and
  user settings/plugins/MCPs while inheriting only the unchanged local-model transport environment

STATUS: APPROVED
