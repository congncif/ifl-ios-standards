---
name: enterprise-ios
description: >-
  Use when designing, implementing, reviewing, or governing enterprise iOS concerns involving Swift
  concurrency, SwiftUI production, security, privacy, data lifecycle, accessibility, observability,
  testing, performance, resilience, supply chain, or legal ownership.
---

# Enterprise iOS

Load the Core/Boardy standards first, then read only the chapter(s) matching the task. Chapters own
normative detail; this router does not restate or weaken their Rules.

| Concern | Chapter |
|---|---|
| Swift 6 isolation, Sendable, tasks, cancellation, continuations | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/swift-6-concurrency.md` |
| SwiftUI state, lifecycle, identity, navigation, performance, UIKit interop | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/swiftui-production.md` |
| Data classification, storage, encryption, retention, deletion, migration, offline | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/data-lifecycle.md` |
| Threat modeling, auth material, Keychain, trust, input, WebView, secrets, logs | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/mobile-security.md` |
| Inventory, manifests, required-reason APIs, consent, minimization, disclosure | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/privacy-compliance.md` |
| VoiceOver, Dynamic Type, contrast, motion, focus, input, localization, RTL | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/accessibility-global-readiness.md` |
| Events, crashes, metrics, correlation, redaction, buffering, ownership | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/observability-operability.md` |
| Swift Testing/XCTest, async determinism, contracts, snapshots, accessibility, performance | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/modern-testing.md` |
| Startup, frame, memory, energy, network, budgets, offline behavior, retry | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/performance-resilience.md` |
| Pinning, provenance, checksums, inventory, vulnerabilities, integrity, licenses | `${CLAUDE_PLUGIN_ROOT}/standards/enterprise/supply-chain-legal.md` |

## Operating rules

- Apply all chapters whose dependencies intersect the task; security consumes data classification,
  privacy consumes data/security, observability consumes data/security/privacy, and performance
  consumes observability/testing.
- Keep organization-specific thresholds, legal decisions, contacts, approved vendors, retention
  periods, and risk acceptance in consuming-project governance. Never invent them.
- Preserve the humble-View boundary: Presenter/equivalent prepares semantic display values; Views own
  framework rendering and small UX-local state only.
- Use TDD/tests for executable code behavior only. Review standards text through Brain-Flow's one final
  AI consistency review; do not add verifier scripts or CI policy.
- Escalate a missing legal/security/product authority instead of weakening a `must` Rule.
