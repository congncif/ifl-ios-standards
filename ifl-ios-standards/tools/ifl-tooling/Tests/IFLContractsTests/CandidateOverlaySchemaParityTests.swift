import Foundation
@testable import IFLContracts
import Testing

@Suite("CandidateOverlaySchemaParityTests")
struct CandidateOverlaySchemaParityTests {
    @Test("component bundle schema, closed decoder, and canonical fixture remain byte-identical")
    func componentBundleSchemaAndDecoderParity() throws {
        let schemaData = try Data(contentsOf: schemaURL)
        let schemaDigest = CanonicalTreeDigest.sha256(schemaData)
        #expect(ComponentBundleSchemaIdentity.v1.rawValue == componentBundleSchemaIdentity)
        #expect(ComponentBundleSchemaIdentity.v1.schemaDigest == schemaDigest)

        let fixtureData = try Data(contentsOf: bundleFixtureURL)
        try expectCanonicalJSONFile(fixtureData)
        let fixtureObject = try #require(
            JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
        )
        let schema = try #require(
            JSONSerialization.jsonObject(with: schemaData) as? [String: Any]
        )
        #expect(schemaAccepts(fixtureObject, against: schema, root: schema))

        let bundle = try ComponentBundleSchemaIdentity.v1.decodeBundle(from: fixtureData)
        #expect(bundle.schemaIdentity == .v1)
        #expect(bundle.schemaDigest == schemaDigest)
        #expect(bundle.artifacts.map(\.artifactID) == [
            "adr-9999-markdown",
            "adr-9999-metadata",
            "chapter-test",
            "check-test",
            "delta-test",
            "derived-artifacts-index",
            "fixture-test",
            "migration-test",
            "profile-minimal",
            "requirements",
            "rule-test",
            "rules-index",
            "skill-test",
        ])
        #expect(bundle.publications.map(\.publicationID) == [
            "publish-adr-9999-markdown",
            "publish-adr-9999-metadata",
            "publish-chapter-test",
            "publish-derived-artifacts-index",
            "publish-profile-minimal",
            "publish-requirements",
            "publish-rule-test",
            "publish-rules-index",
            "publish-skill-test",
        ])
        #expect(bundle.targetDirectories.map(\.directoryID) == ["dir-rules-core"])

        var encoded = try CanonicalJSON.encode(bundle)
        encoded.append(0x0A)
        #expect(encoded == fixtureData)
    }

    @Test("component bundle closes IDs, paths, modes, before entries, and directory ownership")
    func componentBundleMutationMatrix() throws {
        let base = try bundleFixtureObject()

        var unknown = base
        unknown["schema_registry"] = []
        try expectBundleRejected(unknown)

        var explicitNull = base
        var nullPublications = try #require(explicitNull["publications"] as? [[String: Any]])
        nullPublications[0]["before_entry"] = NSNull()
        explicitNull["publications"] = nullPublications
        try expectBundleRejected(explicitNull)

        var invalidMode = base
        var modePublications = try #require(invalidMode["publications"] as? [[String: Any]])
        modePublications[0]["target_mode"] = 421
        invalidMode["publications"] = modePublications
        try expectBundleRejected(invalidMode)

        var duplicateArtifactPath = base
        var pathArtifacts = try #require(duplicateArtifactPath["artifacts"] as? [[String: Any]])
        pathArtifacts[1]["candidate_relative_path"] = pathArtifacts[0]["candidate_relative_path"]
        duplicateArtifactPath["artifacts"] = pathArtifacts
        try expectBundleRejected(duplicateArtifactPath)

        var duplicateTarget = base
        var targetPublications = try #require(duplicateTarget["publications"] as? [[String: Any]])
        targetPublications[1]["target_namespace"] = targetPublications[0]["target_namespace"]
        targetPublications[1]["target_relative_path"] = targetPublications[0]["target_relative_path"]
        duplicateTarget["publications"] = targetPublications
        try expectBundleRejected(duplicateTarget)

        var chmod = base
        var chmodPublications = try #require(chmod["publications"] as? [[String: Any]])
        let skillOffset = try #require(
            chmodPublications.firstIndex { $0["publication_id"] as? String == "publish-skill-test" }
        )
        chmodPublications[skillOffset]["target_mode"] = 493
        chmod["publications"] = chmodPublications
        try expectBundleRejected(chmod)

        var invalidDirectoryMode = base
        var directories = try #require(invalidDirectoryMode["target_directories"] as? [[String: Any]])
        directories[0]["mode"] = 420
        invalidDirectoryMode["target_directories"] = directories
        try expectBundleRejected(invalidDirectoryMode)

        var orphanDirectoryClaim = base
        var orphanDirectories = try #require(orphanDirectoryClaim["target_directories"] as? [[String: Any]])
        orphanDirectories[0]["publication_ids"] = ["publish-skill-test"]
        orphanDirectoryClaim["target_directories"] = orphanDirectories
        try expectBundleRejected(orphanDirectoryClaim)

        var duplicateDirectoryID = base
        var duplicateDirectories = try #require(
            duplicateDirectoryID["target_directories"] as? [[String: Any]]
        )
        var duplicateDirectory = duplicateDirectories[0]
        duplicateDirectory["target_relative_path"] = "rules"
        duplicateDirectories.append(duplicateDirectory)
        duplicateDirectoryID["target_directories"] = duplicateDirectories
        try expectBundleError(
            .duplicateIdentifier(kind: "bundle_target_directory", id: "dir-rules-core"),
            from: duplicateDirectoryID
        )
    }

    @Test("bundle schema closes Canon namespace paths while Swift owns the artifact-family join")
    func componentBundlePathSchemaCausality() throws {
        let schema = try schemaObject()
        let base = try bundleFixtureObject()
        #expect(schemaAccepts(base, against: schema, root: schema))

        var protected = base
        var protectedPublications = try #require(protected["publications"] as? [[String: Any]])
        protectedPublications[0]["target_relative_path"] = "VERSION"
        protected["publications"] = protectedPublications
        #expect(!schemaAccepts(protected, against: schema, root: schema))
        try expectBundleRejected(protected)

        var wrongFamily = base
        var wrongFamilyPublications = try #require(wrongFamily["publications"] as? [[String: Any]])
        let ruleOffset = try #require(
            wrongFamilyPublications.firstIndex { $0["publication_id"] as? String == "publish-rule-test" }
        )
        wrongFamilyPublications[ruleOffset]["target_relative_path"] = "profiles/wrong.profile.json"
        wrongFamily["publications"] = wrongFamilyPublications
        #expect(schemaAccepts(wrongFamily, against: schema, root: schema))
        try expectBundleError(
            .invalidContract(
                kind: "candidate_bundle_publication",
                reason: "target path or publication kind does not match family rule"
            ),
            from: wrongFamily
        )

        var nonASCIIADR = base
        var artifacts = try #require(nonASCIIADR["artifacts"] as? [[String: Any]])
        artifacts.append([
            "artifact_id": "z-adr-markdown",
            "candidate_file_digest": String(repeating: "e", count: 64),
            "candidate_relative_path": "payloads/canon/adrs/ADR-9999-test.md",
            "family": "adr_markdown",
            "logical_id": "ADR-9999",
        ])
        artifacts.append([
            "artifact_id": "z-adr-metadata",
            "candidate_file_digest": String(repeating: "d", count: 64),
            "candidate_relative_path": "payloads/canon/adrs/ADR-9999-test.json",
            "family": "adr_metadata",
            "logical_id": "ADR-9999",
        ])
        nonASCIIADR["artifacts"] = artifacts
        var publications = try #require(nonASCIIADR["publications"] as? [[String: Any]])
        publications.append([
            "artifact_id": "z-adr-markdown",
            "publication_id": "z-publish-adr-markdown",
            "publication_kind": "exact_copy",
            "target_mode": 420,
            "target_namespace": "canon",
            "target_relative_path": "adrs/ADR-\u{FF11}\u{FF12}\u{FF13}\u{FF14}-test.md",
        ])
        publications.append([
            "artifact_id": "z-adr-metadata",
            "publication_id": "z-publish-adr-metadata",
            "publication_kind": "resolver_transformed",
            "target_mode": 420,
            "target_namespace": "canon",
            "target_relative_path": "adrs/ADR-\u{FF11}\u{FF12}\u{FF13}\u{FF14}-test.json",
        ])
        nonASCIIADR["publications"] = publications
        #expect(!schemaAccepts(nonASCIIADR, against: schema, root: schema))
        try expectBundleRejected(nonASCIIADR)
    }

    @Test("bundle nested optionality reports exact contract errors")
    func componentBundleNestedErrorTaxonomy() throws {
        var unknown = try bundleFixtureObject()
        var artifacts = try #require(unknown["artifacts"] as? [[String: Any]])
        artifacts[0]["legacy_digest"] = String(repeating: "0", count: 64)
        unknown["artifacts"] = artifacts
        try expectBundleError(
            .unexpectedKeys(kind: "candidate_bundle_artifact", keys: ["legacy_digest"]),
            from: unknown
        )

        var explicitNull = try bundleFixtureObject()
        var publications = try #require(explicitNull["publications"] as? [[String: Any]])
        publications[0]["before_entry"] = NSNull()
        explicitNull["publications"] = publications
        try expectBundleError(
            .invalidContract(
                kind: "candidate_bundle_publication",
                reason: "before_entry must be absent rather than null when there is no before state"
            ),
            from: explicitNull
        )
    }

    @Test("compiled publication authority is exactly the frozen 142-row descriptor")
    func publicationAuthorityMapIsExactAndClosed() throws {
        let fixtureData = try Data(contentsOf: authorityFixtureURL)
        try expectCanonicalJSONFile(fixtureData)

        let authority = CandidatePublicationAuthorityMap.v1
        #expect(authority.identity == "urn:ifl:standards:candidate-publication-authority-map:v1")
        #expect(authority.digest == CanonicalTreeDigest.sha256(fixtureData))
        #expect(try authority.canonicalFileData() == fixtureData)
        #expect(authority.rows.count == 142)
        #expect(Dictionary(grouping: authority.rows, by: \.componentFamily).mapValues(\.count) == [
            .standardsCore: 27,
            .runtimeAgents: 29,
            .enterpriseRouting: 70,
            .scaffolds: 16,
        ])
        #expect(authority.rows.map(\.targetPath.rawValue) == authority.rows.map(\.targetPath.rawValue).sorted())
        #expect(Set(authority.rows.map(\.targetPath.rawValue)).count == 142)
        #expect(authority.rows.allSatisfy { !$0.targetPath.rawValue.contains(where: { "*?[".contains($0) }) })
        #expect(authority.rows.allSatisfy { $0.targetNamespace == .pluginDerived })
        #expect(authority.rows.allSatisfy { $0.publicationKind == .exactCopy })
        #expect(authority.rows.count(where: { $0.targetMode == .executable }) == 3)

        let wrapperPath = try PluginDerivedTargetPath(validating: "bin/ifl-init")
        #expect(authority.allows(
            componentFamily: .scaffolds,
            artifactKind: .wrapper,
            targetPath: wrapperPath,
            publicationKind: .exactCopy,
            mode: .executable
        ))
        #expect(!authority.allows(
            componentFamily: .scaffolds,
            artifactKind: .wrapper,
            targetPath: wrapperPath,
            publicationKind: .exactCopy,
            mode: .file
        ))
        #expect(try authority.row(for: PluginDerivedTargetPath(validating: "tools/ifl-tooling/Package.swift")) == nil)
        #expect(try authority.row(for: PluginDerivedTargetPath(validating: ".codex-plugin/plugin.json")) == nil)
    }

    @Test("candidate schemas use only keywords implemented by the local evaluator")
    func localEvaluatorKeywordCoverage() throws {
        for url in [schemaURL, overlaySchemaURL, activationReceiptSchemaURL] {
            let root = try #require(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            )
            let unsupported = unsupportedKeywords(in: root, path: "#")
            #expect(unsupported.isEmpty, "\(url.lastPathComponent): \(unsupported.joined(separator: "; "))")
        }
    }
}

