import Foundation
import Testing

struct FatCatAvatarContractTests {
    @Test func productionDefinitionKeepsTheOriginalRoundGeometryAndCatalog() throws {
        let definition = try loadJSON("public/strobi.avatar.json")
        let body = try #require(definition["body"] as? [String: Any])
        let primary = try #require(body["primary"] as? [String: Any])
        let colors = try #require(definition["colors"] as? [String: Any])
        let expressionOrder = try #require(definition["expressionOrder"] as? [String])
        let animationOrder = try #require(definition["animationOrder"] as? [String])

        #expect(definition["name"] as? String == "FatCat")
        #expect(primary["type"] as? String == "sphere")
        #expect(primary["width"] as? Double == 240)
        #expect(primary["height"] as? Double == 240)
        #expect(primary["depth"] as? Double == 240.03671875)
        #expect(primary["roundness"] as? Double == 1)
        #expect(colors["body"] as? String == "#F28C38" || colors["body"] as? String == "#f28c38")
        #expect(colors["eyes"] as? String == "#111316")
        #expect(expressionOrder.count == 28)
        #expect(animationOrder.count == 23)
        #expect(animationOrder.contains("idle"))
        #expect(animationOrder.contains("thinking"))
        #expect(animationOrder.contains("celebrate"))
    }

    @Test func originalExpressionAndAnimationKeysRemainInOrder() throws {
        let definition = try loadJSON("public/strobi.avatar.json")
        let expressions = try #require(definition["expressions"] as? [String: Any])
        let animations = try #require(definition["animations"] as? [String: Any])
        let expressionOrder = try #require(definition["expressionOrder"] as? [String])
        let animationOrder = try #require(definition["animationOrder"] as? [String])

        #expect(Set(expressionOrder) == Set(expressions.keys))
        #expect(Set(animationOrder) == Set(animations.keys))
        #expect(expressionOrder.first == "neutral")
        #expect(animationOrder.first == "sleeping")
    }

    @Test func productPathUsesTransparentWebAvatarAndNotTheNativeRenderer() throws {
        let appMain = try loadText("macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift")
        let manifest = try loadText("macos/PeppaAnywhere/Package.swift")

        #expect(appMain.contains("WKWebView"))
        #expect(appMain.contains("FatCatAvatar"))
        #expect(appMain.contains("drawsBackground"))
        #expect(appMain.contains("underPageBackgroundColor = .clear"))
        #expect(appMain.contains("acceptsFirstResponder"))
        #expect(!appMain.contains("PeppaAvatarRenderer"))
        #expect(!appMain.contains("PeppaAvatarView"))
        #expect(!appMain.contains("SceneKit"))
        #expect(!appMain.contains("RealityKit"))
        #expect(manifest.contains("exclude: [\"PeppaAvatar.swift\"]"))
        #expect(manifest.contains("Resources/FatCatAvatar"))
    }

    private func loadJSON(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func loadText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
