import Foundation
import IFLContracts

public enum ApprovalValidationResult: String, Codable, CaseIterable, Hashable, Sendable {
    case current
    case stale
    case rejected
}

struct VerifiedApprovalAuthenticatedEvent: Hashable, Sendable {
    let recordDigest: HashDigest
    let authenticatedEventDigest: HashDigest

    private init(recordDigest: HashDigest, authenticatedEventDigest: HashDigest) throws {
        self.recordDigest = try HashDigest(validating: recordDigest.rawValue)
        self.authenticatedEventDigest = try HashDigest(
            validating: authenticatedEventDigest.rawValue
        )
    }

    fileprivate static func sealedForTesting(
        recordDigest: HashDigest,
        authenticatedEventDigest: HashDigest
    ) throws -> Self {
        try Self(
            recordDigest: recordDigest,
            authenticatedEventDigest: authenticatedEventDigest
        )
    }
}

struct VerifiedApprovalTrustPolicy: Hashable, Sendable {
    let trustPolicyDigest: HashDigest

    private init(trustPolicyDigest: HashDigest) throws {
        self.trustPolicyDigest = try HashDigest(validating: trustPolicyDigest.rawValue)
    }

    fileprivate static func sealedForTesting(trustPolicyDigest: HashDigest) throws -> Self {
        try Self(trustPolicyDigest: trustPolicyDigest)
    }
}

struct VerifiedApprovalSignature: Hashable, Sendable {
    let recordDigest: HashDigest
    let authenticatedEventDigest: HashDigest
    let signatureDigest: HashDigest
    let trustPolicyDigest: HashDigest

    private init(
        recordDigest: HashDigest,
        authenticatedEventDigest: HashDigest,
        signatureDigest: HashDigest,
        trustPolicyDigest: HashDigest
    ) throws {
        self.recordDigest = try HashDigest(validating: recordDigest.rawValue)
        self.authenticatedEventDigest = try HashDigest(
            validating: authenticatedEventDigest.rawValue
        )
        self.signatureDigest = try HashDigest(validating: signatureDigest.rawValue)
        self.trustPolicyDigest = try HashDigest(validating: trustPolicyDigest.rawValue)
    }

    fileprivate static func sealedForTesting(
        recordDigest: HashDigest,
        authenticatedEventDigest: HashDigest,
        signatureDigest: HashDigest,
        trustPolicyDigest: HashDigest
    ) throws -> Self {
        try Self(
            recordDigest: recordDigest,
            authenticatedEventDigest: authenticatedEventDigest,
            signatureDigest: signatureDigest,
            trustPolicyDigest: trustPolicyDigest
        )
    }
}

#if DEBUG
struct ApprovalAttestationTestCapabilities {
    let authenticatedEvent: VerifiedApprovalAuthenticatedEvent
    let signature: VerifiedApprovalSignature
    let trustPolicy: VerifiedApprovalTrustPolicy

    static func make(
        recordDigest: HashDigest,
        authenticatedEventDigest: HashDigest,
        signatureDigest: HashDigest,
        trustPolicyDigest: HashDigest
    ) throws -> Self {
        Self(
            authenticatedEvent: try .sealedForTesting(
                recordDigest: recordDigest,
                authenticatedEventDigest: authenticatedEventDigest
            ),
            signature: try .sealedForTesting(
                recordDigest: recordDigest,
                authenticatedEventDigest: authenticatedEventDigest,
                signatureDigest: signatureDigest,
                trustPolicyDigest: trustPolicyDigest
            ),
            trustPolicy: try .sealedForTesting(trustPolicyDigest: trustPolicyDigest)
        )
    }
}
#endif

struct VerifiedApprovalAttestation: Hashable, Sendable {
    let recordDigest: HashDigest
    let attestationReference: String
    let authenticatedEventDigest: HashDigest
    let signatureDigest: HashDigest
    let trustPolicyDigest: HashDigest
    let capabilityDigest: HashDigest
}

