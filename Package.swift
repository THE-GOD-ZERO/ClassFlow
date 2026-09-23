// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClassFlowCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ClassFlowCore", targets: ["ClassFlowCore"])],
    targets: [
        .target(name: "ClassFlowCore", path: "ClassFlow/Core"),
        .testTarget(name: "ClassFlowCoreTests", dependencies: ["ClassFlowCore"],
                    path: "Tests/CoreTests")
    ]
)
