import Foundation
@testable import IFLVerification
import Testing

@Suite("CandidateOverlayRootLocatorTests", .serialized)
struct CandidateOverlayRootLocatorTests {
    @Test("plugin and workspace selection retain exactly one candidate-overlay authority")
    func pluginAndWorkspaceRetainOneAuthority() throws {
        try withWorkspace { workspace, plugin, canon in
            let locator = VerificationRootLocator()
            let fromPlugin = try locator.resolveAnchored(root: plugin, canonRoot: nil)
            let fromWorkspace = try locator.resolveAnchored(root: workspace, canonRoot: nil)

            #expect(fromPlugin.canonRoot == canon)
            #expect(fromWorkspace.canonRoot == canon)
            #expect(fromPlugin.retainedPluginRootAnchor != nil)
            #expect(fromWorkspace.retainedPluginRootAnchor != nil)
        }
    }

    @Test("direct Canon selection remains authority-free for candidate validation")
    func directCanonSelectionIsAuthorityFree() throws {
        try withWorkspace { _, _, canon in
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: nil,
                canonRoot: canon
            )

            #expect(resolved.canonRoot == canon)
            #expect(resolved.retainedPluginRootAnchor == nil)
        }
    }

    @Test("ambiguous workspace roots mint no retained plugin authority")
    func ambiguousWorkspaceHasNoAuthority() throws {
        try withWorkspace { workspace, plugin, _ in
            let second = workspace.appendingPathComponent("second-plugin", isDirectory: true)
            try createPlugin(at: second)

            do {
                _ = try VerificationRootLocator().resolveAnchored(
                    root: workspace,
                    canonRoot: nil
                )
                Issue.record("Expected ambiguous workspace")
            } catch let error as VerificationRootError {
                #expect(error == .ambiguousPluginRoots([plugin.path, second.path]))
                #expect(error.exitCode == .invalidInput)
            } catch {
                Issue.record("Unexpected ambiguity error: \(error)")
            }
        }
    }

    @Test("a workspace with no retained plugin is an exact blocked binding")
    func missingWorkspacePluginIsBlocked() throws {
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ifl-candidate-root-empty-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: workspace) }

        do {
            _ = try VerificationRootLocator().resolveAnchored(root: workspace, canonRoot: nil)
            Issue.record("Expected missing workspace binding")
        } catch let error as VerificationRootError {
            #expect(error == .missingBinding(workspace.path))
            #expect(error.exitCode == .blockedEnvironment)
        } catch {
            Issue.record("Unexpected missing-workspace error: \(error)")
        }
    }

    @Test("a trusted ancestor alias does not change the retained selected plugin")
    func trustedAncestorAliasRetainsSelectedPlugin() throws {
        try withWorkspace { workspace, plugin, canon in
            let alias = workspace.deletingLastPathComponent().appendingPathComponent(
                "alias-\(UUID().uuidString)",
                isDirectory: true
            )
            try FileManager.default.createSymbolicLink(
                at: alias,
                withDestinationURL: workspace
            )
            defer { try? FileManager.default.removeItem(at: alias) }

            let aliasedPlugin = alias.appendingPathComponent(plugin.lastPathComponent)
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: aliasedPlugin,
                canonRoot: nil
            )

            #expect(resolved.canonRoot.path.hasSuffix("standards/canon"))
            #expect(resolved.retainedPluginRootAnchor != nil)
            #expect(try resolved.retainedPluginRootAnchor?.captureBaseEvidence().inventory.entries
                .contains { $0.relativePath == "standards/canon/VERSION" } == true)
            #expect(canon.lastPathComponent == "canon")
        }
    }
}

private extension CandidateOverlayRootLocatorTests {
    func withWorkspace<T>(_ body: (URL, URL, URL) throws -> T) throws -> T {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory.appendingPathComponent(
            "ifl-candidate-root-locator-\(UUID().uuidString)",
            isDirectory: true
        )
        let plugin = workspace.appendingPathComponent("plugin", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: workspace) }
        try createPlugin(at: plugin)
        return try body(
            workspace,
            plugin,
            plugin.appendingPathComponent("standards/canon", isDirectory: true)
        )
    }

    func createPlugin(at plugin: URL) throws {
        let minimalCanon = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("verification/fixtures/canon/positive/minimal")
        let canon = plugin.appendingPathComponent("standards/canon", isDirectory: true)
        try FileManager.default.createDirectory(
            at: canon.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: minimalCanon, to: canon)
    }
}
