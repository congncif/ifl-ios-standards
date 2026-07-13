import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

@Suite("CanonValidatorRemediationTests", .serialized)
struct CanonValidatorRemediationTests {
    @Test("a missing replacement Rule is a reference finding")
    func missingReplacementRule() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installLegacyRule(in: root)

            let findings = try CanonValidator().validate(load(root))
            #expect(findings == [CanonFinding(
                checkID: "CHK-CAN-REFERENCE-001",
                severity: .high,
                message: "Rule CAN-LEGACY-002 references missing replacement Rule CAN-MISSING-003.",
                evidenceReferences: ["rule:CAN-LEGACY-002", "rule:CAN-MISSING-003"]
            )])
        }
    }

    @Test("repository-selected Profiles include inherited Profiles")
    func inheritedProfileClosureSelectsInactiveRule() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installInheritedInactiveRule(in: root)

            let snapshot = try load(root)
            #expect(snapshot.selectedProfileIDs.map(\.rawValue) == ["core", "inherited"])
            #expect(CanonValidator().validate(snapshot) == [CanonFinding(
                checkID: "CHK-CAN-PROFILE-001",
                severity: .high,
                message: "Selected Profile inherited includes non-active Rule CAN-INHERITED-002.",
                evidenceReferences: ["profile:inherited", "rule:CAN-INHERITED-002"]
            )])
        }
    }

    @Test("Profile to Rule membership drift is detected in the reverse direction")
    func reverseMembershipDrift() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            var profile = try CanonRepositoryFixture.object(
                at: "profiles/minimal.profile.json",
                in: root
            )
            profile["id"] = "auxiliary"
            profile["display_name"] = "Auxiliary"
            profile["inherits_profile_ids"] = []
            try addProfile(profile, id: "auxiliary", in: root)

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-CAN-PROFILE-001",
                severity: .high,
                message: "Rule CAN-MINIMAL-001 and Profile auxiliary membership is not reciprocal.",
                evidenceReferences: ["profile:auxiliary", "rule:CAN-MINIMAL-001"]
            )])
        }
    }

    @Test("one canonical finding is emitted for a Profile inheritance SCC")
    func profileInheritanceCycle() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            var alpha = try CanonRepositoryFixture.object(
                at: "profiles/minimal.profile.json",
                in: root
            )
            alpha["id"] = "alpha"
            alpha["display_name"] = "Alpha"
            alpha["inherits_profile_ids"] = ["beta"]
            var beta = alpha
            beta["id"] = "beta"
            beta["display_name"] = "Beta"
            beta["inherits_profile_ids"] = ["alpha"]
            try addProfile(alpha, id: "alpha", in: root)
            try addProfile(beta, id: "beta", in: root)
            try mutateRule(in: root) { rule in
                rule["profile_ids"] = ["alpha", "beta", "core"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-CAN-PROFILE-001",
                severity: .high,
                message: "Profile inheritance cycle includes alpha, beta.",
                evidenceReferences: ["profile:alpha", "profile:beta"]
            )])
        }
    }

    @Test("a reciprocal three-ADR supersession cycle is rejected")
    func adrSupersessionCycle() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installADRCycle(in: root)

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR supersession cycle includes ADR-9996, ADR-9997, ADR-9998.",
                evidenceReferences: ["adr:ADR-9996", "adr:ADR-9997", "adr:ADR-9998"]
            )])
        }
    }

    @Test("a missing superseded ADR is an ADR lifecycle finding")
    func missingSupersededADR() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try mutateADR(in: root) { adr in
                adr["supersedes_adr_ids"] = ["ADR-9998"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 maps unresolved superseded ADR ADR-9998.",
                evidenceReferences: ["adr:ADR-9998", "adr:ADR-9999"]
            )])
        }
    }

    @Test("an existing superseded ADR requires a reciprocal link")
    func nonreciprocalSupersession() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try addAcceptedADR(id: "ADR-9998", in: root)
            try mutateADR(in: root) { adr in
                adr["supersedes_adr_ids"] = ["ADR-9998"]
            }
            try mutateRule(in: root) { rule in
                rule["rationale_adrs"] = ["ADR-9998", "ADR-9999"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 supersedes ADR ADR-9998 without a reciprocal superseded_by link.",
                evidenceReferences: ["adr:ADR-9998", "adr:ADR-9999"]
            )])
        }
    }

    @Test("a missing superseded_by target is an ADR lifecycle finding")
    func missingSupersedingADR() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try markBaselineADRSuperseded(by: "ADR-9998", in: root)

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 maps unresolved superseding ADR ADR-9998.",
                evidenceReferences: ["adr:ADR-9998", "adr:ADR-9999"]
            )])
        }
    }

    @Test("an existing superseded_by target requires reciprocal supersedes")
    func nonreciprocalSupersededBy() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try addAcceptedADR(id: "ADR-9998", in: root)
            try markBaselineADRSuperseded(by: "ADR-9998", in: root)
            try mutateRule(in: root) { rule in
                rule["rationale_adrs"] = ["ADR-9998", "ADR-9999"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 has superseded_by ADR ADR-9998 without a reciprocal supersedes link.",
                evidenceReferences: ["adr:ADR-9998", "adr:ADR-9999"]
            )])
        }
    }

    @Test("a reciprocal superseded_by target is clean")
    func reciprocalSupersededBy() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try addAcceptedADR(
                id: "ADR-9998",
                supersedes: ["ADR-9999"],
                in: root
            )
            try markBaselineADRSuperseded(by: "ADR-9998", in: root)
            try mutateRule(in: root) { rule in
                rule["rationale_adrs"] = ["ADR-9998", "ADR-9999"]
            }

            #expect(try CanonValidator().validate(load(root)).isEmpty)
        }
    }

    @Test("a Rule rationale ADR must affect that Rule")
    func ruleRationaleRequiresAffectedRule() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installAuxiliaryRule(in: root)
            try mutateADR(in: root) { adr in
                adr["affected_rule_ids"] = ["CAN-AUXILIARY-002"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "Rule CAN-MINIMAL-001 cites ADR ADR-9999 as rationale, but the ADR does not affect the Rule.",
                evidenceReferences: ["adr:ADR-9999", "rule:CAN-MINIMAL-001"]
            )])
        }
    }

    @Test("an ADR affected Rule must cite that ADR as rationale")
    func affectedRuleRequiresRationale() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try addAcceptedADR(id: "ADR-9998", in: root)
            try mutateRule(in: root) { rule in
                rule["rationale_adrs"] = ["ADR-9998"]
            }

            #expect(try CanonValidator().validate(load(root)) == [CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 affects Rule CAN-MINIMAL-001, but the Rule does not cite the ADR as rationale.",
                evidenceReferences: ["adr:ADR-9999", "rule:CAN-MINIMAL-001"]
            )])
        }
    }

    @Test("matching derived projections become stale after canonical source mutations")
    func derivedProjectionControlAndMutationMatrix() throws {
        try CanonRepositoryFixture.withPositiveRoot { root in
            try installValidChapter(in: root)
            let sources = try load(root)
            let rule = try #require(sources.rules.first { $0.id.rawValue == "CAN-MINIMAL-001" })
            let profile = try #require(sources.profiles.first { $0.id.rawValue == "core" })
            let adr = try #require(sources.adrs.first { $0.id.rawValue == "ADR-9999" })
            let markdown = try #require(sources.adrMarkdownByID[adr.id])
            let requirement = try #require(
                sources.requirementRegistry.requirements.first {
                    $0.id.rawValue == "REQ-CANON"
                }
            )
            let chapter = try #require(sources.chapters.first { $0.id == "minimal" })
            let adrDigest = try ADRSemanticDigest.digest(metadata: adr, markdown: markdown)
            let chapterDigest = try CanonicalTreeDigest.sha256(CanonicalJSON.encode(chapter))
            let profileDigest = try ProfileSemanticDigest.digest(profile)
            let requirementDigest = try CanonicalTreeDigest.sha256(
                CanonicalJSON.encode(requirement)
            )
            let ruleDigest = try RuleSemanticDigest.digest(rule)
            try CanonRepositoryFixture.mutateObject(
                at: "registry/derived-artifacts.index.json",
                in: root
            ) { index in
                index["entries"] = [
                    projectionEntry(
                        key: "adr-projection",
                        targetPath: "generated/01-adr.md",
                        sourceKind: "adr",
                        sourceID: "ADR-9999",
                        digest: adrDigest
                    ),
                    projectionEntry(
                        key: "chapter-projection",
                        targetPath: "generated/02-chapter.md",
                        sourceKind: "chapter",
                        sourceID: "minimal",
                        digest: chapterDigest
                    ),
                    projectionEntry(
                        key: "profile-projection",
                        targetPath: "generated/03-profile.md",
                        sourceKind: "profile",
                        sourceID: "core",
                        digest: profileDigest
                    ),
                    projectionEntry(
                        key: "requirement-projection",
                        targetPath: "generated/04-requirement.md",
                        sourceKind: "requirement",
                        sourceID: "REQ-CANON",
                        digest: requirementDigest
                    ),
                    projectionEntry(
                        key: "rule-projection",
                        targetPath: "generated/05-rule.md",
                        sourceKind: "rule",
                        sourceID: "CAN-MINIMAL-001",
                        digest: ruleDigest
                    ),
                ]
            }

            #expect(try CanonValidator().validate(load(root)).isEmpty)

            try mutateProjectionSources(in: root)

            #expect(try CanonValidator().validate(load(root)) == [
                staleProjectionFinding(
                    key: "adr-projection",
                    sourceKind: "adr",
                    sourceID: "ADR-9999"
                ),
                staleProjectionFinding(
                    key: "chapter-projection",
                    sourceKind: "chapter",
                    sourceID: "minimal"
                ),
                staleProjectionFinding(
                    key: "profile-projection",
                    sourceKind: "profile",
                    sourceID: "core"
                ),
                staleProjectionFinding(
                    key: "requirement-projection",
                    sourceKind: "requirement",
                    sourceID: "REQ-CANON"
                ),
                staleProjectionFinding(
                    key: "rule-projection",
                    sourceKind: "rule",
                    sourceID: "CAN-MINIMAL-001"
                ),
            ])
        }
    }

    @Test("missing ADR Markdown is a finding rather than a thrown error")
    func missingADRMarkdown() throws {
        let baseline = try load(CanonRepositoryFixture.positiveRoot)
        let adr = try #require(baseline.adrs.first)
        let markdown = try #require(baseline.adrMarkdownByID[adr.id])
        let binding = try SourceSemanticBinding(
            sourceKind: "adr",
            sourceID: adr.id.rawValue,
            digest: ADRSemanticDigest.digest(metadata: adr, markdown: markdown)
        )
        let derived = try DerivedRegistrationEntry(
            indexKey: "adr-missing-markdown",
            targetPath: "generated/adr-missing-markdown.md",
            artifactKind: .guide,
            fileDigest: HashDigest(validating: remediationStaleDigest),
            citedRuleIDs: [],
            citedADRIDs: [adr.id],
            sourceSemanticBindings: [binding]
        )
        let snapshot = CanonSnapshot(
            canonVersion: baseline.canonVersion,
            rules: baseline.rules,
            profiles: baseline.profiles,
            selectedProfileIDs: baseline.selectedProfileIDs,
            adrs: baseline.adrs,
            adrMarkdownByID: [:],
            chapters: baseline.chapters,
            requirementRegistry: baseline.requirementRegistry,
            derivedArtifacts: [derived],
            snapshotContentDigest: baseline.snapshotContentDigest
        )

        #expect(CanonValidator().validate(snapshot) == [
            CanonFinding(
                checkID: "CHK-ADR-LIFECYCLE-001",
                severity: .high,
                message: "ADR ADR-9999 is missing its Markdown entry.",
                evidenceReferences: ["adr:ADR-9999"]
            ),
            CanonFinding(
                checkID: "CHK-CAN-DERIVED-001",
                severity: .high,
                message: "Derived artifact adr-missing-markdown cannot project ADR ADR-9999 because its Markdown entry is missing.",
                evidenceReferences: ["adr:ADR-9999", "derived:adr-missing-markdown"]
            ),
        ])
    }

    private func load(_ root: URL) throws -> CanonSnapshot {
        try FileCanonRepository(root: root).snapshot(
            profiles: [CanonRepositoryFixture.coreProfileID()]
        )
    }

    private func installLegacyRule(in root: URL) throws {
        var rule = try CanonRepositoryFixture.object(
            at: "rules/core/minimal.rules.json",
            in: root
        )
        rule["id"] = "CAN-LEGACY-002"
        rule["statement"] = "A legacy Rule must resolve its replacement."
        rule["profile_ids"] = ["legacy"]
        rule["lifecycle"] = "deprecated"
        rule["replacement_id"] = "CAN-MISSING-003"
        try addRule(rule, id: "CAN-LEGACY-002", path: "rules/core/legacy.rules.json", in: root)

        var profile = try CanonRepositoryFixture.object(
            at: "profiles/minimal.profile.json",
            in: root
        )
        profile["id"] = "legacy"
        profile["display_name"] = "Legacy"
        profile["inherits_profile_ids"] = []
        profile["rule_ids"] = ["CAN-LEGACY-002"]
        try addProfile(profile, id: "legacy", in: root)
        try appendAffectedRule("CAN-LEGACY-002", in: root)
    }

    private func installInheritedInactiveRule(in root: URL) throws {
        var rule = try CanonRepositoryFixture.object(
            at: "rules/core/minimal.rules.json",
            in: root
        )
        rule["id"] = "CAN-INHERITED-002"
        rule["statement"] = "Inherited selected Rules must be active."
        rule["profile_ids"] = ["inherited"]
        rule["lifecycle"] = "accepted"
        try addRule(
            rule,
            id: "CAN-INHERITED-002",
            path: "rules/core/inherited.rules.json",
            in: root
        )

        var profile = try CanonRepositoryFixture.object(
            at: "profiles/minimal.profile.json",
            in: root
        )
        profile["id"] = "inherited"
        profile["display_name"] = "Inherited"
        profile["inherits_profile_ids"] = []
        profile["rule_ids"] = ["CAN-INHERITED-002"]
        try addProfile(profile, id: "inherited", in: root)
        try CanonRepositoryFixture.mutateObject(
            at: "profiles/minimal.profile.json",
            in: root
        ) { core in
            core["inherits_profile_ids"] = ["inherited"]
        }
        try CanonRepositoryFixture.updateRecordDigest(
            for: "profiles/minimal.profile.json",
            in: "profiles.index.json",
            root: root
        )
        try appendAffectedRule("CAN-INHERITED-002", in: root)
    }

    private func installADRCycle(in root: URL) throws {
        let specifications = [
            ADRCycleSpecification(id: "ADR-9996", supersedes: "ADR-9998", supersededBy: "ADR-9997"),
            ADRCycleSpecification(id: "ADR-9997", supersedes: "ADR-9996", supersededBy: "ADR-9998"),
            ADRCycleSpecification(id: "ADR-9998", supersedes: "ADR-9997", supersededBy: "ADR-9996"),
        ]
        for specification in specifications {
            try addCycleADR(specification, in: root)
        }
        try mutateRule(in: root) { rule in
            rule["rationale_adrs"] = ["ADR-9996", "ADR-9997", "ADR-9998", "ADR-9999"]
        }
    }

    private func installAuxiliaryRule(in root: URL) throws {
        var rule = try CanonRepositoryFixture.object(
            at: "rules/core/minimal.rules.json",
            in: root
        )
        rule["id"] = "CAN-AUXILIARY-002"
        rule["statement"] = "An auxiliary Rule supports reciprocal rationale testing."
        rule["profile_ids"] = ["auxiliary"]
        rule["lifecycle"] = "accepted"
        try addRule(
            rule,
            id: "CAN-AUXILIARY-002",
            path: "rules/core/auxiliary.rules.json",
            in: root
        )

        var profile = try CanonRepositoryFixture.object(
            at: "profiles/minimal.profile.json",
            in: root
        )
        profile["id"] = "auxiliary"
        profile["display_name"] = "Auxiliary"
        profile["inherits_profile_ids"] = []
        profile["rule_ids"] = ["CAN-AUXILIARY-002"]
        try addProfile(profile, id: "auxiliary", in: root)
    }

    private func addCycleADR(_ specification: ADRCycleSpecification, in root: URL) throws {
        let decision = "Preserve reciprocal links while forming the cycle for \(specification.id)."
        let markdown = "# \(specification.id): Cycle fixture\n\n## Decision\n\n\(decision)\n"
        let markdownPath = "adrs/\(specification.id)-cycle.md"
        let markdownURL = root.appendingPathComponent(markdownPath)
        try Data(markdown.utf8).write(to: markdownURL, options: .atomic)
        try CanonRepositoryFixture.setPermissions(0o644, at: markdownURL)

        var adr = try CanonRepositoryFixture.object(
            at: "adrs/ADR-9999-minimal-test.json",
            in: root
        )
        adr["id"] = specification.id
        adr["title"] = "Cycle fixture \(specification.id)"
        adr["status"] = "superseded"
        adr["decision"] = decision
        adr["markdown_digest"] = CanonicalTreeDigest.sha256(Data(markdown.utf8)).rawValue
        adr["reference_artifact_ids"] = [markdownPath]
        adr["supersedes_adr_ids"] = [specification.supersedes]
        adr["superseded_by"] = specification.supersededBy
        let jsonPath = "adrs/\(specification.id)-cycle.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(adr, to: jsonPath, in: root)
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: specification.id,
            relativePath: jsonPath,
            indexFilename: "adrs.index.json",
            root: root
        )
    }

    private func addAcceptedADR(
        id: String,
        supersedes: [String] = [],
        in root: URL
    ) throws {
        let decision = "Provide a second accepted ADR for reciprocal-link testing."
        let markdown = "# \(id): Reciprocal fixture\n\n## Decision\n\n\(decision)\n"
        let markdownPath = "adrs/\(id)-reciprocal.md"
        let markdownURL = root.appendingPathComponent(markdownPath)
        try Data(markdown.utf8).write(to: markdownURL, options: .atomic)
        try CanonRepositoryFixture.setPermissions(0o644, at: markdownURL)

        var adr = try CanonRepositoryFixture.object(
            at: "adrs/ADR-9999-minimal-test.json",
            in: root
        )
        adr["id"] = id
        adr["title"] = "Reciprocal fixture \(id)"
        adr["decision"] = decision
        adr["markdown_digest"] = CanonicalTreeDigest.sha256(Data(markdown.utf8)).rawValue
        adr["reference_artifact_ids"] = [markdownPath]
        adr["supersedes_adr_ids"] = supersedes
        adr.removeValue(forKey: "superseded_by")
        let jsonPath = "adrs/\(id)-reciprocal.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(adr, to: jsonPath, in: root)
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: id,
            relativePath: jsonPath,
            indexFilename: "adrs.index.json",
            root: root
        )
    }

    private func installValidChapter(in root: URL) throws {
        let path = "chapters/minimal.chapter.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(
            [
                "applicability": ["canon-fixture"],
                "check_ids": ["CHK-CAN-MINIMAL-001"],
                "compliant_example_ids": ["FIX-CAN-MINIMAL-001-PASS"],
                "exception_policy": "No exceptions apply to this fixture chapter.",
                "id": "minimal",
                "negative_fixture_ids": ["FIX-CAN-MINIMAL-001-FAIL-001"],
                "non_compliant_example_ids": ["FIX-CAN-MINIMAL-001-FAIL-002"],
                "owner_role_id": "Canon Maintainer",
                "positive_fixture_ids": ["FIX-CAN-MINIMAL-001-PASS"],
                "rationale": "Exercise Chapter semantic projection.",
                "rationale_adr_ids": ["ADR-9999"],
                "required_evidence_kinds": ["contract_test"],
                "required_rule_dependencies": [],
                "requirement_id": "REQ-CANON",
                "review_cadence": "per_release",
                "review_checklist_ids": ["CAN-CHAPTER-REVIEW-001"],
                "rule_ids": ["CAN-MINIMAL-001"],
                "schema_version": 1,
                "title": "Minimal Canon chapter",
            ],
            to: path,
            in: root
        )
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: "minimal",
            relativePath: path,
            indexFilename: "chapters.index.json",
            root: root
        )
    }

    private func addRule(
        _ rule: CanonRepositoryFixture.JSONObject,
        id: String,
        path: String,
        in root: URL
    ) throws {
        try CanonRepositoryFixture.writeCanonicalJSONObject(rule, to: path, in: root)
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: id,
            relativePath: path,
            indexFilename: "rules.index.json",
            root: root
        )
    }

    private func addProfile(
        _ profile: CanonRepositoryFixture.JSONObject,
        id: String,
        in root: URL
    ) throws {
        let path = "profiles/\(id).profile.json"
        try CanonRepositoryFixture.writeCanonicalJSONObject(profile, to: path, in: root)
        try CanonRepositoryFixture.addRecordIndexEntry(
            id: id,
            relativePath: path,
            indexFilename: "profiles.index.json",
            root: root
        )
    }

    private func appendAffectedRule(_ ruleID: String, in root: URL) throws {
        try CanonRepositoryFixture.mutateObject(
            at: "adrs/ADR-9999-minimal-test.json",
            in: root
        ) { adr in
            var ids = try #require(adr["affected_rule_ids"] as? [String])
            ids.append(ruleID)
            ids.sort()
            adr["affected_rule_ids"] = ids
        }
        try CanonRepositoryFixture.updateRecordDigest(
            for: "adrs/ADR-9999-minimal-test.json",
            in: "adrs.index.json",
            root: root
        )
    }

    private func markBaselineADRSuperseded(by adrID: String, in root: URL) throws {
        try mutateADR(in: root) { adr in
            adr["status"] = "superseded"
            adr["superseded_by"] = adrID
        }
    }

    private func mutateProjectionSources(in root: URL) throws {
        try mutateRule(in: root) { rule in
            rule["statement"] = "The controlled Rule mutation invalidates its semantic binding."
        }
        try CanonRepositoryFixture.mutateObject(
            at: "profiles/minimal.profile.json",
            in: root
        ) { profile in
            profile["description"] = "Controlled Profile semantic mutation."
        }
        try CanonRepositoryFixture.updateRecordDigest(
            for: "profiles/minimal.profile.json",
            in: "profiles.index.json",
            root: root
        )
        try mutateADR(in: root) { adr in
            adr["context"] = "Controlled ADR semantic mutation."
        }
        try CanonRepositoryFixture.mutateObject(
            at: "registry/requirements.v1.json",
            in: root
        ) { registry in
            var requirements = try #require(
                registry["requirements"] as? [CanonRepositoryFixture.JSONObject]
            )
            let index = try #require(requirements.firstIndex {
                $0["id"] as? String == "REQ-CANON"
            })
            requirements[index]["status"] = "in_progress"
            registry["requirements"] = requirements
        }
        try CanonRepositoryFixture.mutateObject(
            at: "chapters/minimal.chapter.json",
            in: root
        ) { chapter in
            chapter["rationale"] = "Controlled Chapter semantic mutation."
        }
        try CanonRepositoryFixture.updateRecordDigest(
            for: "chapters/minimal.chapter.json",
            in: "chapters.index.json",
            root: root
        )
    }

    private func mutateADR(
        in root: URL,
        _ mutation: (inout CanonRepositoryFixture.JSONObject) throws -> Void
    ) throws {
        try CanonRepositoryFixture.mutateObject(
            at: "adrs/ADR-9999-minimal-test.json",
            in: root,
            mutation
        )
        try CanonRepositoryFixture.updateRecordDigest(
            for: "adrs/ADR-9999-minimal-test.json",
            in: "adrs.index.json",
            root: root
        )
    }

    private func mutateRule(
        in root: URL,
        _ mutation: (inout CanonRepositoryFixture.JSONObject) throws -> Void
    ) throws {
        try CanonRepositoryFixture.mutateObject(
            at: "rules/core/minimal.rules.json",
            in: root,
            mutation
        )
        try CanonRepositoryFixture.updateRecordDigest(
            for: "rules/core/minimal.rules.json",
            in: "rules.index.json",
            root: root
        )
    }
}

private struct ADRCycleSpecification {
    let id: String
    let supersedes: String
    let supersededBy: String
}

private let remediationStaleDigest = String(repeating: "0", count: 64)

private func projectionEntry(
    key: String,
    targetPath: String,
    sourceKind: String,
    sourceID: String,
    digest: HashDigest
) -> CanonRepositoryFixture.JSONObject {
    [
        "artifact_kind": "guide",
        "cited_adr_ids": sourceKind == "adr" ? [sourceID] : [],
        "cited_rule_ids": sourceKind == "rule" ? [sourceID] : [],
        "file_digest": remediationStaleDigest,
        "index_key": key,
        "source_semantic_bindings": [[
            "digest": digest.rawValue,
            "source_id": sourceID,
            "source_kind": sourceKind,
        ]],
        "target_path": targetPath,
    ]
}

private func staleProjectionFinding(
    key: String,
    sourceKind: String,
    sourceID: String
) -> CanonFinding {
    CanonFinding(
        checkID: "CHK-CAN-DERIVED-001",
        severity: .high,
        message: "Derived artifact \(key) has a stale semantic digest for \(sourceKind) \(sourceID).",
        evidenceReferences: ["derived:\(key)", "\(sourceKind):\(sourceID)"]
    )
}
