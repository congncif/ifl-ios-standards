import Foundation
@testable import IFLContracts
import Testing

@Suite("CandidateOverlayTransformContractTests")
struct CandidateOverlayTransformContractTests {
    @Test("compiled transform descriptor binds every frozen schema, policy, and authority identity")
    func transformDescriptorParity() throws {
        let descriptor = CandidateOverlayTransformDescriptor.v1
        let fixtureData = try Data(contentsOf: descriptorFixtureURL)
        #expect(try descriptor.canonicalFileData() == fixtureData)
        #expect(descriptor.digest == CanonicalTreeDigest.sha256(fixtureData))
        #expect(descriptor.identity == "urn:ifl:standards:canon-activation-transform:v1")
        #expect(descriptor.overlaySchemaIdentity == "urn:ifl:standards:schema:candidate-overlay:v1")
        #expect(try descriptor.overlaySchemaDigest == CanonicalTreeDigest.sha256(Data(contentsOf: overlaySchemaURL)))
        #expect(descriptor.componentBundleSchemaIdentity == .v1)
        #expect(descriptor.componentBundleSchemaDigest == ComponentBundleSchemaIdentity.v1.schemaDigest)
        #expect(descriptor.publicationAuthorityMapIdentity == CandidatePublicationAuthorityMap.v1.identity)
        #expect(descriptor.publicationAuthorityMapDigest == CandidatePublicationAuthorityMap.v1.digest)
        #expect(descriptor.pathNamespacePolicy == "canon-and-plugin-derived-exact-paths/v1")
        #expect(descriptor.publicationModePolicy == "portable-modes-420-493/v1")
        #expect(descriptor.mutationPolicy == "no-delete-no-existing-chmod/v1")
        #expect(descriptor.canonSnapshotContentPolicyVersion == 1)
        #expect(descriptor.fullPluginInventoryPolicyVersion == 1)
        #expect(descriptor.transformAlgorithmVersion == 1)
    }

    @Test("typed transform set is closed, canonical, and complete for mutable bindings")
    func transformSetClosure() throws {
        let manifest = try amendedManifest()
        #expect(manifest.activationTransformSet.rules.map(\.id.rawValue) == ["TEST-CANON-001"])
        #expect(manifest.activationTransformSet.adrs.map(\.id.rawValue) == ["ADR-9999"])
        #expect(manifest.activationTransformSet.requirements.map(\.id.rawValue) == ["REQ-CONVERGENCE"])
        #expect(
            manifest.activationTransformSet.indexEntries.map(\.entryID)
                == ["skill.brain-execute", "TEST-CANON-001"]
        )
        #expect(manifest.activationTransformSet.derivedPublications.map(\.indexKey) == ["skill.brain-execute"])

        var missingRule = try amendedObject()
        var transformSet = try #require(missingRule["activation_transform_set"] as? [String: Any])
        transformSet["rules"] = []
        missingRule["activation_transform_set"] = transformSet
        try expectManifestRejected(missingRule)

        var wrongSource = try amendedObject()
        var wrongTransformSet = try #require(wrongSource["activation_transform_set"] as? [String: Any])
        var indexEntries = try #require(wrongTransformSet["index_entries"] as? [[String: Any]])
        indexEntries[0]["source_kind"] = "adr_metadata"
        indexEntries[0]["source_id"] = "ADR-9999"
        wrongTransformSet["index_entries"] = indexEntries
        wrongSource["activation_transform_set"] = wrongTransformSet
        try expectManifestRejected(wrongSource)

