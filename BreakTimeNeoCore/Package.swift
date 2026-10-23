// swift-tools-version: 6.4
import PackageDescription

// Break logic without any UI or system services, so it can be tested by
// fast-forwarding time instead of waiting.
let package = Package(
    name: "BreakTimeNeoCore",
    platforms: [.macOS(.v27)],
    products: [
        .library(name: "BreakTimeNeoCore", targets: ["BreakTimeNeoCore"]),
    ],
    targets: [
        .target(name: "BreakTimeNeoCore"),
        .testTarget(name: "BreakTimeNeoCoreTests", dependencies: ["BreakTimeNeoCore"]),
    ]
)