enum ApprovalAttestationVerifier {
    static func verify(
        record: ApprovalRecord,
        authenticatedEvent: VerifiedApprovalAuthenticatedEvent,
        signature: VerifiedApprovalSignature,
        trustPolicy: VerifiedApprovalTrustPolicy
    ) throws -> VerifiedApprovalAttestation {
        guard artifactIsNonBlank(record.attestationReference) else {
            throw ArtifactError.invalidAttestation
        }
        let recordDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(record))
        guard authenticatedEvent.recordDigest == recordDigest,
              signature.recordDigest == recordDigest,
              signature.authenticatedEventDigest == authenticatedEvent.authenticatedEventDigest,
              signature.trustPolicyDigest == trustPolicy.trustPolicyDigest
        else { throw ArtifactError.invalidAttestation }
        let capabilityDigest = CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(
                ApprovalAttestationCapabilityInput(
                    recordDigest: recordDigest,
                    attestationReference: record.attestationReference,
                    authenticatedEventDigest: authenticatedEvent.authenticatedEventDigest,
                    signatureDigest: signature.signatureDigest,
                    trustPolicyDigest: trustPolicy.trustPolicyDigest
                )
            )
        )
        return VerifiedApprovalAttestation(
            recordDigest: recordDigest,
            attestationReference: record.attestationReference,
            authenticatedEventDigest: authenticatedEvent.authenticatedEventDigest,
            signatureDigest: signature.signatureDigest,
            trustPolicyDigest: trustPolicy.trustPolicyDigest,
            capabilityDigest: capabilityDigest
        )
    }
}

struct ApprovalValidationContext: Sendable {
    let graph: ArtifactGraph
    let currentGate: WorkflowStage
    let gatePolicy: GatePolicy
    let mode: WorkflowMode
    let policyContext: ActivePolicyContext
    let escalationFlags: Set<AuthorityEscalationFlag>
    let authorityEvidence: AuthorityEvidence
    let attestations: [VerifiedApprovalAttestation]

    init(
        graph: ArtifactGraph,
        currentGate: WorkflowStage,
        gatePolicy: GatePolicy,
        mode: WorkflowMode,
        policyContext: ActivePolicyContext,
        escalationFlags: Set<AuthorityEscalationFlag>,
        authorityEvidence: AuthorityEvidence,
        attestations: [VerifiedApprovalAttestation]
    ) throws {
        guard artifactApprovalGateStages.contains(currentGate) else {
            throw ArtifactError.invalidApprovalContext
        }
        self.graph = graph
        self.currentGate = currentGate
        self.gatePolicy = gatePolicy
        self.mode = mode
        self.policyContext = policyContext
        self.escalationFlags = escalationFlags
        self.authorityEvidence = authorityEvidence
        self.attestations = attestations
    }
}

