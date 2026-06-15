// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AppTwin",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "AppTwin",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/AppTwin",
            // rpath so the embedded Sparkle.framework is found at runtime from the .app bundle.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(name: "AppTwinStub", path: "Sources/AppTwinStub"),
    ]
)
