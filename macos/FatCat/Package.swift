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
    name: "FatCat",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FatCatCore", targets: ["FatCatCore"]),
        .executable(name: "FatCat", targets: ["FatCat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "FatCatCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            exclude: ["FatCatAvatar.swift"],
            swiftSettings: testingSwiftSettings
        ),
        .executableTarget(
            name: "FatCat",
            dependencies: ["FatCatCore"],
            resources: [
                .copy("Resources/fatcat.avatar.json"),
                .copy("Resources/FatCatAvatar")
            ]
        ),
        .testTarget(
            name: "FatCatCoreTests",
            dependencies: ["FatCatCore"],
            swiftSettings: testingSwiftSettings,
            linkerSettings: testingLinkerSettings
        ),
    ]
)
