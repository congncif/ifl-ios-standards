import Foundation
import IFLContracts

extension FailureFingerprint: Codable {
    public init(from decoder: any Decoder) throws {
        try self.init(validatingWire: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode(rawValue)
    }
}

public struct IssueFingerprint: RawRepresentable, Codable, Comparable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        let validated: String
        do {
            validated = try HashDigest(validating: rawValue).rawValue
        } catch {
            throw WorkflowPolicyError.invalidFingerprintInput
        }
        self.rawValue = validated
    }

    public init?(rawValue: String) {
        guard let value = try? Self(validating: rawValue) else { return nil }
        self = value
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode(rawValue)
    }

    public static func derive(from components: IssueFingerprintComponents) throws -> Self {
        try Self(validating: CanonicalTreeDigest.sha256(
            try CanonicalJSON.encode(components)
        ).rawValue)
    }

    public var failureFingerprint: FailureFingerprint {
        try! FailureFingerprint(validatingWire: rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct FrozenReviewFindingPolicy: Hashable, Sendable {
    public let digest: HashDigest
    public let mustFixIdentities: [ReviewFindingIdentity]

    private init(digest: HashDigest, mustFixIdentities: [ReviewFindingIdentity]) {
        self.digest = digest
        self.mustFixIdentities = mustFixIdentities
    }

    public static func freeze(
        mustFixIdentities: [ReviewFindingIdentity]
    ) throws -> FrozenReviewFindingPolicy {
        let identities = mustFixIdentities.sorted {
            ($0.kind.rawValue, $0.value) < ($1.kind.rawValue, $1.value)
        }
        guard Set(identities).count == identities.count else {
            throw WorkflowPolicyError.invalidPolicy
        }
        let payload = FrozenReviewFindingPolicyPayload(
            schemaVersion: 1,
            mustFixIdentities: identities
        )
        return FrozenReviewFindingPolicy(
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload)),
            mustFixIdentities: identities
        )
    }

    var hasCanonicalDigest: Bool {
        guard let frozen = try? Self.freeze(mustFixIdentities: mustFixIdentities) else {
            return false
        }
        return frozen.digest == digest
    }
}

private struct FrozenReviewFindingPolicyPayload: Codable {
    let schemaVersion: Int
    let mustFixIdentities: [ReviewFindingIdentity]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case mustFixIdentities = "must_fix_identities"
    }
}

public struct IssueDispositionEvidence: Sendable {
    public let fingerprint: FailureFingerprint
    public let envelope: DispositionEvidenceEnvelope
    public let verifiedAuthority: VerifiedDispositionAuthorityFact

    public init(
        fingerprint: FailureFingerprint,
        envelope: DispositionEvidenceEnvelope,
        verifiedAuthority: VerifiedDispositionAuthorityFact
    ) {
        self.fingerprint = fingerprint
        self.envelope = envelope
        self.verifiedAuthority = verifiedAuthority
    }
}

public struct IssueRegisterSource: Codable, Hashable, Sendable {
    public let assignmentID: ReviewAssignmentID
    public let inventoryDigest: HashDigest
    public let findingID: String
    public let findingDigest: HashDigest

    init(
        assignmentID: ReviewAssignmentID,
        inventoryDigest: HashDigest,
        findingID: String,
        findingDigest: HashDigest
    ) throws {
        guard WorkflowIdentifier.isValid(findingID) else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        self.assignmentID = assignmentID
        self.inventoryDigest = inventoryDigest
        self.findingID = findingID
        self.findingDigest = findingDigest
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            assignmentID: values.decode(ReviewAssignmentID.self, forKey: .assignmentID),
            inventoryDigest: values.decode(HashDigest.self, forKey: .inventoryDigest),
            findingID: values.decode(String.self, forKey: .findingID),
            findingDigest: values.decode(HashDigest.self, forKey: .findingDigest)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case assignmentID = "assignment_id"
        case inventoryDigest = "inventory_digest"
        case findingID = "finding_id"
        case findingDigest = "finding_digest"
    }
}

public struct IssueRegisterEntry: Codable, Hashable, Sendable {
    public let fingerprint: IssueFingerprint
    public let severity: RiskClass
    public let mustFix: Bool
    public let identity: ReviewFindingIdentity
    public let sources: [IssueRegisterSource]

