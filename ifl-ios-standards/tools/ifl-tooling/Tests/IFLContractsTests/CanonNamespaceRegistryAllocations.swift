extension CanonRegistryFileTests {
    static let namespaceAllocations = [
        StrictNamespaceAllocation(
            identityKind: "adr",
            pattern: "ADR-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "accessibility-global-readiness",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "data-lifecycle",
            stewardRoleID: "Data Lifecycle Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "mobile-security",
            stewardRoleID: "Security Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "modern-testing",
            stewardRoleID: "Testing Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "observability-operability",
            stewardRoleID: "Operability Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "performance-resilience",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "privacy-compliance",
            stewardRoleID: "Privacy Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "supply-chain-legal",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "swift-6-concurrency",
            stewardRoleID: "Concurrency Chapter Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "chapter",
            pattern: "swiftui-production",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-AGENT-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-EVIDENCE-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-FLOW-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-RELEASE-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-RUN-CONVERGENCE",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "check",
            pattern: "CHK-WF-CONV-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "enterprise-routing.*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "runtime-agents.*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "scaffolds.*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "derived_artifact",
            pattern: "standards.*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "fixture",
            pattern: "FIX-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "migration",
            pattern: "MIG-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "assurance-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "boardy-vip",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "build-*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "core",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "swiftui",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "profile",
            pattern: "uikit",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "ENT-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P0-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P1-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P2-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "P3-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "requirement",
            pattern: "REQ-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "A11Y-*",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "ADP-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "ADR-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-CAP-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-ROLE-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "AGT-SOD-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "BRD-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-AUTH-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CAN-CONSIST-*",
            stewardRoleID: "Canon Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CONC-*",
            stewardRoleID: "Concurrency Chapter Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "CORE-*",
            stewardRoleID: "Chief Architecture Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "DATA-*",
            stewardRoleID: "Data Lifecycle Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EFF-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EVD-CMD-*",
            stewardRoleID: "Runtime/Agent Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "EVD-TRUST-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "I18N-*",
            stewardRoleID: "Accessibility Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "LEGAL-*",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "MIG-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "MSEC-*",
            stewardRoleID: "Security Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "OBS-*",
            stewardRoleID: "Operability Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "PERF-*",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "PRIV-*",
            stewardRoleID: "Privacy Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "REL-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "RES-*",
            stewardRoleID: "Performance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SCF-SAFE-*",
            stewardRoleID: "Scaffolding Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SEC-*",
            stewardRoleID: "Security/Compliance Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SUP-*",
            stewardRoleID: "Security/Legal Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "SWUI-*",
            stewardRoleID: "SwiftUI Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "TEST-*",
            stewardRoleID: "Testing Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UI-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UI-HUMBLE-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "UIKIT-*",
            stewardRoleID: "iOS Profile Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-IOS-*",
            stewardRoleID: "Verification Owner"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "VER-VERSION-*",
            stewardRoleID: "Release Steward"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "WF-BYPASS-*",
            stewardRoleID: "Workflow Maintainer"
        ),
        StrictNamespaceAllocation(
            identityKind: "rule",
            pattern: "WF-FSM-*",
            stewardRoleID: "Workflow Maintainer"
        ),
    ]
}
