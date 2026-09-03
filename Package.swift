// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MobileConsentsSDK",
    defaultLocalization: LanguageTag(rawValue: "en"),
    platforms: [.iOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MobileConsentsSDK",
            targets: ["MobileConsentsSDK"]),
    ],
    targets: [
        .target(
            name: "MobileConsentsSDK",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(
            name: "MobileConsentsSDKTests",
            dependencies: ["MobileConsentsSDK"],
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ])
    ]
)
