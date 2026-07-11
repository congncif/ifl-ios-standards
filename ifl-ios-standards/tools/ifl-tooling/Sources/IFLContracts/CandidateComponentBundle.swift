import Foundation

enum CandidateCanonPathGrammar {
    static let indexPaths: Set<String> = [
        "registry/rules.index.json",
        "registry/profiles.index.json",
        "registry/adrs.index.json",
        "registry/chapters.index.json",
        "registry/derived-artifacts.index.json",
    ]

    static func isNamespacePath(_ path: String) -> Bool {
        if path == "registry" || path == "registry/requirements.v1.json" || indexPaths.contains(path) {
            return true
        }
        if path == "rules" || path.hasPrefix("rules/")
            || path == "chapters" || path.hasPrefix("chapters/")
        {
            return true
        }
        if path == "profiles" || isProfilePath(path) {
            return true
        }
        return path == "adrs"
            || isADRPath(path, suffix: ".json")
            || isADRPath(path, suffix: ".md")
    }

    static func isRulePath(_ path: String) -> Bool {
        isNestedFile(path, root: "rules", suffix: ".rules.json")
    }

    static func isProfilePath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2
            && components[0] == "profiles"
            && hasNonEmptyStem(String(components[1]), suffix: ".profile.json")
    }

    static func isADRPath(
        _ path: String,
        suffix: String,
        expectedID: String? = nil
    ) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, components[0] == "adrs" else { return false }
        let name = String(components[1])
        guard hasNonEmptyStem(name, suffix: suffix) else { return false }
        let stem = String(name.dropLast(suffix.count))
        let pieces = stem.split(separator: "-", omittingEmptySubsequences: false)
        guard pieces.count >= 3,
              pieces[0] == "ADR",
              pieces[1].utf8.count == 4,
              pieces[1].utf8.allSatisfy({ (0x30 ... 0x39).contains($0) }),
              pieces.dropFirst(2).allSatisfy({ part in
                  !part.isEmpty && part.utf8.allSatisfy {
                      (0x61 ... 0x7A).contains($0) || (0x30 ... 0x39).contains($0)
                  }
              })
        else { return false }
        if let expectedID {
            return expectedID == "ADR-\(pieces[1])"
        }
        return true
    }

    static func isChapterPath(_ path: String) -> Bool {
        isNestedFile(path, root: "chapters", suffix: ".chapter.json")
    }

    private static func isNestedFile(_ path: String, root: String, suffix: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count >= 2
            && components[0] == Substring(root)
            && hasNonEmptyStem(String(components.last ?? ""), suffix: suffix)
    }

    private static func hasNonEmptyStem(_ name: String, suffix: String) -> Bool {
        name.hasSuffix(suffix) && name.count > suffix.count
    }
}

public enum ComponentBundleSchemaIdentity: String, Codable, CaseIterable, Hashable, Sendable {
    case v1 = "urn:ifl:standards:schema:candidate-component-bundle:v1"

    public var schemaDigest: HashDigest {
        HashDigest(uncheckedLowercaseSHA256: "97d0623fe83f18c540535210b95718954779c7a40b9e734aa2552c7e01fb4f58")
    }

    public func decodeBundle(from fileData: Data) throws -> CandidateComponentBundle {
        let bundle = try CanonicalJSON.decode(CandidateComponentBundle.self, from: fileData)
        guard bundle.schemaIdentity == self else {
            throw ContractError.invalidContract(
                kind: "candidate_component_bundle",
                reason: "schema_identity does not select the compiled v1 decoder"
            )
        }
        guard bundle.schemaDigest == schemaDigest else {
            throw ContractError.digestMismatch(
                kind: "candidate_component_bundle_schema",
                expected: schemaDigest.rawValue,
                actual: bundle.schemaDigest.rawValue
            )
        }
        var canonical = try CanonicalJSON.encode(bundle)
        canonical.append(0x0A)
        guard canonical == fileData else {
            throw ContractError.invalidContract(
                kind: "candidate_component_bundle",
                reason: "bundle file must be canonical JSON followed by exactly one LF"
            )
        }
        return bundle
    }

    public func componentDigest(for fileData: Data) throws -> HashDigest {
        _ = try decodeBundle(from: fileData)
        var payload = Data("ifl.candidate-component.bundle/v1\0".utf8)
        payload.append(fileData)
        return CanonicalTreeDigest.sha256(payload)
    }
}

