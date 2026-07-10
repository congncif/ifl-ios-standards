public struct RuleOverlayBinding: Codable, Hashable, Sendable {
    public let id: RuleID
    public let reviewedComponentID: String
    public let relativePath: String
    public let semanticDigest: HashDigest
    public let beforeFullDigest: HashDigest?
    public let expectedActivatedFullDigest: HashDigest

    public init(
        id: RuleID,
        reviewedComponentID: String,
        relativePath: String,
        semanticDigest: HashDigest,
        beforeFullDigest: HashDigest?,
        expectedActivatedFullDigest: HashDigest
    ) throws {
        let kind = "rule_overlay_binding"
        self.id = try IFLCanonContractSupport.ruleID(id)
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.semanticDigest = try IFLCanonContractSupport.digest(semanticDigest)
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.expectedActivatedFullDigest = try IFLCanonContractSupport.digest(expectedActivatedFullDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case relativePath = "relative_path"
        case semanticDigest = "semantic_digest"
        case beforeFullDigest = "before_full_digest"
        case expectedActivatedFullDigest = "expected_activated_full_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "rule_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(RuleID.self, forKey: .id),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            semanticDigest: container.decode(HashDigest.self, forKey: .semanticDigest),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeFullDigest,
                kind: kind,
                field: "before_full_digest"
            ),
            expectedActivatedFullDigest: container.decode(HashDigest.self, forKey: .expectedActivatedFullDigest)
        )
    }
}

public struct ProfileOverlayBinding: Codable, Hashable, Sendable {
    public let id: ProfileID
    public let reviewedComponentID: String
    public let exactFileDigest: HashDigest
    public let orderedRuleIDs: [RuleID]

    public init(
        id: ProfileID,
        reviewedComponentID: String,
        exactFileDigest: HashDigest,
        orderedRuleIDs: [RuleID]
    ) throws {
        let kind = "profile_overlay_binding"
        self.id = try IFLCanonContractSupport.profileID(id)
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.exactFileDigest = try IFLCanonContractSupport.digest(exactFileDigest)
        try IFLCanonContractSupport.requireNonEmpty(orderedRuleIDs, kind: kind, field: "ordered_rule_ids")
        let validatedRules = try orderedRuleIDs.map(IFLCanonContractSupport.ruleID)
        try IFLCanonContractSupport.requireUnique(validatedRules, kind: "profile_rule", id: { $0.rawValue })
        self.orderedRuleIDs = validatedRules
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case exactFileDigest = "exact_file_digest"
        case orderedRuleIDs = "ordered_rule_ids"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "profile_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(ProfileID.self, forKey: .id),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            exactFileDigest: container.decode(HashDigest.self, forKey: .exactFileDigest),
            orderedRuleIDs: container.decode([RuleID].self, forKey: .orderedRuleIDs)
        )
    }
}

public struct ADROverlayBinding: Codable, Hashable, Sendable {
    public let id: ADRIdentifier
    public let reviewedComponentID: String
    public let relativePath: String
    public let semanticDigest: HashDigest
    public let beforeFullDigest: HashDigest?
    public let expectedActivatedFullDigest: HashDigest

    public init(
        id: ADRIdentifier,
        reviewedComponentID: String,
        relativePath: String,
        semanticDigest: HashDigest,
        beforeFullDigest: HashDigest?,
        expectedActivatedFullDigest: HashDigest
    ) throws {
        let kind = "adr_overlay_binding"
        self.id = try IFLCanonContractSupport.adrID(id)
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.semanticDigest = try IFLCanonContractSupport.digest(semanticDigest)
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.expectedActivatedFullDigest = try IFLCanonContractSupport.digest(expectedActivatedFullDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case relativePath = "relative_path"
        case semanticDigest = "semantic_digest"
        case beforeFullDigest = "before_full_digest"
        case expectedActivatedFullDigest = "expected_activated_full_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "adr_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(ADRIdentifier.self, forKey: .id),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            semanticDigest: container.decode(HashDigest.self, forKey: .semanticDigest),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeFullDigest,
                kind: kind,
                field: "before_full_digest"
            ),
            expectedActivatedFullDigest: container.decode(HashDigest.self, forKey: .expectedActivatedFullDigest)
        )
    }
}

public struct ExactArtifactBinding: Codable, Hashable, Sendable {
    public let id: String
    public let reviewedComponentID: String
    public let relativePath: String
    public let digest: HashDigest

    public init(
        id: String,
        reviewedComponentID: String,
        relativePath: String,
        digest: HashDigest
    ) throws {
        let kind = "exact_artifact_binding"
        self.id = try IFLCanonContractSupport.nonBlank(id, kind: kind, field: "id")
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.digest = try IFLCanonContractSupport.digest(digest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case reviewedComponentID = "reviewed_component_id"
        case relativePath = "relative_path"
        case digest
    }

    public init(from decoder: any Decoder) throws {
        let kind = "exact_artifact_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            digest: container.decode(HashDigest.self, forKey: .digest)
        )
    }
}

