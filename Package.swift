// swift-tools-version: 6.0
import PackageDescription

// The drawing model is deliberately independent of AppKit, so it can be tested
// on Linux as well as macOS. The native app lives in Altanboard.xcodeproj.
let package = Package(
    name: "AltanboardCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WhiteboardCore", targets: ["WhiteboardCore"])
    ],
    targets: [
        .target(name: "WhiteboardCore"),
        .testTarget(
            name: "WhiteboardCoreTests",
            dependencies: ["WhiteboardCore"]
        )
    ]
)