public enum CandidateArtifactFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case rule
    case profile
    case adrMetadata = "adr_metadata"
    case adrMarkdown = "adr_markdown"
    case chapter
    case requirementRegistry = "requirement_registry"
    case check
    case fixture
    case migration
    case index
    case derivedDelta = "derived_delta"
    case derivedTarget = "derived_target"
}

public enum CandidatePublicationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case exactCopy = "exact_copy"
    case resolverTransformed = "resolver_transformed"
}

public enum CandidateTargetNamespace: String, Codable, CaseIterable, Hashable, Sendable {
    case canon
    case pluginDerived = "plugin_derived"
}

public enum CandidatePortableMode: UInt16, Codable, CaseIterable, Hashable, Sendable {
    case file = 420
    case executable = 493
}

public struct CanonTargetPath: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        let path = try IFLCanonContractSupport.exactRelativePath(
            rawValue,
            kind: "canon_target_path",
            field: "target_relative_path"
        )
        guard CandidateCanonPathGrammar.isNamespacePath(path) else {
            throw ContractError.invalidContract(
                kind: "canon_target_path",
                reason: "target_relative_path is outside the closed Canon publication families"
            )
        }
        self.rawValue = path
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct PluginDerivedTargetPath: Codable, Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        self.rawValue = try IFLCanonContractSupport.exactRelativePath(
            rawValue,
            kind: "plugin_derived_target_path",
            field: "target_relative_path"
        )
    }

    init(compiledRawValue: String) {
        rawValue = compiledRawValue
    }

    public init(from decoder: any Decoder) throws {
        try self.init(validating: decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum CandidateTargetPath: Hashable, Sendable {
    case canon(CanonTargetPath)
    case pluginDerived(PluginDerivedTargetPath)

    public var namespace: CandidateTargetNamespace {
        switch self {
        case .canon: .canon
        case .pluginDerived: .pluginDerived
        }
    }

    public var rawValue: String {
        switch self {
        case let .canon(path): path.rawValue
        case let .pluginDerived(path): path.rawValue
        }
    }

    static func validating(
        namespace: CandidateTargetNamespace,
        rawValue: String
    ) throws -> CandidateTargetPath {
        switch namespace {
        case .canon:
            try .canon(CanonTargetPath(validating: rawValue))
        case .pluginDerived:
            try .pluginDerived(PluginDerivedTargetPath(validating: rawValue))
        }
    }
}

public struct CandidateBundleBeforeEntry: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case regularFile = "regular_file"
    }

    public let kind: Kind
    public let contentSHA256: HashDigest
    public let mode: CandidatePortableMode

    public init(
        kind: Kind,
        contentSHA256: HashDigest,
        mode: CandidatePortableMode
    ) throws {
        self.kind = kind
        self.contentSHA256 = try IFLCanonContractSupport.digest(contentSHA256)
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case contentSHA256 = "content_sha256"
        case mode
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_bundle_before_entry"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: container.decode(Kind.self, forKey: .kind),
            contentSHA256: container.decode(HashDigest.self, forKey: .contentSHA256),
            mode: container.decode(CandidatePortableMode.self, forKey: .mode)
        )
    }
}

public struct CandidateBundleArtifact: Codable, Hashable, Sendable {
    public let artifactID: String
    public let family: CandidateArtifactFamily
    public let logicalID: String
    public let candidateRelativePath: String
    public let candidateFileDigest: HashDigest