public struct RequirementTraceabilityOverlayBinding: Codable, Hashable, Sendable {
    public let requirementID: RequirementID
    public let reviewedComponentID: String
    public let registryRelativePath: String
    public let requirementJSONPointer: String
    public let traceabilityJSONPointer: String
    public let beforeRequirementRecordDigest: HashDigest?
    public let beforeTraceabilityRecordDigest: HashDigest?
    public let candidateRequirementRecordDigest: HashDigest
    public let candidateTraceabilityRecordDigest: HashDigest
    public let expectedActivatedRequirementDigest: HashDigest
    public let expectedActivatedTraceabilityDigest: HashDigest

    public init(
        requirementID: RequirementID,
        reviewedComponentID: String,
        registryRelativePath: String,
        requirementJSONPointer: String,
        traceabilityJSONPointer: String,
        beforeRequirementRecordDigest: HashDigest?,
        beforeTraceabilityRecordDigest: HashDigest?,
        candidateRequirementRecordDigest: HashDigest,
        candidateTraceabilityRecordDigest: HashDigest,
        expectedActivatedRequirementDigest: HashDigest,
        expectedActivatedTraceabilityDigest: HashDigest
    ) throws {
        let kind = "requirement_traceability_overlay_binding"
        self.requirementID = try IFLCanonContractSupport.requirementID(requirementID)
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.registryRelativePath = try IFLCanonContractSupport.exactRelativePath(
            registryRelativePath,
            kind: kind,
            field: "registry_relative_path"
        )
        self.requirementJSONPointer = try ActivationFieldReference.canonicalJSONPointer(
            requirementJSONPointer,
            kind: kind,
            field: "requirement_json_pointer"
        )
        self.traceabilityJSONPointer = try ActivationFieldReference.canonicalJSONPointer(
            traceabilityJSONPointer,
            kind: kind,
            field: "traceability_json_pointer"
        )
        let requirementTokens = ActivationFieldReference.tokens(self.requirementJSONPointer)
        let traceabilityTokens = ActivationFieldReference.tokens(self.traceabilityJSONPointer)
        guard requirementTokens.count == 3,
              requirementTokens[0] == "requirements",
              ActivationFieldReference.isCanonicalArrayIndex(requirementTokens[1]),
              requirementTokens[2] == "status"
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "requirement_json_pointer must be /requirements/<canonical-index>/status"
            )
        }
        guard traceabilityTokens.count == 2,
              traceabilityTokens[0] == "traceability",
              ActivationFieldReference.isCanonicalArrayIndex(traceabilityTokens[1])
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "traceability_json_pointer must be /traceability/<canonical-index>"
            )
        }
        guard requirementTokens[1] == traceabilityTokens[1] else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "requirement and traceability pointers must bind the same canonical record index"
            )
        }
        self.beforeRequirementRecordDigest = try beforeRequirementRecordDigest.map(
            IFLCanonContractSupport.digest
        )
        self.beforeTraceabilityRecordDigest = try beforeTraceabilityRecordDigest.map(
            IFLCanonContractSupport.digest
        )
        self.candidateRequirementRecordDigest = try IFLCanonContractSupport.digest(
            candidateRequirementRecordDigest
        )
        self.candidateTraceabilityRecordDigest = try IFLCanonContractSupport.digest(
            candidateTraceabilityRecordDigest
        )
        self.expectedActivatedRequirementDigest = try IFLCanonContractSupport.digest(
            expectedActivatedRequirementDigest
        )
        self.expectedActivatedTraceabilityDigest = try IFLCanonContractSupport.digest(
            expectedActivatedTraceabilityDigest
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case requirementID = "requirement_id"
        case reviewedComponentID = "reviewed_component_id"
        case registryRelativePath = "registry_relative_path"
        case requirementJSONPointer = "requirement_json_pointer"
        case traceabilityJSONPointer = "traceability_json_pointer"
        case beforeRequirementRecordDigest = "before_requirement_record_digest"
        case beforeTraceabilityRecordDigest = "before_traceability_record_digest"
        case candidateRequirementRecordDigest = "candidate_requirement_record_digest"
        case candidateTraceabilityRecordDigest = "candidate_traceability_record_digest"
        case expectedActivatedRequirementDigest = "expected_activated_requirement_digest"
        case expectedActivatedTraceabilityDigest = "expected_activated_traceability_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "requirement_traceability_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            requirementID: container.decode(RequirementID.self, forKey: .requirementID),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            registryRelativePath: container.decode(String.self, forKey: .registryRelativePath),
            requirementJSONPointer: container.decode(String.self, forKey: .requirementJSONPointer),
            traceabilityJSONPointer: container.decode(String.self, forKey: .traceabilityJSONPointer),
            beforeRequirementRecordDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeRequirementRecordDigest,
                kind: kind,
                field: "before_requirement_record_digest"
            ),
            beforeTraceabilityRecordDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeTraceabilityRecordDigest,
                kind: kind,
                field: "before_traceability_record_digest"
            ),
            candidateRequirementRecordDigest: container.decode(
                HashDigest.self,
                forKey: .candidateRequirementRecordDigest
            ),
            candidateTraceabilityRecordDigest: container.decode(
                HashDigest.self,
                forKey: .candidateTraceabilityRecordDigest
            ),
            expectedActivatedRequirementDigest: container.decode(
                HashDigest.self,
                forKey: .expectedActivatedRequirementDigest
            ),
            expectedActivatedTraceabilityDigest: container.decode(
                HashDigest.self,
                forKey: .expectedActivatedTraceabilityDigest
            )
        )
    }
}

