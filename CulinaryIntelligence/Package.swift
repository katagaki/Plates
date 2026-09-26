// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CulinaryIntelligence",
    defaultLocalization: "en-US",
    platforms: [.iOS("27.0")],
    products: [
        .library(name: "CulinaryIntelligence", targets: ["CulinaryIntelligence"]),
    ],
    targets: [
        // The newest llama.cpp release that still carries an iOS simulator slice. Later
        // releases ship the device slice only, which leaves the app unable to run in Simulator.
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b10456/llama-b10456-xcframework.zip",
            checksum: "0223bedd0a01232399d943dcb72bc227882bc90df98e29d7a92343531a88cc02"
        ),
        .target(
            name: "CulinaryIntelligence",
            dependencies: ["llama"],
            resources: [.process("Resources")],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
