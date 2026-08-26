// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "prismBar",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .library(name: "prismBarCore", targets: ["prismBarCore"]),
        .library(name: "prismBarEngine", targets: ["prismBarEngine"]),
        .library(name: "prismPluginKit", targets: ["prismPluginKit"]),
        .library(name: "prismCalcPlugin", targets: ["prismCalcPlugin"])
    ],
    targets: [
        .target(name: "prismBarCore"),
        .target(
            name: "prismBarEngine",
            dependencies: ["prismBarCore"]
        ),
        .target(name: "prismPluginKit"),
        .target(
            name: "prismCalcPlugin",
            dependencies: ["prismPluginKit"]
        ),
        .testTarget(
            name: "prismBarCoreTests",
            dependencies: ["prismBarCore"]
        ),
        .testTarget(
            name: "prismBarEngineTests",
            dependencies: ["prismBarCore", "prismBarEngine"]
        ),
        .testTarget(
            name: "prismPluginKitTests",
            dependencies: ["prismPluginKit"]
        ),
        .testTarget(
            name: "prismCalcPluginTests",
            dependencies: ["prismCalcPlugin"]
        )
    ],
    swiftLanguageModes: [.v6]
)
