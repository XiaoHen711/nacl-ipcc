// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NaCl",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "NaCl", targets: ["NaCl"]),
    ],
    targets: [
        .target(name: "NaCl", path: "Sources/NaCl"),
    ]
)
