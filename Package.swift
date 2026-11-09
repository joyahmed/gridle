// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Pro is built only when its code is here. The public (free) copy has no Pro/ folders,
// so the same file builds both editions.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let hasPro = FileManager.default.fileExists(atPath: packageDir.appendingPathComponent("Sources/GridleCore/Pro").path)
let edition: [SwiftSetting] = hasPro ? [.define("GRIDLE_PRO")] : []

let package = Package(
    name: "Gridle",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: where a window goes for each action. No AppKit, fully tested.
        .target(name: "GridleCore", swiftSettings: edition),
        // The menu-bar app: global keys, moving real windows, show desktop.
        .executableTarget(name: "Gridle", dependencies: ["GridleCore"], swiftSettings: edition),
        .testTarget(name: "GridleCoreTests", dependencies: ["GridleCore"], swiftSettings: edition),
    ],
    swiftLanguageModes: [.v5]
)
