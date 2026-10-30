// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileFinder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FileFinder",
            targets: ["FileFinder"]
        ),
        .library(
            name: "FileFinderLib",
            targets: ["FileFinderLib"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FileFinderLib",
            path: "Sources/FileFinderLib",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "FileFinder",
            dependencies: ["FileFinderLib"],
            path: "Sources/FileFinderApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "FileFinderTests",
            dependencies: ["FileFinderLib"],
            path: "Tests/FileFinderTests"
        )
    ]
)
