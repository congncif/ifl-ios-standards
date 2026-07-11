// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IFLTooling",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "IFLContracts", targets: ["IFLContracts"]),
        .library(name: "IFLCanon", targets: ["IFLCanon"]),
        .library(name: "IFLWorkflow", targets: ["IFLWorkflow"]),
        .library(name: "IFLVerification", targets: ["IFLVerification"]),
        .executable(name: "ifl-verify", targets: ["IFLVerifyCLI"]),
    ],
    targets: [
        .target(name: "IFLContracts"),
        .target(name: "IFLCanon", dependencies: ["IFLContracts"]),
        .target(name: "IFLWorkflow", dependencies: ["IFLContracts", "IFLCanon"]),
        .target(name: "IFLVerification", dependencies: ["IFLContracts", "IFLCanon"]),
        .executableTarget(name: "IFLVerifyCLI", dependencies: ["IFLVerification"]),
        .testTarget(name: "IFLContractsTests", dependencies: ["IFLContracts"]),
        .testTarget(name: "IFLCanonTests", dependencies: ["IFLCanon"]),
        .testTarget(name: "IFLWorkflowTests", dependencies: ["IFLWorkflow"]),
        .testTarget(name: "IFLVerificationTests", dependencies: ["IFLVerification"]),
    ],
    swiftLanguageModes: [.v6]
)