    init(
        fingerprint: IssueFingerprint,
        severity: RiskClass,
        mustFix: Bool,
        identity: ReviewFindingIdentity,
        sources: [IssueRegisterSource]
    ) throws {
        let sorted = sources.sorted(by: issueSourceOrder)
        guard !sorted.isEmpty,
              sorted == sources,
              Set(sorted.map { "\($0.assignmentID.rawValue)/\($0.inventoryDigest.rawValue)/\($0.findingID)/\($0.findingDigest.rawValue)" }).count == sorted.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.fingerprint = fingerprint
        self.severity = severity
        self.mustFix = mustFix
        self.identity = identity
        self.sources = sorted
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            fingerprint: values.decode(IssueFingerprint.self, forKey: .fingerprint),
            severity: values.decode(RiskClass.self, forKey: .severity),
            mustFix: values.decode(Bool.self, forKey: .mustFix),
            identity: values.decode(ReviewFindingIdentity.self, forKey: .identity),
            sources: values.decode([IssueRegisterSource].self, forKey: .sources)
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fingerprint
        case severity
        case mustFix = "must_fix"
        case identity
        case sources
    }
}

public struct RegisteredDispositionBasis: Codable, Hashable, Sendable {
    public let kind: IssueDispositionKind
    public let remediationAssignmentID: String?
    public let scopeDigest: HashDigest?
    public let canonicalFingerprint: FailureFingerprint?
    public let evidenceReferences: [String]
    public let governingClauseDigest: HashDigest?
    public let accountableOwner: String?
    public let deferredScope: String?
    public let revisitCondition: String?
    public let humanRiskAcceptance: Bool

