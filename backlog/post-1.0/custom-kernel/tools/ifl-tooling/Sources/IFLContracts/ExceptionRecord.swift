import Foundation

public struct ExceptionRecord: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let ruleID: RuleID
    public let exactScope: [String]
    public let reason: String
    public let riskClass: RiskClass
    public let compensatingControls: [String]
    public let ownerPrincipalID: String
    public let ownerActorID: String
    public let ownerRoleID: String
    public let approverPrincipalID: String
    public let approverActorID: String
    public let approverRoleID: String
    public let expiresAt: Date
    public let affectedArtifactDigest: HashDigest
    public let removalPlan: String

    public init(
        schemaVersion: Int,
        id: String,
        ruleID: RuleID,
        exactScope: [String],
        reason: String,
        riskClass: RiskClass,
        compensatingControls: [String],
        ownerPrincipalID: String,
        ownerActorID: String,
        ownerRoleID: String,
        approverPrincipalID: String,
        approverActorID: String,
        approverRoleID: String,
        expiresAt: Date,
        affectedArtifactDigest: HashDigest,
        removalPlan: String
    ) throws {
        let kind = "exception_record"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        try IFLCanonContractSupport.requireNonEmpty(exactScope, kind: kind, field: "exact_scope")
        let validatedScope = try exactScope.map {
            try IFLCanonContractSupport.exactRelativePath($0, kind: kind, field: "exact_scope")
        }
        try IFLCanonContractSupport.requireUnique(validatedScope, kind: "exception_scope", id: { $0 })

        try IFLCanonContractSupport.requireNonEmpty(
            compensatingControls,
            kind: kind,
            field: "compensating_controls"
        )
        let validatedControls = try compensatingControls.map {
            try IFLCanonContractSupport.nonBlank($0, kind: kind, field: "compensating_control")
        }
        try IFLCanonContractSupport.requireUnique(
            validatedControls,
            kind: "compensating_control",
            id: { $0 }
        )

        let validatedOwnerPrincipal = try IFLCanonContractSupport.nonBlank(
            ownerPrincipalID,
            kind: kind,
            field: "owner_principal_id"
        )
        let validatedOwnerActor = try IFLCanonContractSupport.nonBlank(
            ownerActorID,
            kind: kind,
            field: "owner_actor_id"
        )
        let validatedApproverPrincipal = try IFLCanonContractSupport.nonBlank(
            approverPrincipalID,
            kind: kind,
            field: "approver_principal_id"
        )
        let validatedApproverActor = try IFLCanonContractSupport.nonBlank(
            approverActorID,
            kind: kind,
            field: "approver_actor_id"
        )
        guard validatedOwnerPrincipal != validatedApproverPrincipal,
              validatedOwnerActor != validatedApproverActor
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "owner and approver must have distinct actors and principals"
            )
        }

        self.schemaVersion = schemaVersion
        self.id = try IFLCanonContractSupport.nonBlank(id, kind: kind, field: "id")
        self.ruleID = try IFLCanonContractSupport.ruleID(ruleID)
        self.exactScope = validatedScope.sorted(by: IFLCanonContractSupport.canonicalLess)
        self.reason = try IFLCanonContractSupport.nonBlank(reason, kind: kind, field: "reason")
        self.riskClass = riskClass
        self.compensatingControls = validatedControls.sorted(by: IFLCanonContractSupport.canonicalLess)
        self.ownerPrincipalID = validatedOwnerPrincipal
        self.ownerActorID = validatedOwnerActor
        self.ownerRoleID = try IFLCanonContractSupport.nonBlank(ownerRoleID, kind: kind, field: "owner_role_id")
        self.approverPrincipalID = validatedApproverPrincipal
        self.approverActorID = validatedApproverActor
        self.approverRoleID = try IFLCanonContractSupport.nonBlank(
            approverRoleID,
            kind: kind,
            field: "approver_role_id"
        )
        self.expiresAt = try IFLCanonContractSupport.canonicalDate(
            expiresAt,
            kind: kind,
            field: "expires_at"
        )
        self.affectedArtifactDigest = try IFLCanonContractSupport.digest(affectedArtifactDigest)
        self.removalPlan = try IFLCanonContractSupport.nonBlank(removalPlan, kind: kind, field: "removal_plan")
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case id
        case ruleID = "rule_id"
        case exactScope = "exact_scope"
        case reason
        case riskClass = "risk_class"
        case compensatingControls = "compensating_controls"
        case ownerPrincipalID = "owner_principal_id"
        case ownerActorID = "owner_actor_id"
        case ownerRoleID = "owner_role_id"
        case approverPrincipalID = "approver_principal_id"
        case approverActorID = "approver_actor_id"
        case approverRoleID = "approver_role_id"
        case expiresAt = "expires_at"
        case affectedArtifactDigest = "affected_artifact_digest"
        case removalPlan = "removal_plan"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "exception_record"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawScope = try container.decode([String].self, forKey: .exactScope)
        let rawControls = try container.decode([String].self, forKey: .compensatingControls)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(String.self, forKey: .id),
            ruleID: container.decode(RuleID.self, forKey: .ruleID),
            exactScope: rawScope,
            reason: container.decode(String.self, forKey: .reason),
            riskClass: container.decode(RiskClass.self, forKey: .riskClass),
            compensatingControls: rawControls,
            ownerPrincipalID: container.decode(String.self, forKey: .ownerPrincipalID),
            ownerActorID: container.decode(String.self, forKey: .ownerActorID),
            ownerRoleID: container.decode(String.self, forKey: .ownerRoleID),
            approverPrincipalID: container.decode(String.self, forKey: .approverPrincipalID),
            approverActorID: container.decode(String.self, forKey: .approverActorID),
            approverRoleID: container.decode(String.self, forKey: .approverRoleID),
            expiresAt: IFLCanonContractSupport.decodeCanonicalDate(
                from: container,
                forKey: .expiresAt,
                kind: kind,
                field: "expires_at"
            ),
            affectedArtifactDigest: container.decode(HashDigest.self, forKey: .affectedArtifactDigest),
            removalPlan: container.decode(String.self, forKey: .removalPlan)
        )
        guard rawScope == exactScope, rawControls == compensatingControls else {
            throw ContractError.invalidContract(kind: kind, reason: "arrays must use canonical order")
        }
    }
}
