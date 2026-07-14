# IIS-0008 Q1 targeted requalification

## Result

- Final row result: **PASSED**.
- Candidate: `1.0.0-rc.4` at `f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.
- Runtime: ChatGPT-bundled `codex-cli 0.144.2`, Full Access from session start.
- Provider state: row-owned `/private/tmp/iis0008-provider-q1`; no writable state shared with Q5.
- Source provenance: clean IIS-0007 source baseline `7871194d…`, exported into a new history.
- Bound baseline: `ca5496128cb1e9143ca977e4431435ce01a3a3e6`.
- Fixture HEAD: `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef`; worktree clean.

## Controlled Profile binding

The new baseline contains identical root `CLAUDE.md` and `AGENTS.md` files selecting only the `core`
Profile, SwiftPM, auto mode, the project-owned `swift test` command, scoped local commit authority,
and no Boardy/release authority. Before provider execution the fixture contained no Package.swift,
Swift source, test source, or Boardy dependency.

The provider loaded exact RC4 and these Standards skills:

- `brain-flow`;
- `brain-design`;
- `brain-architect`;
- `brain-plan`;
- `brain-execute`;
- `brain-testing`.

It did not load or apply `boardy-vip` or any `boardy-*` skill. Reading the Brain stage routers did not
open another requirements/plan gate; the provider consumed outer plan `336a4af…` and left the joined
review to IIS-0008.

## Delivered semantic task

Commit `3cd7fa84c2d00e1bf7ee9942df02eda63d78ecef`
(`feat: add delivery eligibility capability`) adds:

- a pure Swift Domain with typed request/decision values;
- a package-visible concrete policy with stable inactive/unsupported/risk/eligible precedence;
- case-sensitive injected supported regions, including empty-set behavior;
- an Application-owned public use-case seam and composition factory depending inward on Domain;
- focused Domain/Application tests and a concise package-boundary README.

No Boardy source, import, assumption, or reference appears in Package.swift, Sources, Tests, or the
delivered README.

## Executable signal and boundary

- Command: `swift test`, run exactly once after the completed implementation.
- Result: exit `0`; 9 XCTest tests, 0 failures, 0 unexpected failures. The separate Swift Testing
  runner reported 0 tests in 0 suites.
- No intermediate/duplicate build or test, nested review, permission retry, external configuration
  mutation, push, tag, publication, install, release, or history rewrite occurred.

The IIS-0007 Q1 provider/Profile failure did not reproduce when the consuming repository supplied the
Profile binding required by Brain Flow. The joined review closed it as a resolved fixture-binding
failure, not a candidate defect.
