// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "appshots",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Appshots", targets: ["Appshots"]),
    ],
    dependencies: [
        .package(path: "kwwk-computer-use-core"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "Appshots",
            dependencies: [
                .product(name: "KWWKComputerUseCore", package: "kwwk-computer-use-core"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            exclude: [
                "Configuration",
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
