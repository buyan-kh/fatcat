import Foundation
import Testing
@testable import PeppaAnywhereCore

struct NativeAvatarTests {
    @Test func decodesTheRealPeppaDefinitionAndKeepsItsKeys() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent("public/strobi.avatar.json"))
        let definition = try PeppaAvatarDefinition.decode(data: data)

        #expect(definition.name == "Peppa")
        #expect(definition.animationOrder.count == 23)
        #expect(definition.expressionOrder.count == 28)
        #expect(definition.animations["thinking"] != nil)
        #expect(definition.animations["celebrate"] != nil)
    }

    @Test func nativeRendererProducesAFrameForRealAnimation() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent("public/strobi.avatar.json"))
        let definition = try PeppaAvatarDefinition.decode(data: data)
        let renderer = PeppaAvatarRenderer(definition: definition)

        let frame = renderer.frame(animationKey: "idle", elapsed: 0.5)

        #expect(!frame.head.isEmpty)
        #expect(!frame.leftEye.isEmpty)
        #expect(!frame.rightEye.isEmpty)
        #expect(frame.bodyColor == "#5b7fe5")
    }

    @Test func rendererInterpolatesWithoutMutatingTheDefinition() throws {
        let definition = PeppaAvatarDefinition(
            name: "Peppa",
            body: .sphere,
            colors: .init(body: "#5b7fe5", eyes: "#111316"),
            expressions: [
                "neutral": .neutral,
                "shifted": .neutral.with(headX: 20),
            ],
            expressionOrder: ["neutral", "shifted"],
            animations: ["test": .init(steps: [
                .init(expression: "neutral", holdMs: 100, transitionMs: 100, transition: "smooth"),
                .init(expression: "shifted", holdMs: 100, transitionMs: 100, transition: "smooth"),
            ])],
            animationOrder: ["test"]
        )
        let renderer = PeppaAvatarRenderer(definition: definition)

        let frame = renderer.frame(animationKey: "test", elapsed: 0.15)

        #expect(frame.head != renderer.frame(animationKey: "test", elapsed: 0).head)
        #expect(definition.expressions["neutral"]?.head.x == 0)
    }

    @Test func rendererProvidesAContainmentScaleForCompactPetSurfaces() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let definition = try PeppaAvatarDefinition.decode(data: Data(contentsOf: repositoryRoot.appendingPathComponent("public/strobi.avatar.json")))
        let renderer = PeppaAvatarRenderer(definition: definition)

        #expect(renderer.scaleToFit(width: 220, height: 220) < 1)
        #expect(renderer.scaleToFit(width: 220, height: 220) > 0.7)
    }
}

private extension PeppaAvatarExpression {
    static let neutral = Self(
        head: .init(x: 0, y: 0, z: 0),
        eyes: .init(
            left: .init(width: 20, height: 50, x: 0, y: -7, angle: 0),
            right: .init(width: 20, height: 50, x: 0, y: -7, angle: 0),
            spacing: 35
        ),
        perspective: 1,
        motion: .init(eyes: "none", body: "none")
    )

    func with(headX: Double) -> Self {
        var copy = self
        copy.head.x = headX
        return copy
    }
}
