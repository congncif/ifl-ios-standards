import Darwin
import Foundation
import IFLCanon
import IFLContracts

public enum VerificationRootError: Error, Equatable, Sendable {
    case invalidSelection
    case missingBinding(String)
    case ambiguousPluginRoots([String])
    case symlinkBoundary(String)

    public var exitCode: IFLExitCode {
        switch self {
        case .invalidSelection, .ambiguousPluginRoots:
            .invalidInput
        case .missingBinding:
            .blockedEnvironment
        case .symlinkBoundary:
            .integrityViolation
        }
    }
}

extension VerificationRootError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidSelection:
            "Exactly one of --root and --canon-root is required."
        case let .missingBinding(path):
            "Required Canon root binding is missing or incomplete: \(path)"
        case let .ambiguousPluginRoots(paths):
            "Workspace contains multiple direct plugin roots: \(paths.joined(separator: ", "))"
        case let .symlinkBoundary(path):
            "Canon root selection crosses a symlink boundary: \(path)"
        }
    }
}

package enum VerificationRootLocatorWorkspaceCandidateEvent: Equatable {
    case didQualifyCandidate(String)
}

package typealias VerificationRootLocatorWorkspaceCandidateEventHandler = @Sendable (
    VerificationRootLocatorWorkspaceCandidateEvent
) throws -> Void

package final class ResolvedVerificationRoot: @unchecked Sendable {
    package let canonRoot: URL
    package let canonAnchor: CanonRootAnchor
    package let retainedPluginRootAnchor: RetainedPluginRootAnchor?
    private let bindings: [VerificationDirectoryBinding]

    fileprivate init(
        canonRoot: URL,
        bindings: [VerificationDirectoryBinding],
        pluginBinding: VerificationDirectoryBinding?
    ) throws {
        guard let canonBinding = bindings.last else {
            throw VerificationRootError.missingBinding(canonRoot.path)
        }
        self.canonRoot = canonRoot
        self.bindings = bindings
        do {
            canonAnchor = try CanonRootAnchor(
                duplicatingRootDirectoryDescriptor: canonBinding.descriptor.rawValue,
                path: canonRoot.path
            )
            if let pluginBinding {
                retainedPluginRootAnchor = try RetainedPluginRootAnchor(
                    duplicatingPluginRootDirectoryDescriptor: pluginBinding.descriptor.rawValue,
                    path: pluginBinding.path
                )
            } else {
                retainedPluginRootAnchor = nil
            }
        } catch {
            throw VerificationRootError.symlinkBoundary(canonRoot.path)
        }
        try validateBinding()
    }

    package func validateBinding() throws {
        for binding in bindings {
            try binding.validate()
        }
    }
}

public struct VerificationRootLocator: Sendable {
    private let workspaceCandidateEventHandler:
        VerificationRootLocatorWorkspaceCandidateEventHandler

    public init() {
        workspaceCandidateEventHandler = { _ in }
    }

    package init(
        workspaceCandidateEventHandler: @escaping
        VerificationRootLocatorWorkspaceCandidateEventHandler
    ) {
        self.workspaceCandidateEventHandler = workspaceCandidateEventHandler
    }

    public func resolve(root: URL?, canonRoot: URL?) throws -> URL {
        try resolveAnchored(root: root, canonRoot: canonRoot).canonRoot
    }

    package func resolveAnchored(
        root: URL?,
        canonRoot: URL?
    ) throws -> ResolvedVerificationRoot {
        guard (root == nil) != (canonRoot == nil) else {
            throw VerificationRootError.invalidSelection
        }

        if let canonRoot {
            let selectedURL = canonRoot.standardizedFileURL
            let selected = try openSelectedBoundary(selectedURL)
            try validateRequiredFiles(in: selected)
            return try ResolvedVerificationRoot(
                canonRoot: selectedURL,
                bindings: [selected],
                pluginBinding: nil
            )
        }

        let selectedURL = root!.standardizedFileURL
        let selected = try openSelectedBoundary(selectedURL)
        let standardsPath = selectedURL.appendingPathComponent("standards")
        switch try node(at: selected.descriptor.rawValue, name: "standards") {
        case .missing:
            return try resolveWorkspace(selectedURL: selectedURL, selected: selected)
        case .symlink:
            throw VerificationRootError.symlinkBoundary(standardsPath.path)
        case .directory:
            return try resolvePlugin(
                pluginURL: selectedURL,
                prefixBindings: [selected],
                pluginBinding: selected
            )
        default:
            throw VerificationRootError.missingBinding(standardsPath.path)
        }
    }

