// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "TrackerInstrumentation",
    platforms: [
        .iOS(.v26),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TrackerInstrumentation",
            targets: ["TrackerInstrumentation"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.1"
        ),
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            from: "9.4.0"
        ),
    ],
    targets: [
        .target(
            name: "TrackerInstrumentation",
            dependencies: [
                "TrackerInstrumentationMacros",
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            swiftSettings: swiftSettings
        ),
        .macro(
            name: "TrackerInstrumentationMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "TrackerInstrumentationTests",
            dependencies: [
                "TrackerInstrumentation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
