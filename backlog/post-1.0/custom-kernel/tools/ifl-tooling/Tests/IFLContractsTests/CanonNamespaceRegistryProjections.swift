extension CanonRegistryFileTests {
    static let namespaceProjections = [
        NamespaceProjection(
            identityKind: "rule",
            id: "WF-BYPASS-ROUTE-001",
            expectedPattern: "WF-BYPASS-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-CAP-EXEC-001",
            expectedPattern: "AGT-CAP-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EVD-CMD-AUTH-001",
            expectedPattern: "EVD-CMD-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-IOS-CONTENT-001",
            expectedPattern: "VER-IOS-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "CAN-CONSIST-SNAPSHOT-001",
            expectedPattern: "CAN-CONSIST-*",
            expectedStewardRoleID: "Canon Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SCF-SAFE-PATH-001",
            expectedPattern: "SCF-SAFE-*",
            expectedStewardRoleID: "Scaffolding Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "WF-FSM-RESUME-001",
            expectedPattern: "WF-FSM-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SEC-TRUST-001",
            expectedPattern: "SEC-*",
            expectedStewardRoleID: "Security/Compliance Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "LEGAL-LICENSE-001",
            expectedPattern: "LEGAL-*",
            expectedStewardRoleID: "Security/Legal Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "SUP-PROVENANCE-001",
            expectedPattern: "SUP-*",
            expectedStewardRoleID: "Security/Legal Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "CAN-AUTH-REGISTRY-001",
            expectedPattern: "CAN-AUTH-*",
            expectedStewardRoleID: "Canon Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "UI-HUMBLE-VIEW-001",
            expectedPattern: "UI-HUMBLE-*",
            expectedStewardRoleID: "iOS Profile Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "ADP-CLAUDE-001",
            expectedPattern: "ADP-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-ROLE-OWNER-001",
            expectedPattern: "AGT-ROLE-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "AGT-SOD-APPROVAL-001",
            expectedPattern: "AGT-SOD-*",
            expectedStewardRoleID: "Runtime/Agent Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EFF-FENCE-001",
            expectedPattern: "EFF-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "EVD-TRUST-SIGNATURE-001",
            expectedPattern: "EVD-TRUST-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-CLI-001",
            expectedPattern: "VER-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "VER-VERSION-MIGRATION-001",
            expectedPattern: "VER-VERSION-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "MIG-LEGACY-001",
            expectedPattern: "MIG-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "rule",
            id: "REL-MANIFEST-001",
            expectedPattern: "REL-*",
            expectedStewardRoleID: "Release Steward"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-CAN-AUTH-001",
            expectedPattern: "CHK-*",
            expectedStewardRoleID: "Verification Owner"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-WF-CONV-BASELINE-001",
            expectedPattern: "CHK-WF-CONV-*",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-FLOW-CONVERGENCE",
            expectedPattern: "CHK-FLOW-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-AGENT-CONVERGENCE",
            expectedPattern: "CHK-AGENT-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-EVIDENCE-CONVERGENCE",
            expectedPattern: "CHK-EVIDENCE-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-RUN-CONVERGENCE",
            expectedPattern: "CHK-RUN-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
        NamespaceProjection(
            identityKind: "check",
            id: "CHK-RELEASE-CONVERGENCE",
            expectedPattern: "CHK-RELEASE-CONVERGENCE",
            expectedStewardRoleID: "Workflow Maintainer"
        ),
    ]
}
