// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WhoRealtime",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Desert-Ant-Labs/desert-ant-core.git", from: "4.2.3"),
    ],
    targets: [
        .target(
            name: "WhoTapCore",
            linkerSettings: [.linkedFramework("CoreAudio")]
        ),
        // The app: capture, transcription, diarization, doc, and the UI views.
        .target(
            name: "WhoRealtime",
            dependencies: [
                "WhoTapCore",
                .product(name: "Who", package: "desert-ant-core"),
                .product(name: "Voz", package: "desert-ant-core"),
            ],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
        // Two flavors of the same app, on one library:
        .executableTarget(
            name: "WhoMenuBar",
            dependencies: ["WhoRealtime"]
        ),
        .executableTarget(
            name: "WhoWindowed",
            dependencies: ["WhoRealtime"]
        ),
        .testTarget(
            name: "WhoRealtimeTests",
            dependencies: ["WhoRealtime"],
            swiftSettings: [
                .defaultIsolation(MainActor.self),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
    ]
)
