# Joined review — IIS-0008 RC4 targeted requalification

## Frozen input

- Planning commit: `336a4af3e591939873c603558cf760a8e014d799`.
- Q1 result commit: `1c9efe0d8adc5b54ed03040bb2770aa80f90ec42`.
- Q5 result commit and review HEAD: `ee47e08f8947730bb1d73a2fb4db9956fb6ec78f`.
- Candidate payload: exact commit `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Q1 fixture: `ca5496128cb1e9143ca977e4431435ce01a3a3e6` through
  `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef`.
- Q5 fixture: `3cbf36cfd5369fcc2bf95eca3571ab1665d6662f` through
  `69556d8815e5c05f79cc4a0aa6d11130be9ae0fa`.
- Retained Q3 fixture: `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1` against the same
  immutable candidate.
- Excluded: later closeout mutations, credentials/provider state, protected product source,
  `.superpowers/`, and all external release/configuration effects.

Both provider writers stopped before this one joined read-only review. No build, test, provider/auth
action, fixture/candidate mutation, or second review occurred.

## Verdict

**Q1 and Q5 pass. Open candidate P0/P1/P2 = `0/0/0`.** Together with retained Q3, RC4 now has 3 of 6
passing qualification rows. RC4 remains **NOT QUALIFIED** because Q2, Q4, and Q6 did not execute past
Claude's pre-inference authentication boundary.

## Historical finding closures

### IIS-0007 Q1 P1 — fixture-binding failure — closed

The original unbound Q1 fixture permitted an ambiguous Profile route. In IIS-0008 the consuming
repository supplied identical `core`-only bindings. Exact RC4 routed only through pattern-neutral Brain
skills, loaded no Boardy skill/source/assumption, committed a pure Domain/Application package, and
passed one `swift test` signal with 9 tests and 0 failures.

- Evidence: `qualification-q1.md:15-31,44-56`.
- Disposition: Q1 `PASSED`; candidate attribution rejected. No RC4 semantic correction is warranted.

### IIS-0007 Q5 fixture blocker — closed

The Q5 optional-date assertion was a fixture test compile defect. IIS-0008 changed only that test
seam, preserved every production/distribution/transition surface and organization-policy handoff, and
passed one package signal with 8 tests and 0 failures.

- Evidence: `qualification-q5.md:15-23,27-37`.
- Disposition: Q5 `PASSED`. The provider's historical preliminary P0 remains in the IIS-0007 audit
  trail, but candidate attribution remains rejected and no open candidate P0 exists.

## Retained and external rows

- Q3 remains `PASSED`: candidate identity and fixture HEAD are unchanged; no signal was duplicated.
- Q2/Q4/Q6 remain `NOT QUALIFIED — external Claude 401`: no authentication retry, fixture exposure,
  provider substitution, or compatibility inference occurred.

## Lane conclusions

- Profile/architecture: Q1 demonstrates Core-only pattern-neutral routing; Q3 retains typed
  Boardy/VIP + humble SwiftUI conformance; Q5 retains partial enterprise conformance and explicit
  human policy ownership.
- Signals/cadence: Q1 ran one final 9/0 SwiftPM signal; Q5 ran one final 8/0 package signal; Q3 reused
  its exact-candidate pass. No unchanged signal or review was repeated.
- Security/authority/YAGNI: provider state remained separate; Q5 stayed historyless/sanitized; no
  candidate payload, custom verifier, CI, kernel, evidence system, organization risk, remote, tag,
  publication, marketplace, install, or release state changed.

Final counts: open candidate P0/P1/P2 = `0/0/0`; open fixture/qualification P0/P1/P2 = `0/0/0`;
external authentication blockers = `3`.