private extension CandidateOverlaySchemaParityTests {
    var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    var schemaURL: URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/candidate-component-bundle.schema.json")
    }

    var overlaySchemaURL: URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/candidate-overlay.schema.json")
    }

    var activationReceiptSchemaURL: URL {
        pluginRoot.appendingPathComponent("standards/canon/schemas/v1/activation-receipt.schema.json")
    }

    var bundleFixtureURL: URL {
        pluginRoot.appendingPathComponent(
            "verification/fixtures/canon/candidate-overlay/contracts/amended-v1/component-core.bundle.json"
        )
    }

    var authorityFixtureURL: URL {
        pluginRoot.appendingPathComponent(
            "verification/fixtures/canon/candidate-overlay/contracts/amended-v1/candidate-publication-authority-map.json"
        )
    }

    func bundleFixtureObject() throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: bundleFixtureURL)) as? [String: Any]
        )
    }

    func schemaObject() throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        )
    }

    func expectBundleRejected(_ object: [String: Any]) throws {
        #expect(throws: (any Error).self) {
            try CanonicalJSON.decode(
                CandidateComponentBundle.self,
                from: canonicalFileData(object)
            )
        }
    }

    func expectBundleError(_ expected: ContractError, from object: [String: Any]) throws {
        do {
            _ = try CanonicalJSON.decode(
                CandidateComponentBundle.self,
                from: canonicalFileData(object)
            )
            Issue.record("expected \(expected)")
        } catch let error as ContractError {
            #expect(error == expected)
        } catch {
            Issue.record("expected ContractError, received \(error)")
        }
    }

    func canonicalFileData(_ object: Any) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        return data
    }

    func expectCanonicalJSONFile(_ data: Data) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        #expect(try canonicalFileData(object) == data)
    }

    var componentBundleSchemaIdentity: String {
        "urn:ifl:standards:schema:candidate-component-bundle:v1"
    }

    func unsupportedKeywords(in schema: [String: Any], path: String) -> [String] {
        let supported: Set = [
            "$defs", "$id", "$ref", "$schema", "additionalProperties", "allOf", "anyOf",
            "const", "contains", "else", "enum", "format", "if", "items", "maxContains",
            "maxItems", "maxLength", "minContains", "minItems", "minLength", "not", "oneOf",
            "pattern", "prefixItems", "properties", "required", "then", "type", "uniqueItems",
            "description", "title",
            "x-ifl-format-assertion-required",
        ]
        var result = schema.keys.filter { !supported.contains($0) }.map { "\(path)/\($0)" }
        for key in ["$defs", "properties"] {
            guard let children = schema[key] as? [String: Any] else { continue }
            for name in children.keys.sorted() {
                guard let child = children[name] as? [String: Any] else { continue }
                result += unsupportedKeywords(in: child, path: "\(path)/\(key)/\(name)")
            }
        }
        for key in ["items", "contains", "not", "if", "then", "else"] {
            guard let child = schema[key] as? [String: Any] else { continue }
            result += unsupportedKeywords(in: child, path: "\(path)/\(key)")
        }
        for key in ["allOf", "anyOf", "oneOf", "prefixItems"] {
            guard let children = schema[key] as? [[String: Any]] else { continue }
            for (index, child) in children.enumerated() {
                result += unsupportedKeywords(in: child, path: "\(path)/\(key)/\(index)")
            }
        }
        return result
    }
}