    init(_ basis: DispositionBasis) {
        switch basis {
        case .acceptedCurrentScope(let value):
            kind = .acceptedCurrentScope
            remediationAssignmentID = value.remediationAssignmentID
            scopeDigest = value.scopeDigest
            canonicalFingerprint = nil
            evidenceReferences = []
            governingClauseDigest = nil
            accountableOwner = nil
            deferredScope = nil
            revisitCondition = nil
            humanRiskAcceptance = false
        case .duplicate(let value):
            kind = .duplicate
            remediationAssignmentID = nil
            scopeDigest = nil
            canonicalFingerprint = value.canonicalFingerprint
            evidenceReferences = value.equivalenceEvidenceReferences.sorted()
            governingClauseDigest = nil
            accountableOwner = nil
            deferredScope = nil
            revisitCondition = nil
            humanRiskAcceptance = false
        case .rejectedWithEvidence(let value):
            kind = .rejectedWithEvidence
            remediationAssignmentID = nil
            scopeDigest = nil
            canonicalFingerprint = nil
            evidenceReferences = value.evidenceReferences.sorted()
            governingClauseDigest = nil
            accountableOwner = nil
            deferredScope = nil
            revisitCondition = nil
            humanRiskAcceptance = false
        case .deferredByPolicy(let value):
            kind = .deferredByPolicy
            remediationAssignmentID = nil
            scopeDigest = nil
            canonicalFingerprint = nil
            evidenceReferences = []
            governingClauseDigest = value.governingClauseDigest
            accountableOwner = value.accountableOwner
            deferredScope = value.scope
            revisitCondition = value.revisitCondition
            humanRiskAcceptance = value.humanRiskAcceptance
        }
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(IssueDispositionKind.self, forKey: .kind)
        remediationAssignmentID = try values.decodeIfPresent(
            String.self,
            forKey: .remediationAssignmentID
        )
        scopeDigest = try values.decodeIfPresent(HashDigest.self, forKey: .scopeDigest)
        canonicalFingerprint = try values.decodeIfPresent(
            FailureFingerprint.self,
            forKey: .canonicalFingerprint
        )
        evidenceReferences = try values.decode([String].self, forKey: .evidenceReferences)
        governingClauseDigest = try values.decodeIfPresent(
            HashDigest.self,
            forKey: .governingClauseDigest
        )
        accountableOwner = try values.decodeIfPresent(String.self, forKey: .accountableOwner)
        deferredScope = try values.decodeIfPresent(String.self, forKey: .deferredScope)
        revisitCondition = try values.decodeIfPresent(String.self, forKey: .revisitCondition)
        humanRiskAcceptance = try values.decode(Bool.self, forKey: .humanRiskAcceptance)
        guard evidenceReferences == evidenceReferences.sorted(),
              Set(evidenceReferences).count == evidenceReferences.count,
              hasValidShape
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    private var hasValidShape: Bool {
        switch kind {
        case .acceptedCurrentScope:
            remediationAssignmentID != nil && scopeDigest != nil &&
                canonicalFingerprint == nil && evidenceReferences.isEmpty &&
                governingClauseDigest == nil && accountableOwner == nil &&
                deferredScope == nil && revisitCondition == nil && !humanRiskAcceptance
        case .duplicate:
            remediationAssignmentID == nil && scopeDigest == nil &&
                canonicalFingerprint != nil && !evidenceReferences.isEmpty &&
                governingClauseDigest == nil && accountableOwner == nil &&
                deferredScope == nil && revisitCondition == nil && !humanRiskAcceptance
        case .rejectedWithEvidence:
            remediationAssignmentID == nil && scopeDigest == nil &&
                canonicalFingerprint == nil && !evidenceReferences.isEmpty &&
                governingClauseDigest == nil && accountableOwner == nil &&
                deferredScope == nil && revisitCondition == nil && !humanRiskAcceptance
        case .deferredByPolicy:
            remediationAssignmentID == nil && scopeDigest == nil &&
                canonicalFingerprint == nil && evidenceReferences.isEmpty &&
                governingClauseDigest != nil && accountableOwner != nil &&
                deferredScope != nil && revisitCondition != nil
        case .resolved:
            false
        }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case remediationAssignmentID = "remediation_assignment_id"
        case scopeDigest = "scope_digest"
        case canonicalFingerprint = "canonical_fingerprint"
        case evidenceReferences = "evidence_references"
        case governingClauseDigest = "governing_clause_digest"
        case accountableOwner = "accountable_owner"
        case deferredScope = "deferred_scope"
        case revisitCondition = "revisit_condition"
        case humanRiskAcceptance = "human_risk_acceptance"
    }
}

public struct RegisteredDispositionTransition: Codable, Hashable, Sendable {
    public let previous: IssueDispositionKind?
    public let current: IssueDispositionKind
    public let basis: RegisteredDispositionBasis
    public let actorID: ActorID
    public let principalID: PrincipalID
    public let authorityPolicyDigest: HashDigest
    public let rationaleDigest: HashDigest
    public let evidenceReferences: [String]

    init(_ transition: IssueDispositionTransition) {
        previous = transition.previous
        current = transition.current
        basis = RegisteredDispositionBasis(transition.basis)
        actorID = transition.actorID
        principalID = transition.principalID
        authorityPolicyDigest = transition.authorityPolicyDigest
        rationaleDigest = transition.rationaleDigest
        evidenceReferences = transition.evidenceReferences.sorted()
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        previous = try values.decodeIfPresent(IssueDispositionKind.self, forKey: .previous)
        current = try values.decode(IssueDispositionKind.self, forKey: .current)
        basis = try values.decode(RegisteredDispositionBasis.self, forKey: .basis)
        actorID = try values.decode(ActorID.self, forKey: .actorID)
        principalID = try values.decode(PrincipalID.self, forKey: .principalID)
        authorityPolicyDigest = try values.decode(HashDigest.self, forKey: .authorityPolicyDigest)
        rationaleDigest = try values.decode(HashDigest.self, forKey: .rationaleDigest)
        evidenceReferences = try values.decode([String].self, forKey: .evidenceReferences)
        guard current == basis.kind,
              evidenceReferences == evidenceReferences.sorted(),
              Set(evidenceReferences).count == evidenceReferences.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case previous
        case current
        case basis
        case actorID = "actor_id"
        case principalID = "principal_id"
        case authorityPolicyDigest = "authority_policy_digest"
        case rationaleDigest = "rationale_digest"
        case evidenceReferences = "evidence_references"
    }
}

public struct RegisteredIssueDisposition: Codable, Hashable, Sendable {
    public let fingerprint: FailureFingerprint
    public let current: IssueDispositionKind
    public let basis: RegisteredDispositionBasis
    public let history: [RegisteredDispositionTransition]