    private func resolveWorkspace(
        selectedURL: URL,
        selected: VerificationDirectoryBinding
    ) throws -> ResolvedVerificationRoot {
        let names = try directoryNames(
            descriptor: selected.descriptor.rawValue,
            path: selectedURL.path
        )
        var candidates: [VerificationWorkspaceCandidate] = []

        for name in names {
            let childURL = selectedURL.appendingPathComponent(name)
            switch try node(at: selected.descriptor.rawValue, name: name) {
            case .symlink:
                throw VerificationRootError.symlinkBoundary(childURL.path)
            case .directory:
                break
            default:
                continue
            }

            let child = try openDirectoryComponent(
                parent: selected,
                name: name,
                url: childURL
            )
            let standardsURL = childURL.appendingPathComponent("standards")
            switch try node(at: child.descriptor.rawValue, name: "standards") {
            case .missing:
                continue
            case .symlink:
                throw VerificationRootError.symlinkBoundary(standardsURL.path)
            case .directory:
                break
            default:
                continue
            }

            let standards = try openDirectoryComponent(
                parent: child,
                name: "standards",
                url: standardsURL
            )
            let canonURL = standardsURL.appendingPathComponent("canon")
            switch try node(at: standards.descriptor.rawValue, name: "canon") {
            case .symlink:
                throw VerificationRootError.symlinkBoundary(canonURL.path)
            case .directory:
                let canon = try openDirectoryComponent(
                    parent: standards,
                    name: "canon",
                    url: canonURL
                )
                candidates.append(VerificationWorkspaceCandidate(
                    pluginURL: childURL,
                    canonURL: canonURL,
                    plugin: child,
                    standards: standards,
                    canon: canon
                ))
                try workspaceCandidateEventHandler(.didQualifyCandidate(childURL.path))
            default:
                continue
            }
        }

        guard candidates.count == 1 else {
            if candidates.isEmpty {
                throw VerificationRootError.missingBinding(selectedURL.path)
            }
            throw VerificationRootError.ambiguousPluginRoots(candidates.map(\.pluginURL.path))
        }

        let candidate = candidates[0]
        try validateRequiredFiles(in: candidate.canon)
        return try ResolvedVerificationRoot(
            canonRoot: candidate.canonURL,
            bindings: [
                selected,
                candidate.plugin,
                candidate.standards,
                candidate.canon,
            ],
            pluginBinding: candidate.plugin
        )
    }

    private func resolvePlugin(
        pluginURL: URL,
        prefixBindings: [VerificationDirectoryBinding],
        pluginBinding: VerificationDirectoryBinding
    ) throws -> ResolvedVerificationRoot {
        let standardsURL = pluginURL.appendingPathComponent("standards")
        let standards = try openRequiredDirectoryComponent(
            parent: pluginBinding,
            name: "standards",
            url: standardsURL
        )
        let canonURL = standardsURL.appendingPathComponent("canon")
        let canon = try openRequiredDirectoryComponent(
            parent: standards,
            name: "canon",
            url: canonURL
        )
        try validateRequiredFiles(in: canon)
        return try ResolvedVerificationRoot(
            canonRoot: canonURL,
            bindings: prefixBindings + [standards, canon],
            pluginBinding: pluginBinding
        )
    }

