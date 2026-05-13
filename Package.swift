// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DevilSign",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DevilSign",
            targets: ["DevilSign"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/weichsel/ZIPFoundation.git",
            from: "0.9.0"
        )
    ],
    targets: [
        .target(
            name: "DevilSign",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources"
        )
    ]
)
