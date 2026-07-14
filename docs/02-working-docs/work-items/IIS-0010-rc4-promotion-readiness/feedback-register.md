# RC4 feedback register

## Register authority and scope

- Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Register owner pending designation: Standards Owner.
- Triage owner for this consolidation: Qualification Owner.
- Sources reviewed: IIS-0004 through IIS-0009 and one read-only origin visibility audit on 2026-07-14.
  IIS-0004 was pre-RC4 qualification readiness; IIS-0005 exercised RC3 and found the navigation defect
  later corrected when RC4 was created. Neither produced an additional material RC4 item, so their
  history is not relabeled as RC4 feedback. IIS-0006 through IIS-0009 produced the deduplicated items
  below.
- This register records observed internal qualification feedback. It does not assert that unobservable
  external feedback is absent.

## Deduplicated items

### RC4-FB-001 — Core-only routing symptom in the first Q1 fixture

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Codex Qualification Owner / Qualification Owner |
| Provider | Codex |
| Profiles / chapters | `core`; no Boardy; enterprise chapters N/A |
| Build system / adoption mode | SwiftPM / greenfield |
| Reproducible scenario | First Q1 fixture lacked explicit consuming-repository Profile bindings; the provider loaded a Boardy route while produced source stayed pattern-neutral. |
| Expected / actual | Expected Core/Brain only; actual provider route included Boardy in the unbound fixture. |
| Affected authority artifact | Profile binding and Brain Flow routing contract; no proven Canon/ADR/payload defect. |
| Impact / relevance | Initially blocked Q1. Security/privacy/legal: N/A; no protected data or release action. |
| Severity / disposition | Historical qualification P1; `not applicable` to candidate defect after controlled reproduction. |
| Rationale / owner / state | Explicit identical `core` bindings removed the ambiguity; exact RC4 Q1 then passed 9/0. Qualification Owner. **CLOSED — fixture binding resolved**. |

### RC4-FB-002 — Q5 optional-date test compile symptom

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Codex Qualification Owner / Qualification Owner |
| Provider | Codex |
| Profiles / chapters | `core` plus applicable enterprise chapters; policy-owner handoffs retained |
| Build system / adoption mode | CocoaPods + SwiftPM hybrid / transitional migration |
| Reproducible scenario | The sanitized fixture's optional restored-date assertion did not compile after the migration implementation. |
| Expected / actual | Expected one final package signal; actual first signal stopped on a fixture test assertion. |
| Affected authority artifact | Test fixture only; production, distribution, Canon, ADR, and candidate payload unchanged. |
| Impact / relevance | Initially blocked Q5. Privacy/security/legal relevance remained in human-owned transition handoffs; the test defect did not alter them. |
| Severity / disposition | Historical qualification P1; `not applicable` to candidate defect after focused recovery. |
| Rationale / owner / state | One test-only `XCTUnwrap` correction produced an 8/0 final package result. Qualification Owner plus applicable Policy Owners for retained handoffs. **CLOSED — fixture test resolved**. |

### RC4-FB-003 — historical Claude rows stopped before inference

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Claude Qualification Owner / Qualification Owner |
| Provider | Claude Code `2.1.207` through operator-owned local transport |
| Profiles / chapters | Q2: Boardy/UIKit; Q4: Core/UIKit/SwiftUI; Q6: Boardy/mixed UI/applicable enterprise |
| Build system / adoption mode | Q2 CocoaPods/brownfield; Q4 Bazel/brownfield; Q6 organization Bazel graph/existing app |
| Reproducible scenario | Earlier automated CLI invocations stopped before inference. Direct runs later succeeded when normal setting sources supplied the configured transport. |
| Expected / actual | Expected provider-native row execution; direct Q2/Q4/Q6 all reached inference, loaded exact RC4 through `--plugin-dir`, and completed. |
| Affected authority artifact | Provider transport only. Normal settings provided transport, never Standards authority. |
| Impact / relevance | Historical execution delay only; no candidate, security, privacy, legal, or organization-policy defect. |
| Severity / disposition | Severity N/A as a candidate finding; direct execution superseded the startup observation. |
| Rationale / owner / state | Q2 `0ada3e1…`, Q4 `04d5085…`, and Q6 `3476c3c…` plus `4793004…` completed. Claude Qualification Owner/operator. **CLOSED**. |

