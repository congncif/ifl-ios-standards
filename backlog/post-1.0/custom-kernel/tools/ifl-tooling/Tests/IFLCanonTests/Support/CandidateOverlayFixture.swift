import Darwin
import Foundation
@testable import IFLCanon
import IFLContracts
import Testing

enum CandidateOverlayFixture {
    struct Options {
        var ruleLifecycle: RuleLifecycle = .proposed
        var adrStatus: ADRStatus = .inReview
        var componentKind = "enterprise-routing"
        var pluginTargetPath = "skills/brain-execute/SKILL.md"
        var derivedArtifactKind: DerivedArtifactKind = .skill
        var pluginTargetMode: CandidatePortableMode = .file
        var omitPluginTargetBeforeEntry = false
    }

    static func withValidFixture<T>(
        options: Options = Options(),
        _ body: (InstalledCandidateOverlayFixture) throws -> T
    ) throws -> T {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory.appendingPathComponent(
            "ifl-candidate-overlay-\(UUID().uuidString)",
            isDirectory: true
        )
        let plugin = workspace.appendingPathComponent("plugin", isDirectory: true)
        let canon = plugin.appendingPathComponent("standards/canon", isDirectory: true)
        try fileManager.createDirectory(
            at: canon.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        defer { try? fileManager.removeItem(at: workspace) }
        try fileManager.copyItem(at: CanonRepositoryFixture.positiveRoot, to: canon)
        try setMode(0o755, at: plugin)
        try setMode(0o755, at: canon.deletingLastPathComponent())

        let chapterParent = canon.appendingPathComponent("chapters/core", isDirectory: true)
        try fileManager.createDirectory(at: chapterParent, withIntermediateDirectories: true)
        try setMode(0o755, at: canon.appendingPathComponent("chapters", isDirectory: true))
        try setMode(0o755, at: chapterParent)

        let existingPluginTarget = plugin.appendingPathComponent(options.pluginTargetPath)
        try fileManager.createDirectory(
            at: existingPluginTarget.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try setDirectoryModes(
            from: existingPluginTarget.deletingLastPathComponent(),
            through: plugin
        )
        try Data("# Existing retained skill\n".utf8).write(to: existingPluginTarget)
        try setMode(Int(options.pluginTargetMode.rawValue), at: existingPluginTarget)

        let overlayID = try CandidateOverlayID(validating: "enterprise-v1")
        let candidate = plugin.appendingPathComponent(
            "standards/canon-candidates/\(overlayID.rawValue)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
        try setMode(
            0o755,
            at: plugin.appendingPathComponent("standards/canon-candidates", isDirectory: true)
        )
        try setMode(0o755, at: candidate)

        let anchor = try retainedAnchor(at: plugin)
        let base = try FileCanonRepository(anchor: anchor.canonRootAnchor()).snapshot(profiles: [])
        let baseCanonEvidence = try #require(base.candidateOverlayEvidence)
        let pluginInventory = try CanonicalTreeScanner().scan(
            root: plugin,
            policy: CanonicalTreePolicy(excludedRoots: [])
        )

        let installation = try buildInstallation(
            plugin: plugin,
            canon: canon,
            candidate: candidate,
            anchor: anchor,
            base: base,
            baseCanonEvidence: baseCanonEvidence,
            pluginInventory: pluginInventory,
            overlayID: overlayID,
            options: options
        )
        return try body(installation)
    }
}

enum TwoComponentFixtureMutation: String, CaseIterable, CustomTestStringConvertible {
    case duplicateCandidateSource
    case fileDirectoryConflict
    case missingComponentLocalParent

    var testDescription: String {
        rawValue
    }
}

enum OptionalAuthorityMismatch: String, CaseIterable, CustomTestStringConvertible {
    case check
    case fixture
    case migration

    var testDescription: String {
        rawValue
    }
}

struct InstalledCandidateOverlayFixture {
    let workspace: URL
    let pluginRoot: URL
    let canonRoot: URL
    let candidateRoot: URL
    let anchor: RetainedPluginRootAnchor
    let overlayID: CandidateOverlayID
    let baseSnapshot: CanonSnapshot
    let manifest: CandidateOverlayManifest
    let bundle: CandidateComponentBundle

    func validate(
        eventHandler: @escaping CandidateOverlayValidationEventHandler = { _ in }
    ) throws -> ValidatedCandidateOverlay {
        try CandidateOverlayValidator(
            anchor: anchor,
            eventHandler: eventHandler
        ).validate(overlayID: overlayID, base: baseSnapshot)
    }

    func addExtraCandidateFile() throws {
        let url = candidateRoot.appendingPathComponent("payloads/extra.txt")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("undeclared\n".utf8).write(to: url)
        try CandidateOverlayFixture.setMode(0o755, at: url.deletingLastPathComponent())
        try CandidateOverlayFixture.setMode(0o644, at: url)
    }

    func removeCandidateFile(relativePath: String) throws {
        try FileManager.default.removeItem(
            at: candidateRoot.appendingPathComponent(relativePath)
        )
    }

    func setCandidateMode(_ mode: Int, relativePath: String) throws {
        try CandidateOverlayFixture.setMode(
            mode,
            at: candidateRoot.appendingPathComponent(relativePath)
        )
    }

    func makeManifestNonCanonical() throws {
        let url = candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var data = try Data(contentsOf: url)
        data.append(0x20)
        try data.write(to: url, options: .atomic)
        try CandidateOverlayFixture.setMode(0o644, at: url)
    }

    func mutateBundleBytes() throws {
        let url = candidateRoot.appendingPathComponent(bundle.bundleRelativePath)
        var object = try CandidateOverlayFixture.jsonObject(at: url)
        object["component_kind"] = "standards-core"
        try CandidateOverlayFixture.writeCanonicalJSONObject(object, to: url)
    }

    func makeBundleClaimConfusionWithRecomputedReviewDigest() throws {
        let bundleURL = candidateRoot.appendingPathComponent(bundle.bundleRelativePath)
        var bundleObject = try CandidateOverlayFixture.jsonObject(at: bundleURL)
        var artifacts = try #require(bundleObject["artifacts"] as? [[String: Any]])
        let artifactIndex = try #require(
            artifacts.firstIndex { $0["artifact_id"] as? String == "rule-minimal" }
        )
        artifacts[artifactIndex]["logical_id"] = "R-CONFUSED-001"
        bundleObject["artifacts"] = artifacts
        try CandidateOverlayFixture.writeCanonicalJSONObject(bundleObject, to: bundleURL)

        let bundleData = try Data(contentsOf: bundleURL)
        let componentDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: bundleData
        )
        let manifestURL = candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var manifestObject = try CandidateOverlayFixture.jsonObject(at: manifestURL)
        var reviewed = try #require(
            manifestObject["reviewed_components"] as? [[String: Any]]
        )
        var component = try #require(reviewed.first)
        component["component_digest"] = componentDigest.rawValue
        for approvalKey in [
            "accountable_owner_approval",
            "independent_reviewer_approval",
        ] {
            var approval = try #require(component[approvalKey] as? [String: Any])
            approval["reviewed_component_digest"] = componentDigest.rawValue
            component[approvalKey] = approval
        }
        reviewed[0] = component
        manifestObject["reviewed_components"] = reviewed
        try CandidateOverlayFixture.writeCanonicalJSONObject(manifestObject, to: manifestURL)
    }

