# Requirements — IIS-0009 RC4 Claude local-provider qualification

## Meta

- Created: 2026-07-14
- Flow mode: auto
- Candidate version: `1.0.0-rc.4`
- Immutable candidate commit: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Predecessor closeout: IIS-0008 at `a454c33c9eea8ea447c1275c13172d2c5cff3a53`
- Verification: provider-native row result, the smallest representative repository-owned executable
  signal when applicable or an explicit owner waiver with residual risk, and one joined final AI
  review per closeout plan; no plugin-owned verifier, script, CI, receipt, or custom kernel

## Goal

Execute the three remaining Claude Code qualification rows Q2, Q4, and Q6 against exact immutable
RC4. Treat the locally customized `claude` CLI as the provider runtime: command execution and observed
task behavior are authoritative; authentication metadata is not a qualification gate. Retain the
already passing Q1, Q3, and Q5 results without rerunning them.

## Authority and fixed boundary

- The user clarified that `claude` runs through a local model and that qualification should execute the
  CLI and observe its result without treating authentication as a prerequisite.
- Each provider session starts in Full Access and may read/write/commit only its isolated temporary
  fixture. If a local permission action fails, classify it once and continue or close the row; do not
  enter a permission loop.
- The candidate payload is read-only and extracted from exact commit `f7cd2cf…`. Public or installed
  RC1 and later Standards reporting commits are not qualification payloads.
- Q1, Q3, and Q5 remain passed because RC4 is unchanged. Do not rerun their provider sessions or final
  signals.
- No live adopter repository may be mutated. Q2/Q4/Q6 use new isolated clones from the already prepared
  exact baselines. Each fixture has one writer and its own branch/history.
- Reports use neutral fixture aliases and must not publish adopter brand names, source URLs, protected
  source, credentials, provider settings, or raw transcripts.
- No candidate mutation, persistent plugin/provider installation or configuration, push, tag, release,
  marketplace update, rollout, GA declaration, or organization risk acceptance is authorized.

## Fixed scenarios

### Q2 — Boardy/VIP + UIKit / CocoaPods / `0.18.x` brownfield

- Baseline: new isolated clone of the constructed migration fixture at
  `8af9959876c1a130d9e6071d131f13f3a10138fe`. That commit is based on product source
  `d00e842905a53de17be65c134d40c15d58dfde0b` and separately commits exact Standards `0.18.4`
  bindings from `ee011fe5f8b018cbb263e93e320349934b34d97b`.
- Invoke exact RC4 Brain Flow in auto mode. Migrate only project bindings/adoption guidance from the
  constructed `0.18.4` state to RC4 and assess one existing Boardy/UIKit IO/Plugins boundary.
- Preserve CocoaPods, product behavior, and repository-owned commands. Because this is binding/review
  work only, do not run an artificial build or test.
- Pass when exact RC4 is loaded, migration remains incremental, Boardy stays in the selected shell,
  bindings are coherent, one semantic fixture commit exists, the worktree is clean, and no release
  authority is crossed.

### Q4 — Core + UIKit + SwiftUI / Bazel / brownfield / no Boardy in scope

- Baseline: new isolated clone of the representative enterprise fixture at
  `6296c186812011be89e25429f387064e9dedc4a4`.
- Scope only the existing SwiftUI widget adapter and UIKit search adapter. Boardy is non-applicable to
  this bounded surface even if other modules use it.
- Invoke exact RC4 Brain Flow in auto mode. Implement one small framework-neutral destination policy
  consumed by both adapters, with focused tests or the narrowest existing executable coverage.
- Preserve Bazel and repository-owned commands. Select the smallest viable representative final
  signal after the complete code change. A named owner may waive a nonstandard target when an accepted
  platform signal exists, provided the omitted coverage and residual risk remain explicit.
- Pass when exact RC4 loads only Core/UIKit/SwiftUI guidance for the scope, the shared policy remains
  framework-neutral, both adapters stay humble, no Boardy assumption or package-manager rewrite is
  introduced, semantic commits exist, the representative-signal decision is truthful, and the
  worktree is clean.

### Q6 — Boardy/VIP + mixed UIKit/SwiftUI + enterprise / organization build graph

- Baseline: a separate new isolated clone of the same representative enterprise fixture at
  `6296c186812011be89e25429f387064e9dedc4a4`.
- Invoke exact RC4 Brain Flow in auto mode. Migrate portable bindings `2.2.0` to `2.5.0`, reconcile
  local full-auto authority, then make one bounded public-contract purity correction in the selected
  Boardy/UIKit feature while considering the existing SwiftUI and applicable enterprise surfaces.