    public var entersRemediation: Bool { current == .acceptedCurrentScope }

    init(_ record: IssueDispositionRecord) {
        fingerprint = record.fingerprint
        current = record.current
        basis = RegisteredDispositionBasis(record.basis)
        history = record.history.map(RegisteredDispositionTransition.init)
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fingerprint = try values.decode(FailureFingerprint.self, forKey: .fingerprint)
        current = try values.decode(IssueDispositionKind.self, forKey: .current)
        basis = try values.decode(RegisteredDispositionBasis.self, forKey: .basis)
        history = try values.decode([RegisteredDispositionTransition].self, forKey: .history)
        guard current != .resolved,
              basis.kind == current,
              history.count == 1,
              history[0].previous == nil,
              history[0].current == current,
              history[0].basis == basis
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fingerprint
        case current
        case basis
        case history
    }
}

public enum IssueRegisterPathDecision: String, Codable, Hashable, Sendable {
    case directConvergenceNoAcceptedCurrentScope = "direct_convergence_no_accepted_current_scope"
    case requiresRemediation = "requires_remediation"
}

public struct IssueRegister: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let baselineDigest: HashDigest
    public let roundID: ReviewRoundID
    public let rosterDigest: HashDigest
    public let inventoryDigests: [HashDigest]
    public let findingPolicyDigest: HashDigest
    public let dispositionPolicyDigest: HashDigest
    public let entries: [IssueRegisterEntry]
    public let dispositions: [RegisteredIssueDisposition]
    public let acceptedCurrentScopeAssignments: [FailureFingerprint]
    public let pathDecision: IssueRegisterPathDecision
    public let digest: HashDigest

    private init(payload: IssueRegisterPayload, digest: HashDigest) {
        schemaVersion = payload.schemaVersion
        baselineDigest = payload.baselineDigest
        roundID = payload.roundID
        rosterDigest = payload.rosterDigest
        inventoryDigests = payload.inventoryDigests
        findingPolicyDigest = payload.findingPolicyDigest
        dispositionPolicyDigest = payload.dispositionPolicyDigest
        entries = payload.entries
        dispositions = payload.dispositions
        acceptedCurrentScopeAssignments = payload.acceptedCurrentScopeAssignments
        pathDecision = payload.pathDecision
        self.digest = digest
    }

