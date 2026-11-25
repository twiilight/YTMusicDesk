// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "YTMusicDesk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "YTMusicDesk",
            targets: ["YoutubeMusicApp"]
        )
    ],
    targets: [
        .target(
            name: "CoreDomain",
            dependencies: []
        ),
        .target(
            name: "WebEnhancements",
            dependencies: ["CoreDomain"]
        ),
        .target(
            name: "WebEngine",
            dependencies: ["CoreDomain"]
        ),
        .target(
            name: "LyricsService",
            dependencies: ["CoreDomain"]
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["CoreDomain"]
        ),
        .executableTarget(
            name: "YoutubeMusicApp",
            dependencies: [
                "CoreDomain",
                "WebEnhancements",
                "WebEngine",
                "LyricsService",
                "DesignSystem"
            ]
        ),
        .testTarget(
            name: "CoreDomainTests",
            dependencies: [
                "CoreDomain",
                "WebEnhancements",
                "LyricsService",
                "WebEngine"
            ]
        )
    ]
)
