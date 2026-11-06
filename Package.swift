// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AuthenticatorBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AuthenticatorCore"),
        .executableTarget(name: "AuthenticatorBar", dependencies: ["AuthenticatorCore"]),
        .testTarget(name: "AuthenticatorCoreTests", dependencies: ["AuthenticatorCore"]),
    ]
)
