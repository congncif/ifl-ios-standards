import IFLContracts

struct ReferenceGraph {
    let rulesByID: [RuleID: RuleRecord]
    let profilesByID: [ProfileID: ProfileRecord]
    let adrsByID: [ADRIdentifier: ADRMetadata]
    let chaptersByID: [String: ChapterMetadata]
    let requirementsByID: [RequirementID: RequirementRecord]
    let selectedProfileIDs: Set<ProfileID>

    private let adrMarkdownByID: [ADRIdentifier: String]
    private let checkIDs: Set<String>
    private let fixtureIDs: Set<String>
    private let ownersByRuleID: [RuleID: Set<String>]
    private let profileIDsByRuleID: [RuleID: Set<ProfileID>]
    private let ruleIDsByProfileID: [ProfileID: Set<RuleID>]
    private let semanticProjectionsBySource: [SemanticSourceKey: SemanticProjection]
    private let traceabilityByRequirementID: [RequirementID: TraceabilityRecord]

    init(_ snapshot: CanonSnapshot) {
        let rules = Self.index(snapshot.rules, by: \RuleRecord.id)
        let profiles = Self.index(snapshot.profiles, by: \ProfileRecord.id)
        let adrs = Self.index(snapshot.adrs, by: \ADRMetadata.id)
        let chapters = Self.index(snapshot.chapters, by: \ChapterMetadata.id)
        let requirements = Self.index(
            snapshot.requirementRegistry.requirements,
            by: \RequirementRecord.id
        )
        rulesByID = rules
        profilesByID = profiles
        adrsByID = adrs
        chaptersByID = chapters
        requirementsByID = requirements
        selectedProfileIDs = Set(snapshot.selectedProfileIDs)
        adrMarkdownByID = snapshot.adrMarkdownByID
        profileIDsByRuleID = Dictionary(
            uniqueKeysWithValues: snapshot.rules.map { ($0.id, Set($0.profileIDs)) }
        )
        ruleIDsByProfileID = Dictionary(
            uniqueKeysWithValues: snapshot.profiles.map { ($0.id, Set($0.ruleIDs)) }
        )

        var declaredCheckIDs = Set<String>()
        var declaredFixtureIDs = Set<String>()
        var collectedOwners: [RuleID: Set<String>] = [:]
        var traceabilityIndex: [RequirementID: TraceabilityRecord] = [:]
        for traceability in snapshot.requirementRegistry.traceability {
            traceabilityIndex[traceability.requirementID] = traceability
            declaredCheckIDs.formUnion(traceability.allCheckIDs)
            for mapping in traceability.fixtureMappings {
                declaredFixtureIDs.formUnion(mapping.positiveFixtureIDs)
                declaredFixtureIDs.formUnion(mapping.negativeFixtureIDs)
            }
            for binding in traceability.ruleBindings {
                collectedOwners[binding.ruleID, default: []].insert(binding.ownerRoleID)
            }
        }
        checkIDs = declaredCheckIDs
        fixtureIDs = declaredFixtureIDs
        ownersByRuleID = collectedOwners
        traceabilityByRequirementID = traceabilityIndex

        var projections: [SemanticSourceKey: SemanticProjection] = [:]
        for binding in snapshot.derivedArtifacts.flatMap(\.sourceSemanticBindings) {
            let key = SemanticSourceKey(binding)
            guard projections[key] == nil else { continue }
            projections[key] = Self.project(
                key,
                rulesByID: rules,
                profilesByID: profiles,
                adrsByID: adrs,
                adrMarkdownByID: snapshot.adrMarkdownByID,
                requirementsByID: requirements,
                chaptersByID: chapters
            )
        }
        semanticProjectionsBySource = projections
    }

    func containsCheck(_ id: String) -> Bool {
        checkIDs.contains(id)
    }

    func containsFixture(_ id: String) -> Bool {
        fixtureIDs.contains(id)
    }

    func hasOwnerBinding(for ruleID: RuleID) -> Bool {
        ownersByRuleID[ruleID]?.isEmpty == false
    }

    func rule(_ ruleID: RuleID, declares profileID: ProfileID) -> Bool {
        profileIDsByRuleID[ruleID]?.contains(profileID) == true
    }

    func profile(_ profileID: ProfileID, declares ruleID: RuleID) -> Bool {
        ruleIDsByProfileID[profileID]?.contains(ruleID) == true
    }