    public static func issue(
        baseline: ReviewBaseline,
        inventories: VerifiedCompleteInventorySet,
        policies: VerifiedReviewPolicySet,
        dispositionEvidence: [VerifiedReviewDispositionEvidence]
    ) throws -> IssueRegister {
        let sortedInventories = inventories.inventories.sorted { $0.assignmentID < $1.assignmentID }
        let requiredAssignments = baseline.roster.assignments.map(\.id)
        guard inventories.baselineDigest == baseline.digest,
              inventories.roundID == baseline.roundID,
              inventories.rosterDigest == baseline.rosterDigest,
              inventories.authorities.count == requiredAssignments.count,
              policies.baselineDigest == baseline.digest,
              policies.runID == baseline.runID,
              policies.findingPolicy.hasCanonicalDigest,
              policies.dispositionPolicy.hasCanonicalDigest,
              sortedInventories.count == requiredAssignments.count,
              sortedInventories.map(\.assignmentID) == requiredAssignments,
              Set(sortedInventories.map(\.digest)).count == sortedInventories.count,
              sortedInventories.allSatisfy({
                  $0.baselineDigest == baseline.digest &&
                      $0.roundID == baseline.roundID &&
                      $0.rosterDigest == baseline.rosterDigest &&
                      $0.complete
              })
        else { throw WorkflowPolicyError.invalidDispositionEvidence }

        struct FindingSource {
            let finding: ReviewerFinding
            let inventory: ReviewerFindingInventory
            let fingerprint: IssueFingerprint
        }
        var grouped: [IssueFingerprint: [FindingSource]] = [:]
        for inventory in sortedInventories {
            for finding in inventory.findings {
                guard baseline.artifactScopes.contains(where: {
                    $0.id == finding.components.artifactID &&
                        $0.scope == finding.components.scopeSelector
                }) else { throw WorkflowPolicyError.invalidDispositionEvidence }
                let fingerprint = try IssueFingerprint.derive(from: finding.components)
                grouped[fingerprint, default: []].append(
                    FindingSource(finding: finding, inventory: inventory, fingerprint: fingerprint)
                )
            }
        }
        let entries = try grouped.keys.sorted().map { fingerprint in
            let sources = grouped[fingerprint] ?? []
            guard let first = sources.first else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            let identities = Set(sources.map { $0.finding.components.identity })
            guard identities.count == 1 else {
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
            let severity = sources.map { $0.finding.severity }.max {
                $0.reviewRank < $1.reviewRank
            } ?? .low
            let mustFix = sources.contains(where: { $0.finding.mustFixClaim }) ||
                policies.findingPolicy.mustFixIdentities.contains(first.finding.components.identity)
            let registerSources = try sources.map { source in
                try IssueRegisterSource(
                    assignmentID: source.inventory.assignmentID,
                    inventoryDigest: source.inventory.digest,
                    findingID: source.finding.findingID,
                    findingDigest: CanonicalTreeDigest.sha256(
                        try CanonicalJSON.encode(source.finding)
                    )
                )
            }.sorted {
                ($0.assignmentID.rawValue, $0.findingID, $0.findingDigest.rawValue) <
                    ($1.assignmentID.rawValue, $1.findingID, $1.findingDigest.rawValue)
            }
            return try IssueRegisterEntry(
                fingerprint: fingerprint,
                severity: severity,
                mustFix: mustFix,
                identity: first.finding.components.identity,
                sources: registerSources
            )
        }

        guard dispositionEvidence.count == entries.count,
              Set(dispositionEvidence.map(\.fingerprint)).count == dispositionEvidence.count
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        let evidenceByFingerprint = Dictionary(
            uniqueKeysWithValues: dispositionEvidence.map { ($0.fingerprint, $0) }
        )
        let policy = IssueDispositionPolicy()
        let dispositions = try entries.map { entry -> RegisteredIssueDisposition in
            guard let evidence = evidenceByFingerprint[entry.fingerprint.failureFingerprint],
                  evidence.baselineDigest == baseline.digest,
                  evidence.evidence.envelope.issueFingerprint == evidence.fingerprint,
                  evidence.evidence.envelope.severity == entry.severity,
                  evidence.evidence.envelope.mustFix == entry.mustFix
            else { throw WorkflowPolicyError.invalidDispositionEvidence }
            switch try policy.deriveInitial(
                from: evidence.evidence.envelope,
                verifiedAuthority: evidence.verifiedAuthority,
                frozenPolicy: policies.dispositionPolicy
            ) {
            case .applied(let record):
                return RegisteredIssueDisposition(record)
            case .waitingForUser:
                throw WorkflowPolicyError.invalidDispositionEvidence
            }
        }
        try validateDuplicateGraph(entries: entries, dispositions: dispositions)
        let accepted = dispositions.filter(\.entersRemediation).map(\.fingerprint).sorted {
            $0.rawValue < $1.rawValue
        }
        let decision: IssueRegisterPathDecision
        switch ReviewConvergencePolicy().selectInitialPath(
            ReviewDispositionSummary(
                initialJoinCompleted: true,
                acceptedCurrentScopeCount: accepted.count,
                hasResolvedTransitions: false,
                hasAmbiguity: false
            )
        ) {
        case .directConvergenceNoAcceptedCurrentScope:
            decision = .directConvergenceNoAcceptedCurrentScope
        case .requiresRemediation:
            decision = .requiresRemediation
        case .requiresNormalConfirmation, .exception, .escalation:
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let payload = IssueRegisterPayload(
            schemaVersion: 1,
            baselineDigest: baseline.digest,
            roundID: baseline.roundID,
            rosterDigest: baseline.rosterDigest,
            inventoryDigests: sortedInventories.map(\.digest).sorted { $0.rawValue < $1.rawValue },
            findingPolicyDigest: policies.findingPolicy.digest,
            dispositionPolicyDigest: policies.dispositionPolicy.digest,
            entries: entries,
            dispositions: dispositions,
            acceptedCurrentScopeAssignments: accepted,
            pathDecision: decision
        )
        return IssueRegister(
            payload: payload,
            digest: CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        )
    }

    public init(from decoder: any Decoder) throws {
        try rejectUnknownFields(from: decoder, allowed: Set(CodingKeys.allCases.map(\.rawValue)))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .schemaVersion) == 1 else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        let payload = try IssueRegisterPayload(
            schemaVersion: 1,
            baselineDigest: values.decode(HashDigest.self, forKey: .baselineDigest),
            roundID: values.decode(ReviewRoundID.self, forKey: .roundID),
            rosterDigest: values.decode(HashDigest.self, forKey: .rosterDigest),
            inventoryDigests: values.decode([HashDigest].self, forKey: .inventoryDigests),
            findingPolicyDigest: values.decode(HashDigest.self, forKey: .findingPolicyDigest),
            dispositionPolicyDigest: values.decode(HashDigest.self, forKey: .dispositionPolicyDigest),
            entries: values.decode([IssueRegisterEntry].self, forKey: .entries),
            dispositions: values.decode([RegisteredIssueDisposition].self, forKey: .dispositions),
            acceptedCurrentScopeAssignments: values.decode(
                [FailureFingerprint].self,
                forKey: .acceptedCurrentScopeAssignments
            ),
            pathDecision: values.decode(IssueRegisterPathDecision.self, forKey: .pathDecision)
        )
        let decodedDigest = try values.decode(HashDigest.self, forKey: .digest)
        let entryFingerprints = payload.entries.map { $0.fingerprint.failureFingerprint }
        let dispositionFingerprints = payload.dispositions.map(\.fingerprint)
        let accepted = payload.dispositions.filter(\.entersRemediation).map(\.fingerprint).sorted {
            $0.rawValue < $1.rawValue
        }
        let expectedPath: IssueRegisterPathDecision = accepted.isEmpty
            ? .directConvergenceNoAcceptedCurrentScope
            : .requiresRemediation
        guard payload.inventoryDigests == payload.inventoryDigests.sorted(by: {
            $0.rawValue < $1.rawValue
        }),
            Set(payload.inventoryDigests).count == payload.inventoryDigests.count,
            payload.entries.map(\.fingerprint) == payload.entries.map(\.fingerprint).sorted(),
            entryFingerprints == dispositionFingerprints,
            Set(entryFingerprints).count == entryFingerprints.count,
            payload.acceptedCurrentScopeAssignments == accepted,
            payload.pathDecision == expectedPath,
            decodedDigest == CanonicalTreeDigest.sha256(try CanonicalJSON.encode(payload))
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        try validateDuplicateGraph(entries: payload.entries, dispositions: payload.dispositions)
        self.init(payload: payload, digest: decodedDigest)
    }

    public static func decodeCanonical(from bytes: Data) throws -> IssueRegister {
        try artifactDecodeCanonical(Self.self, from: bytes)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case inventoryDigests = "inventory_digests"
        case findingPolicyDigest = "finding_policy_digest"
        case dispositionPolicyDigest = "disposition_policy_digest"
        case entries
        case dispositions
        case acceptedCurrentScopeAssignments = "accepted_current_scope_assignments"
        case pathDecision = "path_decision"
        case digest = "register_digest"
    }
}

/// A contextually replayed register plus the authenticated fingerprint components needed later.
public struct VerifiedIssueRegister: Sendable {
    public let register: IssueRegister
    public let baseline: ReviewBaseline
    public let inventories: VerifiedCompleteInventorySet
    public let policies: VerifiedReviewPolicySet
    let componentsByFingerprint: [FailureFingerprint: IssueFingerprintComponents]

