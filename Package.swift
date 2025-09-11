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
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0")
    ],
    targets: [
        .target(
            name: "CUPParser",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
            ]
        ),
        .testTarget(
            name: "CUPParserTests",
            dependencies: ["CUPParser"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