    private func openSelectedBoundary(_ url: URL) throws -> VerificationDirectoryBinding {
        let snapshot = try selectedSnapshot(path: url.path)
        switch snapshot.kind {
        case mode_t(S_IFLNK):
            throw VerificationRootError.symlinkBoundary(url.path)
        case mode_t(S_IFDIR):
            break
        default:
            throw VerificationRootError.missingBinding(url.path)
        }
        try validateDirectorySnapshot(snapshot, parentDevice: nil, path: url.path)

        let rawDescriptor = try openDirectory(path: url.path)
        let descriptor = VerificationOwnedFileDescriptor(rawDescriptor)
        let opened = try descriptorSnapshot(rawDescriptor, path: url.path)
        guard opened == snapshot else {
            throw VerificationRootError.symlinkBoundary(url.path)
        }
        try validateDirectorySnapshot(opened, parentDevice: nil, path: url.path)
        return VerificationDirectoryBinding(
            descriptor: descriptor,
            snapshot: opened,
            path: url.path,
            parentDescriptor: nil,
            name: nil
        )
    }

    private func openRequiredDirectoryComponent(
        parent: VerificationDirectoryBinding,
        name: String,
        url: URL
    ) throws -> VerificationDirectoryBinding {
        switch try node(at: parent.descriptor.rawValue, name: name) {
        case .symlink:
            throw VerificationRootError.symlinkBoundary(url.path)
        case .directory:
            return try openDirectoryComponent(parent: parent, name: name, url: url)
        default:
            throw VerificationRootError.missingBinding(url.path)
        }
    }

    private func openDirectoryComponent(
        parent: VerificationDirectoryBinding,
        name: String,
        url: URL
    ) throws -> VerificationDirectoryBinding {
        let before = try relativeSnapshot(
            parentDescriptor: parent.descriptor.rawValue,
            name: name,
            path: url.path
        )
        guard before.kind == mode_t(S_IFDIR) else {
            if before.kind == mode_t(S_IFLNK) {
                throw VerificationRootError.symlinkBoundary(url.path)
            }
            throw VerificationRootError.missingBinding(url.path)
        }
        try validateDirectorySnapshot(
            before,
            parentDevice: parent.snapshot.device,
            path: url.path
        )

        let rawDescriptor = try openDirectory(
            parentDescriptor: parent.descriptor.rawValue,
            name: name,
            path: url.path
        )
        let descriptor = VerificationOwnedFileDescriptor(rawDescriptor)
        let opened = try descriptorSnapshot(rawDescriptor, path: url.path)
        guard opened == before else {
            throw VerificationRootError.symlinkBoundary(url.path)
        }
        try validateDirectorySnapshot(
            opened,
            parentDevice: parent.snapshot.device,
            path: url.path
        )
        return VerificationDirectoryBinding(
            descriptor: descriptor,
            snapshot: opened,
            path: url.path,
            parentDescriptor: parent.descriptor,
            name: name
        )
    }

    private func validateRequiredFiles(in canon: VerificationDirectoryBinding) throws {
        let requiredFiles = [
            "VERSION",
            "registry/adrs.index.json",
            "registry/chapters.index.json",
            "registry/derived-artifacts.index.json",
            "registry/profiles.index.json",
            "registry/requirements.v1.json",
            "registry/rules.index.json",
        ]
        for relativePath in requiredFiles {
            try validateRequiredFile(relativePath, in: canon)
        }
    }

    private func validateRequiredFile(
        _ relativePath: String,
        in canon: VerificationDirectoryBinding
    ) throws {
        let components = relativePath.split(separator: "/").map(String.init)
        guard let filename = components.last else {
            throw VerificationRootError.missingBinding(canon.path)
        }
        var parent = canon
        var parentURL = URL(fileURLWithPath: canon.path)
        var retainedDirectories: [VerificationDirectoryBinding] = []
        for component in components.dropLast() {
            parentURL.appendPathComponent(component)
            let opened = try openRequiredDirectoryComponent(
                parent: parent,
                name: component,
                url: parentURL
            )
            retainedDirectories.append(opened)
            parent = opened
        }
        _ = retainedDirectories

        let fileURL = URL(fileURLWithPath: canon.path).appendingPathComponent(relativePath)
        let before: VerificationFileSnapshot
        do {
            before = try relativeSnapshot(
                parentDescriptor: parent.descriptor.rawValue,
                name: filename,
                path: fileURL.path
            )
        } catch let error as VerificationRootError {
            throw error
        }
        if before.kind == mode_t(S_IFLNK) {
            throw VerificationRootError.symlinkBoundary(fileURL.path)
        }
        guard before.kind == mode_t(S_IFREG) else {
            throw VerificationRootError.missingBinding(fileURL.path)
        }
        try validateRegularFileSnapshot(
            before,
            rootDevice: canon.snapshot.device,
            path: fileURL.path
        )

        let rawDescriptor = try openFile(
            parentDescriptor: parent.descriptor.rawValue,
            name: filename,
            path: fileURL.path
        )
        let descriptor = VerificationOwnedFileDescriptor(rawDescriptor)
        let opened = try descriptorSnapshot(descriptor.rawValue, path: fileURL.path)
        guard opened == before else {
            throw VerificationRootError.symlinkBoundary(fileURL.path)
        }
        try validateRegularFileSnapshot(
            opened,
            rootDevice: canon.snapshot.device,
            path: fileURL.path
        )
    }

