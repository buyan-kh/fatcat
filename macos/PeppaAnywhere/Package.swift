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
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "PeppaAnywhereCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            exclude: ["PeppaAvatar.swift"],
            swiftSettings: testingSwiftSettings
        ),
        .executableTarget(
            name: "PeppaAnywhere",
            dependencies: ["PeppaAnywhereCore"],
            exclude: ["Resources/WebApp"],
            resources: [
                .copy("Resources/strobI.avatar.json"),
                .copy("Resources/FatCatAvatar")
            ]
        ),
        .testTarget(
            name: "PeppaAnywhereCoreTests",
            dependencies: ["PeppaAnywhereCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ]
)
