// swift-tools-version:5.9
import PackageDescription

// Release mirror package: resolves the prebuilt binary, never source.
// Source of truth for tools-version + platform floors: the dev package
// (monorepo optolink-ios/Package.swift) — keep the two in lockstep.
let package = Package(
    name: "OptoLink",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "OptoLink", targets: ["OptoLink"])
    ],
    targets: [
        .binaryTarget(name: "OptoLink", path: "Sources/OptoLink.xcframework")
    ]
)
