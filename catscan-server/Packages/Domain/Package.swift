// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(
            name: "Domain",
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
