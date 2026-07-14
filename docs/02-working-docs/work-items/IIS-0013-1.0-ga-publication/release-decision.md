# IIS-0013 Standards 1.0 GA release decision

## Decision

On 2026-07-14, the task owner explicitly authorized publishing Standards `1.0.0` and updating the
public marketplace/install references. Administrative procedure and named-role sign-off consolidation
are deferred to post-release documentation and do not block this publication.

This decision accepts the disclosed Q4 Bazel-target and Q6 target-specific coverage residuals. Those
targets remain unproven; the acceptance does not represent an unrun build or test as successful.

## Exact scope

- Qualified content payload: RC7 at `2fc508b8d943fe4ef439bdcbbd86585e398cc513`.
- Qualification closeout: Q1-Q6 6/6, open P0/P1 `0/0`, recorded at IIS-0012.
- GA promotion identity: the `main` commit containing this decision and the `1.0.0` metadata update.
- Version/tag: `1.0.0` / `v1.0.0`.
- Repository/remote: `congncif/ifl-ios-standards`, `origin`.
- Authorized operations: commit the bounded GA metadata; push `main`; create and push immutable tag
  `v1.0.0`; publish a public GitHub Release marked latest; update Claude/Codex marketplace and install
  guidance to `v1.0.0`.
- Not included: local plugin installation/update, adopter rollout, history rewrite, deletion of prior
  tags, or activation of post-1.0 tooling.

## Verification and rollback

The promotion changes release metadata and documentation only. It requires one final consistency
review and mechanical version/ref checks, not another qualification or product build/test run.

If publication must be de-promoted, keep the immutable `v1.0.0` tag, restore public marketplace and
install guidance to last known-good `v1.0.0-rc.1` through a separately recorded operation, and publish
the corrective/de-promotion notice. The task/Release Owner owns that decision until the deferred role
records are consolidated.

## Deferred follow-up

After publication, consolidate the Standards, Canon, Enterprise Adoption, provider Qualification,
policy, Legal where applicable, and DevOps/Release role records into the organization-owned release
register. This administrative follow-up may improve traceability but cannot rewrite the observed
qualification results, accepted residuals, release commit, or immutable tag.
