# RC4 Claude Code field-qualification result

## Result

- Candidate: `1.0.0-rc.4`
- Immutable candidate commit: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Runtime: `Claude Code 2.1.207`
- Group disposition: **NOT QUALIFIED**
- Row results: Q2/Q4/Q6 `SKIPPED — provider authentication`; all remain `NOT QUALIFIED`

One candidate-load probe invoked Claude Code with `--plugin-dir` bound to the exact read-only RC4
extraction. The provider returned `401 Invalid authentication credentials` before inference. No task
prompt or fixture source was sent, no fixture was mutated, and provider compatibility was not inferred
from local files or Codex results.

The session has Full Access for local work, but local filesystem authority cannot repair external
provider authentication. Per user direction and the approved IIS-0007 plan, the failed permission or
authentication boundary was not retried. Public/installed RC1 was not used as a fallback and Codex
was not substituted for any Claude-only row.

## Q2 — Boardy/VIP + UIKit / CocoaPods / 0.18.x brownfield

- Official result: **SKIPPED — provider authentication; NOT QUALIFIED**.
- Candidate findings observed by this row: none; the provider did not reach inference.
- Fixture exposure/mutation/signal: none.
- Recovery owner: Claude Qualification Owner with the provider-authentication owner.
- Residual risk: provider-native migration, Boardy shell confinement, and preservation of
  project-owned CocoaPods commands/bindings remain unobserved.

## Q4 — Core + UIKit + SwiftUI / Bazel / brownfield

- Official result: **SKIPPED — provider authentication; NOT QUALIFIED**.
- Candidate findings observed by this row: none; the provider did not reach inference.
- Protected representative fixture exposure/mutation/signal: none.
- Recovery owner: Claude Qualification Owner with the provider-authentication owner.
- Residual risk: provider-native Core-only Profile selection, shared framework-neutral policy,
  mixed-UI adapters, and repository-owned Bazel behavior remain unobserved.

## Q6 — Boardy/VIP + mixed UI + enterprise

- Official result: **SKIPPED — provider authentication; NOT QUALIFIED**.
- Candidate findings observed by this row: none; the provider did not reach inference.
- Protected representative fixture exposure/mutation/signal: none.
- Recovery owner: Claude Qualification Owner with the provider-authentication owner.
- Residual risk: provider-native handoff/resume, shared-writer control, public-contract correction,
  focused organization-build-graph signals, semantic commits, and joined-flow completion remain
  unobserved.

## Group boundary

The Claude rows are truthfully dispositioned but cannot pass until the provider can authenticate and
execute the exact candidate. No authentication retry, provider substitution, adopter-data transfer,
persistent provider/configuration change, push, tag, publication, marketplace update, install, CI,
custom verifier, receipt/evidence framework, or release action was performed.