- Exercise provider-native handoff/resume and one-writer ownership inside the session. Select the
  smallest viable representative repository-owned signal after the complete code change, or record an
  explicit owner waiver with omitted coverage and residual risk; do not rerun an unchanged failure.
- Pass when exact RC4, Boardy/VIP, mixed UI, enterprise applicability, semantic commits, handoff/resume,
  public-contract purity, shell confinement, a truthful representative-signal decision, clean state,
  and authority boundaries are all observed without inventing organization policy decisions.

## Provider/session isolation and cadence

- Use Claude Code `2.1.207` through the environment's configured local-model transport. Do not inspect,
  gate on, copy, print, or persist authentication material.
- Automated probes gave every row an empty row-owned ephemeral `CLAUDE_CONFIG_DIR`. Direct operator
  sessions inherited the operator's normal setting sources only to reach the configured local-model
  transport; they did not inspect, copy, print, or change that profile. Those settings supplied
  transport, never Standards authority. Exact RC4 loaded only through session-local `--plugin-dir`,
  with Full Access/bypass permission mode, neutral inline plugin settings, and a strict empty MCP
  configuration.
- Q2's tracked `.claude/**` files are migration input only. They must not become runtime settings, hooks,
  MCPs, or plugin registrations. No non-RC4 plugin may load in any row.
- Q2, Q4, and Q6 have independent writable fixtures and row-owned provider state and may execute
  concurrently. They share only the read-only exact RC4 plugin directory and inherited local-model
  transport environment.
- The outer approved work item is the only plan gate. Each Claude row invokes RC4 Brain Flow and
  executes its fixed task without opening nested requirements or review checkpoints.
- Collect all row findings before any Standards correction. A proven candidate defect opens a new
  candidate-revision plan; it is never repaired inside a qualification fixture.
- After all writers stop, freeze their commits/results and run exactly one joined read-only AI review
  over IIS-0009. Apply at most one reporting-only correction batch; no provider rerun, duplicate green
  signal, or routine re-review.
- Commit Standards working documents by semantic task with explicit path staging. Preserve unrelated
  `.superpowers/`.

## Definition of Done

- [x] **D1 — Exact candidate and isolated inputs.** Every row demonstrably loaded RC4 at `f7cd2cf…`;
  each fixture started at its specified baseline and had one writer.
- [x] **D2 — Local-provider boundary.** Claude CLI execution is observed directly; auth metadata is not
  used as a gate or reported as product compatibility evidence. Automated transport investigation is
  closed with a direct operator runbook.
- [x] **D3 — Q2 is observed.** Incremental `0.18.x` binding/adoption migration and Boardy/UIKit shell
  assessment complete without artificial build/test or product/package-manager change.
- [x] **D4 — Q4 is observed.** Core-only mixed-UI policy adoption, focused tests, semantic commit, no
  Boardy assumption, attempted repository-wrapper result, explicit waiver, and unproven target-specific
  compile/test residual are recorded.
- [x] **D5 — Q6 is observed.** Boardy/mixed-UI/enterprise flow, portable binding migration,
  handoff/resume, contract correction, semantic commits, explicit waiver, and unproven target-specific
  compile/test residual are recorded.
- [x] **D6 — Existing passes are retained.** Q1/Q3/Q5 remain bound to unchanged exact RC4 with no rerun.
- [x] **D7 — Review converges once.** One joined final AI review deduplicates candidate, provider,
  fixture, signal, authority, privacy, and release findings; at most one reporting correction follows.
- [x] **D8 — Release result is truthful.** The final Q1-Q6 matrix uses only observed row outcomes and
  does not claim qualification, GA, or compatibility while any required row remains unpassed.
- [x] **D9 — External boundary and history are preserved.** Semantic commits use explicit paths;
  candidate/public RC1/remotes/tags/releases/marketplace/install/rollout and unrelated files are
  unchanged.

Work-item status: **COMPLETED — DIRECT CLI ROWS OBSERVED; FROZEN RC4 QUALIFIED (6/6)**

The final result ledger and post-freeze identity boundary are owned by IIS-0011. Historical
pre-inference transport observations remain valid history but no longer describe current qualification.

## Requirement Gate

- Mode: auto
- Reviewer: independent agent `iis0009_plan_gate`
- Verdict: AUTO_APPROVED after retaining the runtime-isolation amendment

STATUS: APPROVED
