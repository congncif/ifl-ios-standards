import Foundation
import IFLContracts

package struct CandidateCapturedFile {
    package let bytes: Data
    package let mode: UInt16
    package let contentDigest: HashDigest
}

package struct CandidateTreeCapture {
    package let inventory: CanonicalTreeInventory
    package let captureDigest: HashDigest
    package let filesByRelativePath: [String: CandidateCapturedFile]
    let snapshotsByRelativePath: [String: CanonFileSnapshot]

    static func capture(
        anchor: CanonRootAnchor,
        eventHandler: @escaping CandidateOverlayValidationEventHandler
    ) throws -> CandidateTreeCapture {
        let descriptorReader = try CanonDescriptorReader(
            rootDescriptor: anchor.duplicateRootDescriptor(),
            eventHandler: { event in
                if case let .didReadFile(path) = event {
                    try eventHandler(.didCaptureCandidateFile(path))
                }
            }
        )
        let captured = try descriptorReader.captureTree()
        var files: [String: CandidateCapturedFile] = [:]
        files.reserveCapacity(captured.filesByRelativePath.count)
        let entriesByPath = Dictionary(
            uniqueKeysWithValues: captured.inventory.entries.map {
                ($0.relativePath, $0)
            }
        )
        for (path, bytes) in captured.filesByRelativePath {
            guard let entry = entriesByPath[path],
                  entry.kind == .regularFile,
                  let contentDigest = entry.contentSHA256
            else {
                throw CanonDescriptorFailure.integrityViolation(
                    "candidate file capture is absent from its inventory: \(path)"
                )
            }
            files[path] = CandidateCapturedFile(
                bytes: bytes,
                mode: entry.mode,
                contentDigest: contentDigest
            )
        }
        return try CandidateTreeCapture(
            inventory: captured.inventory,
            captureDigest: CanonicalTreeDigest.digest(captured.inventory),
            filesByRelativePath: files,
            snapshotsByRelativePath: captured.snapshotsByRelativePath
        )
    }
}
