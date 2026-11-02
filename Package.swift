// swift-tools-version: 6.0
import Foundation
import PackageDescription

// Pro is built only when its code is here. The public (free) copy has no Pro/ folders,
// so the same file builds both editions.
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let hasPro = FileManager.default.fileExists(atPath: packageDir.appendingPathComponent("Sources/PanesCore/Pro").path)
let edition: [SwiftSetting] = hasPro ? [.define("PANES_PRO")] : []

let package = Package(
    name: "Panes",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: where a window goes for each action. No AppKit, fully tested.
        .target(name: "PanesCore", swiftSettings: edition),
        // The menu-bar app: global keys, moving real windows, show desktop.
        .executableTarget(name: "Panes", dependencies: ["PanesCore"], swiftSettings: edition),
        .testTarget(name: "PanesCoreTests", dependencies: ["PanesCore"], swiftSettings: edition),
    ],
    swiftLanguageModes: [.v5]
)
