// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PhotoDiaryTriage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PhotoDiaryTriage",
            targets: ["PhotoDiaryTriage"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PhotoDiaryTriage",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "PhotoDiaryTriageTests",
            dependencies: ["PhotoDiaryTriage"]
        )
    ]
)
