import Darwin
import Foundation
@testable import IFLContracts
import Testing

@Suite("ToolingLauncherTests", .serialized)
struct ToolingLauncherTests {
    @Test("version output is exactly one line and unknown commands exit two")
    func exactVersionAndUnknownCommand() throws {
        let version = try run(pluginRoot.appendingPathComponent("bin/ifl-verify"), ["--version"])
        #expect(version.status == 0)
        #expect(version.stdout == Data("1.0.0-rc.1\n".utf8))

        let unknown = try run(pluginRoot.appendingPathComponent("bin/ifl-verify"), ["unknown-command"])
        #expect(unknown.status == 2)
    }

    @Test("contained scratch root is rejected before it is created")
    func rejectsContainedScratch() throws {
        let contained = pluginRoot.appendingPathComponent(".scratch-launcher-test")
        try? FileManager.default.removeItem(at: contained)
        defer { try? FileManager.default.removeItem(at: contained) }

        let result = try run(
            pluginRoot.appendingPathComponent("bin/ifl-tooling-swift"),
            ["package", "describe"],
            environment: ["IFL_SWIFTPM_SCRATCH_ROOT": contained.path]
        )
        #expect(result.status == 2)
        #expect(!FileManager.default.fileExists(atPath: contained.path))
    }

    @Test("XDG cache is ignored and SwiftPM never writes an in-package build directory")
    func ignoresXDGCache() throws {
        let cache = pluginRoot.appendingPathComponent(".cache")
        try? FileManager.default.removeItem(at: cache)
        defer { try? FileManager.default.removeItem(at: cache) }

        let result = try run(
            pluginRoot.appendingPathComponent("bin/ifl-verify"),
            ["--version"],
            environment: ["XDG_CACHE_HOME": cache.path]
        )
        #expect(result.status == 0)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        #expect(!FileManager.default.fileExists(atPath: pluginRoot.appendingPathComponent("tools/ifl-tooling/.build").path))
    }

