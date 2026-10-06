// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KineticCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "KineticCore", targets: ["KineticCore"])
    ],
    targets: [
        .target(name: "KineticCore"),
        .testTarget(name: "KineticCoreTests", dependencies: ["KineticCore"])
    ]
)
