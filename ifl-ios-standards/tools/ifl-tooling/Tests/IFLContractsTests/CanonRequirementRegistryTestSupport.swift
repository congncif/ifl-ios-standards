extension CanonRegistryFileTests {
    static let approvedRequirementOwners = [
        "ENT-ACCESSIBILITY": "Accessibility Owner",
        "ENT-CONCURRENCY": "Concurrency Chapter Owner",
        "ENT-DATA": "Data Lifecycle Owner",
        "ENT-OBSERVABILITY": "Operability Owner",
        "ENT-PERFORMANCE": "Performance Owner",
        "ENT-PRIVACY": "Privacy Owner",
        "ENT-SECURITY": "Security Owner",
        "ENT-SUPPLY": "Security/Legal Owner",
        "ENT-SWIFTUI": "SwiftUI Profile Owner",
        "ENT-TESTING": "Testing Owner",
        "P0-1": "Workflow Maintainer",
        "P0-2": "Runtime/Agent Owner",
        "P0-3": "Verification Owner",
        "P0-4": "Canon Maintainer",
        "P0-5": "Scaffolding Owner",
        "P0-6": "Workflow Maintainer",
        "P0-7": "Security/Compliance Owner",
        "REQ-AGENTS": "Runtime/Agent Owner",
        "REQ-BOARDY": "iOS Profile Owner",
        "REQ-CANON": "Canon Maintainer",
        "REQ-CONVERGENCE": "Workflow Maintainer",
        "REQ-EFFECTS": "Workflow Maintainer",
        "REQ-MIGRATION": "Release Steward",
        "REQ-RC": "Release Steward",
        "REQ-RUNTIME": "Runtime/Agent Owner",
        "REQ-VERIFY": "Verification Owner",
    ]

    static let approvedRequirementIDs = approvedRequirementOwners.keys.sorted()

    static let internalConvergenceChecks = [
        "CHK-WF-CONV-BASELINE-001",
        "CHK-WF-CONV-INVENTORY-001",
        "CHK-WF-CONV-REGISTER-001",
        "CHK-WF-CONV-DISPOSITION-001",
        "CHK-WF-CONV-REMEDIATION-001",
        "CHK-WF-CONV-CONFIRMATION-001",
        "CHK-WF-CONV-EXCEPTION-001",
        "CHK-WF-CONV-INVALIDATION-001",
    ]

    static let publicConvergenceChecks = [
        "CHK-FLOW-CONVERGENCE",
        "CHK-AGENT-CONVERGENCE",
        "CHK-EVIDENCE-CONVERGENCE",
        "CHK-RUN-CONVERGENCE",
        "CHK-RELEASE-CONVERGENCE",
    ]

    static let allConvergenceChecks = internalConvergenceChecks + publicConvergenceChecks

    static let forbiddenWorkflowKeys: Set<String> = [
        "approval_record",
        "review_baseline",
        "review_cycle",
        "review_round",
        "run_id",
        "stage_submission",
        "transition_receipt",
        "workflow_state",
    ]
}
