<!-- brain-version: 1.0.0 · last-updated: 2026-07-13 -->

# 20. Canon-Linked Review Checklist

This is a derived review aid, not a second source of obligations. Apply only Rules selected by the
project's active Profiles. If this checklist and Canon differ, Canon governs and the inconsistency must
be corrected under `CAN-AUTH-001`, `CAN-CONSIST-001`, and `CAN-DERIVED-001`.

Use the linked Rule statement, scope, level, and exception policy when deciding conformance. The short
prompts below do not strengthen those Rules or make Boardy, UIKit, SwiftUI, a build system, a workflow
tool, or a verification mechanism universally mandatory.

| Review prompt | Canon source |
|---|---|
| Keep Domain independent of UI, orchestration, persistence, networking, and vendor SDKs. | `CORE-DEP-001` |
| Make Application/Business depend inward and consume outward capabilities through inward-owned protocols. | `CORE-DEP-002` |
| Keep UI and Infrastructure as outward adapters to inward-owned contracts. | `CORE-DEP-003` |
| Keep feature implementation APIs internal except for registered composition entries. | `CORE-API-001` |
| Construct and register implementations only at a declared composition root. | `CORE-COMP-001`; with Boardy, `BRD-COMP-001` |
| Keep Views humble: render display-ready state and forward intent without deriving product meaning. | `UI-HUMBLE-001`…`UI-HUMBLE-004` in the selected UI Profile |
| Mutate rendered UI state on its declared MainActor boundary. | `UI-ISOLATION-001` in the selected UI Profile |
| Follow the selected architecture Profile's lifecycle, communication, and dependency Rules. | The project's active Profile records under `standards/canon/profiles/` |
| Use the risk-appropriate testing obligations selected by Core and any specialized Profile. | Applicable `TEST-*` Rules |

Process discipline such as scoped changes, factual reporting, semantic commits, approval authority, and
one final joined AI review is defined by the approved plan and `standards/process/`; it is operational
guidance, not an additional architecture Rule registry.
