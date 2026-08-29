import Foundation
import Testing
@testable import PeppaAnywhereCore

struct FatCatLifeTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func life(_ now: Date? = nil) -> FatCatLife {
        FatCatLife(now: now ?? start)
    }

    @Test func defaultLifeIsCalmIdle() {
        let life = life()
        #expect(life.mood == .calm)
        #expect(life.attention == .none)
        #expect(life.work == .none)
        #expect(life.task == nil)
        #expect(life.animationKey == "idle")
        #expect(life.peppaState == .idle)
    }

    @Test func observationChangeSparksCuriosityWhileIdle() {
        var life = life()
        life.handle(.observationChanged(app: "Xcode", window: "Fatcat", redacted: false), at: start)

        #expect(life.mood == .curious)
        #expect(life.attention == .screen(app: "Xcode"))
        #expect(life.animationKey == "curious")
        #expect(life.lastCause == .observationChanged(app: "Xcode", window: "Fatcat", redacted: false))
    }

    @Test func redactedObservationDoesNotSparkCuriosity() {
        var life = life()
        life.handle(.observationChanged(app: "Private application", window: "Private window", redacted: true), at: start)

        #expect(life.mood == .calm)
        #expect(life.attention == .none)
        #expect(life.animationKey == "idle")
    }

    @Test func curiosityFadesToCalmAfterHold() {
        var life = life()
        life.handle(.observationChanged(app: "Safari", window: nil, redacted: false), at: start)
        life.handle(.tick, at: start.addingTimeInterval(FatCatLifeTiming.curiosityHold))

        #expect(life.mood == .calm)
        #expect(life.attention == .none)
        #expect(life.animationKey == "idle")
    }

    @Test func idleDecayBecomesDrowsyThenSleeping() {
        var life = life()
        life.handle(.tick, at: start.addingTimeInterval(FatCatLifeTiming.tiredAfter))
        #expect(life.mood == .tired)
        #expect(life.animationKey == "drowsy")
        #expect(!life.asleep)

        life.handle(.tick, at: start.addingTimeInterval(FatCatLifeTiming.sleepAfter))
        #expect(life.asleep)
        #expect(life.animationKey == "sleeping")
        #expect(life.peppaState == .sleeping)
    }

    @Test func userSendOverlaysListeningAndRemembersTask() {
        var life = life()
        life.handle(.observationChanged(app: "Xcode", window: nil, redacted: false), at: start)
        life.handle(.userSentMessage(requestID: "r1", conversationID: "c1"), at: start)

        #expect(life.work == .listening)
        #expect(life.attention == .user)
        #expect(life.task == FatCatTask(conversationID: "c1"))
        #expect(life.animationKey == "listening")
        #expect(life.asleep == false)
    }

    @Test func hermesDeltaMapsToThinkingAndTurnCompleteKeepsTask() {
        var life = life()
        life.handle(.userSentMessage(requestID: "r1", conversationID: "c1"), at: start)
        life.handle(.hermes(.streamDelta), at: start)
        #expect(life.work == .thinking)
        #expect(life.animationKey == "thinking")

        life.handle(.hermes(.turnCompleted), at: start)
        #expect(life.work == .none)
        #expect(life.task == FatCatTask(conversationID: "c1"))
        #expect(life.animationKey == "idle")
    }

    @Test func agentIdleIsNotAnEventAndDoesNotWipeCuriosity() {
        var life = life()
        life.handle(.observationChanged(app: "Mail", window: "Inbox", redacted: false), at: start)
        let before = life
        life.handle(.tick, at: start.addingTimeInterval(1))

        #expect(life.mood == .curious)
        #expect(life.animationKey == "curious")
        #expect(FatCatHermesCause.cause(forAgentState: .idle) == nil)
        #expect(FatCatHermesCause.cause(forAgentState: .listening) == nil)
        #expect(before.mood == life.mood)
    }

    @Test func celebrationRequiresVerifyingAndClearsAfterHold() {
        var life = life()
        life.handle(.hermes(.verifiedSuccess), at: start)
        #expect(life.work == .none)
        #expect(life.animationKey == "idle")

        life.handle(.hermes(.actionSucceeded), at: start)
        #expect(life.work == .verifying)
        life.handle(.hermes(.verifiedSuccess), at: start)
        #expect(life.work == .celebrating)
        #expect(life.animationKey == "celebrate")
        #expect(life.peppaState == .celebrating)

        life.handle(.hermes(.turnCompleted), at: start)
        #expect(life.work == .celebrating)
        #expect(life.animationKey == "celebrate")

        life.handle(.tick, at: start.addingTimeInterval(FatCatLifeTiming.celebrateHold))
        #expect(life.work == .none)
        #expect(life.mood == .pleased)
        #expect(life.animationKey == "idle")
        #expect(life.task == nil)
    }

    @Test func pauseForcesSleepWithoutClearingWork() {
        var life = life()
        life.handle(.userSentMessage(requestID: "r1", conversationID: "c1"), at: start)
        life.handle(.hermes(.thought), at: start)
        life.handle(.observationPaused, at: start)

        #expect(life.observationPaused)
        #expect(life.work == .thinking)
        #expect(life.animationKey == "sleeping")
        #expect(life.peppaState == .sleeping)

        life.handle(.observationResumed, at: start)
        #expect(!life.observationPaused)
        #expect(life.work == .thinking)
        #expect(life.animationKey == "thinking")
    }

    @Test func newChatClearsTaskAndWork() {
        var life = life()
        life.handle(.userSentMessage(requestID: "r1", conversationID: "c1"), at: start)
        life.handle(.hermes(.streamDelta), at: start)
        life.handle(.userStartedNewChat, at: start)

        #expect(life.task == nil)
        #expect(life.work == .none)
        #expect(life.attention == .user)
        #expect(life.animationKey == "idle")
    }

    @Test func stopAndFailureMakeUneasy() {
        var life = life()
        life.handle(.userSentMessage(requestID: "r1", conversationID: "c1"), at: start)
        life.handle(.userStoppedGeneration, at: start)
        #expect(life.work == .none)
        #expect(life.mood == .uneasy)
        #expect(life.animationKey == "suspicious")
        #expect(life.peppaState == .recovering)

        life.handle(.hermes(.turnFailed), at: start.addingTimeInterval(1))
        #expect(life.mood == .uneasy)
        #expect(life.work == .none)
    }

    @Test func toolCallAndPermissionMapToWorkOverlay() {
        var life = life()
        life.handle(.hermes(.toolCall(name: "read")), at: start)
        #expect(life.work == .acting)
        #expect(life.animationKey == "working")

        life.handle(.hermes(.permissionRequested), at: start)
        #expect(life.work == .asking)
        #expect(life.animationKey == "listening")
        #expect(life.peppaState == .askingPermission)
    }

    @Test func searchToolCallsUseTheSearchingAnimation() {
        var life = life()
        life.handle(.hermes(.toolCall(name: "web_search")), at: start)
        #expect(life.work == .searching)
        #expect(life.animationKey == "searching")

        life.handle(.hermes(.toolCall(name: "read")), at: start)
        #expect(life.work == .acting)
        #expect(life.animationKey == "working")
    }
}
