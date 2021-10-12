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
        .package(url: "https://github.com/DimaRU/SwiftyModbus.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "FestoModbus", dependencies: ["SwiftyModbus"]),
    ]
)