    public init(
        artifactID: String,
        family: CandidateArtifactFamily,
        logicalID: String,
        candidateRelativePath: String,
        candidateFileDigest: HashDigest
    ) throws {
        let kind = "candidate_bundle_artifact"
        self.artifactID = try IFLCanonContractSupport.canonicalSlug(
            artifactID,
            kind: kind,
            field: "artifact_id"
        )
        self.family = family
        self.logicalID = try IFLCanonContractSupport.nonBlank(logicalID, kind: kind, field: "logical_id")
        let path = try IFLCanonContractSupport.exactRelativePath(
            candidateRelativePath,
            kind: kind,
            field: "candidate_relative_path"
        )
        guard path.hasPrefix("payloads/") else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "candidate_relative_path must be below payloads"
            )
        }
        self.candidateRelativePath = path
        self.candidateFileDigest = try IFLCanonContractSupport.digest(candidateFileDigest)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case artifactID = "artifact_id"
        case family
        case logicalID = "logical_id"
        case candidateRelativePath = "candidate_relative_path"
        case candidateFileDigest = "candidate_file_digest"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_bundle_artifact"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            artifactID: container.decode(String.self, forKey: .artifactID),
            family: container.decode(CandidateArtifactFamily.self, forKey: .family),
            logicalID: container.decode(String.self, forKey: .logicalID),
            candidateRelativePath: container.decode(String.self, forKey: .candidateRelativePath),
            candidateFileDigest: container.decode(HashDigest.self, forKey: .candidateFileDigest)
        )
    }
}

public struct CandidateBundlePublication: Codable, Hashable, Sendable {
    public let publicationID: String
    public let artifactID: String
    public let publicationKind: CandidatePublicationKind
    public let targetPath: CandidateTargetPath
    public let targetMode: CandidatePortableMode
    public let beforeEntry: CandidateBundleBeforeEntry?

    public var targetNamespace: CandidateTargetNamespace {
        targetPath.namespace
    }

    public var targetRelativePath: String {
        targetPath.rawValue
    }

    public init(
        publicationID: String,
        artifactID: String,
        publicationKind: CandidatePublicationKind,
        targetNamespace: CandidateTargetNamespace,
        targetRelativePath: String,
        targetMode: CandidatePortableMode,
        beforeEntry: CandidateBundleBeforeEntry?
    ) throws {
        let kind = "candidate_bundle_publication"
        self.publicationID = try IFLCanonContractSupport.canonicalSlug(
            publicationID,
            kind: kind,
            field: "publication_id"
        )
        self.artifactID = try IFLCanonContractSupport.canonicalSlug(
            artifactID,
            kind: kind,
            field: "artifact_id"
        )
        self.publicationKind = publicationKind
        targetPath = try CandidateTargetPath.validating(
            namespace: targetNamespace,
            rawValue: targetRelativePath
        )
        self.targetMode = targetMode
        if let beforeEntry, beforeEntry.mode != targetMode {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "an existing target must retain its exact mode"
            )
        }
        self.beforeEntry = beforeEntry
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case publicationID = "publication_id"
        case artifactID = "artifact_id"
        case publicationKind = "publication_kind"
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
        case targetMode = "target_mode"
        case beforeEntry = "before_entry"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_bundle_publication"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            publicationID: container.decode(String.self, forKey: .publicationID),
            artifactID: container.decode(String.self, forKey: .artifactID),
            publicationKind: container.decode(CandidatePublicationKind.self, forKey: .publicationKind),
            targetNamespace: container.decode(CandidateTargetNamespace.self, forKey: .targetNamespace),
            targetRelativePath: container.decode(String.self, forKey: .targetRelativePath),
            targetMode: container.decode(CandidatePortableMode.self, forKey: .targetMode),
            beforeEntry: IFLCanonContractSupport.decodeOptionalRejectingNull(
                CandidateBundleBeforeEntry.self,
                from: container,
                forKey: .beforeEntry,
                kind: kind,
                field: "before_entry"
            )
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(publicationID, forKey: .publicationID)
        try container.encode(artifactID, forKey: .artifactID)
        try container.encode(publicationKind, forKey: .publicationKind)
        try container.encode(targetNamespace, forKey: .targetNamespace)
        try container.encode(targetRelativePath, forKey: .targetRelativePath)
        try container.encode(targetMode, forKey: .targetMode)
        try container.encodeIfPresent(beforeEntry, forKey: .beforeEntry)
    }
}

public struct CandidateBundleTargetDirectory: Codable, Hashable, Sendable {
    public let directoryID: String
    public let targetPath: CandidateTargetPath
    public let mode: CandidatePortableMode
    public let publicationIDs: [String]

    public var targetNamespace: CandidateTargetNamespace {
        targetPath.namespace
    }

    public var targetRelativePath: String {
        targetPath.rawValue
    }

