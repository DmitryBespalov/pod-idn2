// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "idn2Swift",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(
            name: "idn2Swift",
            targets: ["idn2Swift"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "idn2",
            path: "idn2.xcframework"
        ),
        .binaryTarget(
            name: "unistring",
            path: "unistring.xcframework"
        ),
        .target(
            name: "idn2Swift",
            dependencies: ["unistring", "idn2"],
            sources: ["Source"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "idn2SwiftTests",
            dependencies: ["idn2Swift"],
            sources: ["Tests"]
        )
    ]
)
