// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MobileConsentsSDK",
    defaultLocalization: LanguageTag(rawValue: "en"),
    platforms: [.iOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MobileConsentsSDK",
            targets: ["MobileConsentsSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MobileConsentsSDK",
            dependencies: []),
        .testTarget(
            name: "MobileConsentsSDKTests",
            dependencies: ["MobileConsentsSDK"])
    ]
)
