// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketPetCore",
    platforms: [
        .iOS("26.0"),
        .macOS("15.0"),
    ],
    products: [
        .library(name: "PocketPetCore", targets: ["PocketPetCore"]),
    ],
    targets: [
        .target(name: "PocketPetCore"),
        .testTarget(name: "PocketPetCoreTests", dependencies: ["PocketPetCore"]),
    ]
)
