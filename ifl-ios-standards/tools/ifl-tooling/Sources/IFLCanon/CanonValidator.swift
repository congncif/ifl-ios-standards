import IFLContracts

public struct CanonValidator: Sendable {
    public init() {}

    public func validate(_ snapshot: CanonSnapshot) -> [CanonFinding] {
        let graph = ReferenceGraph(snapshot)
        var findings: [CanonFinding] = []

        validateRuleReferences(snapshot.rules, graph: graph, findings: &findings)
        validateProfiles(snapshot, graph: graph, findings: &findings)
        validateADRs(snapshot, graph: graph, findings: &findings)
        validateTraceability(snapshot, graph: graph, findings: &findings)
        validateDerivedArtifacts(snapshot.derivedArtifacts, graph: graph, findings: &findings)

        return findings.sorted(by: CanonFinding.canonicalLess)
    }

    private func validateRuleReferences(
        _ rules: [RuleRecord],
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for rule in rules {
            for profileID in rule.profileIDs where graph.profilesByID[profileID] == nil {
                findings.append(finding(
                    checkID: CheckID.reference,
                    message: "Rule \(rule.id.rawValue) references missing Profile \(profileID.rawValue).",
                    evidence: [ruleReference(rule.id), profileReference(profileID)]
                ))
            }
            for adrID in rule.rationaleADRs where graph.adrsByID[adrID] == nil {
                findings.append(finding(
                    checkID: CheckID.reference,
                    message: "Rule \(rule.id.rawValue) references missing rationale ADR \(adrID.rawValue).",
                    evidence: [ruleReference(rule.id), adrReference(adrID)]
                ))
            }
            if let replacementID = rule.replacementID,
               graph.rulesByID[replacementID] == nil
            {
                findings.append(finding(
                    checkID: CheckID.reference,
                    message: "Rule \(rule.id.rawValue) references missing replacement Rule \(replacementID.rawValue).",
                    evidence: [ruleReference(rule.id), ruleReference(replacementID)]
                ))
            }
        }
    }

    private func validateProfiles(
        _ snapshot: CanonSnapshot,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for profile in snapshot.profiles {
            for ruleID in profile.ruleIDs where graph.rulesByID[ruleID] == nil {
                findings.append(finding(
                    checkID: CheckID.reference,
                    message: "Profile \(profile.id.rawValue) references missing Rule \(ruleID.rawValue).",
                    evidence: [profileReference(profile.id), ruleReference(ruleID)]
                ))
            }
        }

        appendProfileCycleFindings(graph: graph, findings: &findings)

        for rule in snapshot.rules {
            for profileID in rule.profileIDs {
                guard graph.profilesByID[profileID] != nil,
                      !graph.profile(profileID, declares: rule.id)
                else { continue }
                findings.append(membershipFinding(ruleID: rule.id, profileID: profileID))
            }
        }
        for profile in snapshot.profiles {
            for ruleID in profile.ruleIDs {
                guard graph.rulesByID[ruleID] != nil,
                      !graph.rule(ruleID, declares: profile.id)
                else { continue }
                findings.append(membershipFinding(ruleID: ruleID, profileID: profile.id))
            }
        }

        for profileID in graph.selectedProfileIDs {
            guard let profile = graph.profilesByID[profileID] else { continue }
            for ruleID in profile.ruleIDs {
                guard let rule = graph.rulesByID[ruleID], rule.lifecycle != .active else {
                    continue
                }
                findings.append(finding(
                    checkID: CheckID.profile,
                    message: "Selected Profile \(profileID.rawValue) includes non-active Rule \(ruleID.rawValue).",
                    evidence: [profileReference(profileID), ruleReference(ruleID)]
                ))
            }
        }
    }

    private func appendProfileCycleFindings(
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        let components = StronglyConnectedComponents.cyclicComponents(
            nodes: Array(graph.profilesByID.keys),
            successors: graph.inheritedProfileIDs
        )
        for component in components {
            let canonicalIDs = component.map(\.rawValue).sorted(by: utf8Less)
            findings.append(finding(
                checkID: CheckID.profile,
                message: "Profile inheritance cycle includes \(canonicalIDs.joined(separator: ", ")).",
                evidence: canonicalIDs.map { "profile:\($0)" }
            ))
        }
    }