public struct IndexEntryOverlayBinding: Codable, Hashable, Sendable {
    public let id: String
    public let expectedRecordDigest: HashDigest

    public init(id: String, expectedRecordDigest: HashDigest) throws {
        let kind = "index_entry_overlay_binding"
        self.id = try IFLCanonContractSupport.nonBlank(id, kind: kind, field: "id")
        self.expectedRecordDigest = try IFLCanonContractSupport.digest(expectedRecordDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case expectedRecordDigest = "expected_record_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "index_entry_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            expectedRecordDigest: container.decode(HashDigest.self, forKey: .expectedRecordDigest)
        )
    }
}

public struct IndexOverlayBinding: Codable, Hashable, Sendable {
    public let id: String
    public let relativePath: String
    public let beforeFullDigest: HashDigest?
    public let expectedActivatedFullDigest: HashDigest
    public let entries: [IndexEntryOverlayBinding]

    public init(
        id: String,
        relativePath: String,
        beforeFullDigest: HashDigest?,
        expectedActivatedFullDigest: HashDigest,
        entries: [IndexEntryOverlayBinding]
    ) throws {
        let kind = "index_overlay_binding"
        self.id = try IFLCanonContractSupport.canonicalSlug(id, kind: kind, field: "id")
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.beforeFullDigest = try beforeFullDigest.map(IFLCanonContractSupport.digest)
        self.expectedActivatedFullDigest = try IFLCanonContractSupport.digest(expectedActivatedFullDigest)
        try IFLCanonContractSupport.requireNonEmpty(entries, kind: kind, field: "entries")
        try IFLCanonContractSupport.requireUnique(entries, kind: "index_entry", id: { $0.id })
        self.entries = entries.sorted {
            IFLCanonContractSupport.canonicalLess($0.id, $1.id)
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case relativePath = "relative_path"
        case beforeFullDigest = "before_full_digest"
        case expectedActivatedFullDigest = "expected_activated_full_digest"
        case entries
    }

    public init(from decoder: any Decoder) throws {
        let kind = "index_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawEntries = try container.decode([IndexEntryOverlayBinding].self, forKey: .entries)
        try self.init(
            id: container.decode(String.self, forKey: .id),
            relativePath: container.decode(String.self, forKey: .relativePath),
            beforeFullDigest: IFLCanonContractSupport.decodeOptionalRejectingNull(
                HashDigest.self,
                from: container,
                forKey: .beforeFullDigest,
                kind: kind,
                field: "before_full_digest"
            ),
            expectedActivatedFullDigest: container.decode(HashDigest.self, forKey: .expectedActivatedFullDigest),
            entries: rawEntries
        )
        guard rawEntries == entries else {
            throw ContractError.invalidContract(kind: kind, reason: "entries must use canonical order")
        }
    }
}

public struct DerivedTargetBinding: Codable, Hashable, Sendable {
    public let indexKey: String
    public let targetPath: String
    public let expectedFileDigest: HashDigest

    public init(indexKey: String, targetPath: String, expectedFileDigest: HashDigest) throws {
        let kind = "derived_target_binding"
        self.indexKey = try IFLCanonContractSupport.nonBlank(indexKey, kind: kind, field: "index_key")
        self.targetPath = try IFLCanonContractSupport.exactRelativePath(
            targetPath,
            kind: kind,
            field: "target_path"
        )
        self.expectedFileDigest = try IFLCanonContractSupport.digest(expectedFileDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case indexKey = "index_key"
        case targetPath = "target_path"
        case expectedFileDigest = "expected_file_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_target_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            indexKey: container.decode(String.self, forKey: .indexKey),
            targetPath: container.decode(String.self, forKey: .targetPath),
            expectedFileDigest: container.decode(HashDigest.self, forKey: .expectedFileDigest)
        )
    }
}

public struct DerivedRegistrationOverlayBinding: Codable, Hashable, Sendable {
    public let deltaID: String
    public let reviewedComponentID: String
    public let relativePath: String
    public let deltaDigest: HashDigest
    public let targets: [DerivedTargetBinding]