    public init(
        directoryID: String,
        targetNamespace: CandidateTargetNamespace,
        targetRelativePath: String,
        mode: CandidatePortableMode,
        publicationIDs: [String]
    ) throws {
        let kind = "candidate_bundle_target_directory"
        self.directoryID = try IFLCanonContractSupport.canonicalSlug(
            directoryID,
            kind: kind,
            field: "directory_id"
        )
        targetPath = try CandidateTargetPath.validating(
            namespace: targetNamespace,
            rawValue: targetRelativePath
        )
        guard mode == .executable else {
            throw ContractError.invalidContract(kind: kind, reason: "new target directories must use mode 493")
        }
        self.mode = mode
        try IFLCanonContractSupport.requireNonEmpty(publicationIDs, kind: kind, field: "publication_ids")
        let validated = try publicationIDs.map {
            try IFLCanonContractSupport.canonicalSlug($0, kind: kind, field: "publication_id")
        }
        try IFLCanonContractSupport.requireUnique(validated, kind: "directory_publication", id: { $0 })
        self.publicationIDs = validated.sorted(by: IFLCanonContractSupport.canonicalLess)
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case directoryID = "directory_id"
        case targetNamespace = "target_namespace"
        case targetRelativePath = "target_relative_path"
        case mode
        case publicationIDs = "publication_ids"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_bundle_target_directory"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPublicationIDs = try container.decode([String].self, forKey: .publicationIDs)
        try self.init(
            directoryID: container.decode(String.self, forKey: .directoryID),
            targetNamespace: container.decode(CandidateTargetNamespace.self, forKey: .targetNamespace),
            targetRelativePath: container.decode(String.self, forKey: .targetRelativePath),
            mode: container.decode(CandidatePortableMode.self, forKey: .mode),
            publicationIDs: rawPublicationIDs
        )
        guard rawPublicationIDs == publicationIDs else {
            throw ContractError.invalidContract(kind: kind, reason: "publication_ids must use canonical order")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(directoryID, forKey: .directoryID)
        try container.encode(targetNamespace, forKey: .targetNamespace)
        try container.encode(targetRelativePath, forKey: .targetRelativePath)
        try container.encode(mode, forKey: .mode)
        try container.encode(publicationIDs, forKey: .publicationIDs)
    }
}

public struct CandidateComponentBundle: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let schemaIdentity: ComponentBundleSchemaIdentity
    public let schemaDigest: HashDigest
    public let componentID: String
    public let componentKind: String
    public let accountableOwnerRoleID: String
    public let bundleRelativePath: String
    public let artifacts: [CandidateBundleArtifact]
    public let publications: [CandidateBundlePublication]
    public let targetDirectories: [CandidateBundleTargetDirectory]

