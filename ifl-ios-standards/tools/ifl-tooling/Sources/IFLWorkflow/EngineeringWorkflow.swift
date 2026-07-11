public enum EngineeringWorkflow {
    public static let definition = WorkflowDefinition(
        workType: .engineeringRun,
        stages: [
            .intake, .requirements, .requirementGate, .design, .designGate,
            .architecture, .architectureGate, .plan, .planGate, .executePhase,
            .checkpoint, .review, .finalVerification, .finalGate, .readyForHandoff,
        ],
        transitions: [
            .init(from: .intake, event: .intakeRecorded, to: .requirements),
            .init(from: .requirements, event: .requirementsSubmitted, to: .requirementGate),
            .init(from: .requirementGate, event: .requirementApproved, to: .design),
            .init(from: .design, event: .designSubmitted, to: .designGate),
            .init(from: .designGate, event: .designApproved, to: .architecture),
            .init(from: .architecture, event: .architectureSubmitted, to: .architectureGate),
            .init(from: .architectureGate, event: .architectureApproved, to: .plan),
            .init(from: .plan, event: .planSubmitted, to: .planGate),
            .init(from: .planGate, event: .planApproved, to: .executePhase),
            .init(from: .executePhase, event: .phaseSubmitted, to: .checkpoint),
            .init(from: .checkpoint, event: .checkpointPassed, to: .review),
            .init(from: .review, event: .reviewApproved, to: .finalVerification),
            .init(from: .finalVerification, event: .runChecksPassed, to: .finalGate),
            .init(from: .finalGate, event: .runApproved, to: .readyForHandoff),
            .init(from: .readyForHandoff, event: .closeRun, to: .readyForHandoff),
        ]
    )
}
