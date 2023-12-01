// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zcash-swift-payment-uri",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "zcash-swift-payment-uri",
            targets: ["zcash-swift-payment-uri"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "zcash-swift-payment-uri"
        ),
        .testTarget(
            name: "zcash-swift-payment-uriTests",
            dependencies: ["zcash-swift-payment-uri"]
        ),
    ]
)