    @Test("two physical package roots at one version receive distinct workspace keys")
    func distinctWorkspaceKeys() throws {
        try withTemporaryDirectory { temporaryRoot in
            let first = try makePluginFixture(at: temporaryRoot.appendingPathComponent("first"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let second = try makePluginFixture(at: temporaryRoot.appendingPathComponent("second"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let scratch = temporaryRoot.appendingPathComponent("scratch")

            #expect(try run(first.appendingPathComponent("bin/ifl-tooling-swift"), ["package", "describe"], environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratch.path]).status == 0)
            #expect(try run(second.appendingPathComponent("bin/ifl-tooling-swift"), ["package", "describe"], environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratch.path]).status == 0)

            let firstKey = try workspaceKey(for: first.appendingPathComponent("tools/ifl-tooling"))
            let secondKey = try workspaceKey(for: second.appendingPathComponent("tools/ifl-tooling"))
            #expect(firstKey != secondKey)
            #expect(FileManager.default.fileExists(atPath: scratch.appendingPathComponent(firstKey).appendingPathComponent("1.0.0-rc.1").path))
            #expect(FileManager.default.fileExists(atPath: scratch.appendingPathComponent(secondKey).appendingPathComponent("1.0.0-rc.1").path))
        }
    }

    @Test("workspace and version controlled components reject symlinks back into the plugin")
    func rejectsControlledSymlinks() throws {
        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(at: temporaryRoot.appendingPathComponent("plugin"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let scratch = temporaryRoot.appendingPathComponent("scratch")
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
            let packageRoot = fixture.appendingPathComponent("tools/ifl-tooling")
            let key = try workspaceKey(for: packageRoot)
            try FileManager.default.createSymbolicLink(at: scratch.appendingPathComponent(key), withDestinationURL: fixture)

            let result = try run(fixture.appendingPathComponent("bin/ifl-tooling-swift"), ["package", "describe"], environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratch.path])
            #expect(result.status == 2)
        }

        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(at: temporaryRoot.appendingPathComponent("plugin"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let scratch = temporaryRoot.appendingPathComponent("scratch")
            let packageRoot = fixture.appendingPathComponent("tools/ifl-tooling")
            let key = try workspaceKey(for: packageRoot)
            let workspace = scratch.appendingPathComponent(key)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: workspace.appendingPathComponent("1.0.0-rc.1"), withDestinationURL: fixture)

            let result = try run(fixture.appendingPathComponent("bin/ifl-tooling-swift"), ["package", "describe"], environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratch.path])
            #expect(result.status == 2)
        }
    }

    @Test("a physical scratch-base symlink resolving into the plugin is rejected")
    func rejectsScratchBaseSymlinkBack() throws {
        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(at: temporaryRoot.appendingPathComponent("plugin"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let scratchLink = temporaryRoot.appendingPathComponent("scratch-link")
            try FileManager.default.createSymbolicLink(at: scratchLink, withDestinationURL: fixture)

            let result = try run(
                fixture.appendingPathComponent("bin/ifl-tooling-swift"),
                ["package", "describe"],
                environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratchLink.path]
            )
            #expect(result.status == 2)
        }
    }

    @Test("post-creation physical re-resolution rejects a swapped version directory")
    func rejectsPostCreationSymlinkSwap() throws {
        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(at: temporaryRoot.appendingPathComponent("plugin"), versionBytes: Data("1.0.0-rc.1\n".utf8))
            let scratch = temporaryRoot.appendingPathComponent("scratch")
            let gate = temporaryRoot.appendingPathComponent("gate")
            try FileManager.default.createDirectory(at: gate, withIntermediateDirectories: false)

            let process = Process()
            process.executableURL = fixture.appendingPathComponent("bin/ifl-tooling-swift")
            process.arguments = ["package", "describe"]
            process.currentDirectoryURL = temporaryRoot
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.environment = ProcessInfo.processInfo.environment.merging([
                "IFL_SWIFTPM_SCRATCH_ROOT": scratch.path,
                "_IFL_TOOLING_TESTING": "1",
                "_IFL_TOOLING_TEST_GATE_DIR": gate.path,
            ]) { _, replacement in replacement }
            try process.run()

            let ready = gate.appendingPathComponent("ready")
            let deadline = Date().addingTimeInterval(10)
            while !FileManager.default.fileExists(atPath: ready.path), Date() < deadline {
                Thread.sleep(forTimeInterval: 0.02)
            }
            guard FileManager.default.fileExists(atPath: ready.path) else {
                process.terminate()
                process.waitUntilExit()
                throw LauncherTestError.testGateTimedOut
            }

            let packageRoot = fixture.appendingPathComponent("tools/ifl-tooling")
            let key = try workspaceKey(for: packageRoot)
            let versionDirectory = scratch.appendingPathComponent(key).appendingPathComponent("1.0.0-rc.1")
            try FileManager.default.removeItem(at: versionDirectory)
            try FileManager.default.createSymbolicLink(at: versionDirectory, withDestinationURL: fixture)
            try Data().write(to: gate.appendingPathComponent("release"))

            process.waitUntilExit()
            #expect(process.terminationStatus == 2)
        }
    }

    @Test("invalid, non-exact, and traversal-capable versions fail before SwiftPM")
    func rejectsInvalidVersions() throws {
        let invalidVersions = [
            Data("../escape\n".utf8),
            Data("1.0.0/escape\n".utf8),
            Data("1.0.0\\escape\n".utf8),
            Data("01.0.0\n".utf8),
            Data("1.0.0-01\n".utf8),
            Data("1.0.0-rc.1\nextra\n".utf8),
            Data("1.0.0-rc.1".utf8),
            Data("1.0.0-\(String(repeating: "a", count: 300))\n".utf8),
        ]
        for bytes in invalidVersions {
            try withTemporaryDirectory { temporaryRoot in
                let fixture = try makePluginFixture(at: temporaryRoot.appendingPathComponent("plugin"), versionBytes: bytes)
                let result = try run(
                    fixture.appendingPathComponent("bin/ifl-tooling-swift"),
                    ["package", "describe"],
                    environment: ["IFL_SWIFTPM_SCRATCH_ROOT": temporaryRoot.appendingPathComponent("scratch").path]
                )
                #expect(result.status == 2)
            }
        }
    }

    @Test("caller cannot override launcher-owned SwiftPM paths")
    func rejectsProtectedSwiftPMPathOverrides() throws {
        let protectedValueOptions = [
            "--package-path",
            "--scratch-path",
            "--build-path",
            "--cache-path",
            "--config-path",
            "--security-path",
            "--swift-sdks-path",
            "--toolset",
            "--toolchain",
            "--pkg-config-path",
            "--sdk",
            "--swift-sdk",
            "--triple",
            "--netrc-file",
            "--resolver-fingerprint-checking",
            "--resolver-signing-entity-checking",
            "--default-registry-url",
            "-Xcc",
            "-Xswiftc",
            "-Xlinker",
        ]

        for option in protectedValueOptions {
            try withTemporaryDirectory { temporaryRoot in
                let fixture = try makePluginFixture(
                    at: temporaryRoot.appendingPathComponent("plugin"),
                    versionBytes: Data("1.0.0-rc.1\n".utf8)
                )
                let authoritativeScratch = temporaryRoot.appendingPathComponent("authoritative-scratch")
                let override = temporaryRoot.appendingPathComponent("caller-override")
                let launcher = fixture.appendingPathComponent("bin/ifl-tooling-swift")
                let baseEnvironment = ["IFL_SWIFTPM_SCRATCH_ROOT": authoritativeScratch.path]

                let separated = try run(
                    launcher,
                    ["package", "describe", option, override.path],
                    environment: baseEnvironment
                )
                #expect(separated.status == 2)

                let joined = try run(
                    launcher,
                    ["package", "describe", "\(option)=\(override.path)"],
                    environment: baseEnvironment
                )
                #expect(joined.status == 2)
                #expect(!FileManager.default.fileExists(atPath: override.path))
            }
        }

        let protectedFlagOptions = [
            "--disable-sandbox",
            "--netrc",
            "--enable-netrc",
            "--disable-signature-validation",
        ]
        for option in protectedFlagOptions {
            try withTemporaryDirectory { temporaryRoot in
                let fixture = try makePluginFixture(
                    at: temporaryRoot.appendingPathComponent("plugin"),
                    versionBytes: Data("1.0.0-rc.1\n".utf8)
                )
                let result = try run(
                    fixture.appendingPathComponent("bin/ifl-tooling-swift"),
                    ["package", "describe", option],
                    environment: [
                        "IFL_SWIFTPM_SCRATCH_ROOT": temporaryRoot.appendingPathComponent("scratch").path,
                    ]
                )
                #expect(result.status == 2)
            }
        }
    }

    @Test("hostile ambient module-cache variables cannot write inside the plugin")
    func isolatesCompilerModuleCaches() throws {
        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(
                at: temporaryRoot.appendingPathComponent("plugin"),
                versionBytes: Data("1.0.0-rc.1\n".utf8)
            )
            let hostileClang = fixture.appendingPathComponent("hostile-clang-cache")
            let hostileSwiftPM = fixture.appendingPathComponent("hostile-swiftpm-cache")
            let result = try run(
                fixture.appendingPathComponent("bin/ifl-tooling-swift"),
                ["package", "describe"],
                environment: [
                    "IFL_SWIFTPM_SCRATCH_ROOT": temporaryRoot.appendingPathComponent("scratch").path,
                    "CLANG_MODULE_CACHE_PATH": hostileClang.path,
                    "SWIFTPM_MODULECACHE_OVERRIDE": hostileSwiftPM.path,
                ]
            )
            #expect(result.status == 0)
            #expect(!FileManager.default.fileExists(atPath: hostileClang.path))
            #expect(!FileManager.default.fileExists(atPath: hostileSwiftPM.path))
        }
    }

    @Test("pre-existing controlled directories must be private")
    func rejectsNonPrivateControlledDirectory() throws {
        try withTemporaryDirectory { temporaryRoot in
            let fixture = try makePluginFixture(
                at: temporaryRoot.appendingPathComponent("plugin"),
                versionBytes: Data("1.0.0-rc.1\n".utf8)
            )
            let scratch = temporaryRoot.appendingPathComponent("scratch")
            let key = try workspaceKey(for: fixture.appendingPathComponent("tools/ifl-tooling"))
            let workspace = scratch.appendingPathComponent(key)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: UInt16(0o755))],
                ofItemAtPath: workspace.path
            )

