// swift-tools-version: 6.3
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "TrackerAPI",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TrackerAPI",
            targets: ["TrackerAPI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-openapi-generator.git",
            exact: "1.14.2"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-runtime.git",
            exact: "1.13.3"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-urlsession.git",
            exact: "1.4.0"
        ),
        .package(
            url: "https://github.com/apple/swift-http-types.git",
            exact: "1.8.0"
        )
    ],
    targets: [
        .target(
            name: "TrackerAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "TrackerAPITests",
            dependencies: ["TrackerAPI",
                           .product(name: "HTTPTypes", package: "swift-http-types")],
            swiftSettings: swiftSettings
        )
    ]
)