public enum ApprovalValidator {
    static func validate(
        records: [ApprovalRecord],
        context: ApprovalValidationContext
    ) throws -> ApprovalValidationResult {
        guard !records.isEmpty else { return .rejected }
        let reviewedSet = try VerifiedReviewedArtifactSet.derive(
            graph: context.graph,
            gate: context.currentGate
        )
        let policyBinding = try VerifiedApprovalPolicyBinding.derive(
            gatePolicy: context.gatePolicy,
            gate: context.currentGate,
            mode: context.mode,
            policyContext: context.policyContext,
            escalationFlags: context.escalationFlags,
            author: context.authorityEvidence.author
        )
        guard records.allSatisfy({ record in
            record.gate == context.currentGate &&
                record.authorityPolicyDigest == policyBinding.authorityPolicyDigest &&
                record.policyBindingDigest == policyBinding.bindingDigest &&
                record.reviewedSetDigest == reviewedSet.bindingDigest &&
                record.reviewedArtifacts == reviewedSet.reviewedArtifacts
        }) else { return .stale }

        let requiredRoles = policyBinding.requirement.requiredRoles
        guard records.count == requiredRoles.count,
              Set(records.map(\.role)) == requiredRoles,
              Set(records.map(\.attestationReference)).count == records.count
        else { return .rejected }

        var selectedSnapshots: Set<ApprovalAuthoritySnapshot> = []
        for record in records {
            let exactFacts = try context.authorityEvidence.validators.filter { fact in
                try ApprovalAuthoritySnapshot(authorityFact: fact) == record.authoritySnapshot
            }
            guard exactFacts.count == 1, let exactFact = exactFacts.first else {
                return .stale
            }
            guard exactFact.roles.contains(record.role) else { return .rejected }
            let recordDigest = CanonicalTreeDigest.sha256(try CanonicalJSON.encode(record))
            let matchingAttestations = context.attestations.filter {
                $0.recordDigest == recordDigest &&
                    $0.attestationReference == record.attestationReference
            }
            guard matchingAttestations.count == 1 else { return .rejected }
            selectedSnapshots.insert(record.authoritySnapshot)
        }

        let requalificationValidators = try context.authorityEvidence.validators.compactMap {
            fact -> VerifiedAuthorityFact? in
            let snapshot = try ApprovalAuthoritySnapshot(authorityFact: fact)
            if selectedSnapshots.contains(snapshot) { return fact }
            let remainingRoles = fact.roles.subtracting(requiredRoles)
            guard !remainingRoles.isEmpty else { return nil }
            return VerifiedAuthorityFact(
                actorID: fact.actorID,
                principalID: fact.principalID,
                roles: remainingRoles,
                principalKind: fact.principalKind,
                independentContextDigest: fact.independentContextDigest,
                hasAuthorshipEdge: fact.hasAuthorshipEdge,
                hasSourceWriteCapability: fact.hasSourceWriteCapability
            )
        }
        let decision: ApprovalDecision
        do {
            decision = try AuthorityPolicy(gatePolicy: context.gatePolicy).qualify(
                gateDecision: GatePolicy.aggregate([.approved]),
                stage: context.currentGate,
                mode: context.mode,
                context: context.policyContext,
                escalationFlags: context.escalationFlags,
                evidence: AuthorityEvidence(
                    author: context.authorityEvidence.author,
                    validators: requalificationValidators
                )
            )
        } catch {
            return .rejected
        }
        guard decision.finalVerdict == .approved,
              let approvalKind = decision.approvalKind,
              records.allSatisfy({ $0.kind == approvalKind })
        else { return .rejected }
        return .current
    }

    static func invalidatedApprovals(
        approvals: [ApprovalRecord],
        by invalidation: ValidatedArtifactInvalidation
    ) throws -> [ApprovalRecord] {
        let invalidatedArtifactIDs = Set(
            [invalidation.changedArtifactID] + invalidation.staleArtifactIDs
        )
        let selected = approvals.filter { approval in
            approval.reviewedArtifacts.contains {
                invalidatedArtifactIDs.contains($0.artifactID)
            }
        }
        let keyed = try selected.map { approval in
            (try CanonicalJSON.encode(approval), approval)
        }
        return keyed.sorted { lhs, rhs in
            lhs.0.lexicographicallyPrecedes(rhs.0)
        }.map { $0.1 }
    }
}

private struct ApprovalAttestationCapabilityInput: Codable {
    let schemaVersion = 1
    let recordDigest: HashDigest
    let attestationReference: String
    let authenticatedEventDigest: HashDigest
    let signatureDigest: HashDigest
    let trustPolicyDigest: HashDigest

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case recordDigest = "record_digest"
        case attestationReference = "attestation_reference"
        case authenticatedEventDigest = "authenticated_event_digest"
        case signatureDigest = "signature_digest"
        case trustPolicyDigest = "trust_policy_digest"
    }
}
