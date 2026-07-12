# ADR-0001: Standards Authority and Evolution

Status: In Review

Owner: Canon Maintainer

Decision date: 2026-07-13

## Context

Enterprise guidance becomes unsafe when prose, templates, Skills, agents, examples, and tooling can each
define a different obligation. The Standards need durable intent, current machine-addressable Rules,
decision history, scoped profiles, and operational guidance without creating several competing sources
of truth.

## Decision

Use the Constitution for durable intent, the Rule Registry as the sole machine-addressable source of current obligations, ADRs as immutable decision history, Profiles for applicability, and all guidance and agent surfaces as derived consumers that cannot invent Rules.

Every enforceable constitutional clause maps to current Rule IDs. Contradictions among Canon, Profiles,
ADRs, and derived consumers prevent the Standards candidate from being accepted. A material change to an
accepted decision uses a superseding ADR and updates the affected Rules and Profiles as one integration.
Standards 1.0 consistency is assessed once through the final joined AI review of the complete plan.

## Alternatives considered

- Use prose precedence and let readers decide which document wins. Rejected because it hides
  contradictions and cannot provide stable references.
- Duplicate normative statements in every guide and Skill. Rejected because independent copies drift.
- Build a plugin-owned verifier and workflow state engine. Rejected because provider-native operation
  and one final AI review are sufficient for Standards 1.0.

## Consequences

- Every current obligation has a stable Rule ID and an applicable Profile.
- Derived material must cite Canon and cannot silently weaken it.
- Accepted ADR meaning is preserved; change creates an explicit superseding decision.
- The final AI review must treat contradictions and orphan mappings as release-blocking findings.

## Migration

1. Identify enforceable claims in existing guidance and map them to Canon Rule IDs.
2. Replace duplicate normative definitions with concise references to those Rules.
3. Resolve contradictory guidance in the same semantic change that introduces the governing Rule or ADR.
4. Use superseding ADRs and replacement Rule IDs for future material changes; do not edit history into a
   different decision.