        var duplicate = try amendedObject()
        var duplicateSet = try #require(duplicate["activation_transform_set"] as? [String: Any])
        var rules = try #require(duplicateSet["rules"] as? [[String: Any]])
        rules.append(rules[0])
        duplicateSet["rules"] = rules
        duplicate["activation_transform_set"] = duplicateSet
        try expectManifestRejected(duplicate)
    }

    @Test("derived publication closure is reciprocal and targets the derived-artifact index")
    func derivedPublicationClosure() throws {
        let manifest = try amendedManifest()
        let derivedIndex = try #require(
            manifest.indexes.first { $0.targetRelativePath == "registry/derived-artifacts.index.json" }
        )
        let target = try #require(manifest.derivedRegistrationDeltas.first?.targets.first)
        let publication = try #require(manifest.activationTransformSet.derivedPublications.first)
        let indexTransform = try #require(
            manifest.activationTransformSet.indexEntries.first { $0.sourceKind == .derivedRegistrationEntry }
        )

        #expect(derivedIndex.entries.map(\.id) == [target.indexKey])
        #expect(publication.indexKey == target.indexKey)
        #expect(publication.bundleArtifactID == target.bundleArtifactID)
        #expect(publication.bundlePublicationID == target.bundlePublicationID)
        #expect(indexTransform.indexID == derivedIndex.id)
        #expect(indexTransform.entryID == target.indexKey)
        #expect(indexTransform.sourceID == target.indexKey)
        #expect(indexTransform.sourceRelativePath == target.targetRelativePath)

        var arbitraryIndex = try amendedObject()
        var transformSet = try #require(arbitraryIndex["activation_transform_set"] as? [String: Any])
        var indexEntries = try #require(transformSet["index_entries"] as? [[String: Any]])
        let derivedOffset = try #require(
            indexEntries.firstIndex { $0["source_kind"] as? String == "derived_registration_entry" }
        )
        indexEntries[derivedOffset]["index_id"] = "rules-index"
        transformSet["index_entries"] = indexEntries
        arbitraryIndex["activation_transform_set"] = transformSet
        try expectManifestRejected(arbitraryIndex)

        var wrongPath = try amendedObject()
        var wrongPathSet = try #require(wrongPath["activation_transform_set"] as? [String: Any])
        var wrongPathEntries = try #require(wrongPathSet["index_entries"] as? [[String: Any]])
        let wrongPathOffset = try #require(
            wrongPathEntries.firstIndex { $0["source_kind"] as? String == "derived_registration_entry" }
        )
        wrongPathEntries[wrongPathOffset]["source_relative_path"] = "skills/other/SKILL.md"
        wrongPathSet["index_entries"] = wrongPathEntries
        wrongPath["activation_transform_set"] = wrongPathSet
        try expectManifestRejected(wrongPath)
    }

    @Test("publication targets and review evidence identifiers are globally unique")
    func globalManifestUniqueness() throws {
        var duplicateTarget = try manifestObjectWithSecondComponent()
        var checks = try #require(duplicateTarget["checks"] as? [[String: Any]])
        checks.append([
            "bundle_artifact_id": "check-published-duplicate",
            "bundle_publication_id": "publish-check-duplicate",
            "candidate_file_digest": String(repeating: "e", count: 64),
            "id": "CHK-CAN-002",
            "reviewed_component_id": "secondary-authority-v1",
            "target_relative_path": "skills/brain-execute/SKILL.md",
        ])
        duplicateTarget["checks"] = checks
        try expectManifestError(
            .duplicateIdentifier(
                kind: "manifest_publication_target",
                id: "plugin_derived\0skills/brain-execute/SKILL.md"
            ),
            from: duplicateTarget
        )

        var duplicateApproval = try manifestObjectWithSecondComponent()
        var approvalComponents = try #require(duplicateApproval["reviewed_components"] as? [[String: Any]])
        let firstOwner = try #require(approvalComponents[0]["accountable_owner_approval"] as? [String: Any])
        var secondOwner = try #require(approvalComponents[1]["accountable_owner_approval"] as? [String: Any])
        secondOwner["approval_id"] = firstOwner["approval_id"]
        approvalComponents[1]["accountable_owner_approval"] = secondOwner
        duplicateApproval["reviewed_components"] = approvalComponents
        try expectManifestError(
            .reusedIdentifier(kind: "approval", id: "approval-owner"),
            from: duplicateApproval
        )

        var duplicateAttestation = try manifestObjectWithSecondComponent()
        var attestationComponents = try #require(duplicateAttestation["reviewed_components"] as? [[String: Any]])
        let firstReviewer = try #require(
            attestationComponents[0]["independent_reviewer_approval"] as? [String: Any]
        )
        var secondReviewer = try #require(
            attestationComponents[1]["independent_reviewer_approval"] as? [String: Any]
        )
        secondReviewer["attestation_id"] = firstReviewer["attestation_id"]
        attestationComponents[1]["independent_reviewer_approval"] = secondReviewer
        duplicateAttestation["reviewed_components"] = attestationComponents
        try expectManifestError(
            .reusedIdentifier(kind: "attestation", id: "attestation-approval-reviewer"),
            from: duplicateAttestation
        )
    }

    @Test("accepted manifest, component bundle, approvals, and authority row form one digest-bound fixture")
    func acceptedFixtureBijection() throws {
        let manifest = try amendedManifest()
        let bundleData = try Data(contentsOf: bundleFixtureURL)
        let bundle = try ComponentBundleSchemaIdentity.v1.decodeBundle(from: bundleData)
        let reviewed = try #require(manifest.reviewedComponents.first)
        let artifactsByID = Dictionary(uniqueKeysWithValues: bundle.artifacts.map { ($0.artifactID, $0) })
        let publicationsByID = Dictionary(
            uniqueKeysWithValues: bundle.publications.map { ($0.publicationID, $0) }
        )

        #expect(manifest.reviewedComponents.count == 1)
        #expect(reviewed.componentID == bundle.componentID)
        #expect(reviewed.componentKind == bundle.componentKind)
        #expect(reviewed.bundleRelativePath == bundle.bundleRelativePath)
        #expect(reviewed.bundleSchemaDigest == bundle.schemaDigest)
        let fixtureComponentDigest = try ComponentBundleSchemaIdentity.v1.componentDigest(
            for: bundleData
        )
        #expect(reviewed.componentDigest == fixtureComponentDigest)
        #expect(reviewed.accountableOwnerApproval.reviewedComponentDigest == reviewed.componentDigest)
        #expect(reviewed.independentReviewerApproval.reviewedComponentDigest == reviewed.componentDigest)

        var artifactClaims: [(String, HashDigest)] = []
        var publicationClaims: [(String, String, CandidateTargetNamespace, String)] = []
        func claim(
            artifactID: String,
            digest: HashDigest,
            publicationID: String? = nil,
            namespace: CandidateTargetNamespace = .canon,
            path: String? = nil
        ) {
            artifactClaims.append((artifactID, digest))
            if let publicationID, let path {
                publicationClaims.append((publicationID, artifactID, namespace, path))
            }
        }

        for binding in manifest.rules {
            claim(artifactID: binding.bundleArtifactID, digest: binding.candidateFullDigest, publicationID: binding.bundlePublicationID, path: binding.targetRelativePath)
        }
        for binding in manifest.profiles {
            claim(artifactID: binding.bundleArtifactID, digest: binding.candidateFullDigest, publicationID: binding.bundlePublicationID, path: binding.targetRelativePath)
        }
        for binding in manifest.adrs {
            claim(artifactID: binding.metadataBundleArtifactID, digest: binding.candidateMetadataFullDigest, publicationID: binding.metadataBundlePublicationID, path: binding.metadataTargetRelativePath)
            claim(artifactID: binding.markdownBundleArtifactID, digest: binding.candidateMarkdownFullDigest, publicationID: binding.markdownBundlePublicationID, path: binding.markdownTargetRelativePath)
        }
        for binding in manifest.chapters {
            claim(artifactID: binding.bundleArtifactID, digest: binding.candidateFileDigest, publicationID: binding.bundlePublicationID, path: binding.targetRelativePath)
        }
        claim(artifactID: manifest.requirementRegistry.bundleArtifactID, digest: manifest.requirementRegistry.candidateFullDigest, publicationID: manifest.requirementRegistry.bundlePublicationID, path: manifest.requirementRegistry.targetRelativePath)
        for binding in manifest.checks + manifest.fixtures + manifest.migrations {
            claim(artifactID: binding.bundleArtifactID, digest: binding.candidateFileDigest, publicationID: binding.bundlePublicationID, namespace: .pluginDerived, path: binding.targetRelativePath)
        }
        for binding in manifest.indexes {
            claim(artifactID: binding.bundleArtifactID, digest: binding.candidateFullDigest, publicationID: binding.bundlePublicationID, path: binding.targetRelativePath)
        }
        for delta in manifest.derivedRegistrationDeltas {
            claim(artifactID: delta.bundleArtifactID, digest: delta.candidateDeltaDigest)
            for target in delta.targets {
                claim(artifactID: target.bundleArtifactID, digest: target.candidateFileDigest, publicationID: target.bundlePublicationID, namespace: .pluginDerived, path: target.targetRelativePath)
            }
        }

        #expect(Set(artifactClaims.map(\.0)) == Set(bundle.artifacts.map(\.artifactID)))
        #expect(Set(publicationClaims.map(\.0)) == Set(bundle.publications.map(\.publicationID)))
        for (artifactID, expectedDigest) in artifactClaims {
            #expect(artifactsByID[artifactID]?.candidateFileDigest == expectedDigest)
        }
        for (publicationID, artifactID, namespace, path) in publicationClaims {
            let publication = try #require(publicationsByID[publicationID])
            #expect(publication.artifactID == artifactID)
            #expect(publication.targetNamespace == namespace)
            #expect(publication.targetRelativePath == path)
        }

        let derivedPublication = try #require(
            bundle.publications.first { $0.targetNamespace == .pluginDerived }
        )
        let authorityRow = try #require(
            CandidatePublicationAuthorityMap.v1.row(
                for: PluginDerivedTargetPath(validating: derivedPublication.targetRelativePath)
            )
        )
        #expect(authorityRow.componentFamily.rawValue == bundle.componentKind)
        #expect(authorityRow.artifactKind == .skill)
        #expect(authorityRow.publicationKind == derivedPublication.publicationKind)
        #expect(authorityRow.targetMode == derivedPublication.targetMode)
    }

    @Test("reviewed component approval binds bundle path, schema, component, owner, and distinct reviews")
    func reviewedComponentBundleJoins() throws {
        let reviewed = try #require(amendedManifest().reviewedComponents.first)
        #expect(reviewed.bundleRelativePath == "components/core-authority-v1.bundle.json")
        #expect(reviewed.bundleSchemaIdentity == .v1)
        #expect(reviewed.bundleSchemaDigest == ComponentBundleSchemaIdentity.v1.schemaDigest)
        #expect(reviewed.accountableOwnerRoleID == reviewed.accountableOwnerApproval.roleID)

        for key in ["bundle_relative_path", "bundle_schema_identity", "bundle_schema_digest", "accountable_owner_role_id"] {
            var mutation = try amendedObject()
            var components = try #require(mutation["reviewed_components"] as? [[String: Any]])
            switch key {
            case "bundle_relative_path":
                components[0][key] = "components/other.bundle.json"
            case "bundle_schema_identity":
                components[0][key] = "urn:ifl:standards:schema:other:v1"
            case "bundle_schema_digest":
                components[0][key] = String(repeating: "e", count: 64)
            default:
                components[0][key] = "Other Maintainer"
            }
            mutation["reviewed_components"] = components
            try expectManifestRejected(mutation)
        }
    }

    @Test("approval input captures immutable canonical sidecar bytes and is not Codable")
    func approvalInputIsCapturedAndNonCodable() throws {
        let overlayData = try Data(contentsOf: amendedWitnessURL)
        let overlayDigest = try CandidateOverlayManifest.overlayDigest(forCanonicalFileData: overlayData)
        let approval = try approval(
            reviewedID: "enterprise-v1",
            reviewedDigest: overlayDigest
        )
        let sidecar = Data("{\"approved\":true}\n".utf8)
        let sidecarDigest = CanonicalTreeDigest.sha256(sidecar)
        let input = try CanonActivationApprovalInput(
            integrationApproval: approval,
            approvalTimestamp: Date(timeIntervalSince1970: 1_735_689_600.123),
            approvalSourceArtifactID: "integration-review-report",
            approvalSourceArtifactDigest: digest("d"),
            approvalSidecarRelativePath: "reports/enterprise-v1.approval.json",
            approvalSidecarBytes: sidecar,
            approvalSidecarDigest: sidecarDigest
        )
        #expect(input.approvalSidecarBytes == sidecar)
        #expect(input.approvalSidecarDigest == sidecarDigest)
        #expect(!(CanonActivationApprovalInput.self is any Encodable.Type))
        #expect(!(CanonActivationApprovalInput.self is any Decodable.Type))

        #expect(throws: ContractError.self) {
            try CanonActivationApprovalInput(
                integrationApproval: approval,
                approvalTimestamp: input.approvalTimestamp,
                approvalSourceArtifactID: input.approvalSourceArtifactID,
                approvalSourceArtifactDigest: input.approvalSourceArtifactDigest,
                approvalSidecarRelativePath: input.approvalSidecarRelativePath,
                approvalSidecarBytes: sidecar,
                approvalSidecarDigest: digest("e")
            )
        }
    }

    @Test("manifest rejects any compiled transform descriptor substitution")
    func transformDescriptorSubstitutionFails() throws {
        for key in ["activation_transform_identity", "activation_transform_digest"] {
            var mutation = try amendedObject()
            mutation[key] = key.hasSuffix("identity")
                ? "urn:ifl:standards:canon-activation-transform:other"
                : String(repeating: "e", count: 64)
            try expectManifestRejected(mutation)
        }
    }
}