    private func membershipFinding(ruleID: RuleID, profileID: ProfileID) -> CanonFinding {
        finding(
            checkID: CheckID.profile,
            message: "Rule \(ruleID.rawValue) and Profile \(profileID.rawValue) membership is not reciprocal.",
            evidence: [ruleReference(ruleID), profileReference(profileID)]
        )
    }

    private func validateADRs(
        _ snapshot: CanonSnapshot,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for adr in snapshot.adrs {
            validateADRDecision(adr, graph: graph, findings: &findings)

            for ruleID in adr.affectedRuleIDs {
                guard let rule = graph.rulesByID[ruleID] else {
                    findings.append(adrMappingFinding(
                        adrID: adr.id,
                        kind: "Rule",
                        target: ruleReference(ruleID)
                    ))
                    continue
                }
                guard !rule.rationaleADRs.contains(adr.id) else { continue }
                findings.append(finding(
                    checkID: CheckID.adrLifecycle,
                    message: "ADR \(adr.id.rawValue) affects Rule \(ruleID.rawValue), but the Rule does not cite the ADR as rationale.",
                    evidence: [adrReference(adr.id), ruleReference(ruleID)]
                ))
            }
            for profileID in adr.affectedProfileIDs
                where graph.profilesByID[profileID] == nil
            {
                findings.append(adrMappingFinding(
                    adrID: adr.id,
                    kind: "Profile",
                    target: profileReference(profileID)
                ))
            }
            for checkID in adr.checkIDs where !graph.containsCheck(checkID) {
                findings.append(adrMappingFinding(
                    adrID: adr.id,
                    kind: "check",
                    target: checkReference(checkID)
                ))
            }
            for fixtureID in adr.fixtureIDs where !graph.containsFixture(fixtureID) {
                findings.append(adrMappingFinding(
                    adrID: adr.id,
                    kind: "fixture",
                    target: fixtureReference(fixtureID)
                ))
            }

            validateADRSupersession(adr, graph: graph, findings: &findings)
        }

        for rule in snapshot.rules {
            for adrID in rule.rationaleADRs {
                guard let adr = graph.adrsByID[adrID],
                      !adr.affectedRuleIDs.contains(rule.id)
                else { continue }
                findings.append(finding(
                    checkID: CheckID.adrLifecycle,
                    message: "Rule \(rule.id.rawValue) cites ADR \(adrID.rawValue) as rationale, but the ADR does not affect the Rule.",
                    evidence: [ruleReference(rule.id), adrReference(adrID)]
                ))
            }
        }

        appendADRSupersessionCycleFindings(graph: graph, findings: &findings)
    }