### RC4-FB-004 — frozen release-status snapshot is stale after qualification closeout

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Release-readiness audit / Standards Owner |
| Provider | N/A |
| Profiles / chapters | All advertised qualification combinations |
| Build system / adoption mode | All matrix rows / N/A |
| Reproducible scenario | Candidate `RELEASE.md` records all Q1-Q6 as unqualified at freeze; the external working ledger now truthfully records all six rows passed. |
| Expected / actual | Expected immutable candidate status snapshot; actual snapshot is conservative but no longer the live 6/6 ledger. |
| Affected authority artifact | Derived release-status text in frozen payload; working qualification register is current authority for observations. |
| Impact / relevance | Low-risk reader confusion; no compatibility, security, privacy, legal, or executable behavior change. |
| Severity / disposition | P2 / `defer` to promotion metadata plan. |
| Rationale / owner / state | Editing now would change immutable RC4 and invalidate exact-candidate identity. Standards Owner. **OPEN — owned metadata follow-up; non-blocking until promotion metadata is prepared**. |

### RC4-FB-005 — automated versus direct local-transport wording

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | IIS-0009 joined reviewer / Qualification Owner |
| Provider | Claude Code local operator path |
| Profiles / chapters | Q2/Q4/Q6 as above |
| Build system / adoption mode | Q2 CocoaPods; Q4/Q6 Bazel / respective brownfield and existing-app modes |
| Reproducible scenario | Empty setting sources prevented the configured local-model route. Direct execution succeeded after that option was removed and normal sources supplied transport. |
| Expected / actual | Expected transport isolation without losing the configured route; actual corrected command separates transport settings from exact-RC4 Standards authority. |
| Affected authority artifact | IIS-0009 working documents only; candidate payload N/A. |
| Impact / relevance | Editorial/operating clarity. Security/privacy/legal: operator profile remains uninspected and unchanged. |
| Severity / disposition | P2 / `not applicable` to the candidate; IIS-0009 reporting correction accepted and retained. |
| Rationale / owner / state | The corrected runbook omits empty setting sources and retains explicit exact-RC4 loading. Qualification Owner. **CLOSED**. |

### RC4-FB-006 — nonstandard build graph and waived target-specific coverage

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Qualification closeout / Qualification Owner |
| Provider | Claude Code through operator-owned local transport |
| Profiles / chapters | Q4 Core/UIKit/SwiftUI; Q6 Boardy/mixed UI/applicable enterprise |
| Build system / adoption mode | Nonstandard organization build graph / brownfield and existing app |
| Reproducible scenario | Q4's repository wrapper reached Bazel analysis, then a pre-existing missing simulator runner stopped analysis with 0 tests. Q6's target signal was omitted under the same approved scope decision. |
| Expected / actual | Expected the smallest representative platform signal; retained Q3 native `xcodebuild test` passed 5/0, while Q4/Q6 target-specific compilation/tests remained unobserved. |
| Affected authority artifact | Fixture build graph and qualification coverage only; candidate payload N/A. |
| Impact / relevance | Q4/Q6 behavior was reviewed and committed, but their exact targets were not compiled/tested. The Q3 signal cannot be transferred as target-specific proof. |
| Severity / disposition | Candidate severity N/A / explicit user-owned representative-signal waiver. |
| Rationale / owner / state | Exhaustive/nonstandard configuration validation was out of scope once a native iOS platform signal existed. Qualification Owner owns the recorded residual; the selected Standards and Release decision owners must accept or resolve it before promotion. **ACCEPTED RESIDUAL — not a candidate defect**. |

## External visibility audit

Exact RC4 is not present on origin as a branch, tag, release, PR commit, or other remotely addressable
candidate ref. The inspectable public repository surfaces remain the default branch and published RC1
tag. Issues, PRs/reviews/comments, releases, discussions, and commit comments therefore provide no
inspectable feedback surface bound to exact RC4.

Disposition: **UNOBSERVABLE — candidate has no authorized external review surface.** This does not mean
external feedback is absent. The Standards Owner must later either designate this internal register as
sufficient RC feedback scope or obtain exact authority for a candidate review surface and disposition
feedback received there. No push/publication is authorized by this register.

## Current finding counts

- Open proven candidate P0/P1: `0/0`.
- Open candidate/reporting P2: `1` (`RC4-FB-004`, owned metadata follow-up).
- Open qualification rows: none; frozen RC4 is 6/6.
- Q4/Q6 target-specific compilation/test coverage: unobserved under explicit waiver; residual retained.
- External RC feedback: unobservable, not counted as zero.
