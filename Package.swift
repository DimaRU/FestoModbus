// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "FestoModbus",
    platforms: [.macOS(.v10_15)],
//    products: [
//        .library(
//            name: "FestoModbus",
//            targets: ["FestoModbus"]),
//    ],
    dependencies: [
        .package(url: "https://git.dev-og.com/d.borovikov/SwiftyModbus.git", from: "2.0.0"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.16.2")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/sushichop/Puppy.git", from: "0.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TestFestoModbus",
            dependencies: [
                "Puppy",
                "FestoModbus",
                "PromiseKit",
            ]),
        .target(
            name: "FestoModbus",
            dependencies: [
                "SwiftyModbus",
                "PromiseKit",
                .product(name: "Logging", package: "swift-log"),
            ]),
    ]
)