    init(
        register: IssueRegister,
        baseline: ReviewBaseline,
        inventories: VerifiedCompleteInventorySet,
        policies: VerifiedReviewPolicySet
    ) throws {
        var components: [FailureFingerprint: IssueFingerprintComponents] = [:]
        for inventory in inventories.inventories {
            for finding in inventory.findings {
                let fingerprint = try IssueFingerprint.derive(from: finding.components)
                    .failureFingerprint
                if let existing = components[fingerprint], existing != finding.components {
                    throw WorkflowPolicyError.invalidDispositionEvidence
                }
                components[fingerprint] = finding.components
            }
        }
        guard register.baselineDigest == baseline.digest,
              register.roundID == baseline.roundID,
              register.rosterDigest == baseline.rosterDigest,
              register.inventoryDigests == inventories.inventories.map(\.digest).sorted(by: {
                  $0.rawValue < $1.rawValue
              }),
              register.findingPolicyDigest == policies.findingPolicy.digest,
              register.dispositionPolicyDigest == policies.dispositionPolicy.digest,
              Set(register.entries.map { $0.fingerprint.failureFingerprint }) ==
                Set(components.keys)
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
        self.register = register
        self.baseline = baseline
        self.inventories = inventories
        self.policies = policies
        componentsByFingerprint = components
    }