    private func selectedSnapshot(path: String) throws -> VerificationFileSnapshot {
        var value = stat()
        while true {
            let result = path.withCString { Darwin.lstat($0, &value) }
            if result == 0 {
                return VerificationFileSnapshot(value)
            }
            if errno == EINTR {
                continue
            }
            throw VerificationRootError.missingBinding(path)
        }
    }

    private func relativeSnapshot(
        parentDescriptor: Int32,
        name: String,
        path: String
    ) throws -> VerificationFileSnapshot {
        var value = stat()
        while true {
            let result = name.withCString {
                Darwin.fstatat(parentDescriptor, $0, &value, AT_SYMLINK_NOFOLLOW)
            }
            if result == 0 {
                return VerificationFileSnapshot(value)
            }
            if errno == EINTR {
                continue
            }
            if errno == ENOENT || errno == ENOTDIR {
                throw VerificationRootError.missingBinding(path)
            }
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func descriptorSnapshot(
        _ descriptor: Int32,
        path: String
    ) throws -> VerificationFileSnapshot {
        var value = stat()
        while true {
            if Darwin.fstat(descriptor, &value) == 0 {
                return VerificationFileSnapshot(value)
            }
            if errno == EINTR {
                continue
            }
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func node(at parentDescriptor: Int32, name: String) throws -> VerificationNodeKind {
        var value = stat()
        while true {
            let result = name.withCString {
                Darwin.fstatat(parentDescriptor, $0, &value, AT_SYMLINK_NOFOLLOW)
            }
            if result == 0 {
                switch value.st_mode & mode_t(S_IFMT) {
                case mode_t(S_IFDIR):
                    return .directory
                case mode_t(S_IFREG):
                    return .regularFile
                case mode_t(S_IFLNK):
                    return .symlink
                default:
                    return .other
                }
            }
            if errno == EINTR {
                continue
            }
            if errno == ENOENT || errno == ENOTDIR {
                return .missing
            }
            throw VerificationRootError.symlinkBoundary(name)
        }
    }

    private func openDirectory(path: String) throws -> Int32 {
        while true {
            let descriptor = path.withCString {
                Darwin.open($0, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
            }
            if descriptor >= 0 {
                return descriptor
            }
            if errno == EINTR {
                continue
            }
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func openDirectory(
        parentDescriptor: Int32,
        name: String,
        path: String
    ) throws -> Int32 {
        while true {
            let descriptor = name.withCString {
                Darwin.openat(
                    parentDescriptor,
                    $0,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
                )
            }
            if descriptor >= 0 {
                return descriptor
            }
            if errno == EINTR {
                continue
            }
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func openFile(
        parentDescriptor: Int32,
        name: String,
        path: String
    ) throws -> Int32 {
        while true {
            let descriptor = name.withCString {
                Darwin.openat(
                    parentDescriptor,
                    $0,
                    O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
                )
            }
            if descriptor >= 0 {
                return descriptor
            }
            if errno == EINTR {
                continue
            }
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func directoryNames(descriptor: Int32, path: String) throws -> [String] {
        let rawDescriptor = Darwin.openat(
            descriptor,
            ".",
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard rawDescriptor >= 0 else {
            throw VerificationRootError.missingBinding(path)
        }
        guard let directory = Darwin.fdopendir(rawDescriptor) else {
            Darwin.close(rawDescriptor)
            throw VerificationRootError.missingBinding(path)
        }
        defer { Darwin.closedir(directory) }

        var names: [String] = []
        while true {
            errno = 0
            guard let entry = Darwin.readdir(directory) else {
                if errno != 0 {
                    throw VerificationRootError.missingBinding(path)
                }
                break
            }
            let length = Int(entry.pointee.d_namlen)
            let name: String? = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: UInt8.self, capacity: length) { bytes in
                    String(
                        bytes: UnsafeBufferPointer(start: bytes, count: length),
                        encoding: .utf8
                    )
                }
            }
            guard let name else {
                throw VerificationRootError.symlinkBoundary(path)
            }
            if name != ".", name != ".." {
                names.append(name)
            }
        }
        return names.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
    }

    private func validateDirectorySnapshot(
        _ snapshot: VerificationFileSnapshot,
        parentDevice: UInt64?,
        path: String
    ) throws {
        guard snapshot.kind == mode_t(S_IFDIR) else {
            throw VerificationRootError.missingBinding(path)
        }
        guard parentDevice == nil || snapshot.device == parentDevice,
              snapshot.rawMode & mode_t(S_ISUID | S_ISGID | S_ISVTX) == 0
        else {
            throw VerificationRootError.symlinkBoundary(path)
        }
    }

    private func validateRegularFileSnapshot(
        _ snapshot: VerificationFileSnapshot,
        rootDevice: UInt64,
        path: String
    ) throws {
        guard snapshot.kind == mode_t(S_IFREG) else {
            throw VerificationRootError.missingBinding(path)
        }
        guard snapshot.device == rootDevice,
              snapshot.linkCount == 1,
              snapshot.rawMode & mode_t(S_ISUID | S_ISGID | S_ISVTX) == 0
        else {
            throw VerificationRootError.symlinkBoundary(path)
        }
    }
}

private final class VerificationOwnedFileDescriptor: @unchecked Sendable {
    let rawValue: Int32

    init(_ rawValue: Int32) {
        self.rawValue = rawValue
    }

    deinit {
        Darwin.close(rawValue)
    }
}

private struct VerificationDirectoryBinding: @unchecked Sendable {
    let descriptor: VerificationOwnedFileDescriptor
    let snapshot: VerificationFileSnapshot
    let path: String
    let parentDescriptor: VerificationOwnedFileDescriptor?
    let name: String?

    func validate() throws {
        var value = stat()
        guard Darwin.fstat(descriptor.rawValue, &value) == 0,
              VerificationFileSnapshot(value) == snapshot
        else {
            throw VerificationRootError.symlinkBoundary(path)
        }

        if let parentDescriptor, let name {
            var linkValue = stat()
            let result = name.withCString {
                Darwin.fstatat(
                    parentDescriptor.rawValue,
                    $0,
                    &linkValue,
                    AT_SYMLINK_NOFOLLOW
                )
            }
            guard result == 0, VerificationFileSnapshot(linkValue) == snapshot else {
                throw VerificationRootError.symlinkBoundary(path)
            }
        } else {
            var linkValue = stat()
            let result = path.withCString { Darwin.lstat($0, &linkValue) }
            guard result == 0, VerificationFileSnapshot(linkValue) == snapshot else {
                throw VerificationRootError.symlinkBoundary(path)
            }
        }
    }
}

private struct VerificationFileSnapshot: Equatable {
    let device: UInt64
    let inode: UInt64
    let kind: mode_t
    let rawMode: mode_t
    let linkCount: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(_ value: stat) {
        device = UInt64(value.st_dev)
        inode = UInt64(value.st_ino)
        kind = value.st_mode & mode_t(S_IFMT)
        rawMode = value.st_mode
        linkCount = UInt64(value.st_nlink)
        size = value.st_size
        modificationSeconds = Int64(value.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changeSeconds = Int64(value.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }
}

private enum VerificationNodeKind {
    case missing
    case directory
    case regularFile
    case symlink
    case other
}

private struct VerificationWorkspaceCandidate {
    let pluginURL: URL
    let canonURL: URL
    let plugin: VerificationDirectoryBinding
    let standards: VerificationDirectoryBinding
    let canon: VerificationDirectoryBinding
}