    func makeApprovalActorsOverlap() throws {
        let manifestURL = candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var manifestObject = try CandidateOverlayFixture.jsonObject(at: manifestURL)
        var reviewed = try #require(
            manifestObject["reviewed_components"] as? [[String: Any]]
        )
        var component = try #require(reviewed.first)
        let owner = try #require(
            component["accountable_owner_approval"] as? [String: Any]
        )
        var reviewer = try #require(
            component["independent_reviewer_approval"] as? [String: Any]
        )
        reviewer["actor_id"] = try #require(owner["actor_id"] as? String)
        component["independent_reviewer_approval"] = reviewer
        reviewed[0] = component
        manifestObject["reviewed_components"] = reviewed
        try CandidateOverlayFixture.writeCanonicalJSONObject(manifestObject, to: manifestURL)
    }

    func removeRuleTransform() throws {
        let manifestURL = candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        var manifestObject = try CandidateOverlayFixture.jsonObject(at: manifestURL)
        var transformSet = try #require(
            manifestObject["activation_transform_set"] as? [String: Any]
        )
        transformSet["rules"] = []
        manifestObject["activation_transform_set"] = transformSet
        try CandidateOverlayFixture.writeCanonicalJSONObject(manifestObject, to: manifestURL)
    }
}

extension InstalledCandidateOverlayFixture {
    func installTwoComponentMutation(_ mutation: TwoComponentFixtureMutation) throws {
        try CandidateOverlayFixture.installTwoComponentMutation(mutation, in: self)
    }

    func publishOptionalAuthorityMismatch(_ mismatch: OptionalAuthorityMismatch) throws {
        try CandidateOverlayFixture.publishOptionalAuthorityMismatch(mismatch, in: self)
    }

    func installCrossComponentDerivedArtifactReuse() throws {
        try CandidateOverlayFixture.installCrossComponentDerivedArtifactReuse(in: self)
    }

    func substituteProfileSourceIntoRulesIndex() throws {
        try CandidateOverlayFixture.substituteProfileSourceIntoRulesIndex(in: self)
    }

    func driftDerivedIndexFromDelta() throws {
        try CandidateOverlayFixture.driftDerivedIndexFromDelta(in: self)
    }

    func mutateRulesIndexTopLevelID() throws {
        try CandidateOverlayFixture.mutateRulesIndexTopLevelID(in: self)
    }

    func replacePluginFilePreservingBytes(relativePath: String) throws {
        let target = pluginRoot.appendingPathComponent(relativePath)
        let replacement = target.deletingLastPathComponent().appendingPathComponent(
            ".replacement-\(UUID().uuidString)"
        )
        try Data(contentsOf: target).write(to: replacement)
        let mode = try #require(
            FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions]
                as? NSNumber
        )
        try CandidateOverlayFixture.setMode(mode.intValue, at: replacement)
        let result = replacement.path.withCString { source in
            target.path.withCString { destination in
                Darwin.rename(source, destination)
            }
        }
        try #require(result == 0)
    }

    func aliasCandidateRootToCanon() throws {
        try FileManager.default.removeItem(at: candidateRoot)
        try FileManager.default.createSymbolicLink(
            at: candidateRoot,
            withDestinationURL: canonRoot
        )
    }
}

extension CandidateOverlayFixture {
    fileprivate struct Payload {
        let relativePath: String
        let family: CandidateArtifactFamily
        let logicalID: String
        let artifactID: String
        let data: Data
    }

