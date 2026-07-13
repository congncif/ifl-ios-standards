import Foundation
@testable import IFLCanon
import IFLContracts

enum FixtureCanon {
    enum SupportError: Error, Equatable {
        case invalidFixturePath(String)
        case invalidManifest(String)
        case mutationFailed(fixtureID: String, reason: String)
    }

    struct Execution {
        let fixtureID: String
        let expected: FixtureExpected
        let outcome: Outcome
    }

    enum Outcome {
        case snapshot(CanonSnapshot)
        case contractError(ContractError)
    }

    static let positiveRoot = pluginRoot
        .appendingPathComponent("verification/fixtures/canon/positive/minimal")
    static let negativeRoot = pluginRoot
        .appendingPathComponent("verification/fixtures/canon/negative", isDirectory: true)

    static func negativeFixturePaths(at root: URL = negativeRoot) throws -> [String] {
        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
        ]
        let entries = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        return try entries.map { entry in
            let values = try entry.resourceValues(forKeys: resourceKeys)
            guard values.isSymbolicLink != true, values.isDirectory == true else {
                throw SupportError.invalidFixturePath(
                    "negative fixture root contains non-directory entry: \(entry.lastPathComponent)"
                )
            }

            let manifest = entry.appendingPathComponent("fixture.json")
            let manifestValues = try manifest.resourceValues(forKeys: resourceKeys)
            guard manifestValues.isSymbolicLink != true,
                  manifestValues.isRegularFile == true
            else {
                throw SupportError.invalidFixturePath(
                    "negative fixture directory must contain a regular fixture.json: "
                        + entry.lastPathComponent
                )
            }
            return "negative/\(entry.lastPathComponent)"
        }
    }

    static func load(_ fixturePath: String) throws -> CanonSnapshot {
        let execution = try execute(fixturePath)
        switch execution.outcome {
        case let .snapshot(snapshot):
            return snapshot
        case let .contractError(error):
            throw error
        }
    }

    static func execute(_ fixturePath: String) throws -> Execution {
        let manifest = try manifest(at: fixturePath)
        let outcome = try withPositiveRoot { root -> Outcome in
            do {
                try apply(manifest, to: root)
            } catch {
                throw SupportError.mutationFailed(
                    fixtureID: manifest.fixtureID,
                    reason: String(describing: error)
                )
            }

            let repository: any CanonRepository = FileCanonRepository(root: root)
            do {
                return try .snapshot(
                    repository.snapshot(profiles: [ProfileID(validating: "core")])
                )
            } catch let error as ContractError {
                return .contractError(error)
            }
        }
        return Execution(
            fixtureID: manifest.fixtureID,
            expected: manifest.expected,
            outcome: outcome
        )
    }

    static func decodeManifest(_ data: Data) throws -> FixtureManifest {
        do {
            let object = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
            guard object is [String: Any] else {
                throw SupportError.invalidManifest("fixture manifest root must be an object")
            }
            let canonicalData = try fixtureCanonicalJSONFileData(object)
            guard data == canonicalData else {
                throw SupportError.invalidManifest(
                    "fixture manifest must use canonical JSON bytes"
                )
            }
            return try JSONDecoder().decode(FixtureManifest.self, from: data)
        } catch let error as SupportError {
            throw error
        } catch {
            throw SupportError.invalidManifest(String(describing: error))
        }
    }

    static func withPositiveRoot<T>(_ body: (URL) throws -> T) throws -> T {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent(
                "ifl-fixture-canon-\(UUID().uuidString)",
                isDirectory: true
            )
        let root = workspace.appendingPathComponent("canon", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: workspace) }
        try fileManager.copyItem(at: positiveRoot, to: root)
        return try body(root)
    }

    private static let pluginRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func manifest(at fixturePath: String) throws -> FixtureManifest {
        let components = fixturePath.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2,
              components[0] == "negative",
              !components[1].isEmpty,
              components[1] != ".",
              components[1] != ".."
        else {
            throw SupportError.invalidFixturePath(
                "fixture path must be negative/<case>"
            )
        }

        let manifestURL = negativeRoot
            .appendingPathComponent(String(components[1]))
            .appendingPathComponent("fixture.json")
        return try decodeManifest(Data(contentsOf: manifestURL))
    }
}
