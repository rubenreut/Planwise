// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Momentum",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Momentum",
            targets: ["Momentum"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0")
    ],
    targets: [
        .target(
            name: "Momentum",
            dependencies: [
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk")
            ],
            path: "Momentum/Momentum",
            exclude: [
                "Info.plist",
                "Momentum.entitlements",
                "Preview Content"
            ]
        ),
        .testTarget(
            name: "MomentumTests",
            dependencies: ["Momentum"],
            path: "Momentum/MomentumTests"
        )
    ]
)