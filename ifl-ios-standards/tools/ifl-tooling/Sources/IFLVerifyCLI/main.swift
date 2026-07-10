import Darwin
import Foundation
import IFLVerification

private func productVersion() -> String? {
    if let validated = ProcessInfo.processInfo.environment["_IFL_TOOLING_PRODUCT_VERSION"] {
        return validated
    }

    let sourceURL = URL(fileURLWithPath: #filePath)
    let pluginRoot = sourceURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let versionURL = pluginRoot.appendingPathComponent("VERSION")
    guard let data = try? Data(contentsOf: versionURL),
          data.last == 0x0A,
          !data.dropLast().contains(0x0A),
          let value = String(data: data.dropLast(), encoding: .utf8),
          !value.isEmpty
    else {
        return nil
    }
    return value
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--version"], let version = productVersion() {
    print(version)
    exit(0)
}

fputs("usage: ifl-verify --version\n", stderr)
exit(2)