    public init(
        deltaID: String,
        reviewedComponentID: String,
        relativePath: String,
        deltaDigest: HashDigest,
        targets: [DerivedTargetBinding]
    ) throws {
        let kind = "derived_registration_overlay_binding"
        self.deltaID = try IFLCanonContractSupport.canonicalSlug(
            deltaID,
            kind: kind,
            field: "delta_id"
        )
        self.reviewedComponentID = try IFLCanonContractSupport.nonBlank(
            reviewedComponentID,
            kind: kind,
            field: "reviewed_component_id"
        )
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.deltaDigest = try IFLCanonContractSupport.digest(deltaDigest)
        try IFLCanonContractSupport.requireNonEmpty(targets, kind: kind, field: "targets")
        try IFLCanonContractSupport.requireUnique(
            targets,
            kind: "derived_target_index",
            id: { $0.indexKey }
        )
        try IFLCanonContractSupport.requireUnique(
            targets,
            kind: "derived_target_path",
            id: { $0.targetPath }
        )
        self.targets = targets.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.indexKey + "\u{0}" + $0.targetPath,
                $1.indexKey + "\u{0}" + $1.targetPath
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case deltaID = "delta_id"
        case reviewedComponentID = "reviewed_component_id"
        case relativePath = "relative_path"
        case deltaDigest = "delta_digest"
        case targets
    }

    public init(from decoder: any Decoder) throws {
        let kind = "derived_registration_overlay_binding"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTargets = try container.decode([DerivedTargetBinding].self, forKey: .targets)
        try self.init(
            deltaID: container.decode(String.self, forKey: .deltaID),
            reviewedComponentID: container.decode(String.self, forKey: .reviewedComponentID),
            relativePath: container.decode(String.self, forKey: .relativePath),
            deltaDigest: container.decode(HashDigest.self, forKey: .deltaDigest),
            targets: rawTargets
        )
        guard rawTargets == targets else {
            throw ContractError.invalidContract(kind: kind, reason: "targets must use canonical order")
        }
    }
}

public struct ActivationFieldReference: Codable, Hashable, Sendable {
    public let relativePath: String
    public let jsonPointer: String

    public init(relativePath: String, jsonPointer: String) throws {
        let kind = "activation_field_reference"
        self.relativePath = try IFLCanonContractSupport.exactRelativePath(
            relativePath,
            kind: kind,
            field: "relative_path"
        )
        self.jsonPointer = try Self.canonicalJSONPointer(
            jsonPointer,
            kind: kind,
            field: "json_pointer"
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case relativePath = "relative_path"
        case jsonPointer = "json_pointer"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "activation_field_reference"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            relativePath: container.decode(String.self, forKey: .relativePath),
            jsonPointer: container.decode(String.self, forKey: .jsonPointer)
        )
    }

    static func canonicalJSONPointer(
        _ pointer: String,
        kind: String,
        field: String
    ) throws -> String {
        if pointer.isEmpty {
            return pointer
        }
        guard pointer.hasPrefix("/"), pointer.count > 1 else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) must be a canonical absolute JSON pointer"
            )
        }
        let tokens = pointer.dropFirst().split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard tokens.allSatisfy({ token in
            guard !token.isEmpty else { return false }
            var index = token.startIndex
            while index < token.endIndex {
                if token[index] == "~" {
                    let next = token.index(after: index)
                    guard next < token.endIndex,
                          token[next] == "0" || token[next] == "1"
                    else { return false }
                    index = token.index(after: next)
                } else {
                    index = token.index(after: index)
                }
            }
            return true
        }) else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "\(field) contains an empty or non-canonical token"
            )
        }
        return pointer
    }

    static func tokens(_ pointer: String) -> [String] {
        guard !pointer.isEmpty else { return [] }
        return pointer.dropFirst().split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map {
            String($0)
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
        }
    }

    static func isCanonicalArrayIndex(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 })
        else { return false }
        return value == "0" || !value.hasPrefix("0")
    }
}

