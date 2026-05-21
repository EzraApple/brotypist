// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Brotypist",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BrotypistCore", targets: ["BrotypistCore"]),
        .executable(name: "brotypist", targets: ["BrotypistApp"]),
        .executable(name: "brotypistctl", targets: ["BrotypistCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/llama.swift", .upToNextMajor(from: "2.8665.0"))
    ],
    targets: [
        .target(name: "BrotypistCore"),
        .target(
            name: "BrotypistRuntime",
            dependencies: [
                "BrotypistCore",
                .product(name: "LlamaSwift", package: "llama.swift")
            ]
        ),
        .executableTarget(
            name: "BrotypistApp",
            dependencies: ["BrotypistCore", "BrotypistRuntime"]
        ),
        .executableTarget(
            name: "BrotypistCLI",
            dependencies: ["BrotypistCore", "BrotypistRuntime"]
        ),
        .testTarget(
            name: "BrotypistCoreTests",
            dependencies: ["BrotypistCore"]
        )
    ]
)
