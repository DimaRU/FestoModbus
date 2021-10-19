// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "FestoModbus",
    products: [
        .library(
            name: "FestoModbus",
            targets: ["FestoModbus"]),
    ],
    dependencies: [
        .package(url: "https://git.dev-og.com/d.borovikov/SwiftyModbus.git", from: "2.0.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.15.2")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FestoModbus",
            dependencies: [
                "SwiftyModbus",
                "PromiseKit",
                .product(name: "Logging", package: "swift-log"),
            ]),
    ]
)