public struct CandidateOverlayManifest: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let overlayID: String
    public let targetCanonVersion: Int
    public let targetProductVersion: String
    public let baseSnapshotContentDigest: HashDigest
    public let reviewedComponents: [ReviewedComponentApproval]
    public let rules: [RuleOverlayBinding]
    public let profiles: [ProfileOverlayBinding]
    public let adrs: [ADROverlayBinding]
    public let chapters: [ExactArtifactBinding]
    public let requirementTraceability: [RequirementTraceabilityOverlayBinding]
    public let checks: [ExactArtifactBinding]
    public let fixtures: [ExactArtifactBinding]
    public let migrations: [ExactArtifactBinding]
    public let indexes: [IndexOverlayBinding]
    public let derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding]
    public let activationFields: [ActivationFieldReference]
    public let expectedPublishedSnapshotContentDigest: HashDigest

    public init(
        schemaVersion: Int,
        overlayID: String,
        targetCanonVersion: Int,
        targetProductVersion: String,
        baseSnapshotContentDigest: HashDigest,
        reviewedComponents: [ReviewedComponentApproval],
        rules: [RuleOverlayBinding],
        profiles: [ProfileOverlayBinding],
        adrs: [ADROverlayBinding],
        chapters: [ExactArtifactBinding],
        requirementTraceability: [RequirementTraceabilityOverlayBinding],
        checks: [ExactArtifactBinding],
        fixtures: [ExactArtifactBinding],
        migrations: [ExactArtifactBinding],
        indexes: [IndexOverlayBinding],
        derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding],
        activationFields: [ActivationFieldReference],
        expectedPublishedSnapshotContentDigest: HashDigest
    ) throws {
        let kind = "candidate_overlay_manifest"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        guard targetCanonVersion == 1 else {
            throw ContractError.unsupportedSchemaVersion(kind: "target_canon", value: targetCanonVersion)
        }
        try Self.requireCompleteFamilies(
            reviewedComponents: reviewedComponents,
            rules: rules,
            profiles: profiles,
            adrs: adrs,
            chapters: chapters,
            requirementTraceability: requirementTraceability,
            checks: checks,
            fixtures: fixtures,
            migrations: migrations,
            indexes: indexes,
            derivedRegistrationDeltas: derivedRegistrationDeltas,
            activationFields: activationFields
        )
        try IFLCanonContractSupport.requireUnique(
            reviewedComponents,
            kind: "reviewed_component",
            id: { $0.componentID }
        )
        try IFLCanonContractSupport.requireUnique(rules, kind: "rule_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(rules, kind: "rule_overlay_path", id: { $0.relativePath })
        try IFLCanonContractSupport.requireUnique(profiles, kind: "profile_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(adrs, kind: "adr_overlay", id: { $0.id.rawValue })
        try IFLCanonContractSupport.requireUnique(adrs, kind: "adr_overlay_path", id: { $0.relativePath })
        try IFLCanonContractSupport.requireUnique(
            requirementTraceability,
            kind: "requirement_traceability_overlay",
            id: { $0.requirementID.rawValue }
        )
        try IFLCanonContractSupport.requireUnique(indexes, kind: "index_overlay", id: { $0.id })
        try IFLCanonContractSupport.requireUnique(indexes, kind: "index_overlay_path", id: { $0.relativePath })
        try IFLCanonContractSupport.requireUnique(
            derivedRegistrationDeltas,
            kind: "derived_registration_overlay",
            id: { $0.deltaID }
        )
        try IFLCanonContractSupport.requireUnique(
            derivedRegistrationDeltas,
            kind: "derived_registration_overlay_path",
            id: { $0.relativePath }
        )
        try IFLCanonContractSupport.requireUnique(
            activationFields,
            kind: "activation_field",
            id: { $0.relativePath + "\u{0}" + $0.jsonPointer }
        )

        let exactBindings = chapters + checks + fixtures + migrations
        try IFLCanonContractSupport.requireUnique(exactBindings, kind: "exact_artifact", id: { $0.id })
        try IFLCanonContractSupport.requireUnique(
            exactBindings,
            kind: "exact_artifact_path",
            id: { $0.relativePath }
        )
        for check in checks {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                check.id,
                prefix: "CHK-",
                kind: "check_overlay_binding",
                field: "id"
            )
        }
        for fixture in fixtures {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                fixture.id,
                prefix: "FIX-",
                kind: "fixture_overlay_binding",
                field: "id"
            )
        }
        for migration in migrations {
            _ = try IFLCanonContractSupport.canonicalUppercaseIdentifier(
                migration.id,
                prefix: "MIG-",
                kind: "migration_overlay_binding",
                field: "id"
            )
        }
        let nonRegistryPaths = rules.map(\.relativePath)
            + adrs.map(\.relativePath)
            + exactBindings.map(\.relativePath)
            + indexes.map(\.relativePath)
            + derivedRegistrationDeltas.map(\.relativePath)
        try IFLCanonContractSupport.requireUnique(
            nonRegistryPaths,
            kind: "overlay_artifact_path",
            id: { $0 }
        )
        let nonRegistryPathSet = Set(nonRegistryPaths)
        for binding in requirementTraceability
            where nonRegistryPathSet.contains(binding.registryRelativePath)
        {
            throw ContractError.duplicateIdentifier(
                kind: "overlay_artifact_path",
                id: binding.registryRelativePath
            )
        }

        let derivedTargets = derivedRegistrationDeltas.flatMap(\.targets)
        try IFLCanonContractSupport.requireUnique(
            derivedTargets,
            kind: "derived_target_index",
            id: { $0.indexKey }
        )
        try IFLCanonContractSupport.requireUnique(
            derivedTargets,
            kind: "derived_target_path",
            id: { $0.targetPath }
        )
        let governedPaths = nonRegistryPathSet.union(
            requirementTraceability.map(\.registryRelativePath)
        )
        for target in derivedTargets where governedPaths.contains(target.targetPath) {
            throw ContractError.duplicateIdentifier(
                kind: "overlay_artifact_path",
                id: target.targetPath
            )
        }
        for target in derivedTargets {
            let matchingIndexes = indexes.filter { index in
                index.entries.contains { $0.id == target.indexKey }
            }
            guard matchingIndexes.count == 1 else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "derived target index_key must resolve to exactly one index entry: \(target.indexKey)"
                )
            }
        }

        let componentIDs = Set(reviewedComponents.map(\.componentID))
        let componentReferences = rules.map(\.reviewedComponentID)
            + profiles.map(\.reviewedComponentID)
            + adrs.map(\.reviewedComponentID)
            + exactBindings.map(\.reviewedComponentID)
            + requirementTraceability.map(\.reviewedComponentID)
            + derivedRegistrationDeltas.map(\.reviewedComponentID)
        for reference in componentReferences where !componentIDs.contains(reference) {
            throw ContractError.unresolvedReference(kind: "reviewed_component", id: reference)
        }
        for componentID in componentIDs where !componentReferences.contains(componentID) {
            throw ContractError.unresolvedReference(kind: "component_binding", id: componentID)
        }

        let ruleIDs = Set(rules.map(\.id))
        for profile in profiles {
            for ruleID in profile.orderedRuleIDs where !ruleIDs.contains(ruleID) {
                throw ContractError.unresolvedReference(kind: "profile_rule", id: ruleID.rawValue)
            }
        }

        let approvals = reviewedComponents.flatMap {
            [$0.accountableOwnerApproval, $0.independentReviewerApproval]
        }
        try IFLCanonContractSupport.requireUnique(approvals, kind: "approval", id: { $0.approvalID })
        try IFLCanonContractSupport.requireUnique(approvals, kind: "attestation", id: { $0.attestationID })
        try Self.validateActivationJoins(
            fields: activationFields,
            rules: rules,
            adrs: adrs,
            requirements: requirementTraceability,
            indexes: indexes,
            derivedRegistrations: derivedRegistrationDeltas
        )

        self.schemaVersion = schemaVersion
        self.overlayID = try IFLCanonContractSupport.nonBlank(overlayID, kind: kind, field: "overlay_id")
        self.targetCanonVersion = targetCanonVersion
        self.targetProductVersion = try IFLCanonContractSupport.semanticVersion(
            targetProductVersion,
            kind: kind,
            field: "target_product_version"
        )
        self.baseSnapshotContentDigest = try IFLCanonContractSupport.digest(baseSnapshotContentDigest)
        self.reviewedComponents = reviewedComponents.sorted {
            IFLCanonContractSupport.canonicalLess($0.componentID, $1.componentID)
        }
        self.rules = rules.sorted {
            IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue)
        }
        self.profiles = profiles.sorted {
            IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue)
        }
        self.adrs = adrs.sorted {
            IFLCanonContractSupport.canonicalLess($0.id.rawValue, $1.id.rawValue)
        }
        self.chapters = Self.sortedExactBindings(chapters)
        self.requirementTraceability = requirementTraceability.sorted {
            IFLCanonContractSupport.canonicalLess($0.requirementID.rawValue, $1.requirementID.rawValue)
        }
        self.checks = Self.sortedExactBindings(checks)
        self.fixtures = Self.sortedExactBindings(fixtures)
        self.migrations = Self.sortedExactBindings(migrations)
        self.indexes = indexes.sorted {
            IFLCanonContractSupport.canonicalLess($0.id, $1.id)
        }
        self.derivedRegistrationDeltas = derivedRegistrationDeltas.sorted {
            IFLCanonContractSupport.canonicalLess($0.deltaID, $1.deltaID)
        }
        self.activationFields = activationFields.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.relativePath + "\u{0}" + $0.jsonPointer,
                $1.relativePath + "\u{0}" + $1.jsonPointer
            )
        }
        self.expectedPublishedSnapshotContentDigest = try IFLCanonContractSupport.digest(
            expectedPublishedSnapshotContentDigest
        )
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case overlayID = "overlay_id"
        case targetCanonVersion = "target_canon_version"
        case targetProductVersion = "target_product_version"
        case baseSnapshotContentDigest = "base_snapshot_content_digest"
        case reviewedComponents = "reviewed_components"
        case rules
        case profiles
        case adrs
        case chapters
        case requirementTraceability = "requirement_traceability"
        case checks
        case fixtures
        case migrations
        case indexes
        case derivedRegistrationDeltas = "derived_registration_deltas"
        case activationFields = "activation_fields"
        case expectedPublishedSnapshotContentDigest = "expected_published_snapshot_content_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_overlay_manifest"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawReviewed = try container.decode([ReviewedComponentApproval].self, forKey: .reviewedComponents)
        let rawRules = try container.decode([RuleOverlayBinding].self, forKey: .rules)
        let rawProfiles = try container.decode([ProfileOverlayBinding].self, forKey: .profiles)
        let rawADRs = try container.decode([ADROverlayBinding].self, forKey: .adrs)
        let rawChapters = try container.decode([ExactArtifactBinding].self, forKey: .chapters)
        let rawRequirements = try container.decode(
            [RequirementTraceabilityOverlayBinding].self,
            forKey: .requirementTraceability
        )
        let rawChecks = try container.decode([ExactArtifactBinding].self, forKey: .checks)
        let rawFixtures = try container.decode([ExactArtifactBinding].self, forKey: .fixtures)
        let rawMigrations = try container.decode([ExactArtifactBinding].self, forKey: .migrations)
        let rawIndexes = try container.decode([IndexOverlayBinding].self, forKey: .indexes)
        let rawDeltas = try container.decode(
            [DerivedRegistrationOverlayBinding].self,
            forKey: .derivedRegistrationDeltas
        )
        let rawActivationFields = try container.decode(
            [ActivationFieldReference].self,
            forKey: .activationFields
        )
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            overlayID: container.decode(String.self, forKey: .overlayID),
            targetCanonVersion: container.decode(Int.self, forKey: .targetCanonVersion),
            targetProductVersion: container.decode(String.self, forKey: .targetProductVersion),
            baseSnapshotContentDigest: container.decode(HashDigest.self, forKey: .baseSnapshotContentDigest),
            reviewedComponents: rawReviewed,
            rules: rawRules,
            profiles: rawProfiles,
            adrs: rawADRs,
            chapters: rawChapters,
            requirementTraceability: rawRequirements,
            checks: rawChecks,
            fixtures: rawFixtures,
            migrations: rawMigrations,
            indexes: rawIndexes,
            derivedRegistrationDeltas: rawDeltas,
            activationFields: rawActivationFields,
            expectedPublishedSnapshotContentDigest: container.decode(
                HashDigest.self,
                forKey: .expectedPublishedSnapshotContentDigest
            )
        )
        guard rawReviewed == reviewedComponents,
              rawRules == rules,
              rawProfiles == profiles,
              rawADRs == adrs,
              rawChapters == chapters,
              rawRequirements == requirementTraceability,
              rawChecks == checks,
              rawFixtures == fixtures,
              rawMigrations == migrations,
              rawIndexes == indexes,
              rawDeltas == derivedRegistrationDeltas,
              rawActivationFields == activationFields
        else {
            throw ContractError.invalidContract(kind: kind, reason: "binding arrays must use canonical order")
        }
    }

    private static func validateActivationJoins(
        fields: [ActivationFieldReference],
        rules: [RuleOverlayBinding],
        adrs: [ADROverlayBinding],
        requirements: [RequirementTraceabilityOverlayBinding],
        indexes: [IndexOverlayBinding],
        derivedRegistrations: [DerivedRegistrationOverlayBinding]
    ) throws {
        let kind = "candidate_overlay_manifest"
        let canonicalRequirements = requirements.sorted {
            IFLCanonContractSupport.canonicalLess(
                $0.requirementID.rawValue,
                $1.requirementID.rawValue
            )
        }
        for (recordIndex, requirement) in canonicalRequirements.enumerated() {
            let expectedRequirementPointer = "/requirements/\(recordIndex)/status"
            let expectedTraceabilityPointer = "/traceability/\(recordIndex)"
            guard requirement.requirementJSONPointer == expectedRequirementPointer,
                  requirement.traceabilityJSONPointer == expectedTraceabilityPointer
            else {
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "requirement/traceability pointers do not bind canonical index \(recordIndex) for \(requirement.requirementID.rawValue)"
                )
            }
        }

        var coveredBindings: Set<String> = []
        for field in fields {
            var matches: [String] = []
            for rule in rules
                where field.relativePath == rule.relativePath && isRuleActivationPointer(field.jsonPointer)
            {
                matches.append("rule:\(rule.id.rawValue)")
            }
            for adr in adrs
                where field.relativePath == adr.relativePath && isADRActivationPointer(field.jsonPointer)
            {
                matches.append("adr:\(adr.id.rawValue)")
            }
            for requirement in requirements where field.relativePath == requirement.registryRelativePath {
                if field.jsonPointer == requirement.requirementJSONPointer {
                    matches.append("requirement:\(requirement.requirementID.rawValue):record")
                }
                if field.jsonPointer == requirement.traceabilityJSONPointer {
                    matches.append("requirement:\(requirement.requirementID.rawValue):traceability")
                }
            }
            for index in indexes where field.relativePath == index.relativePath {
                if let entryID = indexEntryID(
                    for: field.jsonPointer,
                    entries: index.entries
                ) {
                    matches.append("index:\(index.id):\(entryID)")
                }
            }
            for derived in derivedRegistrations {
                for target in derived.targets
                    where field.relativePath == target.targetPath && field.jsonPointer.isEmpty
                {
                    matches.append("derived:\(derived.deltaID):\(target.indexKey)")
                }
            }
            guard matches.count == 1, let match = matches.first else {
                let reason = matches.isEmpty
                    ? "activation field is orphaned"
                    : "activation field is ambiguous across typed bindings"
                throw ContractError.invalidContract(
                    kind: kind,
                    reason: "\(reason): \(field.relativePath)#\(field.jsonPointer)"
                )
            }
            coveredBindings.insert(match)
        }

        let requiredBindings = Set(
            rules.map { "rule:\($0.id.rawValue)" }
                + adrs.map { "adr:\($0.id.rawValue)" }
                + requirements.flatMap {
                    [
                        "requirement:\($0.requirementID.rawValue):record",
                        "requirement:\($0.requirementID.rawValue):traceability",
                    ]
                }
                + indexes.flatMap { index in
                    index.entries.map { "index:\(index.id):\($0.id)" }
                }
                + derivedRegistrations.flatMap { derived in
                    derived.targets.map { "derived:\(derived.deltaID):\($0.indexKey)" }
                }
        )
        for missing in requiredBindings.subtracting(coveredBindings).sorted(
            by: IFLCanonContractSupport.canonicalLess
        ) {
            throw ContractError.unresolvedReference(kind: "activation_field_binding", id: missing)
        }
    }

    private static func isRuleActivationPointer(_ pointer: String) -> Bool {
        let tokens = ActivationFieldReference.tokens(pointer)
        if tokens.count == 1 {
            return ["lifecycle", "effective_in"].contains(tokens[0])
        }
        return tokens.count == 3
            && tokens[0] == "rules"
            && ActivationFieldReference.isCanonicalArrayIndex(tokens[1])
            && ["lifecycle", "effective_in"].contains(tokens[2])
    }

    private static func isADRActivationPointer(_ pointer: String) -> Bool {
        let tokens = ActivationFieldReference.tokens(pointer)
        if tokens.count == 1 {
            return ["status", "accepted_at"].contains(tokens[0])
        }
        return tokens.count == 3
            && tokens[0] == "adrs"
            && ActivationFieldReference.isCanonicalArrayIndex(tokens[1])
            && ["status", "accepted_at"].contains(tokens[2])
    }

    private static func indexEntryID(
        for pointer: String,
        entries: [IndexEntryOverlayBinding]
    ) -> String? {
        let tokens = ActivationFieldReference.tokens(pointer)
        guard tokens.count == 3,
              tokens[0] == "entries",
              ["record_digest", "file_digest", "digest", "expected_record_digest"].contains(tokens[2])
        else { return nil }
        if ActivationFieldReference.isCanonicalArrayIndex(tokens[1]),
           let index = Int(tokens[1])
        {
            guard entries.indices.contains(index) else { return nil }
            return entries[index].id
        }
        return entries.first { $0.id == tokens[1] }?.id
    }

    private static func requireCompleteFamilies(
        reviewedComponents: [ReviewedComponentApproval],
        rules: [RuleOverlayBinding],
        profiles: [ProfileOverlayBinding],
        adrs: [ADROverlayBinding],
        chapters: [ExactArtifactBinding],
        requirementTraceability: [RequirementTraceabilityOverlayBinding],
        checks: [ExactArtifactBinding],
        fixtures: [ExactArtifactBinding],
        migrations: [ExactArtifactBinding],
        indexes: [IndexOverlayBinding],
        derivedRegistrationDeltas: [DerivedRegistrationOverlayBinding],
        activationFields: [ActivationFieldReference]
    ) throws {
        let kind = "candidate_overlay_manifest"
        try IFLCanonContractSupport.requireNonEmpty(reviewedComponents, kind: kind, field: "reviewed_components")
        try IFLCanonContractSupport.requireNonEmpty(rules, kind: kind, field: "rules")
        try IFLCanonContractSupport.requireNonEmpty(profiles, kind: kind, field: "profiles")
        try IFLCanonContractSupport.requireNonEmpty(adrs, kind: kind, field: "adrs")
        try IFLCanonContractSupport.requireNonEmpty(chapters, kind: kind, field: "chapters")
        try IFLCanonContractSupport.requireNonEmpty(
            requirementTraceability,
            kind: kind,
            field: "requirement_traceability"
        )
        try IFLCanonContractSupport.requireNonEmpty(checks, kind: kind, field: "checks")
        try IFLCanonContractSupport.requireNonEmpty(fixtures, kind: kind, field: "fixtures")
        try IFLCanonContractSupport.requireNonEmpty(migrations, kind: kind, field: "migrations")
        try IFLCanonContractSupport.requireNonEmpty(indexes, kind: kind, field: "indexes")
        try IFLCanonContractSupport.requireNonEmpty(
            derivedRegistrationDeltas,
            kind: kind,
            field: "derived_registration_deltas"
        )
        try IFLCanonContractSupport.requireNonEmpty(activationFields, kind: kind, field: "activation_fields")
    }

    private static func sortedExactBindings(_ values: [ExactArtifactBinding]) -> [ExactArtifactBinding] {
        values.sorted { IFLCanonContractSupport.canonicalLess($0.id, $1.id) }
    }
}
