// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StreamableHTML5PublishPlugin",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "StreamableHTML5PublishPlugin",
            targets: ["StreamableHTML5PublishPlugin"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/johnsundell/Publish", from: "0.2.0"),
        .package(url: "https://github.com/Amzd/OutputForPublishPlugins", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "StreamableHTML5PublishPlugin",
            dependencies: ["Publish", "OutputForPublishPlugins"]),
        .testTarget(
            name: "StreamableHTML5PublishPluginTests",
            dependencies: ["StreamableHTML5PublishPlugin"]),
    ]
)
