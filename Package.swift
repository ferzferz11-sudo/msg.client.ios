// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LavenderMessenger",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "LavenderMessenger", targets: ["LavenderMessengerLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.70.0"),
    ],
    targets: [
        .target(
            name: "LavenderMessengerLib",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            path: "Sources",
            sources: ["LavenderMessenger"]
        ),
        .testTarget(
            name: "LavenderMessengerTests",
            dependencies: ["LavenderMessengerLib"],
            path: "Tests"
        ),
    ]
)
