// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LavenderMessenger",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LavenderMessenger",
            targets: ["LavenderMessengerLib"]
        ),
    ],
    dependencies: [
        // gRPC Swift
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.1.0"),
        // SwiftProtobuf
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        // Swift gRPC HTTP/2 transport (NEW — replaces NIOTransportServices for newer grpc-swift)
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.70.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.35.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.24.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.28.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.23.0"),
        // Keychain access for secure credential storage
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .target(
            name: "LavenderMessengerLib",
            dependencies: [
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ],
            path: "Sources/LavenderMessenger",
            exclude: [],
            sources: [
                "Generated",
                "Models",
                "DataLayer",
                "BusinessLayer",
                "UI",
                "Resources"
            ]
        ),
        .testTarget(
            name: "LavenderMessengerTests",
            dependencies: [
                "LavenderMessengerLib",
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Tests"
        ),
    ]
)