    private func appendADRSupersessionCycleFindings(
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        let components = StronglyConnectedComponents.cyclicComponents(
            nodes: Array(graph.adrsByID.keys),
            successors: graph.supersededADRIDs
        )
        for component in components {
            let canonicalIDs = component.map(\.rawValue).sorted(by: utf8Less)
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR supersession cycle includes \(canonicalIDs.joined(separator: ", ")).",
                evidence: canonicalIDs.map { "adr:\($0)" }
            ))
        }
    }

    private func validateADRDecision(
        _ adr: ADRMetadata,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        switch graph.decisionProjection(for: adr.id) {
        case let .decision(markdownDecision):
            guard adr.decision != markdownDecision else { return }
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR \(adr.id.rawValue) metadata Decision differs from its Markdown Decision.",
                evidence: [adrReference(adr.id)]
            ))
        case .missingMarkdown:
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR \(adr.id.rawValue) is missing its Markdown entry.",
                evidence: [adrReference(adr.id)]
            ))
        case .unavailable:
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR \(adr.id.rawValue) Markdown Decision cannot be projected.",
                evidence: [adrReference(adr.id)]
            ))
        }
    }

    private func validateADRSupersession(
        _ adr: ADRMetadata,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for supersededID in adr.supersedesADRIDs {
            guard let superseded = graph.adrsByID[supersededID] else {
                findings.append(adrMappingFinding(
                    adrID: adr.id,
                    kind: "superseded ADR",
                    target: adrReference(supersededID)
                ))
                continue
            }
            guard superseded.supersededBy != adr.id else { continue }
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR \(adr.id.rawValue) supersedes ADR \(supersededID.rawValue) without a reciprocal superseded_by link.",
                evidence: [adrReference(adr.id), adrReference(supersededID)]
            ))
        }

        guard let supersedingID = adr.supersededBy else { return }
        guard let superseding = graph.adrsByID[supersedingID] else {
            findings.append(adrMappingFinding(
                adrID: adr.id,
                kind: "superseding ADR",
                target: adrReference(supersedingID)
            ))
            return
        }
        guard superseding.supersedesADRIDs.contains(adr.id) else {
            findings.append(finding(
                checkID: CheckID.adrLifecycle,
                message: "ADR \(adr.id.rawValue) has superseded_by ADR \(supersedingID.rawValue) without a reciprocal supersedes link.",
                evidence: [adrReference(adr.id), adrReference(supersedingID)]
            ))
            return
        }
    }

    private func adrMappingFinding(
        adrID: ADRIdentifier,
        kind: String,
        target: String
    ) -> CanonFinding {
        finding(
            checkID: CheckID.adrLifecycle,
            message: "ADR \(adrID.rawValue) maps unresolved \(kind) \(target.dropKindPrefix).",
            evidence: [adrReference(adrID), target]
        )
    }

    private func validateTraceability(
        _ snapshot: CanonSnapshot,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for traceability in snapshot.requirementRegistry.traceability {
            for binding in traceability.ruleBindings
                where graph.rulesByID[binding.ruleID] == nil
            {
                findings.append(finding(
                    checkID: CheckID.traceability,
                    message: "Requirement \(traceability.requirementID.rawValue) binds missing Rule \(binding.ruleID.rawValue).",
                    evidence: [
                        requirementReference(traceability.requirementID),
                        ruleReference(binding.ruleID),
                    ]
                ))
            }
        }

        for rule in snapshot.rules
            where rule.lifecycle == .active && !graph.hasOwnerBinding(for: rule.id)
        {
            findings.append(finding(
                checkID: CheckID.traceability,
                message: "Active Rule \(rule.id.rawValue) has no owner binding.",
                evidence: [ruleReference(rule.id)]
            ))
        }

        for chapter in snapshot.chapters {
            validateChapter(chapter, graph: graph, findings: &findings)
        }
    }

    private func validateChapter(
        _ chapter: ChapterMetadata,
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        let chapterEvidence = chapterReference(chapter.id)
        let requirementEvidence = requirementReference(chapter.requirementID)
        if let requirement = graph.requirementsByID[chapter.requirementID] {
            if chapter.ownerRoleID != requirement.accountableOwnerRoleID {
                findings.append(finding(
                    checkID: CheckID.traceability,
                    message: "Chapter \(chapter.id) owner does not match Requirement \(chapter.requirementID.rawValue).",
                    evidence: [chapterEvidence, requirementEvidence]
                ))
            }
        } else {
            findings.append(finding(
                checkID: CheckID.traceability,
                message: "Chapter \(chapter.id) references missing Requirement \(chapter.requirementID.rawValue).",
                evidence: [chapterEvidence, requirementEvidence]
            ))
        }

        for ruleID in chapter.ruleIDs where graph.rulesByID[ruleID] == nil {
            findings.append(chapterCrossRecordReferenceFinding(
                chapter: chapter,
                kind: "Rule",
                target: ruleReference(ruleID)
            ))
        }
        for adrID in chapter.rationaleADRIDs where graph.adrsByID[adrID] == nil {
            findings.append(chapterCrossRecordReferenceFinding(
                chapter: chapter,
                kind: "rationale ADR",
                target: adrReference(adrID)
            ))
        }

        let declaredChecks = graph.chapterCheckIDs(for: chapter.requirementID)
        for checkID in chapter.checkIDs where !declaredChecks.contains(checkID) {
            findings.append(chapterTraceabilityFinding(
                chapter: chapter,
                kind: "check",
                target: checkReference(checkID)
            ))
        }

        let positiveFixtures = graph.chapterPositiveFixtureIDs(
            for: chapter.requirementID,
            checkIDs: chapter.checkIDs
        )
        for fixtureID in chapter.positiveFixtureIDs where !positiveFixtures.contains(fixtureID) {
            findings.append(chapterTraceabilityFinding(
                chapter: chapter,
                kind: "positive fixture",
                target: fixtureReference(fixtureID)
            ))
        }

        let negativeFixtures = graph.chapterNegativeFixtureIDs(
            for: chapter.requirementID,
            checkIDs: chapter.checkIDs
        )
        for fixtureID in chapter.negativeFixtureIDs where !negativeFixtures.contains(fixtureID) {
            findings.append(chapterTraceabilityFinding(
                chapter: chapter,
                kind: "negative fixture",
                target: fixtureReference(fixtureID)
            ))
        }
    }

    private func chapterCrossRecordReferenceFinding(
        chapter: ChapterMetadata,
        kind: String,
        target: String
    ) -> CanonFinding {
        finding(
            checkID: CheckID.reference,
            message: "Chapter \(chapter.id) declares unresolved \(kind) \(target.dropKindPrefix).",
            evidence: [
                chapterReference(chapter.id),
                requirementReference(chapter.requirementID),
                target,
            ]
        )
    }

    private func chapterTraceabilityFinding(
        chapter: ChapterMetadata,
        kind: String,
        target: String
    ) -> CanonFinding {
        finding(
            checkID: CheckID.traceability,
            message: "Chapter \(chapter.id) declares unresolved \(kind) \(target.dropKindPrefix).",
            evidence: [
                chapterReference(chapter.id),
                requirementReference(chapter.requirementID),
                target,
            ]
        )
    }

    private func validateDerivedArtifacts(
        _ entries: [DerivedRegistrationEntry],
        graph: ReferenceGraph,
        findings: inout [CanonFinding]
    ) {
        for entry in entries {
            for binding in entry.sourceSemanticBindings {
                let evidence = [
                    "derived:\(entry.indexKey)",
                    "\(binding.sourceKind):\(binding.sourceID)",
                ]
                switch graph.semanticProjection(for: binding) {
                case let .digest(actual) where actual != binding.digest:
                    findings.append(finding(
                        checkID: CheckID.derived,
                        message: "Derived artifact \(entry.indexKey) has a stale semantic digest for \(binding.sourceKind) \(binding.sourceID).",
                        evidence: evidence
                    ))
                case .digest:
                    break
                case .missingSource:
                    findings.append(finding(
                        checkID: CheckID.derived,
                        message: "Derived artifact \(entry.indexKey) binds missing \(binding.sourceKind) \(binding.sourceID).",
                        evidence: evidence
                    ))
                case .missingADRMarkdown:
                    findings.append(finding(
                        checkID: CheckID.derived,
                        message: "Derived artifact \(entry.indexKey) cannot project ADR \(binding.sourceID) because its Markdown entry is missing.",
                        evidence: evidence
                    ))
                case .unavailable:
                    findings.append(finding(
                        checkID: CheckID.derived,
                        message: "Derived artifact \(entry.indexKey) cannot project \(binding.sourceKind) \(binding.sourceID).",
                        evidence: evidence
                    ))
                }
            }
        }
    }

    private func finding(
        checkID: String,
        message: String,
        evidence: [String]
    ) -> CanonFinding {
        CanonFinding(
            checkID: checkID,
            severity: .high,
            message: message,
            evidenceReferences: evidence
        )
    }

    private func ruleReference(_ id: RuleID) -> String {
        "rule:\(id.rawValue)"
    }

    private func profileReference(_ id: ProfileID) -> String {
        "profile:\(id.rawValue)"
    }

    private func adrReference(_ id: ADRIdentifier) -> String {
        "adr:\(id.rawValue)"
    }

    private func requirementReference(_ id: RequirementID) -> String {
        "requirement:\(id.rawValue)"
    }

    private func chapterReference(_ id: String) -> String {
        "chapter:\(id)"
    }

    private func checkReference(_ id: String) -> String {
        "check:\(id)"
    }

    private func fixtureReference(_ id: String) -> String {
        "fixture:\(id)"
    }

    private func utf8Less(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

private enum CheckID {
    static let reference = "CHK-CAN-REFERENCE-001"
    static let profile = "CHK-CAN-PROFILE-001"
    static let adrLifecycle = "CHK-ADR-LIFECYCLE-001"
    static let traceability = "CHK-CAN-TRACEABILITY-001"
    static let derived = "CHK-CAN-DERIVED-001"
}

private extension String {
    var dropKindPrefix: Substring {
        split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).last ?? self[...]
    }
}
