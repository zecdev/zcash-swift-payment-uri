// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
#if os(macOS) || os(iOS)
let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", exact: Version(stringLiteral: "1.0.0")),
    .package(url: "https://github.com/mgriebling/BigDecimal.git", exact: Version(stringLiteral: "2.2.3")),
    .package(url: "https://github.com/mgriebling/BigInt.git", exact: Version(stringLiteral: "2.0.10")),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/mgriebling/UInt128.git", exact: Version(stringLiteral: "3.1.5")),
]

let targets: [Target] = [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
        name: "ZcashPaymentURI",
        dependencies: [
            .product(name: "Parsing", package: "swift-parsing"),
            .product(name: "BigDecimal", package: "BigDecimal"),
            .product(name: "BigInt", package: "BigInt"),
            .product(name: "CustomDump", package: "swift-custom-dump")
        ]
    ),
    .testTarget(
        name: "ZcashPaymentURITests",
        dependencies: [
            "ZcashPaymentURI"
        ]
    ),
]
#else // linux and others
let dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0"),
    .package(url: "https://github.com/pointfreeco/swift-case-paths", exact: Version(stringLiteral: "1.0.0")),
    .package(url: "https://github.com/mgriebling/BigDecimal.git", from: "2.0.0"),
    .package(url: "https://github.com/mgriebling/BigInt.git", exact: Version(stringLiteral: "2.0.11")),
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
    .package(url: "https://github.com/mgriebling/UInt128.git", exact: Version(stringLiteral: "3.1.5")),
]

let targets: [Target] = [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
        name: "ZcashPaymentURI",
        dependencies: [
            .product(name: "Parsing", package: "swift-parsing"),
            .product(name: "BigDecimal", package: "BigDecimal"),
        ]
    ),
    .testTarget(
        name: "ZcashPaymentURITests",
        dependencies: [
            "ZcashPaymentURI"
        ]
    ),
]
#endif

let package = Package(
    name: "zcash-swift-payment-uri",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZcashPaymentURI",
            targets: ["ZcashPaymentURI"]
        ),
    ],
    dependencies: dependencies,
    targets: targets
)
