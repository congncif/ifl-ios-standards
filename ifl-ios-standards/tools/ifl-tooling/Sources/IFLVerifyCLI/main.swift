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

private enum OutputFormat: String {
    case human
    case json
}

private struct CanonOptions {
    let root: URL?
    let canonRoot: URL?
    let profiles: Set<String>
    let requirements: Set<String>
    let format: OutputFormat
}

private enum CanonCommandError: Error, CustomStringConvertible {
    case duplicateOption(String)
    case missingValue(String)
    case unknownArgument(String)
    case unsupportedFormat(String)

    var description: String {
        switch self {
        case let .duplicateOption(option):
            "Duplicate option: \(option)"
        case let .missingValue(option):
            "Missing value for option: \(option)"
        case let .unknownArgument(argument):
            "Unknown argument: \(argument)"
        case let .unsupportedFormat(format):
            "Unsupported format: \(format)"
        }
    }
}

private func parseCanonOptions(_ arguments: [String]) throws -> CanonOptions {
    var root: URL?
    var canonRoot: URL?
    var profiles: Set<String> = []
    var requirements: Set<String> = []
    var format = OutputFormat.human
    var sawFormat = false
    var sawOffline = false
    var index = 0

    func value(after option: String) throws -> String {
        let valueIndex = index + 1
        guard arguments.indices.contains(valueIndex),
              !arguments[valueIndex].hasPrefix("--"),
              !arguments[valueIndex].isEmpty
        else {
            throw CanonCommandError.missingValue(option)
        }
        return arguments[valueIndex]
    }

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--root":
            guard root == nil else { throw CanonCommandError.duplicateOption(argument) }
            root = try URL(fileURLWithPath: value(after: argument))
            index += 2
        case "--canon-root":
            guard canonRoot == nil else { throw CanonCommandError.duplicateOption(argument) }
            canonRoot = try URL(fileURLWithPath: value(after: argument))
            index += 2
        case "--profile":
            try profiles.insert(value(after: argument))
            index += 2
        case "--requirement":
            try requirements.insert(value(after: argument))
            index += 2
        case "--offline":
            guard !sawOffline else { throw CanonCommandError.duplicateOption(argument) }
            sawOffline = true
            index += 1
        case "--format":
            guard !sawFormat else { throw CanonCommandError.duplicateOption(argument) }
            let rawFormat = try value(after: argument)
            guard let parsed = OutputFormat(rawValue: rawFormat) else {
                throw CanonCommandError.unsupportedFormat(rawFormat)
            }
            format = parsed
            sawFormat = true
            index += 2
        default:
            throw CanonCommandError.unknownArgument(argument)
        }
    }

    return CanonOptions(
        root: root,
        canonRoot: canonRoot,
        profiles: profiles,
        requirements: requirements,
        format: format
    )
}

private func requestedFormat(in arguments: [String]) -> OutputFormat {
    for index in arguments.indices where arguments[index] == "--format" {
        let valueIndex = index + 1
        if arguments.indices.contains(valueIndex),
           let format = OutputFormat(rawValue: arguments[valueIndex])
        {
            return format
        }
    }
    return .human
}

private func write(_ report: VerificationReport, format: OutputFormat) {
    let output: Data
    switch format {
    case .json:
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        output = (try? encoder.encode(report)) ?? Data()
    case .human:
        var lines = ["exit_code: \(report.exitCode.rawValue)"]
        for check in report.checks {
            var line = "\(escapeHumanField(check.checkID)): "
                + (check.passed ? "passed" : "failed")
            if let severity = check.severity {
                line += " severity=\(escapeHumanField(severity.rawValue))"
            }
            if let message = check.message {
                line += " message=\(escapeHumanField(message))"
            }
            lines.append(line)
        }
        output = Data(lines.joined(separator: "\n").utf8)
    }
    FileHandle.standardOutput.write(output)
    FileHandle.standardOutput.write(Data([0x0A]))
}

private func escapeHumanField(_ value: String) -> String {
    var escaped = ""
    escaped.reserveCapacity(value.utf8.count)
    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 0x00:
            escaped += #"\0"#
        case 0x0A:
            escaped += #"\n"#
        case 0x0D:
            escaped += #"\r"#
        case 0x1B:
            escaped += #"\e"#
        case 0x5C:
            escaped += #"\\"#
        case 0x00 ... 0x1F, 0x7F ... 0x9F, 0x2028, 0x2029:
            escaped += String(format: #"\u{%04X}"#, scalar.value)
        default:
            escaped.unicodeScalars.append(scalar)
        }
    }
    return escaped
}

private let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--version"], let version = productVersion() {
    print(version)
    exit(0)
}

guard arguments.first == "canon" else {
    fputs("usage: ifl-verify --version\n", stderr)
    exit(2)
}

private let canonArguments = Array(arguments.dropFirst())
private let options: CanonOptions
do {
    options = try parseCanonOptions(canonArguments)
} catch {
    let report = VerificationReport(
        exitCode: .invalidInput,
        checks: [CheckResult(
            checkID: "CHK-CAN-COMMAND-001",
            passed: false,
            message: String(describing: error)
        )]
    )
    write(report, format: requestedFormat(in: canonArguments))
    exit(report.exitCode.rawValue)
}

private let resolvedRoot: ResolvedVerificationRoot
do {
    resolvedRoot = try VerificationRootLocator().resolveAnchored(
        root: options.root,
        canonRoot: options.canonRoot
    )
} catch let error as VerificationRootError {
    let report = VerificationReport(
        exitCode: error.exitCode,
        checks: [CheckResult(
            checkID: "CHK-CAN-ROOT-001",
            passed: false,
            message: error.description
        )]
    )
    write(report, format: options.format)
    exit(report.exitCode.rawValue)
} catch {
    let report = VerificationReport(
        exitCode: .internalError,
        checks: [CheckResult(
            checkID: "CHK-CAN-ROOT-001",
            passed: false,
            message: String(describing: error)
        )]
    )
    write(report, format: options.format)
    exit(report.exitCode.rawValue)
}

private let report = CanonVerificationProvider(resolvedRoot: resolvedRoot).report(
    profiles: options.profiles,
    requirements: options.requirements
)
write(report, format: options.format)
exit(report.exitCode.rawValue)
