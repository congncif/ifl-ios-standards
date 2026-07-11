import IFLContracts

public enum IssueDispositionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case acceptedCurrentScope = "accepted_current_scope"
    case duplicate
    case rejectedWithEvidence = "rejected_with_evidence"
    case deferredByPolicy = "deferred_by_policy"
    case resolved
}

public enum InitialIssueDispositionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case acceptedCurrentScope = "accepted_current_scope"
    case duplicate
    case rejectedWithEvidence = "rejected_with_evidence"
    case deferredByPolicy = "deferred_by_policy"

    var dispositionKind: IssueDispositionKind {
        switch self {
        case .acceptedCurrentScope: .acceptedCurrentScope
        case .duplicate: .duplicate
        case .rejectedWithEvidence: .rejectedWithEvidence
        case .deferredByPolicy: .deferredByPolicy
        }
    }
}

public enum DispositionEvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case acceptedScope = "accepted_scope"
    case equivalence
    case refutation
    case governingPolicy = "governing_policy"
}

public enum DispositionAuthorityKind: String, Codable, CaseIterable, Hashable, Sendable {
    case kernel
    case human
    case agent
}

/// A claim carried by an evidence envelope. It is data, not proof of authority.
public struct DispositionAuthorityClaim: Codable, Hashable, Sendable {
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let claimedKind: DispositionAuthorityKind
    public let claimedAuthenticated: Bool
    public let authorityPolicyDigest: HashDigest
    public let rationaleDigest: HashDigest
    public let evidenceReferences: [String]

    public init(
        actorID: ActorID,
        principalID: PrincipalID,
        claimedKind: DispositionAuthorityKind,
        claimedAuthenticated: Bool,
        authorityPolicyDigest: HashDigest,
        rationaleDigest: HashDigest,
        evidenceReferences: [String]
    ) throws {
        guard !evidenceReferences.isEmpty,
              evidenceReferences.allSatisfy(WorkflowIdentifier.isValid),
              Set(evidenceReferences).count == evidenceReferences.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.actorID = actorID
        self.principalID = principalID
        self.claimedKind = claimedKind
        self.claimedAuthenticated = claimedAuthenticated
        self.authorityPolicyDigest = authorityPolicyDigest
        self.rationaleDigest = rationaleDigest
        self.evidenceReferences = evidenceReferences
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            actorID: container.decode(ActorID.self, forKey: .actorID),
            principalID: container.decode(PrincipalID.self, forKey: .principalID),
            claimedKind: container.decode(DispositionAuthorityKind.self, forKey: .claimedKind),
            claimedAuthenticated: container.decode(Bool.self, forKey: .claimedAuthenticated),
            authorityPolicyDigest: container.decode(HashDigest.self, forKey: .authorityPolicyDigest),
            rationaleDigest: container.decode(HashDigest.self, forKey: .rationaleDigest),
            evidenceReferences: container.decode([String].self, forKey: .evidenceReferences)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case actorID = "actor_id"
        case principalID = "principal_id"
        case claimedKind = "authority_kind"
        case claimedAuthenticated = "authenticated"
        case authorityPolicyDigest = "authority_policy_digest"
        case rationaleDigest = "rationale_digest"
        case evidenceReferences = "evidence_references"
    }
}

public enum VerifiedDispositionAuthorityKind: String, Hashable, Sendable {
    case kernel
    case human
}

/// An adapter-authenticated fact. External callers can inspect it but cannot mint one.
public struct VerifiedDispositionAuthorityFact: Hashable, Sendable {
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let kind: VerifiedDispositionAuthorityKind
    public let authorityPolicyDigest: HashDigest
    public let rationaleDigest: HashDigest
    public let evidenceReferences: [String]

    init(
        actorID: ActorID,
        principalID: PrincipalID,
        kind: VerifiedDispositionAuthorityKind,
        authorityPolicyDigest: HashDigest,
        rationaleDigest: HashDigest,
        evidenceReferences: [String]
    ) {
        self.actorID = actorID
        self.principalID = principalID
        self.kind = kind
        self.authorityPolicyDigest = authorityPolicyDigest
        self.rationaleDigest = rationaleDigest
        self.evidenceReferences = evidenceReferences
    }
}

