// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SimonsLights",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "SimonsLights",
            dependencies: [.product(name: "HotKey", package: "HotKey")],
            path: "Sources",
            exclude: ["setup_bridge.py", "Info.plist", "config.json", "control_monkey.py"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Accelerate")
            ]
        )
    ]
)
