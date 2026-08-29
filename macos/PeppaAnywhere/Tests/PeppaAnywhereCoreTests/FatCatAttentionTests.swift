import Foundation
import Testing
@testable import PeppaAnywhereCore

struct FatCatAttentionTests {
    let petPosition = CGPoint(x: 600, y: 500)

    @Test func downwardLookRequiresAnActiveTargetBelow() {
        var engine = FatCatAttentionEngine()
        let now = Date(timeIntervalSince1970: 100)
        #expect(engine.gaze(petPosition: petPosition, at: now) == .neutral)
        engine.focus(on: FatCatAttentionTarget(kind: .click, position: CGPoint(x: 610, y: 300), createdAt: now))
        #expect(engine.gaze(petPosition: petPosition, at: now.addingTimeInterval(0.1)) == .down)
    }

    @Test func targetsAboveThePetNeverProduceADownwardLook() {
        var engine = FatCatAttentionEngine()
        let now = Date(timeIntervalSince1970: 100)
        engine.focus(on: FatCatAttentionTarget(kind: .click, position: CGPoint(x: 610, y: 900), createdAt: now))
        #expect(engine.gaze(petPosition: petPosition, at: now.addingTimeInterval(0.1)) == .neutral)
    }

    @Test func staleTargetsExpireQuicklyAndReturnTheGazeToNeutral() {
        var engine = FatCatAttentionEngine()
        let now = Date(timeIntervalSince1970: 100)
        engine.focus(on: FatCatAttentionTarget(kind: .click, position: CGPoint(x: 610, y: 300), createdAt: now))
        // The lifetime must sit inside the 0.6-1.2 second window.
        #expect(FatCatAttentionEngine.targetLifetime >= 0.6)
        #expect(FatCatAttentionEngine.targetLifetime <= 1.2)
        let later = now.addingTimeInterval(FatCatAttentionEngine.targetLifetime + 0.05)
        #expect(engine.gaze(petPosition: petPosition, at: later) == .neutral)
        #expect(engine.state(at: later) == .stale)
    }

    @Test func theEngineDistinguishesActiveStaleAndNoTarget() {
        var engine = FatCatAttentionEngine()
        let now = Date(timeIntervalSince1970: 100)
        #expect(engine.state(at: now) == .none)
        let target = FatCatAttentionTarget(kind: .chatSurface, position: CGPoint(x: 0, y: 0), createdAt: now)
        engine.focus(on: target)
        #expect(engine.state(at: now.addingTimeInterval(0.2)) == .active(target))
        #expect(engine.state(at: now.addingTimeInterval(5)) == .stale)
        engine.clear()
        #expect(engine.state(at: now.addingTimeInterval(5)) == .none)
    }

    @Test func clicksElsewhereAreIgnoredUnlessExplicitlyMeaningful() {
        var engine = FatCatAttentionEngine()
        let now = Date(timeIntervalSince1970: 100)
        // Only explicit focus calls create targets; there is no cursor feed at all.
        #expect(engine.state(at: now) == .none)
        engine.focus(on: FatCatAttentionTarget(kind: .permissionPrompt, position: CGPoint(x: 610, y: 300), createdAt: now))
        #expect(engine.state(at: now) != .none)
    }
}
