// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SimonsLights",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        // Add HotKey library for better global hotkey support
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "SimonsLights",
            dependencies: ["HotKey"],
            path: ".",
            exclude: ["setup_bridge.py", "Info.plist", "config.json", "control_monkey.py"],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ],
            linkerSettings: [
                .linkedFramework("Speech")
            ]
        )
    ]
)
