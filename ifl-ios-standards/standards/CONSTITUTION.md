# IFL iOS Standards Constitution

Status: Standards 1.0 candidate

This Constitution records the durable intent of the IFL iOS Standards. It is deliberately small: the
Canon Rule Registry owns current normative obligations, while this document defines why that authority
model and the core architectural boundaries must endure.

## 1. One normative authority

The organization maintains one machine-addressable source for current obligations. Constitutional
intent, decision history, profiles, guidance, Skills, agents, templates, examples, and scaffolds remain
coherent with that source; none becomes a competing rule system.

Rule mapping: `CAN-AUTH-001`, `CAN-AUTH-002`, `CAN-CONSIST-001`, `CAN-DERIVED-001`.

## 2. Decisions evolve without rewriting history

Architectural decisions preserve their original context and consequences. A material change is made
through a superseding decision and an integrated update of every affected canonical surface. Temporary
delivery pressure does not create a permanent waiver or a silent alternate standard.

Rule mapping: `ADR-LIFECYCLE-001`, `CAN-CONSIST-001`.

## 3. Business policy remains independent

Business meaning remains isolated from UI, orchestration frameworks, storage, networking, and vendor
technology. Application behavior depends inward, owns the capability contracts it needs, and receives
outward behavior through adapters that depend toward those contracts. Replaceable technology must not
become the owner of product policy.

Rule mapping: `CORE-DEP-001`, `CORE-DEP-002`, `CORE-DEP-003`.

## 4. Profiles specialize; they do not fork Core

Profiles may select or strengthen applicable Rules for a product context. They cannot create a parallel
definition of a Core obligation. Any new enforceable meaning first enters Canon through the governed Rule
and ADR lifecycle.

Rule mapping: `CAN-AUTH-001`, `CAN-DERIVED-001`, `ADR-LIFECYCLE-001`.

## 5. Amendment governance

A constitutional amendment requires explicit human governance, identifies the Rules and ADRs that carry
its enforceable meaning, and is reviewed together with the complete Standards change. The amendment is
not effective while its canonical mappings contradict or omit that meaning.

Rule mapping: `CAN-AUTH-002`, `CAN-CONSIST-001`, `ADR-LIFECYCLE-001`.

