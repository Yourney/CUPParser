// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CUPParser",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13)
    ],
    products: [
        .library(name: "CUPParser", targets: ["CUPParser"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation", exact: "0.9.20")
    ],
    targets: [
        .target(
            name: "CUPParser",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .testTarget(
            name: "CUPParserTests",
            dependencies: ["CUPParser", "ZIPFoundation"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