    func components(for fingerprint: FailureFingerprint) throws -> IssueFingerprintComponents {
        guard let value = componentsByFingerprint[fingerprint] else {
            throw WorkflowPolicyError.invalidDispositionEvidence
        }
        return value
    }
}

/// Non-serializable authority proving one frozen review round joined completely and terminally.
struct VerifiedReviewRoundClosureFact: Hashable, Sendable {
    let runID: RunID
    let cycleID: ReviewCycleID
    let gate: ReviewGateKind
    let roundID: ReviewRoundID
    let roundKind: ReviewRoundKind
    let semanticOrdinal: UInt64
    let roundAnchorEventHead: HashDigest
    let predecessorBaselineDigest: HashDigest?
    let baselineDigest: HashDigest
    let rosterDigest: HashDigest
    let inventoryDigests: [HashDigest]
    let registerDigest: HashDigest
    let pathDecision: IssueRegisterPathDecision
    let currentArtifactSetDigest: HashDigest
    let currentEventHead: HashDigest
    let activeProfileDigest: HashDigest
    let riskPolicyDigest: HashDigest
    let assurancePolicyDigest: HashDigest
    let convergencePolicyDigest: HashDigest
    let redactionPolicy: RedactionPolicyBinding
    let findingPolicyDigest: HashDigest
    let dispositionPolicyDigest: HashDigest