            let result = try run(
                fixture.appendingPathComponent("bin/ifl-tooling-swift"),
                ["package", "describe"],
                environment: ["IFL_SWIFTPM_SCRATCH_ROOT": scratch.path]
            )
            #expect(result.status == 2)
        }
    }

    @Test("launcher uses xcrun and never a PATH swift executable")
    func neverUsesPATHSwift() throws {
        try withTemporaryDirectory { temporaryRoot in
            let bin = temporaryRoot.appendingPathComponent("bin")
            try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: false)
            let marker = temporaryRoot.appendingPathComponent("path-swift-used")
            let fake = bin.appendingPathComponent("swift")
            try Data("#!/bin/bash\ntouch \"\(marker.path)\"\nexit 99\n".utf8).write(to: fake)
            try makeExecutable(fake)

            let result = try run(
                pluginRoot.appendingPathComponent("bin/ifl-verify"),
                ["--version"],
                environment: ["PATH": "\(bin.path):/usr/bin:/bin"]
            )
            #expect(result.status == 0)
            #expect(!FileManager.default.fileExists(atPath: marker.path))
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

    private func makePluginFixture(at root: URL, versionBytes: Data) throws -> URL {
        let bin = root.appendingPathComponent("bin")
        let package = root.appendingPathComponent("tools/ifl-tooling")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try versionBytes.write(to: root.appendingPathComponent("VERSION"))
        try FileManager.default.copyItem(
            at: pluginRoot.appendingPathComponent("bin/ifl-tooling-swift"),
            to: bin.appendingPathComponent("ifl-tooling-swift")
        )
        try makeExecutable(bin.appendingPathComponent("ifl-tooling-swift"))
        let manifest = """
        // swift-tools-version: 6.0
        import PackageDescription
        let package = Package(name: "Fixture")
        """
        try Data(manifest.utf8).write(to: package.appendingPathComponent("Package.swift"))
        return root
    }

    private func workspaceKey(for packageRoot: URL) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let resolved = packageRoot.path.withCString { path in
            buffer.withUnsafeMutableBufferPointer { storage in
                realpath(path, storage.baseAddress)
            }
        }
        guard resolved != nil else {
            throw LauncherTestError.physicalPathResolutionFailed
        }
        let pathBytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let physicalPath = String(decoding: pathBytes, as: UTF8.self)
        return CanonicalTreeDigest.sha256(Data(physicalPath.utf8)).rawValue
    }

    private func makeExecutable(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let current = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: current | 0o100)], ofItemAtPath: url.path)
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ifl-launcher-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func run(
        _ executable: URL,
        _ arguments: [String],
        environment additions: [String: String] = [:]
    ) throws -> (status: Int32, stdout: Data, stderr: Data) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ifl-process-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
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
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardOutput = stdout
        process.standardError = stderr
        var environment = ProcessInfo.processInfo.environment.merging(additions) { _, replacement in replacement }
        if additions["IFL_SWIFTPM_SCRATCH_ROOT"] == nil {
            environment["IFL_SWIFTPM_SCRATCH_ROOT"] = directory.appendingPathComponent("swiftpm-scratch").path
        }
        process.environment = environment
        try process.run()
        process.waitUntilExit()
        try stdout.synchronize()
        try stderr.synchronize()
        return try (process.terminationStatus, Data(contentsOf: stdoutURL), Data(contentsOf: stderrURL))
    }
}

private enum LauncherTestError: Error {
    case testGateTimedOut
    case physicalPathResolutionFailed
}
