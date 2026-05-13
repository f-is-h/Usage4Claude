// swift-tools-version: 5.9
//
// Lightweight SwiftPM package for unit-testing pure functions extracted from
// the Xcode app target. The .xcodeproj remains the authoritative app build;
// this manifest exists only so contributors can run:
//
//     swift test
//
// against pure-function helpers without spinning up Xcode. Targets reference
// existing source files in place via `path:` + `sources:` — no duplication,
// no drift. As more pure code is extracted into focused files, add it to the
// Usage4ClaudeCore target's `sources` and write tests in Tests/.
//
import PackageDescription

let package = Package(
    name: "Usage4ClaudeTests",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Usage4ClaudeCore", targets: ["Usage4ClaudeCore"])
    ],
    targets: [
        .target(
            name: "Usage4ClaudeCore",
            path: "Usage4Claude/Models",
            sources: ["ClaudeAPIResponseModels.swift"]
        ),
        .testTarget(
            name: "Usage4ClaudeCoreTests",
            dependencies: ["Usage4ClaudeCore"],
            path: "Tests/Usage4ClaudeCoreTests"
        )
    ]
)
