# ifl-ios-standards roadmap

## Status and authority

This roadmap is non-normative planning guidance. Active Canon Rules/Profiles and accepted ADRs remain
the standards authority. A roadmap item creates no requirement, release commitment, implementation
authority, or permission to add tooling.

Standards `1.0.0-rc.4` is an unpublished working candidate for field qualification toward 1.0 GA.
The latest published release remains `v1.0.0-rc.1`.

## Evidence-triggered 1.1 lifecycle domains

The following domains are intentionally deferred from Standards 1.0. They enter a 1.1 requirements
work item only when adopter or qualification evidence shows that the current Core and applicable
enterprise standards cannot govern a material risk consistently.

### Platform, toolchain, and support lifecycle

Potential scope includes supported Swift/Xcode/iOS ranges, upgrade and deprecation windows, platform
compatibility, support ownership, migration sequencing, and rollback posture.

Evidence trigger: a reproducible adopter compatibility failure, material upgrade incident, or field
qualification gap with an accountable owner and a decision that cannot be expressed through current
project bindings or enterprise guidance.

### API and network-contract lifecycle

Potential scope includes schema and endpoint evolution, compatibility windows, consumer/provider
coordination, staged rollout, deprecation, rollback, and contract observability.

Evidence trigger: a real multi-consumer API migration, production contract incident, or qualification
finding demonstrating that current domain/infrastructure boundaries and organization-owned API policy
leave a material lifecycle decision undefined.

### App, background, and platform-event lifecycle

Potential scope includes app/scene transitions, background execution, task expiration and resumption,
push/deep-link entry, platform interruptions, restoration, and lifecycle-specific observability.

Evidence trigger: an adopter flow or incident with reproducible lifecycle behavior, measurable impact,
and a cross-project rule need that cannot be handled by project-specific bindings.

For any domain above, the 1.1 intake must include concrete evidence, affected adopters, severity,
existing-rule analysis, organization policy owners, migration and compatibility impact, and an
accepted ADR when the proposal changes normative architecture or public contracts. Without that
record, keep the topic in discovery rather than adding a speculative chapter.

## Post-1.0 custom-kernel decision boundary

The frozen custom-kernel backlog at `backlog/post-1.0/custom-kernel/` is inactive, non-shipping, and
excluded from the installable plugin payload. Provider-native task/thread, subagent, tool, and
approval capabilities remain the Standards 1.0 operating model.

Reconsider a custom orchestration kernel only when product and adopter evidence demonstrates a
specific capability gap that provider-native orchestration cannot resolve. A proposal must provide:

- reproducible multi-provider or product scenarios and measured failure/cost;
- why simpler provider-native configuration or process guidance is insufficient;
- explicit product value, adopters, owner, maintenance budget, and exit criteria;
- security, privacy, portability, migration, and compatibility analysis;
- alternatives and YAGNI analysis; and
- an accepted ADR before any implementation enters the shipping plugin.

Do not pre-build a workflow runtime, state engine, contract compiler, verifier/lint/smoke suite,
receipt or evidence-digest pipeline, registry, or CI framework in anticipation of that evidence.
Canon data-integrity hashes remain Canon integrity fields and are not justification for workflow
evidence machinery.

## Promotion rule

A roadmap item moves into delivery only through a separately approved requirement and plan with a
named owner, observable Definition of Done, migration posture, and release authority. Field feedback
alone informs the decision; it does not silently expand the 1.0 or GA scope.
