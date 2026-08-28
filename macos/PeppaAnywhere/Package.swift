// swift-tools-version: 6.0
import PackageDescription
import Foundation

let commandLineToolsFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let commandLineToolsSwiftLibraries = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let testingSwiftSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: commandLineToolsFrameworks)
    ? [.unsafeFlags(["-F", commandLineToolsFrameworks], .when(platforms: [.macOS]))]
    : []
let testingLinkerSettings: [LinkerSetting] = FileManager.default.fileExists(atPath: commandLineToolsFrameworks)
    ? [
        .linkedFramework("Testing"),
        .unsafeFlags(["-F", commandLineToolsFrameworks, "-Xlinker", "-rpath", "-Xlinker", commandLineToolsFrameworks, "-Xlinker", "-rpath", "-Xlinker", commandLineToolsSwiftLibraries], .when(platforms: [.macOS]))
    ]
    : [.linkedFramework("Testing")]

let package = Package(
    name: "PeppaAnywhere",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PeppaAnywhereCore", targets: ["PeppaAnywhereCore"]),
        .executable(name: "PeppaAnywhere", targets: ["PeppaAnywhere"]),
    ],
    targets: [
        .target(name: "PeppaAnywhereCore", swiftSettings: testingSwiftSettings),
        .executableTarget(
            name: "PeppaAnywhere",
            dependencies: ["PeppaAnywhereCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PeppaAnywhereCoreTests",
            dependencies: ["PeppaAnywhereCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ]
)
