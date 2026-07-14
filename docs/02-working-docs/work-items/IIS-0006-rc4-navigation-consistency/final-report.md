# Final Report — IIS-0006 RC4 navigation consistency

## Outcome

IIS-0006 is engineering-complete. The immutable unpublished `1.0.0-rc.4` candidate corrects the RC3
navigation contradiction and has no open joined-review P0/P1/P2 after one accepted corrective batch.
This is not a publication, field-qualification, GA, install, rollout, or organization risk-acceptance
claim.

## Immutable identities

| Boundary | Commit |
|---|---|
| IIS-0005 RC3 closeout baseline | `7dcc5d8c7023dd7ac3cd8237881f3698b59e9f73` |
| IIS-0006 approved planning baseline | `f91032648e92f8a655b3cda0e243bba4f2c9f701` |
| Task 1 navigation/metadata implementation | `7ecc0c62634d5745770e997537cc2ef2ceeb937e` |
| Task 2 joined review, correction, and immutable RC4 candidate | `f7cd2cf87711f1a757d2fbdec5be9be02ee69173` |

The closeout commit containing this report changes work-item records only; it does not mutate the
candidate payload.

## Delivered result

- Simple back targets the current ViewController through a source-identity round trip.
- Targeted return is owned by the explicit destination coordinator. Plain `Bus<Void>` is limited to
  intentional fan-out or one live destination; concurrent destinations carry and filter a stable
  value-typed destination identity.
- Child boards emit typed output only; Interactors do not infer navigation.
- Full, compact, example, context, bus, composable, and reviewer surfaces use build → watch → connect
  or register → put into context → expose.
- Active metadata identifies unpublished RC4. The published release and public Codex marketplace pin
  remain `v1.0.0-rc.1`.
- Current candidate payload, filenames, and new IIS-0006 output contain no protected adopter identity.
  Legacy historical refs remain outside this candidate and were not rewritten; removing content from
  existing remote history/tags requires separate destructive Git and release authority.

## Joined review

- Frozen range: `f91032648e92f8a655b3cda0e243bba4f2c9f701` exclusive through
  `7ecc0c62634d5745770e997537cc2ef2ceeb937e` inclusive.
- One independent joined review collected `P0/P1/P2 = 0/2/1`.
- All three findings were accepted and applied together: Board-originated target selection,
  protected-brand wording, and compact-guidance synchronization.
- Post-disposition open findings: `P0/P1/P2 = 0/0/0`.
- No routine re-review or duplicate green signal ran.

## Definition of Done

| DoD | Result |
|---|---|
| D1 — Return targets are unambiguous | PASS |
| D2 — Lifecycle is coherent | PASS |
| D3 — Canon and contracts are preserved | PASS |
| D4 — RC4 metadata is truthful | PASS |
| D5 — Content boundary is safe | PASS |
| D6 — Review is conclusive and lean | PASS |
| D7 — History is traceable | PASS on the closeout-only semantic commit containing this report |

## Verification and operating boundary

This was a documentation/metadata plan. Per the approved operating model, completion used author
inspection plus one joined AI consistency review. It did not use TDD, build, test, provider calls,
plugin-owned scripts/verifiers, CI, receipts, fingerprints, or a duplicate review loop.

`.superpowers/` remains unrelated and untracked. Canon/ADR files, Boardy source/distribution, public
IO, historical work items, remote refs, and public marketplace metadata were not changed.

## Qualification and release handoff

Q1-Q6 are `not qualified` for the exact RC4 candidate. RC3 rehearsal observations do not transfer as
RC4 passes. Provider-native qualification may resume only when the tenant/provider policy permits it,
and every row must target
`f7cd2cf87711f1a757d2fbdec5be9be02ee69173`.

No push, merge, tag, GitHub release, marketplace mutation, plugin install/update, rollout, GA
declaration, or destructive history operation is authorized or performed by this closeout.
