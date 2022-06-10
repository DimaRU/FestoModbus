// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "FestoModbus",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "FestoModbus", targets: ["FestoModbus"]),
    ],
    dependencies: [
        .package(url: "https://git.dev-og.com/d.borovikov/SwiftyModbus.git", from: "2.0.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.16.2")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/DimaRU/swift-log-syslog.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "FestoModbus",
            dependencies: [
                "SwiftyModbus",
                "PromiseKit",
                .product(name: "Logging", package: "swift-log"),
            ]),
        .testTarget(
            name: "FestoModbusTests",
            dependencies: [
                "FestoModbus",
                "PromiseKit",
                .product(name: "LoggingSyslog", package: "swift-log-syslog"),
            ]),
    ]
)