    func inheritedProfileIDs(for profileID: ProfileID) -> [ProfileID] {
        profilesByID[profileID]?.inheritsProfileIDs ?? []
    }

    func supersededADRIDs(for adrID: ADRIdentifier) -> [ADRIdentifier] {
        adrsByID[adrID]?.supersedesADRIDs ?? []
    }

    func chapterCheckIDs(for requirementID: RequirementID) -> Set<String> {
        Set(traceabilityByRequirementID[requirementID]?.allCheckIDs ?? [])
    }

    func chapterPositiveFixtureIDs(
        for requirementID: RequirementID,
        checkIDs: [String]
    ) -> Set<String> {
        let selectedCheckIDs = Set(checkIDs)
        return Set(
            traceabilityByRequirementID[requirementID]?
                .fixtureMappings
                .filter { selectedCheckIDs.contains($0.checkID) }
                .flatMap(\.positiveFixtureIDs) ?? []
        )
    }

    func chapterNegativeFixtureIDs(
        for requirementID: RequirementID,
        checkIDs: [String]
    ) -> Set<String> {
        let selectedCheckIDs = Set(checkIDs)
        return Set(
            traceabilityByRequirementID[requirementID]?
                .fixtureMappings
                .filter { selectedCheckIDs.contains($0.checkID) }
                .flatMap(\.negativeFixtureIDs) ?? []
        )
    }

    func decisionProjection(for adrID: ADRIdentifier) -> DecisionProjection {
        guard let markdown = adrMarkdownByID[adrID] else {
            return .missingMarkdown
        }
        do {
            let decision = try ADRSemanticDigest.decision(in: markdown)
            return .decision(decision)
        } catch {
            return .unavailable
        }
    }

    func semanticProjection(for binding: SourceSemanticBinding) -> SemanticProjection {
        semanticProjectionsBySource[SemanticSourceKey(binding)] ?? .unavailable
    }

    private static func project(
        _ source: SemanticSourceKey,
        rulesByID: [RuleID: RuleRecord],
        profilesByID: [ProfileID: ProfileRecord],
        adrsByID: [ADRIdentifier: ADRMetadata],
        adrMarkdownByID: [ADRIdentifier: String],
        requirementsByID: [RequirementID: RequirementRecord],
        chaptersByID: [String: ChapterMetadata]
    ) -> SemanticProjection {
        do {
            switch source.kind {
            case "rule":
                guard let rule = rulesByID[RuleID(rawValue: source.id)] else {
                    return .missingSource
                }
                return try .digest(RuleSemanticDigest.digest(rule))
            case "profile":
                guard let profile = profilesByID[ProfileID(rawValue: source.id)] else {
                    return .missingSource
                }
                return try .digest(ProfileSemanticDigest.digest(profile))
            case "adr":
                let id = ADRIdentifier(rawValue: source.id)
                guard let adr = adrsByID[id] else {
                    return .missingSource
                }
                guard let markdown = adrMarkdownByID[id] else {
                    return .missingADRMarkdown
                }
                return try .digest(ADRSemanticDigest.digest(metadata: adr, markdown: markdown))
            case "requirement":
                guard let requirement = requirementsByID[RequirementID(rawValue: source.id)] else {
                    return .missingSource
                }
                return try .digest(
                    CanonicalTreeDigest.sha256(CanonicalJSON.encode(requirement))
                )
            case "chapter":
                guard let chapter = chaptersByID[source.id] else {
                    return .missingSource
                }
                return try .digest(CanonicalTreeDigest.sha256(CanonicalJSON.encode(chapter)))
            default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }

    private static func index<Element, Key: Hashable>(
        _ elements: [Element],
        by keyPath: KeyPath<Element, Key>
    ) -> [Key: Element] {
        var result: [Key: Element] = [:]
        result.reserveCapacity(elements.count)
        for element in elements {
            result[element[keyPath: keyPath]] = element
        }
        return result
    }
}

private struct SemanticSourceKey: Hashable {
    let kind: String
    let id: String

    init(_ binding: SourceSemanticBinding) {
        kind = binding.sourceKind
        id = binding.sourceID
    }
}

enum DecisionProjection {
    case decision(String)
    case missingMarkdown
    case unavailable
}

enum SemanticProjection {
    case digest(HashDigest)
    case missingSource
    case missingADRMarkdown
    case unavailable
}
