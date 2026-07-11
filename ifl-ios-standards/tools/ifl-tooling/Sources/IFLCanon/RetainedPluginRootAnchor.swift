import Foundation
import IFLContracts

package final class RetainedPluginRootIdentity: @unchecked Sendable {}

package struct CandidateOverlayID: Hashable {
    package let rawValue: String

    package init(validating rawValue: String) throws {
        let components = rawValue.split(separator: "-", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ component in
                  !component.isEmpty && component.utf8.allSatisfy {
                      (0x61 ... 0x7A).contains($0) || (0x30 ... 0x39).contains($0)
                  }
              })
        else {
            throw ContractError.invalidContract(
                kind: "candidate_overlay_id",
                reason: "overlay ID must be one canonical lowercase ASCII slug component"
            )
        }
        self.rawValue = rawValue
    }
}

package final class RetainedPluginRootAnchor: @unchecked Sendable {
    private static let reservedPackageComponents: Set<String> = [
        ".build",
        ".cache",
        ".scratch",
    ]

    private let rootAnchor: CanonRootAnchor
    private let standardsAnchor: CanonRootAnchor
    private let activeCanonAnchor: CanonRootAnchor
    let identity: RetainedPluginRootIdentity
    package let path: String

    package init(
        duplicatingPluginRootDirectoryDescriptor sourceDescriptor: Int32,
        path: String
    ) throws {
        let identity = RetainedPluginRootIdentity()
        let rootAnchor = try CanonRootAnchor(
            duplicatingRootDirectoryDescriptor: sourceDescriptor,
            path: path,
            retainedPluginIdentity: identity
        )
        let standardsAnchor = try Self.directoryAnchor(
            from: rootAnchor,
            relativePath: "standards",
            retainedPluginIdentity: identity
        )
        let activeCanonAnchor = try Self.directoryAnchor(
            from: standardsAnchor,
            relativePath: "canon",
            retainedPluginIdentity: identity
        )
        self.rootAnchor = rootAnchor
        self.standardsAnchor = standardsAnchor
        self.activeCanonAnchor = activeCanonAnchor
        self.identity = identity
        self.path = path
    }

    package func canonRootAnchor() throws -> CanonRootAnchor {
        activeCanonAnchor
    }

    package func candidateRootAnchor(
        overlayID: CandidateOverlayID
    ) throws -> CanonRootAnchor {
        let retainedPath = "standards/canon-candidates/\(overlayID.rawValue)"
        let candidateAnchor = try Self.directoryAnchor(
            from: standardsAnchor,
            relativePath: "canon-candidates/\(overlayID.rawValue)",
            retainedPluginIdentity: identity,
            missingReference: (kind: "canon file", id: retainedPath)
        )
        guard candidateAnchor.objectIdentity != activeCanonAnchor.objectIdentity else {
            throw CanonDescriptorFailure.integrityViolation(
                "\(retainedPath) aliases the retained active Canon directory"
            )
        }
        return candidateAnchor
    }

    package func captureBaseEvidence() throws -> BasePluginSnapshotEvidence {
        let captured = try reader().captureTree(emitReadEvents: false)
        let inventory = captured.inventory
        if let reservedPath = inventory.entries.first(where: { entry in
            entry.relativePath.split(separator: "/").contains {
                Self.reservedPackageComponents.contains(String($0))
            }
        })?.relativePath {
            throw CanonDescriptorFailure.integrityViolation(
                "package-local artifact node is forbidden: \(reservedPath)"
            )
        }
        return try BasePluginSnapshotEvidence(
            inventory: inventory,
            snapshotsByRelativePath: captured.snapshotsByRelativePath,
            retainedPluginIdentity: identity
        )
    }

    package func owns(_ evidence: CanonSnapshotEvidence) -> Bool {
        evidence.retainedPluginIdentity === identity
    }

    func owns(_ evidence: BasePluginSnapshotEvidence) -> Bool {
        evidence.retainedPluginIdentity === identity
    }

    func reader(
        eventHandler: @escaping CanonRepositoryReadEventHandler = { _ in }
    ) throws -> CanonDescriptorReader {
        try CanonDescriptorReader(
            rootDescriptor: rootAnchor.duplicateRootDescriptor(),
            eventHandler: eventHandler
        )
    }

    private static func directoryAnchor(
        from parent: CanonRootAnchor,
        relativePath rawPath: String,
        retainedPluginIdentity: RetainedPluginRootIdentity,
        missingReference: (kind: String, id: String)? = nil
    ) throws -> CanonRootAnchor {
        let relativePath = try CanonicalRelativePath(validating: rawPath)
        let reader = try CanonDescriptorReader(
            rootDescriptor: parent.duplicateRootDescriptor(),
            eventHandler: { _ in }
        )
        return try reader.openDirectoryAnchor(
            relativePath: relativePath,
            retainedPluginIdentity: retainedPluginIdentity,
            missingReference: missingReference
        )
    }
}
