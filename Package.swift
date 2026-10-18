// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ColorPointer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ColorPointer",
            path: "Sources/ColorPointer"
        )
    ]
)
