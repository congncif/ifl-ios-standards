# Joined review — IIS-0007 RC4 field qualification

## Frozen input

- Planning commit: `586c6ebc20e6be943fa3e163a4f05d6939296489`.
- Codex-result commit: `dea68ee5071035939e8a86150dc7f59a77ed55bf`.
- Claude-result commit and review HEAD: `b7a700b871a1ec2151d5f11b22f28e5aca332f82`.
- Candidate payload: exact commit `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Included: `RELEASE.md`, approved IIS-0007 requirements/plan, both provider reports, named provider
  final outputs, and the exact Q1/Q3/Q5 fixture states.
- Excluded: credentials, protected source outside the sanitized Q5 allowlist, provider-local state,
  raw product history, unrelated `.superpowers/`, and later review/closeout mutations.

All provider writers stopped before this one read-only joined event. A stalled specialist lane
returned no finding list and was reassigned inside the same event; only the joined result below was
accepted. No build, test, provider/authentication action, payload mutation, or review rerun occurred.

## Verdict

**RC4 is NOT QUALIFIED and is not ready for sign-off or promotion.** Q3 passed. Q1 and Q5 remain not
qualified on provider/Profile-routing and fixture-execution failures; Q2, Q4, and Q6 remain externally
blocked before provider inference. The review found no proven candidate P0/P1/P2, but absence of a
proven payload defect does not turn an unpassed row into a pass.

## Deduplicated findings

### `F-IIS0007-001` — P1 qualification/provider-routing failure — open

The corrective Q1 provider session loaded `boardy-vip` while identifying the fixture as Core-only.
`RELEASE.md:97` requires Q1 to complete without loading Boardy, while the produced fixture code stayed
framework-neutral and green. The required agent behavior was therefore not observed.

- Evidence: `qualification-codex.md:24-48`; Q1 fixture HEAD
  `79b4a38904e41d61fff8a31484bdeeed8ca361a9`.
- Affected: Q1, D2, release Profile/provider fidelity.
- Candidate attribution: not proven. The observation establishes a provider/Profile-routing failure,
  but not whether its root cause is RC4 guidance, provider behavior, or session routing context.
- Owner: Qualification Owner with the provider/Profile-routing owner.
- Disposition: keep Q1 not qualified. Do not mutate RC4 or run a third Q1 session inside IIS-0007. A
  new bounded qualification plan may isolate causality; a semantic payload correction requires a new
  approved candidate plan and revision.

### `F-IIS0007-002` — P1 fixture/execution failure — open

Q5's final Full Access signal exited `1` while compiling its test target. XCTest received a
`TimeInterval?` where its accuracy overload requires a non-optional value, so zero tests executed.

- Evidence: `qualification-codex.md:81-109` and Q5 fixture commit `3cbf36c…`,
  `submodules/SharedPreferences/Tests/SharedPreferencesTests/AppPreferencesSerializationTests.swift:29`.
- Affected: Q5, D6, executable-signal sufficiency.
- Candidate attribution: not proven. The provider's preliminary P0 label is preserved in its final
  output, but the joined review does not accept it as a candidate P0. The concrete defect is local to
  the qualification fixture/test result.
- Owner: Qualification Owner with the fixture implementation owner. Applicable Organization Policy
  Owners continue to own their separate promotion decisions.
- Disposition: keep Q5 not qualified. No retry or second correction batch is allowed in IIS-0007. A
  future approved qualification plan may correct the fixture and consume a new executable signal.

### `R-IIS0007-001` — P2 reporting attribution — closed in closeout batch

The frozen Codex report proposed Q1 as a candidate P1 and left Q5's provider-reported P0 pending
adjudication. This one reporting-only batch separates candidate findings from qualification/fixture
failures and records the joined dispositions. No row status, candidate payload, code, or signal changed.

## Lane conclusions

- Candidate/provider fidelity: all executed Codex sessions loaded exact RC4 in separate writable
  provider state; Claude stopped before inference; no installed RC1 fallback or provider substitution
  occurred.
- Architecture/Profile: Q1 failed Profile routing despite pattern-neutral output; Q3 met typed IO,
  Boardy/VIP composition, MainActor display-state, humble SwiftUI View, and vendored-source boundaries;
  Q5 selected Core plus applicable enterprise chapters and preserved owned policy escalation.
- Signal/cadence: Q1's second green signal followed executable correction; Q3's final Xcode signal
  executed 5 tests; Q5's materially different Full Access recovery exposed a real compile failure.
  No unchanged green-signal rerun or second review was used.
- Security/authority/YAGNI: Q5 remained historyless and allowlisted; no credential/provider setting,
  custom verifier, CI, kernel, receipt/evidence system, external release action, or authority crossing
  entered the result.

Final counts: proven candidate P0/P1/P2 = `0/0/0`; open qualification/fixture P0/P1/P2 = `0/2/0`;
closed reporting P0/P1/P2 = `0/0/1`; external authentication blockers = `3`.
