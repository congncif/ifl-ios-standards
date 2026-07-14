# RC4 feedback register

## Register authority and scope

- Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Register owner pending designation: Standards Owner.
- Triage owner for this consolidation: Qualification Owner.
- Sources: RC4 qualification/review working records IIS-0006 through IIS-0009 and one read-only origin
  visibility audit on 2026-07-14.
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

### RC4-FB-003 — Claude rows stopped before inference

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Claude Qualification Owner / Qualification Owner |
| Provider | Claude Code `2.1.207` through operator-owned local transport |
| Profiles / chapters | Q2: Boardy/UIKit; Q4: Core/UIKit/SwiftUI; Q6: Boardy/mixed UI/applicable enterprise |
| Build system / adoption mode | Q2 CocoaPods/brownfield; Q4 Bazel/brownfield; Q6 organization Bazel graph/existing app |
| Reproducible scenario | Automated CLI invocations stopped before inference with zero tokens; no row loaded RC4 skills or received fixture source. |
| Expected / actual | Expected provider-native row execution; actual startup ended before task execution. |
| Affected authority artifact | Provider execution availability only; no Standards authority artifact was exercised. |
| Impact / relevance | Q2/Q4/Q6 remain unqualified. Security/privacy/legal: protected source was not sent; no organization decision occurred. |
| Severity / disposition | Severity N/A as a candidate finding; `defer` provider observation to direct operator CLI execution. |
| Rationale / owner / state | Startup behavior cannot prove or disprove RC4 semantics. Claude Qualification Owner/operator. **OPEN — direct CLI results pending**. |

### RC4-FB-004 — frozen release-status snapshot is stale after partial qualification

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | Release-readiness audit / Standards Owner |
| Provider | N/A |
| Profiles / chapters | All advertised qualification combinations |
| Build system / adoption mode | All matrix rows / N/A |
| Reproducible scenario | Candidate `RELEASE.md` records all Q1-Q6 as unqualified at freeze; the external working ledger now truthfully records Q1/Q3/Q5 passed. |
| Expected / actual | Expected immutable candidate status snapshot; actual snapshot is conservative but no longer the live 3/6 ledger. |
| Affected authority artifact | Derived release-status text in frozen payload; working qualification register is current authority for observations. |
| Impact / relevance | Low-risk reader confusion; no compatibility, security, privacy, legal, or executable behavior change. |
| Severity / disposition | P2 / `defer` to qualification-complete or GA metadata plan. |
| Rationale / owner / state | Editing now would change immutable RC4 and invalidate exact-candidate identity. Standards Owner. **OPEN — owned metadata follow-up; non-blocking until promotion metadata is prepared**. |

### RC4-FB-005 — automated versus direct local-transport wording

| Intake field | Record |
|---|---|
| Candidate | `1.0.0-rc.4` / `f7cd2cf…` |
| Reporter / triage owner | IIS-0009 joined reviewer / Qualification Owner |
| Provider | Claude Code local operator path |
| Profiles / chapters | Q2/Q4/Q6 as above |
| Build system / adoption mode | Q2 CocoaPods; Q4/Q6 Bazel / respective brownfield and existing-app modes |
| Reproducible scenario | Automated plan required empty row config while the direct runbook retained the existing operator profile for local transport; Task 2 wording implied completion before row execution. |
| Expected / actual | Expected a handoff-only status; actual draft could be read as completed qualification. |
| Affected authority artifact | IIS-0009 working documents only; candidate payload N/A. |
| Impact / relevance | Editorial/operating clarity. Security/privacy/legal: operator profile remains uninspected and unchanged. |
| Severity / disposition | P2 / `approved candidate change` N/A; reporting correction accepted in IIS-0009. |
| Rationale / owner / state | One reporting batch aligned the exception/status and strengthened preflight/prompts. Qualification Owner. **CLOSED**. |

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
- Open qualification rows: Q2/Q4/Q6 direct CLI pending.
- External RC feedback: unobservable, not counted as zero.
