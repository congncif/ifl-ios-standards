# RC4 Codex field-qualification result

## Result

- Candidate: `1.0.0-rc.4`
- Immutable candidate commit: `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`
- Runtime: ChatGPT-bundled `codex-cli 0.144.2`
- Group disposition: **NOT QUALIFIED**
- Row results: Q1 `NOT QUALIFIED`, Q3 `PASSED`, Q5 `NOT QUALIFIED`
- Candidate-attributed findings after the joined review: P0/P1/P2 = `0/0/0` proven
- Open qualification/fixture findings: P0/P1/P2 = `0/2/0`

Every Codex row ran in an independent temporary `HOME` and `CODEX_HOME`, with a row-owned auth
linkage and candidate-only marketplace. The only shared provider input was the read-only extraction of
the exact immutable RC4 commit. Each session loaded plugin version `1.0.0-rc.4`; public/installed RC1
was not used as a fallback.

The initial restricted sessions exposed Git and runtime permission boundaries. Consistent with the
user's Full Access direction, each affected row received at most one materially different recovery
under the already approved IIS-0007 scope. No unchanged permission action was repeated. The results
below distinguish provider/session behavior, fixture implementation findings, and defects causally
attributed to the Standards candidate.

## Q1 — Core-only / SwiftPM / greenfield

- Official result: **NOT QUALIFIED — Core-only Profile routing was violated**.
- Qualification finding: `F-IIS0007-001` (P1 provider/Profile-routing failure; not accepted as a
  candidate defect).
- Fixture baseline: `7871194d07eec6e18eae27b5c30c1f81919755ff`.
- Fixture HEAD: `79b4a38904e41d61fff8a31484bdeeed8ca361a9`; worktree clean.
- Semantic commits:
  - `f5579821402cb81c76acb2cace5d9b58ede3abac` — contain the concrete policy implementation inside
    the package;
  - `79b4a38904e41d61fff8a31484bdeeed8ca361a9` — record the package boundary.
- Engineering result: framework-neutral Domain policy and Application use case, no Boardy import or
  Boardy assumption in the fixture implementation, and no release-authority crossing.
- Executable signals:
  - initial `swift test --disable-sandbox`: exit `0`, 8 tests, 0 failures;
  - smallest affected correction signal `swift test`: exit `0`, 10 tests, 0 failures.
- Review/correction cadence: the first review collected the concrete-policy visibility and edge-case
  findings; one consolidated executable correction batch resolved them. The second signal was
  required because that batch changed executable code. No final-review rerun followed.

`F-IIS0007-001` — The corrective provider session explicitly selected and loaded
`/ifl-ios-standards:boardy-vip` while describing Q1 as Core-only. `RELEASE.md` requires Q1 to complete
without loading Boardy. The produced code remained pattern-neutral, but qualification observes the
agent route as well as the source result; therefore the row cannot pass. The joined review classified
this as a P1 provider/Profile-routing failure but found insufficient causal evidence to attribute it
to the RC4 payload. A future controlled qualification plan may isolate that cause; any proven semantic
candidate fix requires a new candidate plan/revision. No third Q1 session is allowed inside IIS-0007.

## Q3 — Boardy/VIP + SwiftUI / SwiftPM / greenfield

- Official result: **PASSED**.
- Open row findings P0/P1/P2: `0/0/0`.
- Fixture baseline: `674b06bf862c3bcb1f439a27b4f8d2912b3acdd8`, seeded from Boardy commit
  `06f4c0de619b3e745f5727d0b2c29469db89b5cc` with vendored version `1.60.1`.
- Fixture HEAD: `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1`; worktree clean.
- Semantic commits:
  - `ceac87cb5fcc47e729954a7f8c040db7602a0503` — define the local package boundary;
  - `e3921c0545ce5de3684d9d9d17f2ba47aefab0f1` — add the SwiftUI Welcome board.
- Observed behavior: typed public Input/Output, public BoardID and ServiceMap composition, Boardy/VIP
  Interactor/Presenter boundaries, `@MainActor` display-ready presentation state, an intent-only
  SwiftUI View, and focused behavior/composition tests. `Vendor/Boardy` remained unchanged.
- Final executable signal:

  ```sh
  xcodebuild test \
    -scheme BoardyWelcomeFixture-Package \
    -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst,id=00008112-001824621A86401E' \
    -only-testing:WelcomePluginsTests
  ```

  Result: `** TEST SUCCEEDED **`; 5 tests, 0 failures.
- Cadence: an earlier restricted-runtime attempt compiled but could not execute the Catalyst bundle.
  One Full Access recovery selected a valid project-owned Xcode destination; no signal ran after the
  green result and no duplicate review was requested.
- Residual: one pre-existing vendored Boardy `@unchecked Sendable` warning was observed and left
  untouched; it is not a project-owned RC4 qualification finding.

## Q5 — enterprise transition / CocoaPods + SwiftPM hybrid

- Official result: **NOT QUALIFIED — final executable signal failed to compile**.
- Provider-reported preliminary finding: P0 `1`; organization-owned promotion blockers were also
  recorded separately.
- Joined disposition: `F-IIS0007-002`, P1 fixture/execution blocker; candidate P0/P1/P2 = `0/0/0`
  proven for this failure. The provider's preliminary P0 label remains in the record but is not
  accepted as a candidate P0 because causal RC4 evidence is absent.
- Product provenance baseline: `d00e842905a53de17be65c134d40c15d58dfde0b`.
- Sanitized historyless fixture baseline: `5141f1156c4227da4f75847fd00f8e4ab0becc5b`.
- Fixture HEAD: `3cbf36cfd5369fcc2bf95eca3571ab1665d6662f`; worktree clean.
- Semantic commits:
  - `83d3ee3b2fa4121e0558e6f0f85eda1678efe473` — add the local SwiftPM boundary and focused tests;
  - `3cbf36cfd5369fcc2bf95eca3571ab1665d6662f` — record hybrid-distribution conformance.
- Observed behavior: the Core Profile and applicable enterprise chapters were selected; the provider
  added an owned, expiring transition record; `HANDOFF_BLOCKED` preserved organization policy-owner
  decisions; and bounded `SAFE_RESUME` was consumed only for package/tests/docs work.
- Fixture safety: 18 tracked allowlisted files; no source Git history, credentials, `.claude`,
  `.codex`, `.agents`, or unrelated product source. The neutral `Podfile` and exported podspec remain
  byte-identical to the sanitized baseline, at SHA-256 `9611f547…f5bed3` and
  `eba932a9…a0029a` respectively.
- Correction cadence: one consolidated review correction added public-interface serialization tests
  and removed an unsupported license-evidence statement. No re-review followed.
- Final executable signal: `swift test --package-path submodules/SharedPreferences`, exit `1`.
  Tests did not execute because `AppPreferencesSerializationTests.swift:29` passed a
  `TimeInterval?` to a non-optional XCTest accuracy overload.
- Disposition: no retry or second correction batch was used. The row stays not qualified. Human-owned
  deployment/security/privacy/legal/supply-chain decisions remain explicit promotion boundaries, not
  AI-accepted risks and not automatically candidate defects.

## Group boundary

No provider session performed a push, tag, publication, install, marketplace update, persistent
provider configuration change, protected adopter-repository write, CI operation, custom verification
script, receipt/evidence framework, or release action. Q1, Q3, and Q5 are fully dispositioned; the
Codex group remains not qualified because Q1 and Q5 did not pass.
