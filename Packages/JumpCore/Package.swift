// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JumpCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "JumpCore", targets: ["JumpCore"])],
    targets: [
        .target(name: "JumpCore"),
        .testTarget(name: "JumpCoreTests", dependencies: ["JumpCore"])
    ]
)