    public init(
        schemaVersion: Int,
        schemaIdentity: ComponentBundleSchemaIdentity,
        schemaDigest: HashDigest,
        componentID: String,
        componentKind: String,
        accountableOwnerRoleID: String,
        bundleRelativePath: String,
        artifacts: [CandidateBundleArtifact],
        publications: [CandidateBundlePublication],
        targetDirectories: [CandidateBundleTargetDirectory]
    ) throws {
        let kind = "candidate_component_bundle"
        try IFLCanonContractSupport.validateSchemaVersion(schemaVersion, kind: kind)
        let digest = try IFLCanonContractSupport.digest(schemaDigest)
        guard schemaIdentity == .v1, digest == schemaIdentity.schemaDigest else {
            throw ContractError.digestMismatch(
                kind: "candidate_component_bundle_schema",
                expected: schemaIdentity.schemaDigest.rawValue,
                actual: digest.rawValue
            )
        }
        let validatedComponentID = try IFLCanonContractSupport.canonicalSlug(
            componentID,
            kind: kind,
            field: "component_id"
        )
        let path = try IFLCanonContractSupport.exactRelativePath(
            bundleRelativePath,
            kind: kind,
            field: "bundle_relative_path"
        )
        guard path == "components/\(validatedComponentID).bundle.json" else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "bundle_relative_path must exactly embed component_id"
            )
        }
        try IFLCanonContractSupport.requireNonEmpty(artifacts, kind: kind, field: "artifacts")
        try IFLCanonContractSupport.requireNonEmpty(publications, kind: kind, field: "publications")
        try IFLCanonContractSupport.requireUnique(artifacts, kind: "bundle_artifact", id: \.artifactID)
        try IFLCanonContractSupport.requireUnique(
            artifacts,
            kind: "bundle_artifact_source_path",
            id: \.candidateRelativePath
        )
        try IFLCanonContractSupport.requireUnique(publications, kind: "bundle_publication", id: \.publicationID)
        try IFLCanonContractSupport.requireUnique(
            publications,
            kind: "bundle_publication_artifact",
            id: \.artifactID
        )
        try IFLCanonContractSupport.requireUnique(
            publications,
            kind: "bundle_publication_target",
            id: { $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath }
        )
        try IFLCanonContractSupport.requireUnique(
            targetDirectories,
            kind: "bundle_target_directory",
            id: \.directoryID
        )
        try IFLCanonContractSupport.requireUnique(
            targetDirectories,
            kind: "bundle_target_directory",
            id: { $0.targetNamespace.rawValue + "\0" + $0.targetRelativePath }
        )
        let artifactsByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.artifactID, $0) })
        for publication in publications {
            guard let artifact = artifactsByID[publication.artifactID] else {
                throw ContractError.unresolvedReference(
                    kind: "bundle_publication_artifact",
                    id: publication.artifactID
                )
            }
            try Self.validate(publication: publication, for: artifact)
        }
        let publicationsByID = Dictionary(uniqueKeysWithValues: publications.map { ($0.publicationID, $0) })
        for directory in targetDirectories {
            for publicationID in directory.publicationIDs {
                guard let publication = publicationsByID[publicationID] else {
                    throw ContractError.unresolvedReference(kind: "directory_publication", id: publicationID)
                }
                guard publication.targetNamespace == directory.targetNamespace,
                      publication.targetRelativePath.hasPrefix(directory.targetRelativePath + "/")
                else {
                    throw ContractError.invalidContract(
                        kind: "candidate_bundle_target_directory",
                        reason: "directory claim must be an ancestor of every referenced publication"
                    )
                }
            }
        }
        try Self.validateADRPairing(artifacts: artifacts, publications: publications)

        self.schemaVersion = schemaVersion
        self.schemaIdentity = schemaIdentity
        self.schemaDigest = digest
        self.componentID = validatedComponentID
        self.componentKind = try IFLCanonContractSupport.canonicalSlug(
            componentKind,
            kind: kind,
            field: "component_kind"
        )
        self.accountableOwnerRoleID = try IFLCanonContractSupport.nonBlank(
            accountableOwnerRoleID,
            kind: kind,
            field: "accountable_owner_role_id"
        )
        self.bundleRelativePath = path
        self.artifacts = artifacts.sorted {
            IFLCanonContractSupport.canonicalLess($0.artifactID, $1.artifactID)
        }
        self.publications = publications.sorted {
            IFLCanonContractSupport.canonicalLess($0.publicationID, $1.publicationID)
        }
        self.targetDirectories = targetDirectories.sorted {
            Self.directorySortKey($0).lexicographicallyPrecedes(
                Self.directorySortKey($1),
                by: IFLCanonContractSupport.canonicalLess
            )
        }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case schemaIdentity = "schema_identity"
        case schemaDigest = "schema_digest"
        case componentID = "component_id"
        case componentKind = "component_kind"
        case accountableOwnerRoleID = "accountable_owner_role_id"
        case bundleRelativePath = "bundle_relative_path"
        case artifacts
        case publications
        case targetDirectories = "target_directories"
    }

    public init(from decoder: any Decoder) throws {
        let kind = "candidate_component_bundle"
        try IFLCanonContractSupport.rejectUnknownKeys(
            from: decoder,
            allowedKeys: Set(CodingKeys.allCases.map(\.rawValue)),
            kind: kind
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawArtifacts = try container.decode([CandidateBundleArtifact].self, forKey: .artifacts)
        let rawPublications = try container.decode([CandidateBundlePublication].self, forKey: .publications)
        let rawDirectories = try container.decode(
            [CandidateBundleTargetDirectory].self,
            forKey: .targetDirectories
        )
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            schemaIdentity: container.decode(ComponentBundleSchemaIdentity.self, forKey: .schemaIdentity),
            schemaDigest: container.decode(HashDigest.self, forKey: .schemaDigest),
            componentID: container.decode(String.self, forKey: .componentID),
            componentKind: container.decode(String.self, forKey: .componentKind),
            accountableOwnerRoleID: container.decode(String.self, forKey: .accountableOwnerRoleID),
            bundleRelativePath: container.decode(String.self, forKey: .bundleRelativePath),
            artifacts: rawArtifacts,
            publications: rawPublications,
            targetDirectories: rawDirectories
        )
        guard rawArtifacts == artifacts,
              rawPublications == publications,
              rawDirectories == targetDirectories
        else {
            throw ContractError.invalidContract(
                kind: kind,
                reason: "bundle arrays must use canonical order"
            )
        }
    }

    private static func validate(
        publication: CandidateBundlePublication,
        for artifact: CandidateBundleArtifact
    ) throws {
        let path = publication.targetRelativePath
        switch (artifact.family, publication.targetNamespace) {
        case (.rule, .canon):
            try require(CandidateCanonPathGrammar.isRulePath(path), family: artifact.family)
        case (.profile, .canon):
            try require(CandidateCanonPathGrammar.isProfilePath(path), family: artifact.family)
        case (.adrMetadata, .canon):
            try require(
                CandidateCanonPathGrammar.isADRPath(
                    path,
                    suffix: ".json",
                    expectedID: artifact.logicalID
                ),
                family: artifact.family
            )
        case (.adrMarkdown, .canon):
            try require(
                CandidateCanonPathGrammar.isADRPath(
                    path,
                    suffix: ".md",
                    expectedID: artifact.logicalID
                ),
                family: artifact.family
            )
        case (.chapter, .canon):
            try require(CandidateCanonPathGrammar.isChapterPath(path), family: artifact.family)
        case (.requirementRegistry, .canon):
            try require(path == "registry/requirements.v1.json", family: artifact.family)
        case (.index, .canon):
            try require(CandidateCanonPathGrammar.indexPaths.contains(path), family: artifact.family)
        case (.check, .pluginDerived), (.fixture, .pluginDerived), (.migration, .pluginDerived),
             (.derivedTarget, .pluginDerived):
            try require(publication.publicationKind == .exactCopy, family: artifact.family)
        default:
            throw ContractError.invalidContract(
                kind: "candidate_bundle_publication",
                reason: "artifact family is not authorized for target namespace"
            )
        }
        switch artifact.family {
        case .rule, .adrMetadata, .requirementRegistry, .index:
            try require(publication.publicationKind == .resolverTransformed, family: artifact.family)
        case .profile, .adrMarkdown, .chapter:
            try require(publication.publicationKind == .exactCopy, family: artifact.family)
        default:
            break
        }
    }

    private static func require(_ condition: Bool, family: CandidateArtifactFamily) throws {
        guard condition else {
            throw ContractError.invalidContract(
                kind: "candidate_bundle_publication",
                reason: "target path or publication kind does not match family \(family.rawValue)"
            )
        }
    }

    private static func validateADRPairing(
        artifacts: [CandidateBundleArtifact],
        publications: [CandidateBundlePublication]
    ) throws {
        let byArtifact = Dictionary(uniqueKeysWithValues: publications.map { ($0.artifactID, $0) })
        let metadata = artifacts.filter { $0.family == .adrMetadata }
        let markdown = artifacts.filter { $0.family == .adrMarkdown }
        guard Set(metadata.map(\.logicalID)) == Set(markdown.map(\.logicalID)) else {
            if metadata.isEmpty, markdown.isEmpty { return }
            throw ContractError.invalidContract(
                kind: "candidate_component_bundle",
                reason: "ADR metadata and Markdown artifacts must form logical-ID pairs"
            )
        }
        for item in metadata {
            guard let peer = markdown.first(where: { $0.logicalID == item.logicalID }),
                  let metadataPath = byArtifact[item.artifactID]?.targetRelativePath,
                  let markdownPath = byArtifact[peer.artifactID]?.targetRelativePath,
                  metadataPath.dropLast(5) == markdownPath.dropLast(3)
            else {
                throw ContractError.invalidContract(
                    kind: "candidate_component_bundle",
                    reason: "ADR metadata and Markdown publications must share one basename"
                )
            }
        }
    }

    private static func directorySortKey(_ directory: CandidateBundleTargetDirectory) -> [String] {
        [directory.directoryID, directory.targetNamespace.rawValue, directory.targetRelativePath]
    }
}