    fileprivate init(
        register: VerifiedIssueRegister,
        currentness: VerifiedReviewScopeCurrentness
    ) {
        let baseline = register.baseline
        let wire = register.register
        runID = baseline.runID
        cycleID = baseline.cycleID
        gate = baseline.gate
        roundID = baseline.roundID
        roundKind = baseline.kind
        semanticOrdinal = baseline.semanticOrdinal
        roundAnchorEventHead = baseline.preCreationEventHead
        predecessorBaselineDigest = baseline.predecessorBaselineDigest
        baselineDigest = baseline.digest
        rosterDigest = baseline.rosterDigest
        inventoryDigests = wire.inventoryDigests
        registerDigest = wire.digest
        pathDecision = wire.pathDecision
        currentArtifactSetDigest = currentness.currentArtifactSetDigest
        currentEventHead = currentness.currentEventHead
        activeProfileDigest = baseline.activeProfileDigest
        riskPolicyDigest = baseline.riskPolicyDigest
        assurancePolicyDigest = baseline.assurancePolicyDigest
        convergencePolicyDigest = baseline.convergencePolicyDigest
        redactionPolicy = baseline.redactionPolicy
        findingPolicyDigest = register.policies.findingPolicy.digest
        dispositionPolicyDigest = register.policies.dispositionPolicy.digest
    }
}

enum ReviewRoundClosureVerifier {
    static func verify(
        register: VerifiedIssueRegister,
        currentness: VerifiedReviewScopeCurrentness
    ) throws -> VerifiedReviewRoundClosureFact {
        let baseline = register.baseline
        let wire = register.register
        let inventories = register.inventories
        let policies = register.policies
        let requiredAssignments = baseline.roster.assignments.map(\.id)
        let orderedInventories = inventories.inventories.sorted {
            $0.assignmentID < $1.assignmentID
        }
        let inventoryDigests = orderedInventories.map(\.digest).sorted {
            $0.rawValue < $1.rawValue
        }

        guard !requiredAssignments.isEmpty,
              orderedInventories.count == requiredAssignments.count,
              orderedInventories.map(\.assignmentID) == requiredAssignments,
              inventories.authorities.count == requiredAssignments.count,
              inventories.baselineDigest == baseline.digest,
              inventories.roundID == baseline.roundID,
              inventories.rosterDigest == baseline.rosterDigest,
              inventories.currentArtifactSetDigest == currentness.currentArtifactSetDigest,
              inventories.currentEventHead == currentness.currentEventHead,
              orderedInventories.allSatisfy({
                  $0.complete &&
                      $0.baselineDigest == baseline.digest &&
                      $0.roundID == baseline.roundID &&
                      $0.rosterDigest == baseline.rosterDigest
              }),
              wire.baselineDigest == baseline.digest,
              wire.roundID == baseline.roundID,
              wire.rosterDigest == baseline.rosterDigest,
              wire.inventoryDigests == inventoryDigests,
              policies.baselineDigest == baseline.digest,
              policies.runID == baseline.runID,
              policies.gate == baseline.gate,
              policies.assurancePolicyDigest == baseline.assurancePolicyDigest,
              wire.findingPolicyDigest == policies.findingPolicy.digest,
              wire.dispositionPolicyDigest == policies.dispositionPolicy.digest,
              currentness.runID == baseline.runID,
              currentness.baselineDigest == baseline.digest,
              currentness.currentArtifacts == baseline.artifactScopes,
              Set(wire.entries.map { $0.fingerprint.failureFingerprint }) ==
                Set(wire.dispositions.map(\.fingerprint))
        else { throw WorkflowPolicyError.invalidPolicy }

        switch wire.pathDecision {
        case .directConvergenceNoAcceptedCurrentScope:
            guard wire.acceptedCurrentScopeAssignments.isEmpty else {
                throw WorkflowPolicyError.invalidPolicy
            }
        case .requiresRemediation:
            guard !wire.acceptedCurrentScopeAssignments.isEmpty else {
                throw WorkflowPolicyError.invalidPolicy
            }
        }

        return VerifiedReviewRoundClosureFact(
            register: register,
            currentness: currentness
        )
    }
}

private struct IssueRegisterPayload: Codable {
    let schemaVersion: Int
    let baselineDigest: HashDigest
    let roundID: ReviewRoundID
    let rosterDigest: HashDigest
    let inventoryDigests: [HashDigest]
    let findingPolicyDigest: HashDigest
    let dispositionPolicyDigest: HashDigest
    let entries: [IssueRegisterEntry]
    let dispositions: [RegisteredIssueDisposition]
    let acceptedCurrentScopeAssignments: [FailureFingerprint]
    let pathDecision: IssueRegisterPathDecision

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case baselineDigest = "baseline_digest"
        case roundID = "round_id"
        case rosterDigest = "roster_digest"
        case inventoryDigests = "inventory_digests"
        case findingPolicyDigest = "finding_policy_digest"
        case dispositionPolicyDigest = "disposition_policy_digest"
        case entries
        case dispositions
        case acceptedCurrentScopeAssignments = "accepted_current_scope_assignments"
        case pathDecision = "path_decision"
    }
}

private extension RiskClass {
    var reviewRank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }
}

private func issueSourceOrder(_ lhs: IssueRegisterSource, _ rhs: IssueRegisterSource) -> Bool {
    (lhs.assignmentID.rawValue, lhs.findingID, lhs.findingDigest.rawValue) <
        (rhs.assignmentID.rawValue, rhs.findingID, rhs.findingDigest.rawValue)
}

private func validateDuplicateGraph(
    entries: [IssueRegisterEntry],
    dispositions: [RegisteredIssueDisposition]
) throws {
    let entryFingerprints = Set(entries.map { $0.fingerprint.failureFingerprint })
    let byFingerprint = Dictionary(uniqueKeysWithValues: dispositions.map { ($0.fingerprint, $0) })
    guard byFingerprint.count == dispositions.count else {
        throw WorkflowPolicyError.invalidDispositionEvidence
    }
    for disposition in dispositions where disposition.current == .duplicate {
        guard let target = disposition.basis.canonicalFingerprint,
              target != disposition.fingerprint,
              entryFingerprints.contains(target),
              let targetDisposition = byFingerprint[target],
              targetDisposition.current != .duplicate
        else { throw WorkflowPolicyError.invalidDispositionEvidence }
    }
}