    fileprivate static func buildInstallation(
        plugin: URL,
        canon: URL,
        candidate: URL,
        anchor: RetainedPluginRootAnchor,
        base: CanonSnapshot,
        baseCanonEvidence: CanonSnapshotEvidence,
        pluginInventory: CanonicalTreeInventory,
        overlayID: CandidateOverlayID,
        options: Options
    ) throws -> InstalledCandidateOverlayFixture {
        let ruleTarget = "rules/core/minimal.rules.json"
        let profileTarget = "profiles/minimal.profile.json"
        let adrMetadataTarget = "adrs/ADR-9999-minimal-test.json"
        let adrMarkdownTarget = "adrs/ADR-9999-minimal-test.md"
        let chapterTarget = "chapters/core/chapter-test.chapter.json"
        let requirementsTarget = "registry/requirements.v1.json"
        let rulesIndexTarget = "registry/rules.index.json"
        let derivedIndexTarget = "registry/derived-artifacts.index.json"

        var ruleObject = try jsonObject(
            at: canon.appendingPathComponent(ruleTarget)
        )
        ruleObject["lifecycle"] = options.ruleLifecycle.rawValue
        let ruleData = try canonicalJSONObjectData(ruleObject)
        let rule = try CanonicalJSON.decode(RuleRecord.self, from: ruleData)

        let profileData = try Data(contentsOf: canon.appendingPathComponent(profileTarget))
        let profile = try CanonicalJSON.decode(ProfileRecord.self, from: profileData)

        var adrObject = try jsonObject(
            at: canon.appendingPathComponent(adrMetadataTarget)
        )
        adrObject["status"] = options.adrStatus.rawValue
        adrObject.removeValue(forKey: "accepted_at")
        let adrMetadataData = try canonicalJSONObjectData(adrObject)
        let adr = try CanonicalJSON.decode(ADRMetadata.self, from: adrMetadataData)
        let adrMarkdownData = try Data(
            contentsOf: canon.appendingPathComponent(adrMarkdownTarget)
        )
        let adrMarkdown = try #require(String(data: adrMarkdownData, encoding: .utf8))

        let chapter = try ChapterMetadata(
            schemaVersion: 1,
            id: "chapter-test",
            requirementID: RequirementID(validating: "REQ-CANON"),
            title: "Candidate overlay chapter",
            ownerRoleID: "Canon Maintainer",
            rationale: "Exercise the closed candidate chapter publication.",
            applicability: ["candidate-overlay"],
            ruleIDs: [rule.id],
            rationaleADRIDs: [adr.id],
            compliantExampleIDs: ["FIX-CANDIDATE-CHAPTER-PASS"],
            nonCompliantExampleIDs: ["FIX-CANDIDATE-CHAPTER-FAIL"],
            checkIDs: ["CHK-CANDIDATE-CHAPTER-001"],
            positiveFixtureIDs: ["FIX-CANDIDATE-CHAPTER-PASS"],
            negativeFixtureIDs: ["FIX-CANDIDATE-CHAPTER-FAIL"],
            requiredEvidenceKinds: ["candidate_overlay/v1"],
            reviewChecklistIDs: ["candidate-overlay-review"],
            exceptionPolicy: "No exceptions.",
            reviewCadence: "At every candidate publication.",
            requiredRuleDependencies: []
        )
        let chapterData = try canonicalFileData(chapter)

        let requirementsData = try Data(
            contentsOf: canon.appendingPathComponent(requirementsTarget)
        )
        let requirementRegistry = try CanonicalJSON.decode(
            RequirementRegistry.self,
            from: requirementsData
        )
        let requirement = try #require(
            requirementRegistry.requirements.first { $0.id.rawValue == "REQ-CANON" }
        )
        let traceability = try #require(
            requirementRegistry.traceability.first { $0.requirementID == requirement.id }
        )
        let requirementDigest = try CanonicalTreeDigest.sha256(
            CanonicalJSON.encode(requirement)
        )
        let traceabilityDigest = try CanonicalTreeDigest.sha256(
            CanonicalJSON.encode(traceability)
        )

        let candidateSkillData = Data("# Candidate retained skill\n".utf8)
        let ruleSemanticDigest = try RuleSemanticDigest.digest(rule)
        let adrSemanticDigest = try ADRSemanticDigest.digest(
            metadata: adr,
            markdown: adrMarkdown
        )
        let derivedEntry = try DerivedRegistrationEntry(
            indexKey: "skill.brain-execute",
            targetPath: options.pluginTargetPath,
            artifactKind: options.derivedArtifactKind,
            fileDigest: CanonicalTreeDigest.sha256(candidateSkillData),
            citedRuleIDs: [rule.id],
            citedADRIDs: [adr.id],
            sourceSemanticBindings: [
                SourceSemanticBinding(
                    sourceKind: "adr",
                    sourceID: adr.id.rawValue,
                    digest: adrSemanticDigest
                ),
                SourceSemanticBinding(
                    sourceKind: "rule",
                    sourceID: rule.id.rawValue,
                    digest: ruleSemanticDigest
                ),
            ]
        )
        let delta = try DerivedRegistrationDelta(
            schemaVersion: 1,
            deltaID: "delta-001",
            ownerRoleID: "Canon Maintainer",
            baseSnapshotContentDigest: base.snapshotContentDigest,
            entries: [derivedEntry]
        )
        let deltaData = try canonicalFileData(delta)

        let ruleDigest = CanonicalTreeDigest.sha256(ruleData)
        let profileDigest = CanonicalTreeDigest.sha256(profileData)
        let adrMetadataDigest = CanonicalTreeDigest.sha256(adrMetadataData)
        let adrMarkdownDigest = CanonicalTreeDigest.sha256(adrMarkdownData)
        let chapterDigest = CanonicalTreeDigest.sha256(chapterData)
        let requirementsDigest = CanonicalTreeDigest.sha256(requirementsData)
        let skillDigest = CanonicalTreeDigest.sha256(candidateSkillData)
        let deltaDigest = CanonicalTreeDigest.sha256(deltaData)

        let rulesIndexData = try canonicalJSONObjectData([
            "entries": [[
                "id": rule.id.rawValue,
                "record_digest": ruleDigest.rawValue,
                "relative_path": ruleTarget,
            ]],
            "id": "rules",
            "schema_version": 1,
        ])
        let derivedIndexData = try canonicalFileData(
            CandidateDerivedIndexWire(
                schemaVersion: 1,
                id: "derived-artifacts",
                entries: [derivedEntry]
            )
        )
        let rulesIndexDigest = CanonicalTreeDigest.sha256(rulesIndexData)
        let derivedIndexDigest = CanonicalTreeDigest.sha256(derivedIndexData)
        let derivedRecordDigest = try CanonicalTreeDigest.sha256(
            CanonicalJSON.encode(derivedEntry)
        )

        let payloads = [
            Payload(
                relativePath: "payloads/canon/adrs/ADR-9999-minimal-test.md",
                family: .adrMarkdown,
                logicalID: adr.id.rawValue,
                artifactID: "adr-9999-markdown",
                data: adrMarkdownData
            ),
            Payload(
                relativePath: "payloads/canon/adrs/ADR-9999-minimal-test.json",
                family: .adrMetadata,
                logicalID: adr.id.rawValue,
                artifactID: "adr-9999-metadata",
                data: adrMetadataData
            ),
            Payload(
                relativePath: "payloads/canon/chapters/core/chapter-test.chapter.json",
                family: .chapter,
                logicalID: chapter.id,
                artifactID: "chapter-test",
                data: chapterData
            ),
            Payload(
                relativePath: "payloads/evidence/checks/CHK-CAN-001.json",
                family: .check,
                logicalID: "CHK-CAN-001",
                artifactID: "check-test",
                data: Data("{\"check\":true}\n".utf8)
            ),
            Payload(
                relativePath: "payloads/canon/derived/delta-001.json",
                family: .derivedDelta,
                logicalID: delta.deltaID,
                artifactID: "delta-test",
                data: deltaData
            ),
            Payload(
                relativePath: "payloads/canon/registry/derived-artifacts.index.json",
                family: .index,
                logicalID: "derived-artifacts-index",
                artifactID: "derived-artifacts-index",
                data: derivedIndexData
            ),
            Payload(
                relativePath: "payloads/evidence/fixtures/FIX-CAN-001.json",
                family: .fixture,
                logicalID: "FIX-CAN-001",
                artifactID: "fixture-test",
                data: Data("{\"fixture\":true}\n".utf8)
            ),
            Payload(
                relativePath: "payloads/evidence/migrations/MIG-CAN-001.json",
                family: .migration,
                logicalID: "MIG-CAN-001",
                artifactID: "migration-test",
                data: Data("{\"migration\":true}\n".utf8)
            ),
            Payload(
                relativePath: "payloads/canon/profiles/minimal.profile.json",
                family: .profile,
                logicalID: profile.id.rawValue,
                artifactID: "profile-minimal",
                data: profileData
            ),
            Payload(
                relativePath: "payloads/canon/registry/requirements.v1.json",
                family: .requirementRegistry,
                logicalID: "requirements-v1",
                artifactID: "requirements",
                data: requirementsData
            ),
            Payload(
                relativePath: "payloads/canon/rules/core/minimal.rules.json",
                family: .rule,
                logicalID: rule.id.rawValue,
                artifactID: "rule-minimal",
                data: ruleData
            ),
            Payload(
                relativePath: "payloads/canon/registry/rules.index.json",
                family: .index,
                logicalID: "rules-index",
                artifactID: "rules-index",
                data: rulesIndexData
            ),
            Payload(
                relativePath: "payloads/plugin-derived/skills/brain-execute/SKILL.md",
                family: .derivedTarget,
                logicalID: derivedEntry.indexKey,
                artifactID: "skill-test",
                data: candidateSkillData
            ),
        ]

        let artifacts = try payloads.map { payload in
            try CandidateBundleArtifact(
                artifactID: payload.artifactID,
                family: payload.family,
                logicalID: payload.logicalID,
                candidateRelativePath: payload.relativePath,
                candidateFileDigest: CanonicalTreeDigest.sha256(payload.data)
            )
        }
        let canonBefore: (String) throws -> CandidateBundleBeforeEntry? = { path in
            try beforeEntry(inventory: baseCanonEvidence.fullInventory, path: path)
        }
        let pluginBefore: (String) throws -> CandidateBundleBeforeEntry? = { path in
            try beforeEntry(inventory: pluginInventory, path: path)
        }
        let publications = try [
            CandidateBundlePublication(
                publicationID: "publish-adr-9999-markdown",
                artifactID: "adr-9999-markdown",
                publicationKind: .exactCopy,
                targetNamespace: .canon,
                targetRelativePath: adrMarkdownTarget,
                targetMode: .file,
                beforeEntry: canonBefore(adrMarkdownTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-adr-9999-metadata",
                artifactID: "adr-9999-metadata",
                publicationKind: .resolverTransformed,
                targetNamespace: .canon,
                targetRelativePath: adrMetadataTarget,
                targetMode: .file,
                beforeEntry: canonBefore(adrMetadataTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-chapter-test",
                artifactID: "chapter-test",
                publicationKind: .exactCopy,
                targetNamespace: .canon,
                targetRelativePath: chapterTarget,
                targetMode: .file,
                beforeEntry: nil
            ),
            CandidateBundlePublication(
                publicationID: "publish-derived-artifacts-index",
                artifactID: "derived-artifacts-index",
                publicationKind: .resolverTransformed,
                targetNamespace: .canon,
                targetRelativePath: derivedIndexTarget,
                targetMode: .file,
                beforeEntry: canonBefore(derivedIndexTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-profile-minimal",
                artifactID: "profile-minimal",
                publicationKind: .exactCopy,
                targetNamespace: .canon,
                targetRelativePath: profileTarget,
                targetMode: .file,
                beforeEntry: canonBefore(profileTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-requirements",
                artifactID: "requirements",
                publicationKind: .resolverTransformed,
                targetNamespace: .canon,
                targetRelativePath: requirementsTarget,
                targetMode: .file,
                beforeEntry: canonBefore(requirementsTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-rule-minimal",
                artifactID: "rule-minimal",
                publicationKind: .resolverTransformed,
                targetNamespace: .canon,
                targetRelativePath: ruleTarget,
                targetMode: .file,
                beforeEntry: canonBefore(ruleTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-rules-index",
                artifactID: "rules-index",
                publicationKind: .resolverTransformed,
                targetNamespace: .canon,
                targetRelativePath: rulesIndexTarget,
                targetMode: .file,
                beforeEntry: canonBefore(rulesIndexTarget)
            ),
            CandidateBundlePublication(
                publicationID: "publish-skill-test",
                artifactID: "skill-test",
                publicationKind: .exactCopy,
                targetNamespace: .pluginDerived,
                targetRelativePath: options.pluginTargetPath,
                targetMode: options.pluginTargetMode,
                beforeEntry: options.omitPluginTargetBeforeEntry
                    ? nil
                    : pluginBefore(options.pluginTargetPath)
            ),
        ]
        let bundle = try CandidateComponentBundle(
            schemaVersion: 1,
            schemaIdentity: .v1,
            schemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentID: "core-authority-v1",
            componentKind: options.componentKind,
            accountableOwnerRoleID: "Canon Maintainer",
            bundleRelativePath: "components/core-authority-v1.bundle.json",
            artifacts: artifacts,
            publications: publications,
            targetDirectories: []
        )
        let bundleData = try canonicalFileData(bundle)
        let componentDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: bundleData
        )
        let reviewed = try reviewedComponent(
            componentKind: options.componentKind,
            componentDigest: componentDigest
        )

        let manifest = try CandidateOverlayManifest(
            schemaVersion: 1,
            overlayID: overlayID.rawValue,
            targetCanonVersion: 1,
            targetProductVersion: "1.0.0-rc.1",
            baseSnapshotContentDigest: base.snapshotContentDigest,
            activationTransformIdentity: CandidateOverlayTransformDescriptor.v1.identity,
            activationTransformDigest: CandidateOverlayTransformDescriptor.v1.digest,
            reviewedComponents: [reviewed],
            rules: [
                RuleOverlayBinding(
                    id: rule.id,
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "rule-minimal",
                    bundlePublicationID: "publish-rule-minimal",
                    targetRelativePath: ruleTarget,
                    semanticDigest: ruleSemanticDigest,
                    beforeFullDigest: canonBefore(ruleTarget)?.contentSHA256,
                    candidateFullDigest: ruleDigest
                ),
            ],
            profiles: [
                ProfileOverlayBinding(
                    id: profile.id,
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "profile-minimal",
                    bundlePublicationID: "publish-profile-minimal",
                    targetRelativePath: profileTarget,
                    candidateFullDigest: profileDigest,
                    orderedRuleIDs: [rule.id]
                ),
            ],
            adrs: [
                ADROverlayBinding(
                    id: adr.id,
                    reviewedComponentID: reviewed.componentID,
                    metadataBundleArtifactID: "adr-9999-metadata",
                    metadataBundlePublicationID: "publish-adr-9999-metadata",
                    metadataTargetRelativePath: adrMetadataTarget,
                    markdownBundleArtifactID: "adr-9999-markdown",
                    markdownBundlePublicationID: "publish-adr-9999-markdown",
                    markdownTargetRelativePath: adrMarkdownTarget,
                    semanticDigest: adrSemanticDigest,
                    beforeMetadataFullDigest: canonBefore(adrMetadataTarget)?.contentSHA256,
                    candidateMetadataFullDigest: adrMetadataDigest,
                    candidateMarkdownFullDigest: adrMarkdownDigest
                ),
            ],
            chapters: [
                ChapterOverlayBinding(
                    id: chapter.id,
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "chapter-test",
                    bundlePublicationID: "publish-chapter-test",
                    targetRelativePath: chapterTarget,
                    candidateFileDigest: chapterDigest
                ),
            ],
            requirementRegistry: RequirementRegistryOverlayBinding(
                reviewedComponentID: reviewed.componentID,
                bundleArtifactID: "requirements",
                bundlePublicationID: "publish-requirements",
                targetRelativePath: requirementsTarget,
                beforeFullDigest: canonBefore(requirementsTarget)?.contentSHA256,
                candidateFullDigest: requirementsDigest,
                records: [
                    RequirementRecordOverlayBinding(
                        id: requirement.id,
                        beforeRequirementRecordDigest: requirementDigest,
                        beforeTraceabilityRecordDigest: traceabilityDigest,
                        candidateRequirementRecordDigest: requirementDigest,
                        candidateTraceabilityRecordDigest: traceabilityDigest
                    ),
                ]
            ),
            checks: [
                OptionalPublicationArtifactBinding(
                    id: "CHK-CAN-001",
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "check-test",
                    candidateFileDigest: digest(for: "check-test", in: payloads),
                    bundlePublicationID: nil,
                    targetRelativePath: nil
                ),
            ],
            fixtures: [
                OptionalPublicationArtifactBinding(
                    id: "FIX-CAN-001",
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "fixture-test",
                    candidateFileDigest: digest(for: "fixture-test", in: payloads),
                    bundlePublicationID: nil,
                    targetRelativePath: nil
                ),
            ],
            migrations: [
                OptionalPublicationArtifactBinding(
                    id: "MIG-CAN-001",
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "migration-test",
                    candidateFileDigest: digest(for: "migration-test", in: payloads),
                    bundlePublicationID: nil,
                    targetRelativePath: nil
                ),
            ],
            indexes: [
                IndexOverlayBinding(
                    id: "derived-artifacts-index",
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "derived-artifacts-index",
                    bundlePublicationID: "publish-derived-artifacts-index",
                    targetRelativePath: derivedIndexTarget,
                    beforeFullDigest: canonBefore(derivedIndexTarget)?.contentSHA256,
                    candidateFullDigest: derivedIndexDigest,
                    entries: [
                        IndexEntryOverlayBinding(
                            id: derivedEntry.indexKey,
                            candidateRecordDigest: derivedRecordDigest
                        ),
                    ]
                ),
                IndexOverlayBinding(
                    id: "rules-index",
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "rules-index",
                    bundlePublicationID: "publish-rules-index",
                    targetRelativePath: rulesIndexTarget,
                    beforeFullDigest: canonBefore(rulesIndexTarget)?.contentSHA256,
                    candidateFullDigest: rulesIndexDigest,
                    entries: [
                        IndexEntryOverlayBinding(
                            id: rule.id.rawValue,
                            candidateRecordDigest: ruleDigest
                        ),
                    ]
                ),
            ],
            derivedRegistrationDeltas: [
                DerivedRegistrationOverlayBinding(
                    deltaID: delta.deltaID,
                    reviewedComponentID: reviewed.componentID,
                    bundleArtifactID: "delta-test",
                    candidateDeltaDigest: deltaDigest,
                    targets: [
                        DerivedTargetBinding(
                            indexKey: derivedEntry.indexKey,
                            bundleArtifactID: "skill-test",
                            bundlePublicationID: "publish-skill-test",
                            targetRelativePath: options.pluginTargetPath,
                            candidateFileDigest: skillDigest
                        ),
                    ]
                ),
            ],
            activationTransformSet: ActivationTransformSet(
                rules: [
                    RuleActivationTransform(
                        id: rule.id,
                        lifecycleSource: .constantActive,
                        effectiveInSource: .targetProductVersion
                    ),
                ],
                adrs: [
                    ADRActivationTransform(
                        id: adr.id,
                        statusSource: .constantAccepted,
                        acceptedAtSource: .integrationApprovalTimestamp
                    ),
                ],
                requirements: [
                    RequirementActivationTransform(
                        id: requirement.id,
                        targetStatus: .completed
                    ),
                ],
                indexEntries: [
                    IndexEntryActivationTransform(
                        indexID: "derived-artifacts-index",
                        entryID: derivedEntry.indexKey,
                        sourceKind: .derivedRegistrationEntry,
                        sourceID: derivedEntry.indexKey,
                        sourceRelativePath: options.pluginTargetPath
                    ),
                    IndexEntryActivationTransform(
                        indexID: "rules-index",
                        entryID: rule.id.rawValue,
                        sourceKind: .ruleRecord,
                        sourceID: rule.id.rawValue,
                        sourceRelativePath: ruleTarget
                    ),
                ],
                derivedPublications: [
                    DerivedPublicationTransform(
                        deltaID: delta.deltaID,
                        indexKey: derivedEntry.indexKey,
                        bundleArtifactID: "skill-test",
                        bundlePublicationID: "publish-skill-test"
                    ),
                ]
            )
        )

        for payload in payloads {
            try writeCandidateFile(
                payload.data,
                relativePath: payload.relativePath,
                candidate: candidate
            )
        }
        try writeCandidateFile(
            bundleData,
            relativePath: bundle.bundleRelativePath,
            candidate: candidate
        )
        try writeCandidateFile(
            canonicalFileData(manifest),
            relativePath: "candidate-overlay.v1.json",
            candidate: candidate
        )
        try normalizeCandidateModes(candidate)

        return InstalledCandidateOverlayFixture(
            workspace: plugin.deletingLastPathComponent(),
            pluginRoot: plugin,
            canonRoot: canon,
            candidateRoot: candidate,
            anchor: anchor,
            overlayID: overlayID,
            baseSnapshot: base,
            manifest: manifest,
            bundle: bundle
        )
    }

    fileprivate static func installTwoComponentMutation(
        _ mutation: TwoComponentFixtureMutation,
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let secondaryComponentID = "secondary-authority-v1"
        let primaryTarget = "standards/specs/EXAMPLES.md"
        let secondaryTarget = switch mutation {
        case .duplicateCandidateSource, .missingComponentLocalParent:
            "standards/specs/EXAMPLES_EXTENSIBLE_PROVIDER.md"
        case .fileDirectoryConflict:
            "standards/specs/EXAMPLES.md/child.json"
        }
        let primaryCandidatePath = "payloads/evidence/fixtures/FIX-CAN-001.json"
        let secondaryCandidatePath = mutation == .duplicateCandidateSource
            ? primaryCandidatePath
            : "payloads/evidence/fixtures/FIX-CAN-002.json"
        let secondaryBytes: Data
        if mutation == .duplicateCandidateSource {
            secondaryBytes = try Data(
                contentsOf: fixture.candidateRoot.appendingPathComponent(primaryCandidatePath)
            )
        } else {
            secondaryBytes = Data("{\"fixture\":2}\n".utf8)
            try writeCandidateFile(
                secondaryBytes,
                relativePath: secondaryCandidatePath,
                candidate: fixture.candidateRoot
            )
        }

        var manifestObject = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        var primaryBundle = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent(fixture.bundle.bundleRelativePath)
        )
        if mutation != .duplicateCandidateSource {
            let primaryPublication = try CandidateBundlePublication(
                publicationID: "publish-fixture-primary",
                artifactID: "fixture-test",
                publicationKind: .exactCopy,
                targetNamespace: .pluginDerived,
                targetRelativePath: primaryTarget,
                targetMode: .file,
                beforeEntry: nil
            )
            let primaryDirectory = try CandidateBundleTargetDirectory(
                directoryID: "primary-specs-parent",
                targetNamespace: .pluginDerived,
                targetRelativePath: "standards/specs",
                mode: .executable,
                publicationIDs: [primaryPublication.publicationID]
            )
            try appendEncoded(primaryPublication, to: "publications", in: &primaryBundle) {
                ($0["publication_id"] as? String) ?? ""
            }
            try appendEncoded(primaryDirectory, to: "target_directories", in: &primaryBundle) {
                ($0["directory_id"] as? String) ?? ""
            }
            try updateOptionalBinding(
                key: "fixtures",
                id: "FIX-CAN-001",
                publicationID: primaryPublication.publicationID,
                targetPath: primaryTarget,
                in: &manifestObject
            )
        }

        let secondaryArtifact = try CandidateBundleArtifact(
            artifactID: "fixture-secondary",
            family: .fixture,
            logicalID: "FIX-CAN-002",
            candidateRelativePath: secondaryCandidatePath,
            candidateFileDigest: CanonicalTreeDigest.sha256(secondaryBytes)
        )
        let secondaryPublication = try CandidateBundlePublication(
            publicationID: "publish-fixture-secondary",
            artifactID: secondaryArtifact.artifactID,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetRelativePath: secondaryTarget,
            targetMode: .file,
            beforeEntry: nil
        )
        let secondaryDirectories: [CandidateBundleTargetDirectory] = switch mutation {
        case .duplicateCandidateSource:
            try [CandidateBundleTargetDirectory(
                directoryID: "secondary-specs-parent",
                targetNamespace: .pluginDerived,
                targetRelativePath: "standards/specs",
                mode: .executable,
                publicationIDs: [secondaryPublication.publicationID]
            )]
        case .fileDirectoryConflict:
            try [CandidateBundleTargetDirectory(
                directoryID: "secondary-file-parent",
                targetNamespace: .pluginDerived,
                targetRelativePath: primaryTarget,
                mode: .executable,
                publicationIDs: [secondaryPublication.publicationID]
            )]
        case .missingComponentLocalParent:
            []
        }
        let secondaryBundle = try CandidateComponentBundle(
            schemaVersion: 1,
            schemaIdentity: .v1,
            schemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentID: secondaryComponentID,
            componentKind: "enterprise-routing",
            accountableOwnerRoleID: "Canon Maintainer",
            bundleRelativePath: "components/\(secondaryComponentID).bundle.json",
            artifacts: [secondaryArtifact],
            publications: [secondaryPublication],
            targetDirectories: secondaryDirectories
        )
        let secondaryData = try canonicalFileData(secondaryBundle)
        try writeCandidateFile(
            secondaryData,
            relativePath: secondaryBundle.bundleRelativePath,
            candidate: fixture.candidateRoot
        )
        let secondaryDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: secondaryData
        )
        let reviewed = try reviewedComponent(
            componentKind: secondaryBundle.componentKind,
            componentDigest: secondaryDigest,
            componentID: secondaryComponentID,
            identitySuffix: "secondary"
        )
        try appendEncoded(reviewed, to: "reviewed_components", in: &manifestObject) {
            ($0["component_id"] as? String) ?? ""
        }
        var fixtures = try #require(manifestObject["fixtures"] as? [[String: Any]])
        fixtures.append([
            "bundle_artifact_id": secondaryArtifact.artifactID,
            "bundle_publication_id": secondaryPublication.publicationID,
            "candidate_file_digest": secondaryArtifact.candidateFileDigest.rawValue,
            "id": "FIX-CAN-002",
            "reviewed_component_id": secondaryComponentID,
            "target_relative_path": secondaryTarget,
        ])
        fixtures.sort { (($0["id"] as? String) ?? "") < (($1["id"] as? String) ?? "") }
        manifestObject["fixtures"] = fixtures
        try writeReboundPrimaryBundle(
            primaryBundle,
            manifestObject: &manifestObject,
            fixture: fixture
        )
        try writeCanonicalJSONObject(
            manifestObject,
            to: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
    }

    fileprivate static func publishOptionalAuthorityMismatch(
        _ mismatch: OptionalAuthorityMismatch,
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let specification: (key: String, id: String, artifactID: String, target: String)
            = switch mismatch
        {
        case .check:
            ("checks", "CHK-CAN-001", "check-test", "standards/specs/EXAMPLES_EXTENSIBLE_PROVIDER.md")
        case .fixture:
            ("fixtures", "FIX-CAN-001", "fixture-test", "standards/specs/BROWNFIELD_MIGRATION.md")
        case .migration:
            ("migrations", "MIG-CAN-001", "migration-test", "standards/specs/EXAMPLES_PLUGIN.md")
        }
        let publication = try CandidateBundlePublication(
            publicationID: "publish-\(mismatch.rawValue)-mismatch",
            artifactID: specification.artifactID,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetRelativePath: specification.target,
            targetMode: .file,
            beforeEntry: nil
        )
        let directory = try CandidateBundleTargetDirectory(
            directoryID: "\(mismatch.rawValue)-specs-parent",
            targetNamespace: .pluginDerived,
            targetRelativePath: "standards/specs",
            mode: .executable,
            publicationIDs: [publication.publicationID]
        )
        var bundleObject = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent(fixture.bundle.bundleRelativePath)
        )
        try appendEncoded(publication, to: "publications", in: &bundleObject) {
            ($0["publication_id"] as? String) ?? ""
        }
        try appendEncoded(directory, to: "target_directories", in: &bundleObject) {
            ($0["directory_id"] as? String) ?? ""
        }
        var manifestObject = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        try updateOptionalBinding(
            key: specification.key,
            id: specification.id,
            publicationID: publication.publicationID,
            targetPath: specification.target,
            in: &manifestObject
        )
        try writeReboundPrimaryBundle(
            bundleObject,
            manifestObject: &manifestObject,
            fixture: fixture
        )
        try writeCanonicalJSONObject(
            manifestObject,
            to: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
    }

    fileprivate static func substituteProfileSourceIntoRulesIndex(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        var manifest = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        let profile = try #require((manifest["profiles"] as? [[String: Any]])?.first)
        let profileID = try #require(profile["id"] as? String)
        let profilePath = try #require(profile["target_relative_path"] as? String)
        let profileDigest = try #require(profile["candidate_full_digest"] as? String)
        try mutateIndexPayload(
            artifactID: "rules-index",
            relativePath: "payloads/canon/registry/rules.index.json",
            targetPath: "registry/rules.index.json",
            fixture: fixture,
            manifest: &manifest
        ) { indexObject, binding, manifestObject in
            var entries = try #require(indexObject["entries"] as? [[String: Any]])
            entries[0]["relative_path"] = profilePath
            entries[0]["record_digest"] = profileDigest
            indexObject["entries"] = entries
            var declared = try #require(binding["entries"] as? [[String: Any]])
            declared[0]["candidate_record_digest"] = profileDigest
            binding["entries"] = declared
            var transformSet = try #require(
                manifestObject["activation_transform_set"] as? [String: Any]
            )
            var transforms = try #require(
                transformSet["index_entries"] as? [[String: Any]]
            )
            let index = try #require(transforms.firstIndex {
                $0["index_id"] as? String == "rules-index"
            })
            transforms[index]["source_kind"] = "profile_record"
            transforms[index]["source_id"] = profileID
            transforms[index]["source_relative_path"] = profilePath
            transformSet["index_entries"] = transforms
            manifestObject["activation_transform_set"] = transformSet
        }
    }

    fileprivate static func driftDerivedIndexFromDelta(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        var manifest = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        try mutateIndexPayload(
            artifactID: "derived-artifacts-index",
            relativePath: "payloads/canon/registry/derived-artifacts.index.json",
            targetPath: "registry/derived-artifacts.index.json",
            fixture: fixture,
            manifest: &manifest
        ) { indexObject, binding, _ in
            var entries = try #require(indexObject["entries"] as? [[String: Any]])
            entries[0]["artifact_kind"] = DerivedArtifactKind.agent.rawValue
            indexObject["entries"] = entries
            let recordDigest = try CanonicalTreeDigest.sha256(
                canonicalJSONValueData(entries[0])
            )
            var declared = try #require(binding["entries"] as? [[String: Any]])
            declared[0]["candidate_record_digest"] = recordDigest.rawValue
            binding["entries"] = declared
        }
    }

    fileprivate static func mutateRulesIndexTopLevelID(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        var manifest = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        try mutateIndexPayload(
            artifactID: "rules-index",
            relativePath: "payloads/canon/registry/rules.index.json",
            targetPath: "registry/rules.index.json",
            fixture: fixture,
            manifest: &manifest
        ) { indexObject, _, _ in
            indexObject["id"] = "profiles"
        }
    }

    fileprivate static func installCrossComponentDerivedArtifactReuse(
        in fixture: InstalledCandidateOverlayFixture
    ) throws {
        let componentID = "secondary-derived-v1"
        let indexKey = "skill.secondary"
        let targetPath = "skills/brain-design/SKILL.md"
        let targetBytes = Data("# Secondary derived target\n".utf8)
        let primaryDeltaData = try Data(
            contentsOf: fixture.candidateRoot.appendingPathComponent(
                "payloads/canon/derived/delta-001.json"
            )
        )
        let primaryDelta = try CanonicalJSON.decode(
            DerivedRegistrationDelta.self,
            from: primaryDeltaData
        )
        let primaryEntry = try #require(primaryDelta.entries.first)
        let secondaryEntry = try DerivedRegistrationEntry(
            indexKey: indexKey,
            targetPath: targetPath,
            artifactKind: .agent,
            fileDigest: CanonicalTreeDigest.sha256(targetBytes),
            citedRuleIDs: primaryEntry.citedRuleIDs,
            citedADRIDs: primaryEntry.citedADRIDs,
            sourceSemanticBindings: primaryEntry.sourceSemanticBindings
        )
        let delta = try DerivedRegistrationDelta(
            schemaVersion: 1,
            deltaID: "delta-002",
            ownerRoleID: "Canon Maintainer",
            baseSnapshotContentDigest: fixture.baseSnapshot.snapshotContentDigest,
            entries: [secondaryEntry]
        )
        let deltaData = try canonicalFileData(delta)
        let deltaPath = "payloads/canon/derived/delta-002.json"
        let targetCandidatePath = "payloads/plugin-derived/skills/brain-design/SKILL.md"
        try writeCandidateFile(deltaData, relativePath: deltaPath, candidate: fixture.candidateRoot)
        try writeCandidateFile(
            targetBytes,
            relativePath: targetCandidatePath,
            candidate: fixture.candidateRoot
        )
        let deltaArtifact = try CandidateBundleArtifact(
            artifactID: "delta-secondary",
            family: .derivedDelta,
            logicalID: delta.deltaID,
            candidateRelativePath: deltaPath,
            candidateFileDigest: CanonicalTreeDigest.sha256(deltaData)
        )
        let targetArtifact = try CandidateBundleArtifact(
            artifactID: "skill-test",
            family: .derivedTarget,
            logicalID: indexKey,
            candidateRelativePath: targetCandidatePath,
            candidateFileDigest: CanonicalTreeDigest.sha256(targetBytes)
        )
        let publication = try CandidateBundlePublication(
            publicationID: "publish-skill-secondary",
            artifactID: targetArtifact.artifactID,
            publicationKind: .exactCopy,
            targetNamespace: .pluginDerived,
            targetRelativePath: targetPath,
            targetMode: .file,
            beforeEntry: nil
        )
        let directory = try CandidateBundleTargetDirectory(
            directoryID: "secondary-skill-parent",
            targetNamespace: .pluginDerived,
            targetRelativePath: "skills/brain-design",
            mode: .executable,
            publicationIDs: [publication.publicationID]
        )
        let secondaryBundle = try CandidateComponentBundle(
            schemaVersion: 1,
            schemaIdentity: .v1,
            schemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentID: componentID,
            componentKind: "enterprise-routing",
            accountableOwnerRoleID: "Canon Maintainer",
            bundleRelativePath: "components/\(componentID).bundle.json",
            artifacts: [deltaArtifact, targetArtifact],
            publications: [publication],
            targetDirectories: [directory]
        )
        let secondaryBundleData = try canonicalFileData(secondaryBundle)
        try writeCandidateFile(
            secondaryBundleData,
            relativePath: secondaryBundle.bundleRelativePath,
            candidate: fixture.candidateRoot
        )
        let reviewed = try reviewedComponent(
            componentKind: secondaryBundle.componentKind,
            componentDigest: ComponentBundleSchemaIdentity.v1.componentDigest(
                for: secondaryBundleData
            ),
            componentID: componentID,
            identitySuffix: "secondary-derived"
        )

        let derivedIndexPath = "payloads/canon/registry/derived-artifacts.index.json"
        let derivedIndexURL = fixture.candidateRoot.appendingPathComponent(derivedIndexPath)
        var derivedIndex = try jsonObject(at: derivedIndexURL)
        var indexEntries = try #require(derivedIndex["entries"] as? [[String: Any]])
        try indexEntries.append(jsonObject(secondaryEntry))
        indexEntries.sort {
            (($0["target_path"] as? String) ?? "") < (($1["target_path"] as? String) ?? "")
        }
        derivedIndex["entries"] = indexEntries
        try writeCanonicalJSONObject(derivedIndex, to: derivedIndexURL)
        let derivedIndexDigest = try CanonicalTreeDigest.sha256(
            Data(contentsOf: derivedIndexURL)
        )
        let secondaryRecordDigest = try CanonicalTreeDigest.sha256(
            CanonicalJSON.encode(secondaryEntry)
        )

        var manifest = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        try appendEncoded(reviewed, to: "reviewed_components", in: &manifest) {
            ($0["component_id"] as? String) ?? ""
        }
        let targetBinding = try DerivedTargetBinding(
            indexKey: indexKey,
            bundleArtifactID: targetArtifact.artifactID,
            bundlePublicationID: publication.publicationID,
            targetRelativePath: targetPath,
            candidateFileDigest: targetArtifact.candidateFileDigest
        )
        let deltaBinding = try DerivedRegistrationOverlayBinding(
            deltaID: delta.deltaID,
            reviewedComponentID: componentID,
            bundleArtifactID: deltaArtifact.artifactID,
            candidateDeltaDigest: deltaArtifact.candidateFileDigest,
            targets: [targetBinding]
        )
        try appendEncoded(deltaBinding, to: "derived_registration_deltas", in: &manifest) {
            ($0["delta_id"] as? String) ?? ""
        }

        var indexes = try #require(manifest["indexes"] as? [[String: Any]])
        let derivedBindingIndex = try #require(indexes.firstIndex {
            $0["target_relative_path"] as? String
                == "registry/derived-artifacts.index.json"
        })
        var derivedBinding = indexes[derivedBindingIndex]
        derivedBinding["candidate_full_digest"] = derivedIndexDigest.rawValue
        var declaredEntries = try #require(
            derivedBinding["entries"] as? [[String: Any]]
        )
        declaredEntries.append([
            "candidate_record_digest": secondaryRecordDigest.rawValue,
            "id": indexKey,
        ])
        declaredEntries.sort {
            (($0["id"] as? String) ?? "") < (($1["id"] as? String) ?? "")
        }
        derivedBinding["entries"] = declaredEntries
        indexes[derivedBindingIndex] = derivedBinding
        manifest["indexes"] = indexes

        var transformSet = try #require(
            manifest["activation_transform_set"] as? [String: Any]
        )
        let indexTransform = try IndexEntryActivationTransform(
            indexID: "derived-artifacts-index",
            entryID: indexKey,
            sourceKind: .derivedRegistrationEntry,
            sourceID: indexKey,
            sourceRelativePath: targetPath
        )
        try appendEncoded(indexTransform, to: "index_entries", in: &transformSet) {
            (($0["index_id"] as? String) ?? "") + "\0"
                + (($0["entry_id"] as? String) ?? "")
        }
        let publicationTransform = try DerivedPublicationTransform(
            deltaID: delta.deltaID,
            indexKey: indexKey,
            bundleArtifactID: targetArtifact.artifactID,
            bundlePublicationID: publication.publicationID
        )
        try appendEncoded(
            publicationTransform,
            to: "derived_publications",
            in: &transformSet
        ) {
            (($0["delta_id"] as? String) ?? "") + "\0"
                + (($0["index_key"] as? String) ?? "")
        }
        manifest["activation_transform_set"] = transformSet

        var primaryBundle = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent(fixture.bundle.bundleRelativePath)
        )
        try updateArtifactDigest(
            artifactID: "derived-artifacts-index",
            digest: derivedIndexDigest,
            in: &primaryBundle
        )
        try writeReboundPrimaryBundle(
            primaryBundle,
            manifestObject: &manifest,
            fixture: fixture
        )
        try writeCanonicalJSONObject(
            manifest,
            to: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
        try normalizeCandidateModes(fixture.candidateRoot)
    }

    fileprivate static func mutateIndexPayload(
        artifactID: String,
        relativePath: String,
        targetPath: String,
        fixture: InstalledCandidateOverlayFixture,
        manifest: inout [String: Any],
        mutation: (
            inout [String: Any],
            inout [String: Any],
            inout [String: Any]
        ) throws -> Void
    ) throws {
        let payloadURL = fixture.candidateRoot.appendingPathComponent(relativePath)
        var indexObject = try jsonObject(at: payloadURL)
        var indexes = try #require(manifest["indexes"] as? [[String: Any]])
        let bindingIndex = try #require(indexes.firstIndex {
            $0["target_relative_path"] as? String == targetPath
        })
        var binding = indexes[bindingIndex]
        try mutation(&indexObject, &binding, &manifest)
        try writeCanonicalJSONObject(indexObject, to: payloadURL)
        let payloadDigest = try CanonicalTreeDigest.sha256(Data(contentsOf: payloadURL))
        binding["candidate_full_digest"] = payloadDigest.rawValue
        indexes[bindingIndex] = binding
        manifest["indexes"] = indexes

        var bundleObject = try jsonObject(
            at: fixture.candidateRoot.appendingPathComponent(fixture.bundle.bundleRelativePath)
        )
        try updateArtifactDigest(
            artifactID: artifactID,
            digest: payloadDigest,
            in: &bundleObject
        )
        try writeReboundPrimaryBundle(
            bundleObject,
            manifestObject: &manifest,
            fixture: fixture
        )
        try writeCanonicalJSONObject(
            manifest,
            to: fixture.candidateRoot.appendingPathComponent("candidate-overlay.v1.json")
        )
    }

    fileprivate static func writeReboundPrimaryBundle(
        _ bundleObject: [String: Any],
        manifestObject: inout [String: Any],
        fixture: InstalledCandidateOverlayFixture
    ) throws {
        let bundleURL = fixture.candidateRoot.appendingPathComponent(
            fixture.bundle.bundleRelativePath
        )
        try writeCanonicalJSONObject(bundleObject, to: bundleURL)
        let componentDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: Data(contentsOf: bundleURL)
        )
        var reviewed = try #require(
            manifestObject["reviewed_components"] as? [[String: Any]]
        )
        let index = try #require(reviewed.firstIndex {
            $0["component_id"] as? String == fixture.bundle.componentID
        })
        var component = reviewed[index]
        component["component_digest"] = componentDigest.rawValue
        for key in ["accountable_owner_approval", "independent_reviewer_approval"] {
            var approval = try #require(component[key] as? [String: Any])
            approval["reviewed_component_digest"] = componentDigest.rawValue
            component[key] = approval
        }
        reviewed[index] = component
        manifestObject["reviewed_components"] = reviewed
    }

    fileprivate static func updateArtifactDigest(
        artifactID: String,
        digest: HashDigest,
        in bundle: inout [String: Any]
    ) throws {
        var artifacts = try #require(bundle["artifacts"] as? [[String: Any]])
        let index = try #require(artifacts.firstIndex {
            $0["artifact_id"] as? String == artifactID
        })
        artifacts[index]["candidate_file_digest"] = digest.rawValue
        bundle["artifacts"] = artifacts
    }

    fileprivate static func updateOptionalBinding(
        key: String,
        id: String,
        publicationID: String,
        targetPath: String,
        in manifest: inout [String: Any]
    ) throws {
        var values = try #require(manifest[key] as? [[String: Any]])
        let index = try #require(values.firstIndex { $0["id"] as? String == id })
        values[index]["bundle_publication_id"] = publicationID
        values[index]["target_relative_path"] = targetPath
        manifest[key] = values
    }

    fileprivate static func appendEncoded(
        _ value: some Encodable,
        to key: String,
        in object: inout [String: Any],
        order: ([String: Any]) -> String
    ) throws {
        var values = try #require(object[key] as? [[String: Any]])
        try values.append(jsonObject(value))
        values.sort { order($0).utf8.lexicographicallyPrecedes(order($1).utf8) }
        object[key] = values
    }

    fileprivate static func jsonObject(_ value: some Encodable) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: CanonicalJSON.encode(value))
                as? [String: Any]
        )
    }

    fileprivate static func canonicalJSONValueData(_ value: Any) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    static func retainedAnchor(at plugin: URL) throws -> RetainedPluginRootAnchor {
        let descriptor = plugin.path.withCString {
            Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        try #require(descriptor >= 0)
        defer { Darwin.close(descriptor) }
        return try RetainedPluginRootAnchor(
            duplicatingPluginRootDirectoryDescriptor: descriptor,
            path: plugin.path
        )
    }

    fileprivate static func reviewedComponent(
        componentKind: String,
        componentDigest: HashDigest,
        componentID: String = "core-authority-v1",
        identitySuffix: String = ""
    ) throws -> ReviewedComponentApproval {
        let suffix = identitySuffix.isEmpty ? "" : "-" + identitySuffix
        let owner = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "approval-owner\(suffix)",
            principalID: "principal-owner\(suffix)",
            actorID: "actor-owner\(suffix)",
            roleID: "Canon Maintainer",
            reviewedComponentID: componentID,
            reviewedComponentDigest: componentDigest,
            attestationID: "attestation-owner\(suffix)",
            attestationDigest: CanonicalTreeDigest.sha256(Data("owner\(suffix)".utf8))
        )
        let reviewer = try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "approval-reviewer\(suffix)",
            principalID: "principal-reviewer\(suffix)",
            actorID: "actor-reviewer\(suffix)",
            roleID: "Independent Reviewer",
            reviewedComponentID: componentID,
            reviewedComponentDigest: componentDigest,
            attestationID: "attestation-reviewer\(suffix)",
            attestationDigest: CanonicalTreeDigest.sha256(Data("reviewer\(suffix)".utf8))
        )
        return try ReviewedComponentApproval(
            componentID: componentID,
            componentKind: componentKind,
            bundleRelativePath: "components/\(componentID).bundle.json",
            bundleSchemaIdentity: .v1,
            bundleSchemaDigest: ComponentBundleSchemaIdentity.v1.schemaDigest,
            componentDigest: componentDigest,
            accountableOwnerRoleID: "Canon Maintainer",
            accountableOwnerApproval: owner,
            independentReviewerApproval: reviewer
        )
    }

    fileprivate static func beforeEntry(
        inventory: CanonicalTreeInventory,
        path: String
    ) throws -> CandidateBundleBeforeEntry? {
        guard let entry = inventory.entries.first(where: { $0.relativePath == path }) else {
            return nil
        }
        guard entry.kind == .regularFile,
              let digest = entry.contentSHA256,
              let mode = CandidatePortableMode(rawValue: entry.mode)
        else {
            throw ContractError.invalidContract(
                kind: "candidate_fixture_before_entry",
                reason: "existing target must be a supported regular file"
            )
        }
        return try CandidateBundleBeforeEntry(
            kind: .regularFile,
            contentSHA256: digest,
            mode: mode
        )
    }

    fileprivate static func digest(for artifactID: String, in payloads: [Payload]) throws -> HashDigest {
        try CanonicalTreeDigest.sha256(
            #require(payloads.first { $0.artifactID == artifactID }).data
        )
    }

    static func canonicalFileData(_ value: some Encodable) throws -> Data {
        var data = try CanonicalJSON.encode(value)
        data.append(0x0A)
        return data
    }

    static func jsonObject(at url: URL) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }

    static func canonicalJSONObjectData(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    static func writeCanonicalJSONObject(_ object: [String: Any], to url: URL) throws {
        try canonicalJSONObjectData(object).write(to: url, options: .atomic)
        try setMode(0o644, at: url)
    }

    fileprivate static func writeCandidateFile(
        _ data: Data,
        relativePath: String,
        candidate: URL
    ) throws {
        let url = candidate.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try setMode(0o644, at: url)
    }

    fileprivate static func normalizeCandidateModes(_ candidate: URL) throws {
        try setMode(0o755, at: candidate)
        guard let enumerator = FileManager.default.enumerator(
            at: candidate,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: nil
        ) else {
            throw ContractError.invalidContract(
                kind: "candidate_fixture",
                reason: "candidate tree cannot be enumerated"
            )
        }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            try setMode(values.isDirectory == true ? 0o755 : 0o644, at: url)
        }
    }

    static func setMode(_ mode: Int, at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: mode],
            ofItemAtPath: url.path
        )
    }

    fileprivate static func setDirectoryModes(from leaf: URL, through root: URL) throws {
        var cursor = leaf
        while cursor.path.hasPrefix(root.path) {
            try setMode(0o755, at: cursor)
            guard cursor != root else { break }
            cursor.deleteLastPathComponent()
        }
    }
}

private struct CandidateDerivedIndexWire: Encodable {
    let schemaVersion: Int
    let id: String
    let entries: [DerivedRegistrationEntry]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case entries
    }
}

final class CandidateOverlayEventStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [CandidateOverlayValidationEvent] = []

    var events: [CandidateOverlayValidationEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    func record(_ event: CandidateOverlayValidationEvent) {
        lock.lock()
        storedEvents.append(event)
        lock.unlock()
    }
}

final class CandidateOverlayMutation: @unchecked Sendable {
    private let lock = NSLock()
    private var hasRun = false
    private let operation: () throws -> Void

    init(_ operation: @escaping () throws -> Void) {
        self.operation = operation
    }

    func runOnce() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !hasRun else { return }
        hasRun = true
        try operation()
    }
}
