import CryptoKit
import Darwin
import Foundation
@testable import IFLVerification
import Testing

@Suite("CanonCommandTests", .serialized)
struct CanonCommandTests {
    @Test("positive minimal JSON is deterministic and exits zero")
    func positiveMinimalJSONIsDeterministic() throws {
        let arguments = [
            "canon",
            "--canon-root", minimalCanonRoot.path,
            "--profile", "core",
            "--requirement", "REQ-CANON",
            "--offline",
            "--format", "json",
        ]

        let first = try runCLI(arguments)
        let second = try runCLI(arguments)
        let report = try JSONDecoder().decode(VerificationReport.self, from: first.stdout)

        #expect(first.status == 0)
        #expect(first.stderr.isEmpty)
        #expect(hasExactlyOneTrailingNewline(first.stdout))
        #expect(first.sideEffects.isEmpty)
        #expect(first.stdout == second.stdout)
        #expect(first.stderr == second.stderr)
        #expect(
            first.stdout == Data(
                #"{"checks":[{"check_id":"CHK-CAN-VALIDATE-001","passed":true}],"exit_code":0,"schema_version":1}"#.utf8
            ) + Data([0x0A])
        )
        #expect(report.exitCode.rawValue == 0)
        #expect(report.checks == [
            CheckResult(checkID: "CHK-CAN-VALIDATE-001", passed: true),
        ])
    }

    @Test("invalid selectors produce an invalid-input JSON report")
    func invalidSelectorExitsTwo() throws {
        let result = try runCLI([
            "canon",
            "--canon-root", minimalCanonRoot.path,
            "--profile", "cor",
            "--format", "json",
        ])
        let report = try JSONDecoder().decode(VerificationReport.self, from: result.stdout)

        #expect(result.status == 2)
        #expect(result.stderr.isEmpty)
        #expect(hasExactlyOneTrailingNewline(result.stdout))
        #expect(result.sideEffects.isEmpty)
        #expect(report.exitCode.rawValue == 2)
        #expect(report.checks == [CheckResult(
            checkID: "CHK-CAN-FILTER-001",
            passed: false,
            severity: .high,
            message: "Unknown Profile selector(s): cor."
        )])
    }

    @Test("digest-tampered Canon exits five")
    func digestTamperingExitsFive() throws {
        try withTemporaryDirectory { root in
            let tamperedCanon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: tamperedCanon)
            let record = tamperedCanon.appendingPathComponent("rules/core/minimal.rules.json")
            var bytes = try Data(contentsOf: record)
            bytes.append(contentsOf: Data(" ".utf8))
            try bytes.write(to: record)

            let result = try runCLI([
                "canon",
                "--canon-root", tamperedCanon.path,
                "--format", "json",
            ])
            let report = try JSONDecoder().decode(VerificationReport.self, from: result.stdout)

            #expect(result.status == 5)
            #expect(result.stderr.isEmpty)
            #expect(hasExactlyOneTrailingNewline(result.stdout))
            #expect(result.sideEffects.isEmpty)
            #expect(report.exitCode.rawValue == 5)
            #expect(report.checks.count == 1)
            #expect(report.checks[0].checkID == "CHK-CAN-LOAD-001")
            #expect(report.checks[0].passed == false)
        }
    }

    @Test("invalid Canon command arguments exit two")
    func invalidCanonArgumentsExitTwo() throws {
        let invalidArguments = [
            ["canon", "--format", "json"],
            [
                "canon",
                "--root", pluginRoot.path,
                "--canon-root", minimalCanonRoot.path,
                "--format", "json",
            ],
            ["canon", "--canon-root", minimalCanonRoot.path, "--unknown"],
            ["canon", "--canon-root"],
            [
                "canon",
                "--canon-root", minimalCanonRoot.path,
                "--canon-root", minimalCanonRoot.path,
            ],
            ["canon", "--canon-root", minimalCanonRoot.path, "--format", "yaml"],
        ]

        for arguments in invalidArguments {
            let result = try runCLI(arguments)
            #expect(result.status == 2)
            #expect(result.stdout.isEmpty == false)
            #expect(result.stderr.isEmpty)
            #expect(hasExactlyOneTrailingNewline(result.stdout))
            #expect(result.sideEffects.isEmpty)
        }
    }

    @Test("human output is stdout-only and version behavior is preserved")
    func stdoutAndVersionBehavior() throws {
        let human = try runCLI([
            "canon",
            "--canon-root", minimalCanonRoot.path,
            "--format", "human",
        ])
        #expect(human.status == 0)
        #expect(human.stderr.isEmpty)
        #expect(hasExactlyOneTrailingNewline(human.stdout))
        #expect(
            human.stdout == Data(
                "exit_code: 0\nCHK-CAN-VALIDATE-001: passed\n".utf8
            )
        )
        #expect(human.sideEffects.isEmpty)

        let version = try runCLI(["--version"])
        #expect(version.status == 0)
        #expect(version.stdout == Data("1.0.0-rc.1\n".utf8))
        #expect(version.stderr.isEmpty)
        #expect(version.sideEffects.isEmpty)
    }

    @Test("root and canon root are mutually exclusive and one source is required")
    func rootSelectionIsExclusiveAndRequired() {
        let locator = VerificationRootLocator()

        expectRootError(.invalidSelection) {
            _ = try locator.resolve(root: pluginRoot, canonRoot: minimalCanonRoot)
        }
        expectRootError(.invalidSelection) {
            _ = try locator.resolve(root: URL?.none, canonRoot: URL?.none)
        }
    }

    @Test("an exact complete canon root is accepted without discovery")
    func exactCanonRootIsAccepted() throws {
        let resolved: URL = try VerificationRootLocator().resolve(
            root: URL?.none,
            canonRoot: minimalCanonRoot
        )

        #expect(resolved.standardizedFileURL == minimalCanonRoot.standardizedFileURL)
    }

    @Test("root accepts the plugin root and its direct workspace parent")
    func pluginAndWorkspaceRootsResolveTheSameCanon() throws {
        let locator = VerificationRootLocator()
        let fromPlugin: URL = try locator.resolve(root: pluginRoot, canonRoot: URL?.none)
        let fromWorkspace: URL = try locator.resolve(root: workspaceRoot, canonRoot: URL?.none)

        #expect(fromPlugin.standardizedFileURL == productionCanonRoot.standardizedFileURL)
        #expect(fromWorkspace.standardizedFileURL == productionCanonRoot.standardizedFileURL)
    }

    @Test("workspace candidates must contain a direct standards canon root")
    func workspaceCandidatesRequireCanonRoot() throws {
        try withTemporaryDirectory { root in
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent("not-a-plugin/standards"),
                withIntermediateDirectories: true
            )
            let plugin = root.appendingPathComponent("plugin")
            try createFixturePlugin(at: plugin)

            let resolved = try VerificationRootLocator().resolve(
                root: root,
                canonRoot: URL?.none
            )

            #expect(resolved.standardizedFileURL == plugin
                .appendingPathComponent("standards/canon")
                .standardizedFileURL)
        }
    }

    @Test("root discovery never searches upward or recursively")
    func rootDiscoveryIsDirectOnly() throws {
        let locator = VerificationRootLocator()

        #expect(throws: (any Error).self) {
            _ = try locator.resolve(
                root: pluginRoot.appendingPathComponent("tools/ifl-tooling"),
                canonRoot: URL?.none
            )
        }

        try withTemporaryDirectory { root in
            let recursivelyNestedPlugin = root
                .appendingPathComponent("nested")
                .appendingPathComponent("ifl-ios-standards")
            try createFixturePlugin(at: recursivelyNestedPlugin)

            #expect(throws: (any Error).self) {
                _ = try locator.resolve(root: root, canonRoot: URL?.none)
            }
        }
    }

    @Test("missing and ambiguous plugin roots are rejected")
    func missingAndAmbiguousPluginRootsAreRejected() throws {
        let locator = VerificationRootLocator()

        _ = try withTemporaryDirectory { emptyRoot in
            expectRootError(.missingBinding(emptyRoot.path)) {
                _ = try locator.resolve(root: emptyRoot, canonRoot: URL?.none)
            }
        }

        try withTemporaryDirectory { ambiguousRoot in
            let pluginB = ambiguousRoot.appendingPathComponent("plugin-b")
            let pluginA = ambiguousRoot.appendingPathComponent("plugin-a")
            try createFixturePlugin(at: pluginB)
            try createFixturePlugin(at: pluginA)

            expectRootError(.ambiguousPluginRoots([pluginA.path, pluginB.path])) {
                _ = try locator.resolve(root: ambiguousRoot, canonRoot: URL?.none)
            }
        }
    }

    @Test("root and canon-root reject symlink escape")
    func symlinkEscapeIsRejected() throws {
        let locator = VerificationRootLocator()

        try withTemporaryDirectory { root in
            let escapedPlugin = root.appendingPathComponent("ifl-ios-standards")
            try FileManager.default.createSymbolicLink(
                at: escapedPlugin,
                withDestinationURL: pluginRoot
            )
            expectRootError(.symlinkBoundary(escapedPlugin.path)) {
                _ = try locator.resolve(root: root, canonRoot: URL?.none)
            }

            let escapedCanon = root.appendingPathComponent("canon")
            try FileManager.default.createSymbolicLink(
                at: escapedCanon,
                withDestinationURL: minimalCanonRoot
            )
            expectRootError(.symlinkBoundary(escapedCanon.path)) {
                _ = try locator.resolve(root: URL?.none, canonRoot: escapedCanon)
            }
        }
    }

    @Test("positive minimal returns deterministic typed passing checks")
    func positiveMinimalReturnsDeterministicTypedChecks() throws {
        let provider = CanonVerificationProvider(canonRoot: minimalCanonRoot)
        let first: [CheckResult] = try provider.checks(
            profiles: Set(["core"]),
            requirements: Set(["REQ-CANON"])
        )
        let second: [CheckResult] = try provider.checks(
            profiles: Set(["core"]),
            requirements: Set(["REQ-CANON"])
        )

        #expect(first == [CheckResult(checkID: "CHK-CAN-VALIDATE-001", passed: true)])
        #expect(first == second)
    }

    @Test("profile and requirement selector failures are exact and canonically ordered")
    func filtersRequireExactRegisteredIDs() throws {
        let provider = CanonVerificationProvider(canonRoot: minimalCanonRoot)
        let accepted: [CheckResult] = try provider.checks(
            profiles: Set(["core"]),
            requirements: Set(["REQ-CANON"])
        )
        let first: [CheckResult] = try provider.checks(
            profiles: Set(["z-missing", "bad profile"]),
            requirements: Set(["bad requirement", "Z-MISSING"])
        )
        let permuted: [CheckResult] = try provider.checks(
            profiles: Set(["bad profile", "z-missing"]),
            requirements: Set(["Z-MISSING", "bad requirement"])
        )

        let expected = [CheckResult(
            checkID: "CHK-CAN-FILTER-001",
            passed: false,
            severity: .high,
            message: "Unknown Profile selector(s): bad profile, z-missing. "
                + "Unknown Requirement selector(s): Z-MISSING, bad requirement."
        )]
        #expect(accepted == [CheckResult(checkID: "CHK-CAN-VALIDATE-001", passed: true)])
        #expect(first == expected)
        #expect(permuted == expected)
    }

    @Test("a missing provider root is a blocked environment")
    func missingProviderRootExitsThree() throws {
        try withTemporaryDirectory { root in
            let report = CanonVerificationProvider(
                canonRoot: root.appendingPathComponent("missing")
            ).report(profiles: [], requirements: [])

            #expect(report.exitCode.rawValue == 3)
            #expect(report.checks.count == 1)
            #expect(report.checks[0].checkID == "CHK-CAN-LOAD-001")
            #expect(report.checks[0].passed == false)
        }
    }

    @Test("missing non-directory and incomplete root bindings have exact blocked errors")
    func missingBindingMatrix() throws {
        let locator = VerificationRootLocator()
        try withTemporaryDirectory { root in
            let missing = root.appendingPathComponent("missing")
            expectRootError(.missingBinding(missing.path)) {
                _ = try locator.resolve(root: missing, canonRoot: URL?.none)
            }

            let regularFile = root.appendingPathComponent("not-a-directory")
            try Data("not a directory\n".utf8).write(to: regularFile)
            expectRootError(.missingBinding(regularFile.path)) {
                _ = try locator.resolve(root: regularFile, canonRoot: URL?.none)
            }

            let incomplete = root.appendingPathComponent("incomplete-canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: incomplete)
            let required = incomplete.appendingPathComponent("registry/rules.index.json")
            try FileManager.default.removeItem(at: required)
            expectRootError(.missingBinding(required.path)) {
                _ = try locator.resolve(root: URL?.none, canonRoot: incomplete)
            }
        }
    }

    @Test("every selected root boundary rejects a symlink with exact integrity error")
    func rootSymlinkBoundaryMatrix() throws {
        let locator = VerificationRootLocator()
        try withTemporaryDirectory { root in
            let selected = root.appendingPathComponent("selected")
            try FileManager.default.createSymbolicLink(
                at: selected,
                withDestinationURL: pluginRoot
            )
            expectRootError(.symlinkBoundary(selected.path)) {
                _ = try locator.resolve(root: selected, canonRoot: URL?.none)
            }
        }

        try withTemporaryDirectory { root in
            let candidate = root.appendingPathComponent("candidate")
            try FileManager.default.createSymbolicLink(
                at: candidate,
                withDestinationURL: pluginRoot
            )
            expectRootError(.symlinkBoundary(candidate.path)) {
                _ = try locator.resolve(root: root, canonRoot: URL?.none)
            }
        }

        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            let target = root.appendingPathComponent("target")
            try FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: false)
            try createFixturePlugin(at: target)
            let standards = plugin.appendingPathComponent("standards")
            try FileManager.default.createSymbolicLink(
                at: standards,
                withDestinationURL: target.appendingPathComponent("standards")
            )
            expectRootError(.symlinkBoundary(standards.path)) {
                _ = try locator.resolve(root: plugin, canonRoot: URL?.none)
            }
        }

        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            let standards = plugin.appendingPathComponent("standards")
            try FileManager.default.createDirectory(at: standards, withIntermediateDirectories: true)
            let canon = standards.appendingPathComponent("canon")
            try FileManager.default.createSymbolicLink(
                at: canon,
                withDestinationURL: minimalCanonRoot
            )
            expectRootError(.symlinkBoundary(canon.path)) {
                _ = try locator.resolve(root: plugin, canonRoot: URL?.none)
            }
        }

        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            let required = canon.appendingPathComponent("VERSION")
            let target = root.appendingPathComponent("version-target")
            try FileManager.default.moveItem(at: required, to: target)
            try FileManager.default.createSymbolicLink(at: required, withDestinationURL: target)
            expectRootError(.symlinkBoundary(required.path)) {
                _ = try locator.resolve(root: URL?.none, canonRoot: canon)
            }
        }
    }

    @Test("malformed unrelated workspace children do not create false ambiguity")
    func malformedUnrelatedWorkspaceChildIsIgnored() throws {
        try withTemporaryDirectory { root in
            let malformedCanon = root.appendingPathComponent("malformed/standards/canon")
            try FileManager.default.createDirectory(
                at: malformedCanon.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("not a directory\n".utf8).write(to: malformedCanon)
            let plugin = root.appendingPathComponent("plugin")
            try createFixturePlugin(at: plugin)

            let resolved = try VerificationRootLocator().resolve(
                root: root,
                canonRoot: URL?.none
            )

            #expect(resolved == plugin.appendingPathComponent("standards/canon"))
        }
    }

    @Test("trusted path ancestors before the selected boundary may be system symlinks")
    func trustedAncestorSymlinkIsAccepted() throws {
        try withTemporaryDirectory { root in
            let physicalParent = root.appendingPathComponent("physical-parent")
            let aliasParent = root.appendingPathComponent("alias-parent")
            try FileManager.default.createDirectory(
                at: physicalParent,
                withIntermediateDirectories: false
            )
            try FileManager.default.createSymbolicLink(
                at: aliasParent,
                withDestinationURL: physicalParent
            )
            let canon = physicalParent.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            let aliasedCanon = aliasParent.appendingPathComponent("canon")

            let resolved = try VerificationRootLocator().resolve(
                root: URL?.none,
                canonRoot: aliasedCanon
            )

            #expect(resolved.path == aliasedCanon.standardizedFileURL.path)
        }
    }

    @Test("workspace qualification retains the exact opened candidate chain")
    func workspaceQualificationCannotReopenReplacement() throws {
        try withTemporaryDirectory { root in
            let workspace = root.appendingPathComponent("workspace")
            let plugin = workspace.appendingPathComponent("plugin")
            let replacementPlugin = root.appendingPathComponent("replacement-plugin")
            let retainedCanon = root.appendingPathComponent("retained-canon")
            try FileManager.default.createDirectory(
                at: workspace,
                withIntermediateDirectories: false
            )
            try createFixturePlugin(at: plugin)
            try createFixturePlugin(at: replacementPlugin)

            let mutation = LockedThrowingMutation {
                try FileManager.default.moveItem(
                    at: plugin.appendingPathComponent("standards/canon"),
                    to: retainedCanon
                )
                try FileManager.default.moveItem(
                    at: replacementPlugin.appendingPathComponent("standards/canon"),
                    to: plugin.appendingPathComponent("standards/canon")
                )
            }
            let qualificationCount = LockedCounter()
            let repositoryReads = LockedCounter()
            let locator = VerificationRootLocator(
                workspaceCandidateEventHandler: { event in
                    if event == .didQualifyCandidate(plugin.path) {
                        qualificationCount.increment()
                        try mutation.runOnce()
                    }
                }
            )

            let exitCode: Int32
            let rootError: VerificationRootError?
            do {
                let resolved = try locator.resolveAnchored(
                    root: workspace,
                    canonRoot: URL?.none
                )
                let report = CanonVerificationProvider(
                    resolvedRoot: resolved,
                    readEventHandler: { _ in repositoryReads.increment() }
                ).report(profiles: [], requirements: [])
                exitCode = report.exitCode.rawValue
                rootError = nil
            } catch let error as VerificationRootError {
                exitCode = error.exitCode.rawValue
                rootError = error
            } catch {
                Issue.record("Expected VerificationRootError, received \(error)")
                exitCode = canonVerificationExitCode(for: error).rawValue
                rootError = nil
            }

            #expect(exitCode == 5)
            #expect(
                rootError == .symlinkBoundary(
                    plugin.appendingPathComponent("standards").path
                )
            )
            #expect(qualificationCount.value == 1)
            #expect(mutation.hasRun)
            #expect(repositoryReads.value == 0)
        }
    }

    @Test("workspace qualification retains the candidate binding below the workspace")
    func workspaceQualificationRetainsCandidateBinding() throws {
        try withTemporaryDirectory { root in
            let workspace = root.appendingPathComponent("workspace")
            let plugin = workspace.appendingPathComponent("plugin")
            let replacementPlugin = root.appendingPathComponent("replacement-plugin")
            let retainedPlugin = root.appendingPathComponent("retained-plugin")
            try FileManager.default.createDirectory(
                at: workspace,
                withIntermediateDirectories: false
            )
            try createFixturePlugin(at: plugin)
            try createFixturePlugin(at: replacementPlugin)

            let mutation = LockedThrowingMutation {
                try FileManager.default.moveItem(at: plugin, to: retainedPlugin)
                try FileManager.default.moveItem(at: replacementPlugin, to: plugin)
            }
            let repositoryReads = LockedCounter()
            let locator = VerificationRootLocator(
                workspaceCandidateEventHandler: { event in
                    if event == .didQualifyCandidate(plugin.path) {
                        try mutation.runOnce()
                    }
                }
            )

            let exitCode: Int32
            let rootError: VerificationRootError?
            do {
                let resolved = try locator.resolveAnchored(
                    root: workspace,
                    canonRoot: URL?.none
                )
                let report = CanonVerificationProvider(
                    resolvedRoot: resolved,
                    readEventHandler: { _ in repositoryReads.increment() }
                ).report(profiles: [], requirements: [])
                exitCode = report.exitCode.rawValue
                rootError = nil
            } catch let error as VerificationRootError {
                exitCode = error.exitCode.rawValue
                rootError = error
            } catch {
                Issue.record("Expected VerificationRootError, received \(error)")
                exitCode = canonVerificationExitCode(for: error).rawValue
                rootError = nil
            }

            #expect(exitCode == 5)
            #expect(rootError == .symlinkBoundary(workspace.path))
            #expect(mutation.hasRun)
            #expect(repositoryReads.value == 0)
        }
    }

    @Test("a resolved standards binding rejects replacement before consumption")
    func resolvedStandardsReplacementFailsAtHandoff() throws {
        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            let replacementPlugin = root.appendingPathComponent("replacement-plugin")
            let retainedStandards = root.appendingPathComponent("retained-standards")
            try createFixturePlugin(at: plugin)
            try createFixturePlugin(at: replacementPlugin)
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: plugin,
                canonRoot: URL?.none
            )

            try FileManager.default.moveItem(
                at: plugin.appendingPathComponent("standards"),
                to: retainedStandards
            )
            try FileManager.default.moveItem(
                at: replacementPlugin.appendingPathComponent("standards"),
                to: plugin.appendingPathComponent("standards")
            )
            let reads = LockedCounter()
            let provider = CanonVerificationProvider(
                resolvedRoot: resolved,
                readEventHandler: { _ in reads.increment() }
            )

            let report = provider.report(profiles: [], requirements: [])

            assertSingleLoadFailure(report, exitCode: 5)
            #expect(reads.value == 0)
        }
    }

    @Test("a retained Canon capability completes one snapshot but reports mid-load replacement")
    func retainedCanonReplacementCannotRedirectReads() throws {
        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            try createFixturePlugin(at: plugin)
            let canon = plugin.appendingPathComponent("standards/canon")
            let retainedCanon = root.appendingPathComponent("retained-canon")
            let replacementCanon = root.appendingPathComponent("replacement-canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: replacementCanon)
            try Data("2\n".utf8).write(
                to: replacementCanon.appendingPathComponent("VERSION"),
                options: .atomic
            )
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: plugin,
                canonRoot: URL?.none
            )
            let readCount = LockedCounter()
            let mutation = LockedThrowingMutation {
                try FileManager.default.moveItem(at: canon, to: retainedCanon)
                try FileManager.default.moveItem(at: replacementCanon, to: canon)
            }
            let provider = CanonVerificationProvider(
                resolvedRoot: resolved,
                readEventHandler: { event in
                    if event == .didReadFile("VERSION") {
                        try mutation.runOnce()
                    }
                    if case .didReadFile = event {
                        readCount.increment()
                    }
                }
            )

            let report = provider.report(profiles: ["core"], requirements: ["REQ-CANON"])

            assertSingleLoadFailure(report, exitCode: 5)
            #expect(mutation.hasRun)
            #expect(readCount.value > 1)
            #expect(
                try Data(contentsOf: canon.appendingPathComponent("VERSION"))
                    == Data("2\n".utf8)
            )
        }
    }

    @Test("binding integrity wins when a malformed retained snapshot also throws")
    func snapshotFailureStillPostvalidatesBinding() throws {
        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            let replacementPlugin = root.appendingPathComponent("replacement-plugin")
            let retainedCanon = root.appendingPathComponent("retained-canon")
            try createFixturePlugin(at: plugin)
            try createFixturePlugin(at: replacementPlugin)
            let canon = plugin.appendingPathComponent("standards/canon")
            try Data("not-one\n".utf8).write(to: canon.appendingPathComponent("VERSION"))
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: plugin,
                canonRoot: URL?.none
            )
            let versionReads = LockedCounter()
            let mutation = LockedThrowingMutation {
                try FileManager.default.moveItem(at: canon, to: retainedCanon)
                try FileManager.default.moveItem(
                    at: replacementPlugin.appendingPathComponent("standards/canon"),
                    to: canon
                )
            }
            let report = CanonVerificationProvider(
                resolvedRoot: resolved,
                readEventHandler: { event in
                    if event == .didReadFile("VERSION") {
                        versionReads.increment()
                        try mutation.runOnce()
                    }
                }
            ).report(profiles: [], requirements: [])

            assertSingleLoadFailure(report, exitCode: 5)
            #expect(versionReads.value == 1)
            #expect(mutation.hasRun)
        }

        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            try Data("not-one\n".utf8).write(to: canon.appendingPathComponent("VERSION"))

            let report = CanonVerificationProvider(canonRoot: canon)
                .report(profiles: [], requirements: [])

            assertSingleLoadFailure(
                report,
                exitCode: 2,
                message: "Invalid Canon version: not-one\n"
            )
        }
    }

    @Test("provider selection and validation use exactly one repository snapshot")
    func providerUsesOneSnapshot() throws {
        let resolved = try VerificationRootLocator().resolveAnchored(
            root: URL?.none,
            canonRoot: minimalCanonRoot
        )
        let versionReads = LockedCounter()
        let provider = CanonVerificationProvider(
            resolvedRoot: resolved,
            readEventHandler: { event in
                if event == .willOpenFile("VERSION") {
                    versionReads.increment()
                }
            }
        )

        let checks = try provider.checks(
            profiles: ["core"],
            requirements: ["REQ-CANON"]
        )

        #expect(checks == [CheckResult(checkID: "CHK-CAN-VALIDATE-001", passed: true)])
        #expect(versionReads.value == 1)
    }

    @Test("provider projects requested profiles with their complete inheritance closure")
    func providerProjectsMultiProfileInheritanceFromOneSnapshot() throws {
        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            try installMultiProfileProjectionCanon(in: canon)
            let resolved = try VerificationRootLocator().resolveAnchored(
                root: URL?.none,
                canonRoot: canon
            )
            let versionReads = LockedCounter()
            let provider = CanonVerificationProvider(
                resolvedRoot: resolved,
                readEventHandler: { event in
                    if event == .willOpenFile("VERSION") {
                        versionReads.increment()
                    }
                }
            )

            let all = try provider.checks(profiles: [], requirements: [])
            #expect(versionReads.value == 1)
            let requested = try provider.checks(
                profiles: ["requested"],
                requirements: []
            )
            #expect(versionReads.value == 2)

            #expect(all == [
                selectedProfileFinding("core"),
                selectedProfileFinding("middle"),
                selectedProfileFinding("requested"),
                selectedProfileFinding("unrelated"),
            ])
            #expect(requested == [
                selectedProfileFinding("core"),
                selectedProfileFinding("middle"),
                selectedProfileFinding("requested"),
            ])
        }
    }

    @Test("a valid unrelated Requirement preserves a global finding and exact mapping")
    func requirementSelectionPreservesGlobalFinding() throws {
        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            try installMissingProfileFinding(in: canon)
            let provider = CanonVerificationProvider(canonRoot: canon)
            let all = try provider.checks(profiles: ["core"], requirements: [])
            let narrowed = try provider.checks(
                profiles: ["core"],
                requirements: ["ENT-ACCESSIBILITY"]
            )
            let report = provider.report(
                profiles: ["core"],
                requirements: ["ENT-ACCESSIBILITY"]
            )
            let expected = [CheckResult(
                checkID: "CHK-CAN-REFERENCE-001",
                passed: false,
                severity: .high,
                message: "Rule CAN-MINIMAL-001 references missing Profile z-missing-profile. "
                    + "Evidence: profile:z-missing-profile, rule:CAN-MINIMAL-001."
            )]

            #expect(all == expected)
            #expect(narrowed == expected)
            #expect(report.exitCode.rawValue == 1)
            #expect(report.checks == expected)
        }
    }

    @Test("provider structural failures have the exact stable taxonomy")
    func providerStructuralFailureTaxonomy() throws {
        try withTemporaryDirectory { root in
            let malformed = root.appendingPathComponent("malformed")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: malformed)
            try Data("not-one\n".utf8).write(to: malformed.appendingPathComponent("VERSION"))
            let malformedReport = CanonVerificationProvider(canonRoot: malformed)
                .report(profiles: [], requirements: [])
            assertSingleLoadFailure(
                malformedReport,
                exitCode: 2,
                message: "Invalid Canon version: not-one\n"
            )

            let missing = root.appendingPathComponent("missing-file")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: missing)
            try FileManager.default.removeItem(
                at: missing.appendingPathComponent("rules/core/minimal.rules.json")
            )
            let missingReport = CanonVerificationProvider(canonRoot: missing)
                .report(profiles: [], requirements: [])
            assertSingleLoadFailure(
                missingReport,
                exitCode: 3,
                message: "Unresolved canon file reference: rules/core/minimal.rules.json"
            )

            let dangling = root.appendingPathComponent("dangling")
            try FileManager.default.createSymbolicLink(
                at: dangling,
                withDestinationURL: root.appendingPathComponent("absent")
            )
            let danglingReport = CanonVerificationProvider(canonRoot: dangling)
                .report(profiles: [], requirements: [])
            assertSingleLoadFailure(
                danglingReport,
                exitCode: 5,
                message: VerificationRootError.symlinkBoundary(dangling.path).description
            )
        }

        #expect(canonVerificationExitCode(for: SyntheticProviderError()) == .internalError)
    }

    @Test("indexed symlink FIFO and hardlink nodes are integrity failures")
    func indexedNodeIntegrityMatrix() throws {
        for kind in IndexedMutationKind.allCases {
            try withTemporaryDirectory { root in
                let canon = root.appendingPathComponent("canon")
                try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
                try installIndexedMutation(kind, in: canon, workspace: root)

                let report = CanonVerificationProvider(canonRoot: canon)
                    .report(profiles: [], requirements: [])

                assertSingleLoadFailure(
                    report,
                    exitCode: 5,
                    message: "Canon descriptor integrity violation: "
                        + "Canon root cannot be scanned as a descriptor-confined canonical tree"
                )
            }
        }
    }

    @Test("every singleton duplicate and value-taking option missing value is rejected")
    func completeParserRejectionMatrix() throws {
        let jsonCases: [[String]] = [
            [
                "canon", "--root", pluginRoot.path,
                "--root", pluginRoot.path, "--format", "json",
            ],
            [
                "canon", "--canon-root", minimalCanonRoot.path,
                "--canon-root", minimalCanonRoot.path, "--format", "json",
            ],
            [
                "canon", "--canon-root", minimalCanonRoot.path,
                "--offline", "--offline", "--format", "json",
            ],
            [
                "canon", "--canon-root", minimalCanonRoot.path,
                "--format", "json", "--format", "human",
            ],
            ["canon", "--root", "--format", "json"],
            ["canon", "--canon-root", "--format", "json"],
            [
                "canon", "--canon-root", minimalCanonRoot.path,
                "--profile", "--format", "json",
            ],
            [
                "canon", "--canon-root", minimalCanonRoot.path,
                "--requirement", "--format", "json",
            ],
        ]
        for arguments in jsonCases {
            let result = try runCLI(arguments)
            assertInvalidCommand(result, json: true)
        }

        let missingFormat = try runCLI([
            "canon", "--canon-root", minimalCanonRoot.path, "--format",
        ])
        assertInvalidCommand(missingFormat, json: false)
    }

    @Test("root mode and repeated selectors execute successfully")
    func rootModeAndRepeatableSelectors() throws {
        try withTemporaryDirectory { root in
            let plugin = root.appendingPathComponent("plugin")
            try createFixturePlugin(at: plugin)
            let result = try runCLI([
                "canon",
                "--root", plugin.path,
                "--profile", "core",
                "--profile", "core",
                "--requirement", "REQ-CANON",
                "--requirement", "REQ-CANON",
                "--format", "json",
            ])

            #expect(result.status == 0)
            #expect(result.stderr.isEmpty)
            #expect(result.sideEffects.isEmpty)
            #expect(
                result.stdout == Data(
                    #"{"checks":[{"check_id":"CHK-CAN-VALIDATE-001","passed":true}],"exit_code":0,"schema_version":1}"#.utf8
                ) + Data([0x0A])
            )
        }
    }

    @Test("every repeated selector occurrence contributes its distinct value")
    func repeatedSelectorsAccumulateDistinctValues() throws {
        let result = try runCLI([
            "canon",
            "--canon-root", minimalCanonRoot.path,
            "--profile", "core",
            "--profile", "z-later-profile",
            "--profile", "core",
            "--requirement", "REQ-CANON",
            "--requirement", "z-later-requirement",
            "--requirement", "REQ-CANON",
            "--format", "json",
        ])
        let report = try JSONDecoder().decode(VerificationReport.self, from: result.stdout)

        #expect(result.status == 2)
        #expect(result.stderr.isEmpty)
        #expect(result.sideEffects.isEmpty)
        #expect(report.checks == [CheckResult(
            checkID: "CHK-CAN-FILTER-001",
            passed: false,
            severity: .high,
            message: "Unknown Profile selector(s): z-later-profile. "
                + "Unknown Requirement selector(s): z-later-requirement."
        )])
    }

    @Test("no command unknown commands and non-exact version retain legacy usage bytes")
    func legacyUnsupportedCommandCompatibility() throws {
        let cases = [
            [String](),
            ["unknown"],
            ["--version", "extra"],
            ["--version=1"],
        ]

        for arguments in cases {
            let result = try runCLI(arguments)
            #expect(result.status == 2)
            #expect(result.stdout.isEmpty)
            #expect(result.stderr == Data("usage: ifl-verify --version\n".utf8))
            #expect(result.sideEffects.isEmpty)
        }
    }

    @Test("invalid command JSON has one exact report identity")
    func exactInvalidCommandReport() throws {
        let result = try runCLI([
            "canon", "--canon-root", minimalCanonRoot.path, "--wat", "--format", "json",
        ])

        #expect(result.status == 2)
        #expect(result.stderr.isEmpty)
        #expect(result.sideEffects.isEmpty)
        #expect(
            result.stdout == Data(
                #"{"checks":[{"check_id":"CHK-CAN-COMMAND-001","message":"Unknown argument: --wat","passed":false}],"exit_code":2,"schema_version":1}"#.utf8
            ) + Data([0x0A])
        )
    }

    @Test("default and explicit human output are byte-identical")
    func defaultHumanOutputIsExact() throws {
        let defaultResult = try runCLI([
            "canon", "--canon-root", minimalCanonRoot.path,
        ])
        let explicitResult = try runCLI([
            "canon", "--canon-root", minimalCanonRoot.path, "--format", "human",
        ])
        let expected = Data("exit_code: 0\nCHK-CAN-VALIDATE-001: passed\n".utf8)

        #expect(defaultResult.status == 0)
        #expect(defaultResult.stdout == expected)
        #expect(defaultResult == explicitResult)
        #expect(defaultResult.sideEffects.isEmpty)
    }

    @Test("human output escapes every hostile control into one physical check line")
    func hostileHumanFieldsAreEscaped() throws {
        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            let hostile = "\0\\\r\n\u{001B}\u{0085}\u{2028}\u{2029}"
            try Data(hostile.utf8).write(to: canon.appendingPathComponent("VERSION"))

            let result = try runCLI([
                "canon", "--canon-root", canon.path, "--format", "human",
            ])

            let expected = #"""
            exit_code: 2
            CHK-CAN-LOAD-001: failed message=Invalid Canon version: \0\\\r\n\e\u{0085}\u{2028}\u{2029}
            """#
            #expect(result.status == 2)
            #expect(result.stdout == Data(expected.utf8) + Data([0x0A]))
            #expect(result.stderr.isEmpty)
            #expect(result.sideEffects.isEmpty)
            #expect(String(decoding: result.stdout, as: UTF8.self).split(separator: "\n").count == 2)
        }
    }

    @Test("offline is byte-inert for clean selector and integrity outcomes")
    func offlineIsSemanticallyInert() throws {
        let clean = ["canon", "--canon-root", minimalCanonRoot.path, "--format", "json"]
        let invalid = clean.dropLast(2) + ["--profile", "missing", "--format", "json"]
        let cleanOnline = try runCLI(clean)
        let cleanOffline = try runCLI(insertingOffline(into: clean))
        let invalidOnline = try runCLI(Array(invalid))
        let invalidOffline = try runCLI(insertingOffline(into: Array(invalid)))

        #expect(cleanOnline == cleanOffline)
        #expect(invalidOnline == invalidOffline)

        try withTemporaryDirectory { root in
            let canon = root.appendingPathComponent("canon")
            try FileManager.default.copyItem(at: minimalCanonRoot, to: canon)
            let record = canon.appendingPathComponent("rules/core/minimal.rules.json")
            var bytes = try Data(contentsOf: record)
            bytes.append(0x20)
            try bytes.write(to: record)
            let arguments = ["canon", "--canon-root", canon.path, "--format", "json"]

            let online = try runCLI(arguments)
            let offline = try runCLI(insertingOffline(into: arguments))

            #expect(online == offline)
            #expect(online.status == 5)
            #expect(online.sideEffects.isEmpty)
        }
    }

    @Test("representative root failures preserve exact CLI exit families")
    func rootFailureCLIExitMatrix() throws {
        let invalid = try runCLI(["canon", "--format", "json"])
        let invalidReport = try JSONDecoder().decode(
            VerificationReport.self,
            from: invalid.stdout
        )
        #expect(invalid.status == 2)
        #expect(invalidReport.checks.map(\.checkID) == ["CHK-CAN-ROOT-001"])

        try withTemporaryDirectory { root in
            let missingPath = root.appendingPathComponent("missing")
            let missing = try runCLI([
                "canon", "--canon-root", missingPath.path, "--format", "json",
            ])
            let missingReport = try JSONDecoder().decode(
                VerificationReport.self,
                from: missing.stdout
            )
            #expect(missing.status == 3)
            #expect(missingReport.checks.map(\.checkID) == ["CHK-CAN-ROOT-001"])

            let symlink = root.appendingPathComponent("symlink")
            try FileManager.default.createSymbolicLink(
                at: symlink,
                withDestinationURL: minimalCanonRoot
            )
            let integrity = try runCLI([
                "canon", "--canon-root", symlink.path, "--format", "json",
            ])
            let integrityReport = try JSONDecoder().decode(
                VerificationReport.self,
                from: integrity.stdout
            )
            #expect(integrity.status == 5)
            #expect(integrityReport.checks.map(\.checkID) == ["CHK-CAN-ROOT-001"])
            #expect(missing.sideEffects.isEmpty)
            #expect(integrity.sideEffects.isEmpty)
        }
    }

    @Test("the CLI resolver fails closed instead of using an ancestor decoy")
    func staleExecutableDecoyIsRejected() throws {
        try withTemporaryDirectory { root in
            let products = root.appendingPathComponent("products")
            let testExecutable = products
                .appendingPathComponent("PackageTests.xctest/Contents/MacOS/PackageTests")
            try FileManager.default.createDirectory(
                at: testExecutable.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let decoy = root.appendingPathComponent("ifl-verify")
            try Data("stale\n".utf8).write(to: decoy)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: decoy.path
            )

            #expect(throws: CanonCommandTestError.missingCLIExecutable) {
                _ = try cliExecutable(besideTestExecutable: testExecutable)
            }
        }

        try withTemporaryDirectory { root in
            let products = root.appendingPathComponent("products")
            let testExecutable = products
                .appendingPathComponent("PackageTests.xctest/Contents/MacOS/PackageTests")
            try FileManager.default.createDirectory(
                at: testExecutable.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let candidate = products.appendingPathComponent("ifl-verify")
            try Data("current\n".utf8).write(to: candidate)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: candidate.path
            )
            #expect(throws: CanonCommandTestError.missingCLIExecutable) {
                _ = try cliExecutable(besideTestExecutable: testExecutable)
            }

            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: candidate.path
            )
            #expect(
                try cliExecutable(besideTestExecutable: testExecutable)
                    == candidate.standardizedFileURL
            )
        }

        try withTemporaryDirectory { root in
            let products = root.appendingPathComponent("products")
            let testExecutable = products
                .appendingPathComponent("PackageTests.xctest/Contents/MacOS/PackageTests")
            try FileManager.default.createDirectory(
                at: testExecutable.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let external = root.appendingPathComponent("external-ifl-verify")
            try Data("stale\n".utf8).write(to: external)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: external.path
            )
            try FileManager.default.createSymbolicLink(
                at: products.appendingPathComponent("ifl-verify"),
                withDestinationURL: external
            )

            #expect(throws: CanonCommandTestError.missingCLIExecutable) {
                _ = try cliExecutable(besideTestExecutable: testExecutable)
            }
        }
    }

    private var pluginRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var workspaceRoot: URL {
        pluginRoot.deletingLastPathComponent()
    }

    private var productionCanonRoot: URL {
        pluginRoot.appendingPathComponent("standards/canon")
    }

    private var minimalCanonRoot: URL {
        pluginRoot.appendingPathComponent("verification/fixtures/canon/positive/minimal")
    }

    private func withTemporaryDirectory<T>(
        _ body: (URL) throws -> T
    ) throws -> T {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ifl-canon-command-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        return try body(root)
    }

    private func createFixturePlugin(at root: URL) throws {
        let standards = root.appendingPathComponent("standards")
        try FileManager.default.createDirectory(
            at: standards,
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(
            at: minimalCanonRoot,
            to: standards.appendingPathComponent("canon")
        )
    }

    private func runCLI(
        _ arguments: [String]
    ) throws -> CLIResult {
        try withTemporaryDirectory { directory in
            let stdoutURL = directory.appendingPathComponent("stdout")
            let stderrURL = directory.appendingPathComponent("stderr")
            FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)
            defer {
                try? stdout.close()
                try? stderr.close()
            }

            let process = Process()
            process.executableURL = try cliExecutable()
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()
            try stdout.synchronize()
            try stderr.synchronize()
            try stdout.close()
            try stderr.close()
            let inventory = try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            ).sorted(by: canonicalLess)
            return try CLIResult(
                status: process.terminationStatus,
                stdout: Data(contentsOf: stdoutURL),
                stderr: Data(contentsOf: stderrURL),
                sideEffects: inventory.filter { $0 != "stdout" && $0 != "stderr" }
            )
        }
    }

    private func hasExactlyOneTrailingNewline(_ data: Data) -> Bool {
        let bytes = Array(data)
        return bytes.last == 0x0A && bytes.dropLast().last != 0x0A
    }

    private func expectRootError(
        _ expected: VerificationRootError,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("Expected \(expected), but root resolution succeeded")
        } catch let error as VerificationRootError {
            #expect(error == expected)
            #expect(error.exitCode == expected.exitCode)
            #expect(error.description == expected.description)
        } catch {
            Issue.record("Expected VerificationRootError, received \(error)")
        }
    }

    private func cliExecutable() throws -> URL {
        let bundles = Set(CommandLine.arguments.compactMap { argument -> URL? in
            var candidate = URL(fileURLWithPath: argument)
            for _ in 0 ..< 5 {
                if candidate.pathExtension == "xctest" {
                    return candidate.standardizedFileURL
                }
                let parent = candidate.deletingLastPathComponent()
                guard parent != candidate else { break }
                candidate = parent
            }
            return nil
        })
        guard bundles.count == 1, let bundle = bundles.first else {
            throw CanonCommandTestError.missingCLIExecutable
        }
        return try cliExecutable(besideTestExecutable: bundle)
    }

    private func cliExecutable(besideTestExecutable testExecutable: URL) throws -> URL {
        var bundle = testExecutable.standardizedFileURL
        for _ in 0 ..< 5 where bundle.pathExtension != "xctest" {
            bundle.deleteLastPathComponent()
        }
        guard bundle.pathExtension == "xctest" else {
            throw CanonCommandTestError.missingCLIExecutable
        }
        let candidate = bundle.deletingLastPathComponent().appendingPathComponent("ifl-verify")
        var candidateSnapshot = stat()
        let metadataResult = candidate.path.withCString {
            Darwin.lstat($0, &candidateSnapshot)
        }
        let executableBits = mode_t(S_IXUSR | S_IXGRP | S_IXOTH)
        guard metadataResult == 0,
              candidateSnapshot.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              candidateSnapshot.st_mode & executableBits != 0
        else {
            throw CanonCommandTestError.missingCLIExecutable
        }
        return candidate
    }

    private func assertSingleLoadFailure(
        _ report: VerificationReport,
        exitCode: Int32,
        message: String? = nil
    ) {
        #expect(report.exitCode.rawValue == exitCode)
        #expect(report.checks.count == 1)
        guard let check = report.checks.first else { return }
        #expect(check.checkID == "CHK-CAN-LOAD-001")
        #expect(check.passed == false)
        #expect(check.severity == nil)
        if let message {
            #expect(check.message == message)
        }
    }

    private func assertInvalidCommand(_ result: CLIResult, json: Bool) {
        #expect(result.status == 2)
        #expect(result.stderr.isEmpty)
        #expect(result.sideEffects.isEmpty)
        #expect(hasExactlyOneTrailingNewline(result.stdout))
        if json {
            guard let report = try? JSONDecoder().decode(
                VerificationReport.self,
                from: result.stdout
            ) else {
                Issue.record("Expected a decodable invalid-command JSON report")
                return
            }
            #expect(report.exitCode.rawValue == 2)
            #expect(report.checks.count == 1)
            #expect(report.checks.first?.checkID == "CHK-CAN-COMMAND-001")
            #expect(report.checks.first?.passed == false)
        } else {
            let output = String(decoding: result.stdout, as: UTF8.self)
            #expect(output.hasPrefix("exit_code: 2\nCHK-CAN-COMMAND-001: failed message="))
        }
    }

    private func insertingOffline(into arguments: [String]) -> [String] {
        var result = arguments
        if let formatIndex = result.firstIndex(of: "--format") {
            result.insert("--offline", at: formatIndex)
        } else {
            result.append("--offline")
        }
        return result
    }

    private func installMissingProfileFinding(in root: URL) throws {
        let rulePath = "rules/core/minimal.rules.json"
        var rule = try jsonObject(at: rulePath, in: root)
        rule["profile_ids"] = ["core", "z-missing-profile"]
        try writeCanonicalJSONObject(rule, to: rulePath, in: root)
        try updateRecordDigest(
            for: rulePath,
            in: "registry/rules.index.json",
            root: root
        )
    }

    private func installMultiProfileProjectionCanon(in root: URL) throws {
        let profileIDs = ["core", "middle", "requested", "unrelated"]
        var core = try jsonObject(at: "profiles/minimal.profile.json", in: root)
        core["rule_ids"] = ["CAN-MINIMAL-001"]
        try writeCanonicalJSONObject(core, to: "profiles/minimal.profile.json", in: root)

        let inheritedProfiles = [
            (id: "middle", inherited: ["core"]),
            (id: "requested", inherited: ["middle"]),
            (id: "unrelated", inherited: [String]()),
        ]
        for profile in inheritedProfiles {
            var record = core
            record["id"] = profile.id
            record["display_name"] = "Projection \(profile.id)"
            record["description"] = "Digest-consistent projection fixture for \(profile.id)."
            record["inherits_profile_ids"] = profile.inherited
            try writeCanonicalJSONObject(
                record,
                to: "profiles/\(profile.id).profile.json",
                in: root
            )
        }

        var profileIndex = try jsonObject(at: "registry/profiles.index.json", in: root)
        profileIndex["entries"] = try profileIDs.map { id -> [String: Any] in
            let relativePath = id == "core"
                ? "profiles/minimal.profile.json"
                : "profiles/\(id).profile.json"
            return try [
                "id": id,
                "record_digest": sha256(
                    Data(contentsOf: root.appendingPathComponent(relativePath))
                ),
                "relative_path": relativePath,
            ]
        }
        try writeCanonicalJSONObject(
            profileIndex,
            to: "registry/profiles.index.json",
            in: root
        )

        let rulePath = "rules/core/minimal.rules.json"
        var rule = try jsonObject(at: rulePath, in: root)
        rule["lifecycle"] = "retired"
        rule["profile_ids"] = profileIDs
        try writeCanonicalJSONObject(rule, to: rulePath, in: root)
        try updateRecordDigest(
            for: rulePath,
            in: "registry/rules.index.json",
            root: root
        )
    }

    private func selectedProfileFinding(_ profileID: String) -> CheckResult {
        CheckResult(
            checkID: "CHK-CAN-PROFILE-001",
            passed: false,
            severity: .high,
            message: "Selected Profile \(profileID) includes non-active Rule "
                + "CAN-MINIMAL-001. Evidence: profile:\(profileID), "
                + "rule:CAN-MINIMAL-001."
        )
    }

    private func updateRecordDigest(
        for relativePath: String,
        in indexPath: String,
        root: URL
    ) throws {
        let digest = try sha256(Data(contentsOf: root.appendingPathComponent(relativePath)))
        var index = try jsonObject(at: indexPath, in: root)
        var entries = try #require(index["entries"] as? [[String: Any]])
        let entryIndex = try #require(
            entries.firstIndex { $0["relative_path"] as? String == relativePath }
        )
        entries[entryIndex]["record_digest"] = digest
        index["entries"] = entries
        try writeCanonicalJSONObject(index, to: indexPath, in: root)
    }

    private func jsonObject(at relativePath: String, in root: URL) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(
            with: Data(contentsOf: root.appendingPathComponent(relativePath)),
            options: [.fragmentsAllowed]
        )
        return try #require(value as? [String: Any])
    }

    private func writeCanonicalJSONObject(
        _ value: [String: Any],
        to relativePath: String,
        in root: URL
    ) throws {
        var data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        data.append(0x0A)
        try data.write(
            to: root.appendingPathComponent(relativePath),
            options: .atomic
        )
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func installIndexedMutation(
        _ kind: IndexedMutationKind,
        in root: URL,
        workspace: URL
    ) throws {
        let target = root.appendingPathComponent("rules/core/minimal.rules.json")
        let outside = workspace.appendingPathComponent("outside-\(kind.rawValue).json")
        switch kind {
        case .symlink:
            try FileManager.default.copyItem(at: target, to: outside)
            try FileManager.default.removeItem(at: target)
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
        case .fifo:
            try FileManager.default.removeItem(at: target)
            let result = target.path.withCString { Darwin.mkfifo($0, mode_t(0o644)) }
            try #require(result == 0)
        case .hardlink:
            try FileManager.default.copyItem(at: target, to: outside)
            try FileManager.default.removeItem(at: target)
            try FileManager.default.linkItem(at: outside, to: target)
        }
    }

    private func canonicalLess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    }
}

private struct CLIResult: Equatable {
    let status: Int32
    let stdout: Data
    let stderr: Data
    let sideEffects: [String]
}

private enum CanonCommandTestError: Error, Equatable {
    case missingCLIExecutable
}

private enum IndexedMutationKind: String, CaseIterable {
    case symlink
    case fifo
    case hardlink
}

private struct SyntheticProviderError: Error {}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private final class LockedThrowingMutation: @unchecked Sendable {
    private let lock = NSLock()
    private var didRun = false
    private let mutation: @Sendable () throws -> Void

    init(_ mutation: @escaping @Sendable () throws -> Void) {
        self.mutation = mutation
    }

    var hasRun: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didRun
    }

    func runOnce() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !didRun else { return }
        didRun = true
        try mutation()
    }
}