private extension CandidateOverlayTransformContractTests {
    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var amendedWitnessURL: URL {
        pluginRoot.appendingPathComponent(
            "verification/fixtures/canon/candidate-overlay/contracts/amended-v1/accepted-overlay.json"
        )
    }

    var descriptorFixtureURL: URL {
        pluginRoot.appendingPathComponent(
            "verification/fixtures/canon/candidate-overlay/contracts/amended-v1/candidate-overlay-transform-descriptor.json"
        )
    }

    var bundleFixtureURL: URL {
        pluginRoot.appendingPathComponent(
            "verification/fixtures/canon/candidate-overlay/contracts/amended-v1/component-core.bundle.json"
        )
    }

    var overlaySchemaURL: URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/candidate-overlay.schema.json")
    }

    func amendedManifest() throws -> CandidateOverlayManifest {
        try CanonicalJSON.decode(
            CandidateOverlayManifest.self,
            from: Data(contentsOf: amendedWitnessURL)
        )
    }

    func amendedObject() throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: amendedWitnessURL)) as? [String: Any]
        )
    }

    func expectManifestRejected(_ object: [String: Any]) throws {
        #expect(throws: (any Error).self) {
            try CanonicalJSON.decode(CandidateOverlayManifest.self, from: canonicalFileData(object))
        }
    }

    func expectManifestError(_ expected: ContractError, from object: [String: Any]) throws {
        do {
            _ = try CanonicalJSON.decode(
                CandidateOverlayManifest.self,
                from: canonicalFileData(object)
            )
            Issue.record("expected \(expected)")
        } catch let error as ContractError {
            #expect(error == expected)
        } catch {
            Issue.record("expected ContractError, received \(error)")
        }
    }

    func manifestObjectWithSecondComponent() throws -> [String: Any] {
        var object = try amendedObject()
        var components = try #require(object["reviewed_components"] as? [[String: Any]])
        var secondary = components[0]
        secondary["component_id"] = "secondary-authority-v1"
        secondary["bundle_relative_path"] = "components/secondary-authority-v1.bundle.json"

        var owner = try #require(secondary["accountable_owner_approval"] as? [String: Any])
        owner["approval_id"] = "approval-secondary-owner"
        owner["attestation_id"] = "attestation-secondary-owner"
        owner["principal_id"] = "principal-secondary-owner"
        owner["actor_id"] = "actor-secondary-owner"
        owner["reviewed_component_id"] = "secondary-authority-v1"
        secondary["accountable_owner_approval"] = owner

        var reviewer = try #require(secondary["independent_reviewer_approval"] as? [String: Any])
        reviewer["approval_id"] = "approval-secondary-reviewer"
        reviewer["attestation_id"] = "attestation-secondary-reviewer"
        reviewer["principal_id"] = "principal-secondary-reviewer"
        reviewer["actor_id"] = "actor-secondary-reviewer"
        reviewer["reviewed_component_id"] = "secondary-authority-v1"
        secondary["independent_reviewer_approval"] = reviewer
        components.append(secondary)
        object["reviewed_components"] = components

        var checks = try #require(object["checks"] as? [[String: Any]])
        checks[0]["reviewed_component_id"] = "secondary-authority-v1"
        object["checks"] = checks
        return object
    }

    func canonicalFileData(_ object: Any) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    func approval(reviewedID: String, reviewedDigest: HashDigest) throws -> ReviewApprovalReference {
        try ReviewApprovalReference(
            schemaVersion: 1,
            approvalID: "integration-approval",
            principalID: "principal-integration",
            actorID: "actor-integration",
            roleID: "Integration Reviewer",
            reviewedComponentID: reviewedID,
            reviewedComponentDigest: reviewedDigest,
            attestationID: "attestation-integration",
            attestationDigest: digest("f")
        )
    }

    func digest(_ character: Character) throws -> HashDigest {
        try HashDigest(validating: String(repeating: character, count: 64))
    }
}
