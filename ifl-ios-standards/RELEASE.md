# Release Candidate Guide

Target: `1.0.0-rc.1`
State: locally accepted release candidate; approved for public distribution under the MIT License

## Acceptance order

The release-candidate order is deliberate:

1. Integrate Plan 08 Tasks 1–5.
2. Run one joined AI consistency review over the complete branch diff and final repository state.
3. Collect the full finding set, decide each disposition, and apply accepted in-scope corrections in one
   batch.
4. After findings are disposed, activate Canon lifecycle/status fields and indexes.
5. Confirm the approved plan's Definition of Done and record the candidate as locally accepted.

Do not activate Canon or declare Definition of Done before step 3. A per-task review, repeated
per-finding review, or unchanged duplicate green run is not a substitute for the joined review. If a
finding materially changes scope or architecture, reopen planning rather than hiding it inside release
cleanup.

## Factual RC checklist

Check an item only from observed repository or review state, not intent. This checklist records the
local candidate state after the joined review, corrective batch, and Canon activation.

- [x] `ifl-ios-standards/VERSION` identifies `1.0.0-rc.1` as the target candidate.
- [x] Tasks 1–5 are integrated and the two provider manifests, marketplace metadata, changelog, and
  user-facing version references agree with the target.
- [x] Canon Rules, Profiles, ADRs, chapter metadata, requirements, and documentation have
  been examined together in one final joined AI review.
- [x] Every joined-review finding has a recorded disposition; every accepted in-scope finding is
  corrected, and any true scope/architecture change has returned to planning.
- [x] Only after finding disposition, Canon lifecycle/status fields and registry indexes are activated
  consistently for the accepted candidate.
- [x] Only after Canon activation, the approved Plan 08 Definition of Done is confirmed against the
  final repository state.
- [x] The final handoff distinguishes local candidate acceptance from any CI, tag, artifact,
  publication, marketplace, or external release action.
- [x] Human Legal/Release authority approved MIT public distribution; repository and packaged LICENSE
  files are present and both provider manifests declare `MIT`.

The approved plan and provider-native task state are sufficient to record these observations. Do not
create a verifier script, receipt/evidence manifest, fingerprint, hash chain, custom gate file, or
provider-independent release state machine for this checklist.

## Versioning and release notes

Use the change classes in `standards/GOVERNANCE.md`. Candidate revisions increment their prerelease
identifier and describe compatibility impact truthfully. Changelog entries identify additions,
behavioral changes, deprecations, removals, and migration impact without claiming tests, approval, or
publication that did not occur.

The `0.18.x` adoption path is documented in `standards/COMPATIBILITY.md`. The release candidate does not
require an adopter to change UI framework, Boardy usage, package manager, or build system merely to
install the new Standards.

## Ownership and out-of-scope operations

Local candidate acceptance covers Standards content and its one joined AI review; it does not by itself
grant Git or external-system authority. For `1.0.0-rc.1`, the Human Legal/Release Owner separately
authorized MIT public distribution, the Git push/tag, local plugin update, and requested E2E. CI
configuration/execution, release automation, artifact building/signing, and rollout remain owned by the
organization's DevOps/Release process and are not implied by that authorization.