public struct DispositionEvidenceEnvelope: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let issueFingerprint: FailureFingerprint
    public let severity: RiskClass
    public let mustFix: Bool
    public let evidenceKind: DispositionEvidenceKind?
    public let remediationAssignmentID: String?
    public let scopeDigest: HashDigest?
    public let canonicalFingerprint: FailureFingerprint?
    public let equivalenceEvidenceReferences: [String]
    public let refutationEvidenceReferences: [String]
    public let governingClauseDigest: HashDigest?
    public let accountableOwner: String?
    public let deferredScope: String?
    public let revisitCondition: String?
    public let humanRiskAcceptance: Bool
    public let disputed: Bool
    public let authority: DispositionAuthorityClaim

    public init(
        issueFingerprint: FailureFingerprint,
        severity: RiskClass,
        mustFix: Bool,
        evidenceKind: DispositionEvidenceKind?,
        remediationAssignmentID: String? = nil,
        scopeDigest: HashDigest? = nil,
        canonicalFingerprint: FailureFingerprint? = nil,
        equivalenceEvidenceReferences: [String] = [],
        refutationEvidenceReferences: [String] = [],
        governingClauseDigest: HashDigest? = nil,
        accountableOwner: String? = nil,
        deferredScope: String? = nil,
        revisitCondition: String? = nil,
        humanRiskAcceptance: Bool,
        disputed: Bool,
        authority: DispositionAuthorityClaim
    ) throws {
        let referenceLists = [equivalenceEvidenceReferences, refutationEvidenceReferences]
        let optionalIdentifiers = [remediationAssignmentID, accountableOwner, deferredScope, revisitCondition]
            .compactMap { $0 }
        guard referenceLists.joined().allSatisfy(WorkflowIdentifier.isValid),
              referenceLists.allSatisfy({ Set($0).count == $0.count }),
              optionalIdentifiers.allSatisfy(WorkflowIdentifier.isValid)
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        schemaVersion = 1
        self.issueFingerprint = issueFingerprint
        self.severity = severity
        self.mustFix = mustFix
        self.evidenceKind = evidenceKind
        self.remediationAssignmentID = remediationAssignmentID
        self.scopeDigest = scopeDigest
        self.canonicalFingerprint = canonicalFingerprint
        self.equivalenceEvidenceReferences = equivalenceEvidenceReferences
        self.refutationEvidenceReferences = refutationEvidenceReferences
        self.governingClauseDigest = governingClauseDigest
        self.accountableOwner = accountableOwner
        self.deferredScope = deferredScope
        self.revisitCondition = revisitCondition
        self.humanRiskAcceptance = humanRiskAcceptance
        self.disputed = disputed
        self.authority = authority
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(
            from: decoder,
            allowed: Set(CodingKeys.allCases.map(\.stringValue))
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let issueWire = try container.decode(String.self, forKey: .issueFingerprint)
        let canonicalWire = try container.decodeIfPresent(String.self, forKey: .canonicalFingerprint)
        try self.init(
            issueFingerprint: FailureFingerprint(validatingWire: issueWire),
            severity: container.decode(RiskClass.self, forKey: .severity),
            mustFix: container.decode(Bool.self, forKey: .mustFix),
            evidenceKind: container.decodeIfPresent(DispositionEvidenceKind.self, forKey: .evidenceKind),
            remediationAssignmentID: container.decodeIfPresent(
                String.self,
                forKey: .remediationAssignmentID
            ),
            scopeDigest: container.decodeIfPresent(HashDigest.self, forKey: .scopeDigest),
            canonicalFingerprint: try canonicalWire.map(FailureFingerprint.init(validatingWire:)),
            equivalenceEvidenceReferences: container.decodeIfPresent(
                [String].self,
                forKey: .equivalenceEvidenceReferences
            ) ?? [],
            refutationEvidenceReferences: container.decodeIfPresent(
                [String].self,
                forKey: .refutationEvidenceReferences
            ) ?? [],
            governingClauseDigest: container.decodeIfPresent(
                HashDigest.self,
                forKey: .governingClauseDigest
            ),
            accountableOwner: container.decodeIfPresent(String.self, forKey: .accountableOwner),
            deferredScope: container.decodeIfPresent(String.self, forKey: .deferredScope),
            revisitCondition: container.decodeIfPresent(String.self, forKey: .revisitCondition),
            humanRiskAcceptance: container.decode(Bool.self, forKey: .humanRiskAcceptance),
            disputed: container.decode(Bool.self, forKey: .disputed),
            authority: container.decode(DispositionAuthorityClaim.self, forKey: .authority)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(issueFingerprint.rawValue, forKey: .issueFingerprint)
        try container.encode(severity, forKey: .severity)
        try container.encode(mustFix, forKey: .mustFix)
        try container.encodeIfPresent(evidenceKind, forKey: .evidenceKind)
        try container.encodeIfPresent(remediationAssignmentID, forKey: .remediationAssignmentID)
        try container.encodeIfPresent(scopeDigest, forKey: .scopeDigest)
        try container.encodeIfPresent(canonicalFingerprint?.rawValue, forKey: .canonicalFingerprint)
        if !equivalenceEvidenceReferences.isEmpty {
            try container.encode(equivalenceEvidenceReferences, forKey: .equivalenceEvidenceReferences)
        }
        if !refutationEvidenceReferences.isEmpty {
            try container.encode(refutationEvidenceReferences, forKey: .refutationEvidenceReferences)
        }
        try container.encodeIfPresent(governingClauseDigest, forKey: .governingClauseDigest)
        try container.encodeIfPresent(accountableOwner, forKey: .accountableOwner)
        try container.encodeIfPresent(deferredScope, forKey: .deferredScope)
        try container.encodeIfPresent(revisitCondition, forKey: .revisitCondition)
        try container.encode(humanRiskAcceptance, forKey: .humanRiskAcceptance)
        try container.encode(disputed, forKey: .disputed)
        try container.encode(authority, forKey: .authority)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case issueFingerprint = "issue_fingerprint"
        case severity
        case mustFix = "must_fix"
        case evidenceKind = "evidence_kind"
        case remediationAssignmentID = "remediation_assignment_id"
        case scopeDigest = "scope_digest"
        case canonicalFingerprint = "canonical_fingerprint"
        case equivalenceEvidenceReferences = "equivalence_evidence_references"
        case refutationEvidenceReferences = "refutation_evidence_references"
        case governingClauseDigest = "governing_clause_digest"
        case accountableOwner = "accountable_owner"
        case deferredScope = "deferred_scope"
        case revisitCondition = "revisit_condition"
        case humanRiskAcceptance = "human_risk_acceptance"
        case disputed
        case authority
    }
}

public struct FrozenDispositionPolicy: Hashable, Sendable {
    public let digest: HashDigest
    public let authorizedPrincipalIDs: [PrincipalID]
    public let mandatorySeverities: [RiskClass]
    public let permitsAuthenticatedHumanRiskAcceptance: Bool

    public init(
        digest: HashDigest,
        authorizedPrincipalIDs: [PrincipalID],
        mandatorySeverities: [RiskClass],
        permitsAuthenticatedHumanRiskAcceptance: Bool
    ) throws {
        guard !authorizedPrincipalIDs.isEmpty,
              Set(authorizedPrincipalIDs).count == authorizedPrincipalIDs.count,
              Set(mandatorySeverities).count == mandatorySeverities.count
        else { throw WorkflowPolicyError.invalidPolicy }
        self.digest = digest
        self.authorizedPrincipalIDs = authorizedPrincipalIDs
        self.mandatorySeverities = mandatorySeverities
        self.permitsAuthenticatedHumanRiskAcceptance = permitsAuthenticatedHumanRiskAcceptance
    }
}

public struct AcceptedCurrentScopeBasis: Hashable, Sendable {
    public let remediationAssignmentID: String
    public let scopeDigest: HashDigest
}

public struct DuplicateDispositionBasis: Hashable, Sendable {
    public let canonicalFingerprint: FailureFingerprint
    public let equivalenceEvidenceReferences: [String]
}

public struct RejectedWithEvidenceBasis: Hashable, Sendable {
    public let evidenceReferences: [String]
}

public struct DeferredByPolicyBasis: Hashable, Sendable {
    public let governingClauseDigest: HashDigest
    public let accountableOwner: String
    public let scope: String
    public let revisitCondition: String
    public let humanRiskAcceptance: Bool
}

public enum DispositionBasis: Hashable, Sendable {
    case acceptedCurrentScope(AcceptedCurrentScopeBasis)
    case duplicate(DuplicateDispositionBasis)
    case rejectedWithEvidence(RejectedWithEvidenceBasis)
    case deferredByPolicy(DeferredByPolicyBasis)
}

public struct IssueDispositionTransition: Hashable, Sendable {
    public let previous: IssueDispositionKind?
    public let current: IssueDispositionKind
    public let basis: DispositionBasis
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let authorityPolicyDigest: HashDigest
    public let rationaleDigest: HashDigest
    public let evidenceReferences: [String]

    private init(
        current: InitialIssueDispositionKind,
        basis: DispositionBasis,
        authority: VerifiedDispositionAuthorityFact
    ) {
        previous = nil
        self.current = current.dispositionKind
        self.basis = basis
        actorID = authority.actorID
        principalID = authority.principalID
        authorityPolicyDigest = authority.authorityPolicyDigest
        rationaleDigest = authority.rationaleDigest
        evidenceReferences = authority.evidenceReferences
    }

    fileprivate static func initial(
        current: InitialIssueDispositionKind,
        basis: DispositionBasis,
        authority: VerifiedDispositionAuthorityFact
    ) -> IssueDispositionTransition {
        IssueDispositionTransition(current: current, basis: basis, authority: authority)
    }
}

public struct IssueDispositionRecord: Hashable, Sendable {
    public let fingerprint: FailureFingerprint
    public let current: IssueDispositionKind
    public let basis: DispositionBasis
    public let history: [IssueDispositionTransition]

    public var entersRemediation: Bool {
        current == .acceptedCurrentScope
    }

    private init(
        fingerprint: FailureFingerprint,
        current: InitialIssueDispositionKind,
        basis: DispositionBasis,
        authority: VerifiedDispositionAuthorityFact
    ) {
        self.fingerprint = fingerprint
        self.current = current.dispositionKind
        self.basis = basis
        history = [.initial(current: current, basis: basis, authority: authority)]
    }

    fileprivate static func initial(
        fingerprint: FailureFingerprint,
        current: InitialIssueDispositionKind,
        basis: DispositionBasis,
        authority: VerifiedDispositionAuthorityFact
    ) -> IssueDispositionRecord {
        IssueDispositionRecord(
            fingerprint: fingerprint,
            current: current,
            basis: basis,
            authority: authority
        )
    }
}

public enum IssueDispositionDecision: Hashable, Sendable {
    case applied(IssueDispositionRecord)
    case waitingForUser(ControlRequest)
}

public struct IssueDispositionPolicy: Sendable {
    public static let initialDispositionKinds = InitialIssueDispositionKind.allCases

    public init() {}

    public func deriveInitial(
        from input: DispositionEvidenceEnvelope,
        verifiedAuthority: VerifiedDispositionAuthorityFact,
        frozenPolicy: FrozenDispositionPolicy
    ) throws -> IssueDispositionDecision {
        try validateAuthorityClaim(
            input.authority,
            verified: verifiedAuthority,
            frozenPolicy: frozenPolicy
        )
        guard !input.disputed else {
            return .waitingForUser(.userInputReceived)
        }
        guard let evidenceKind = input.evidenceKind else {
            return .waitingForUser(.userInputReceived)
        }
        if hasConflictingFacts(input, selected: evidenceKind) {
            return .waitingForUser(.userInputReceived)
        }

        let initial: InitialIssueDispositionKind
        let basis: DispositionBasis
        switch evidenceKind {
        case .acceptedScope:
            guard verifiedAuthority.kind == .kernel,
                  let assignmentID = input.remediationAssignmentID,
                  let scopeDigest = input.scopeDigest
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            initial = .acceptedCurrentScope
            basis = .acceptedCurrentScope(
                AcceptedCurrentScopeBasis(
                    remediationAssignmentID: assignmentID,
                    scopeDigest: scopeDigest
                )
            )
        case .equivalence:
            guard let canonical = input.canonicalFingerprint,
                  canonical != input.issueFingerprint,
                  !input.equivalenceEvidenceReferences.isEmpty,
                  input.equivalenceEvidenceReferences == verifiedAuthority.evidenceReferences
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            initial = .duplicate
            basis = .duplicate(
                DuplicateDispositionBasis(
                    canonicalFingerprint: canonical,
                    equivalenceEvidenceReferences: input.equivalenceEvidenceReferences
                )
            )
        case .refutation:
            guard !input.refutationEvidenceReferences.isEmpty,
                  input.refutationEvidenceReferences == verifiedAuthority.evidenceReferences
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            initial = .rejectedWithEvidence
            basis = .rejectedWithEvidence(
                RejectedWithEvidenceBasis(
                    evidenceReferences: input.refutationEvidenceReferences
                )
            )
        case .governingPolicy:
            guard let clause = input.governingClauseDigest,
                  let scope = input.deferredScope,
                  let revisit = input.revisitCondition,
                  !input.mustFix,
                  !frozenPolicy.mandatorySeverities.contains(input.severity)
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            let requiresRiskAcceptance = input.severity == .high || input.severity == .critical
            if requiresRiskAcceptance {
                guard frozenPolicy.permitsAuthenticatedHumanRiskAcceptance,
                      input.humanRiskAcceptance,
                      verifiedAuthority.kind == .human
                else { throw WorkflowPolicyError.invalidDispositionEvidence }
            } else if input.humanRiskAcceptance && verifiedAuthority.kind != .human {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            guard let owner = input.accountableOwner else {
                return .waitingForUser(.userInputReceived)
            }
            initial = .deferredByPolicy
            basis = .deferredByPolicy(
                DeferredByPolicyBasis(
                    governingClauseDigest: clause,
                    accountableOwner: owner,
                    scope: scope,
                    revisitCondition: revisit,
                    humanRiskAcceptance: input.humanRiskAcceptance
                )
            )
        }

        return .applied(
            .initial(
                fingerprint: input.issueFingerprint,
                current: initial,
                basis: basis,
                authority: verifiedAuthority
            )
        )
    }

    private func validateAuthorityClaim(
        _ claim: DispositionAuthorityClaim,
        verified: VerifiedDispositionAuthorityFact,
        frozenPolicy: FrozenDispositionPolicy
    ) throws {
        let verifiedClaimKind: DispositionAuthorityKind = switch verified.kind {
        case .kernel: .kernel
        case .human: .human
        }
        guard claim.actorID == verified.actorID,
              claim.principalID == verified.principalID,
              claim.claimedKind == verifiedClaimKind,
              claim.authorityPolicyDigest == verified.authorityPolicyDigest,
              claim.rationaleDigest == verified.rationaleDigest,
              claim.evidenceReferences == verified.evidenceReferences,
              verified.authorityPolicyDigest == frozenPolicy.digest,
              frozenPolicy.authorizedPrincipalIDs.contains(verified.principalID),
              !verified.evidenceReferences.isEmpty,
              verified.evidenceReferences.allSatisfy(WorkflowIdentifier.isValid),
              Set(verified.evidenceReferences).count == verified.evidenceReferences.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    private func hasConflictingFacts(
        _ input: DispositionEvidenceEnvelope,
        selected: DispositionEvidenceKind
    ) -> Bool {
        let hasAccepted = input.remediationAssignmentID != nil || input.scopeDigest != nil
        let hasEquivalence = input.canonicalFingerprint != nil ||
            !input.equivalenceEvidenceReferences.isEmpty
        let hasRefutation = !input.refutationEvidenceReferences.isEmpty
        let hasDeferral = input.governingClauseDigest != nil ||
            input.accountableOwner != nil ||
            input.deferredScope != nil ||
            input.revisitCondition != nil ||
            input.humanRiskAcceptance
        let selectedFacts: Bool = switch selected {
        case .acceptedScope: hasAccepted
        case .equivalence: hasEquivalence
        case .refutation: hasRefutation
        case .governingPolicy: hasDeferral
        }
        let factCount = [hasAccepted, hasEquivalence, hasRefutation, hasDeferral]
            .filter { $0 }
            .count
        return factCount > 1 || (factCount == 1 && !selectedFacts)
    }
}
