import Foundation
import Testing
@testable import FatCatCore

struct FatCatFlightTests {
    let visibleFrame = CGRect(x: 0, y: 76, width: 1512, height: 830)
    let petSize = CGSize(width: 220, height: 220)

    // MARK: - Flight state machine

    @Test func flightStateSequenceFollowsTheFullArc() {
        var machine = FatCatFlightStateMachine()
        #expect(machine.state == .grounded)
        let steps: [FatCatFlightState] = [.preparingToFly, .flying, .landing, .settling, .grounded]
        for step in steps {
            let accepted = machine.transition(to: step)
            #expect(accepted)
            #expect(machine.state == step)
        }
    }

    @Test func flightStatesCannotBeSkipped() {
        var machine = FatCatFlightStateMachine()
        for skipped in [FatCatFlightState.flying, .landing, .settling] {
            let accepted = machine.transition(to: skipped)
            #expect(!accepted)
        }
        machine.transition(to: .preparingToFly)
        for skipped in [FatCatFlightState.landing, .settling] {
            let accepted = machine.transition(to: skipped)
            #expect(!accepted)
        }
    }

    @Test func cancellingMidFlightSettlesInsteadOfTeleporting() {
        var machine = FatCatFlightStateMachine()
        machine.transition(to: .preparingToFly)
        machine.transition(to: .flying)
        machine.cancel()
        #expect(machine.state == .settling)
        let grounded = machine.transition(to: .grounded)
        #expect(grounded)
    }

    @Test func cancellingWhilePreparingReturnsStraightToGrounded() {
        var machine = FatCatFlightStateMachine()
        machine.transition(to: .preparingToFly)
        machine.cancel()
        #expect(machine.state == .grounded)
    }

    // MARK: - Safe anchors

    @Test func safeAnchorsPreferEdgesAndCornersAndAvoidTheCenter() {
        let anchors = FatCatMovementPlanner.anchorPositions(visibleFrame: visibleFrame, petSize: petSize, preferred: nil)
        #expect(anchors.count >= 6)
        let centerBand = visibleFrame.insetBy(dx: visibleFrame.width * 0.3, dy: visibleFrame.height * 0.3)
        for anchor in anchors {
            let petCenter = CGPoint(x: anchor.x + petSize.width / 2, y: anchor.y + petSize.height / 2)
            #expect(!centerBand.contains(petCenter))
        }
    }

    @Test func safeAnchorsKeepTheFullPetInsideTheVisibleFrame() {
        let anchors = FatCatMovementPlanner.anchorPositions(visibleFrame: visibleFrame, petSize: petSize, preferred: nil)
        for anchor in anchors {
            let bounds = CGRect(origin: anchor, size: petSize)
            #expect(visibleFrame.contains(bounds))
        }
    }

    @Test func dockAndMenuBarMarginsAreRespectedThroughTheVisibleFrame() {
        // The visible frame already excludes the menu bar (top) and Dock (bottom).
        let fullFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let anchors = FatCatMovementPlanner.anchorPositions(visibleFrame: visibleFrame, petSize: petSize, preferred: nil)
        for anchor in anchors {
            #expect(anchor.y >= visibleFrame.minY + FatCatMovementPlanner.edgeMargin)
            #expect(anchor.y + petSize.height <= visibleFrame.maxY - FatCatMovementPlanner.edgeMargin + 0.001)
            #expect(fullFrame.contains(CGRect(origin: anchor, size: petSize)))
        }
    }

    @Test func unsafePositionsClampToTheNearestSafeEdge() {
        let outside = CGPoint(x: visibleFrame.maxX + 300, y: visibleFrame.minY - 200)
        let safe = FatCatMovementPlanner.nearestSafePosition(for: outside, visibleFrame: visibleFrame, petSize: petSize)
        #expect(visibleFrame.contains(CGRect(origin: safe, size: petSize)))
    }

    @Test func userSelectedPreferredAnchorIsOffered() {
        let preferred = CGPoint(x: 100, y: 200)
        let anchors = FatCatMovementPlanner.anchorPositions(visibleFrame: visibleFrame, petSize: petSize, preferred: preferred)
        #expect(anchors.contains(preferred))
    }

    // MARK: - Flight plans

    @Test func seededPlansAreDeterministic() {
        var randomA = SeededRandomSource(seed: 99)
        var randomB = SeededRandomSource(seed: 99)
        var randomC = SeededRandomSource(seed: 7)
        let origin = CGPoint(x: 40, y: 100)
        let planA = FatCatMovementPlanner.planFlight(from: origin, reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &randomA)
        let planB = FatCatMovementPlanner.planFlight(from: origin, reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &randomB)
        let planC = FatCatMovementPlanner.planFlight(from: origin, reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &randomC)
        #expect(planA == planB)
        #expect(planA != planC)
    }

    @Test func plansFollowACurvedPathNotALinearSlide() {
        var random = SeededRandomSource(seed: 5)
        let origin = CGPoint(x: 40, y: 100)
        let plan = FatCatMovementPlanner.planFlight(from: origin, reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
        let midpoint = plan.position(at: 0.5)
        let chordMidpoint = CGPoint(x: (plan.origin.x + plan.destination.x) / 2, y: (plan.origin.y + plan.destination.y) / 2)
        let deviation = hypot(midpoint.x - chordMidpoint.x, midpoint.y - chordMidpoint.y)
        #expect(deviation > 12)
    }

    @Test func plansEaseInsteadOfConstantSpeed() {
        var random = SeededRandomSource(seed: 5)
        let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 40, y: 100), reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
        func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
        let earlySpeed = distance(plan.position(at: 0.05), plan.position(at: 0.0))
        let midSpeed = distance(plan.position(at: 0.525), plan.position(at: 0.475))
        #expect(midSpeed > earlySpeed * 2)
    }

    @Test func planTimingStaysInsideTheSpecifiedRanges() {
        for seed in UInt64(1)...20 {
            var random = SeededRandomSource(seed: seed)
            let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 40, y: 100), reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
            #expect(plan.duration >= 1.5)
            #expect(plan.duration <= 4.8)
            #expect(plan.anticipationDelay >= 0.12)
            #expect(plan.anticipationDelay <= 0.22)
            #expect(plan.settleDuration >= 0.18)
            #expect(plan.settleDuration <= 0.4)
        }
    }

    @Test func flightTiltStaysInsideTheGentleEnvelope() {
        var random = SeededRandomSource(seed: 3)
        let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 40, y: 100), reason: .playfulAfterInactivity, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
        var sawTilt = false
        for step in 0...40 {
            let tilt = plan.tilt(at: Double(step) / 40)
            #expect(abs(tilt) <= 10)
            if abs(tilt) > 1 { sawTilt = true }
        }
        #expect(sawTilt)
        #expect(abs(plan.tilt(at: 0)) < 0.5)
        #expect(abs(plan.tilt(at: 1)) < 0.5)
    }

    @Test func destinationsStayInsideTheVisibleFrame() {
        for seed in UInt64(1)...30 {
            var random = SeededRandomSource(seed: seed)
            let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 700, y: 400), reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
            #expect(visibleFrame.contains(CGRect(origin: plan.destination, size: petSize)))
        }
    }

    // MARK: - Policy

    private func openContext() -> FatCatFlightContext {
        var context = FatCatFlightContext()
        context.secondsSinceLastFlight = 400
        context.secondsSinceManualDrag = 900
        context.secondsSinceUserActivity = 120
        return context
    }

    @Test func quietIdlePeriodsAllowFlight() {
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: openContext()) == .allowed)
    }

    @Test func typingBlocksFlight() {
        var context = openContext()
        context.isTyping = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.typing))
    }

    @Test func chatFocusBlocksFlight() {
        var context = openContext()
        context.isChatFocused = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.chatFocused))
    }

    @Test func listeningBlocksFlight() {
        var context = openContext()
        context.isListening = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.listening))
    }

    @Test func speakingBlocksFlight() {
        var context = openContext()
        context.isSpeaking = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.speaking))
    }

    @Test func waitingForPermissionBlocksFlight() {
        var context = openContext()
        context.isWaitingForPermission = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.waitingForPermission))
    }

    @Test func meetingsBlockFlight() {
        var context = openContext()
        context.isMeetingActive = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.meeting))
    }

    @Test func fullscreenMediaBlocksFlight() {
        var context = openContext()
        context.isFullscreenMediaActive = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.fullscreen))
    }

    @Test func screenSharingBlocksFlight() {
        var context = openContext()
        context.isScreenSharing = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.screenSharing))
    }

    @Test func importantDialogsBlockFlight() {
        var context = openContext()
        context.hasImportantDialog = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.importantDialog))
    }

    @Test func pausedMovementBlocksFlight() {
        var context = openContext()
        context.isMovementPaused = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.movementPaused))
    }

    @Test func positionLockBlocksFlight() {
        var context = openContext()
        context.isPositionLocked = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.positionLocked))
    }

    @Test func sleepingBlocksFlight() {
        var context = openContext()
        context.isAsleep = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.sleeping))
    }

    @Test func reduceMotionBlocksFlight() {
        var context = openContext()
        context.isReduceMotionEnabled = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.reduceMotion))
    }

    @Test func delicateHermesActionsBlockFlight() {
        var context = openContext()
        context.isHermesDelicate = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.hermesDelicate))
    }

    @Test func draggingBlocksFlight() {
        var context = openContext()
        context.isDraggingPet = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.dragging))
    }

    @Test func autonomousFlightsWaitAtLeastThreeMinutesApart() {
        var context = openContext()
        context.secondsSinceLastFlight = 179
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.flightCooldown))
        context.secondsSinceLastFlight = 181
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .allowed)
    }

    @Test func explicitTestFlightBypassesOnlyIdleAndCooldownGates() {
        var context = openContext()
        context.secondsSinceLastFlight = 1
        context.secondsSinceManualDrag = 1
        context.secondsSinceUserActivity = 0
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.flightCooldown))
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context, bypassIdleAndCooldown: true) == .allowed)
        context.isTyping = true
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context, bypassIdleAndCooldown: true) == .blocked(.typing))
    }

    @Test func playfulAutonomousFlightsUseTheNinetySecondCooldown() {
        var context = openContext()
        context.secondsSinceLastFlight = 89
        #expect(FatCatFlightPolicy.evaluate(reason: .playfulAfterInactivity, context: context) == .blocked(.flightCooldown))
        context.secondsSinceLastFlight = 91
        #expect(FatCatFlightPolicy.evaluate(reason: .playfulAfterInactivity, context: context) == .allowed)
    }

    @Test func manualDraggingStartsATenMinuteCooldown() {
        var context = openContext()
        context.secondsSinceManualDrag = 599
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.dragCooldown))
        context.secondsSinceManualDrag = 601
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .allowed)
    }

    @Test func recentUserActivityBlocksIdleRepositioning() {
        var context = openContext()
        context.secondsSinceUserActivity = 10
        #expect(FatCatFlightPolicy.evaluate(reason: .idleReposition, context: context) == .blocked(.userActive))
    }

    @Test func salientEventsMapToExplicitPresenceCues() {
        #expect(FatCatFlightEventPolicy.cue(for: .userClickedAvatar) == FatCatEventCue(reaction: .perk, flightReason: nil))
        #expect(FatCatFlightEventPolicy.cue(for: .userClosedChat) == FatCatEventCue(reaction: .attention, flightReason: .returnAfterChatClosed))
        #expect(FatCatFlightEventPolicy.cue(for: .hermes(.thought)) == FatCatEventCue(reaction: .attention, flightReason: nil))
        #expect(FatCatFlightEventPolicy.cue(for: .hermes(.toolCall(name: "search"))) == FatCatEventCue(reaction: .perk, flightReason: .stayNearActiveWork))
        #expect(FatCatFlightEventPolicy.cue(for: .hermes(.permissionRequested)) == FatCatEventCue(reaction: .perk, flightReason: .makeRoomForNotification))
        #expect(FatCatFlightEventPolicy.cue(for: .hermes(.verifiedSuccess)) == FatCatEventCue(reaction: .celebrate, flightReason: .verifiedSuccess))
        #expect(FatCatFlightEventPolicy.cue(for: .hermes(.turnFailed)) == FatCatEventCue(reaction: .recoil, flightReason: nil))
        #expect(FatCatFlightEventPolicy.cue(for: .observationChanged(app: "Xcode", window: nil, redacted: false)) == FatCatEventCue(reaction: .attention, flightReason: nil))
        #expect(FatCatFlightEventPolicy.cue(for: .tick) == nil)
    }

    @Test func pendingFlightCueKeepsOnlyTheMostRecentSalientReason() {
        var queue = FatCatFlightCueQueue()
        queue.enqueue(.stayNearActiveWork)
        queue.enqueue(.verifiedSuccess)
        #expect(queue.take() == .verifiedSuccess)
        #expect(queue.take() == nil)
    }

    @Test func onlyCalmLifeStatesAllowAutonomousFlight() {
        #expect(FatCatFlightPolicy.allowsAutonomousFlight(for: .idle))
        #expect(FatCatFlightPolicy.allowsAutonomousFlight(for: .celebrating))
        for state in FatCatState.allCases where state != .idle && state != .celebrating {
            #expect(!FatCatFlightPolicy.allowsAutonomousFlight(for: state))
        }
    }

    // MARK: - Window animator

    @Test func animatorMovesAlongThePlanAndFinishesAtTheDestination() {
        var random = SeededRandomSource(seed: 11)
        let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 40, y: 100), reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
        var animator = FatCatWindowAnimator()
        let start = Date(timeIntervalSince1970: 1000)
        animator.start(plan, at: start)
        let early = animator.frame(at: start.addingTimeInterval(plan.duration * 0.4))
        #expect(early != nil)
        #expect(early?.isFinished == false)
        let final = animator.frame(at: start.addingTimeInterval(plan.duration + 0.01))
        #expect(final?.isFinished == true)
        #expect(final?.position == plan.destination)
    }

    @Test func animatorIsCancellable() {
        var random = SeededRandomSource(seed: 11)
        let plan = FatCatMovementPlanner.planFlight(from: CGPoint(x: 40, y: 100), reason: .idleReposition, visibleFrame: visibleFrame, petSize: petSize, preferred: nil, random: &random)
        var animator = FatCatWindowAnimator()
        let start = Date(timeIntervalSince1970: 1000)
        animator.start(plan, at: start)
        animator.cancel()
        #expect(animator.frame(at: start.addingTimeInterval(0.5)) == nil)
        #expect(animator.activePlan == nil)
    }

    // MARK: - Flight cue bridge

    @Test func flightCueJavaScriptIsWellFormedAndEscaped() {
        let script = FatCatAvatarBridge.setFlightJavaScript(phase: "flying", tiltDegrees: -7.5, durationMs: 2600)
        #expect(script == "window.fatCatAvatar?.setFlight(\"flying\", -7.5, 2600.0);")
        #expect(FatCatAvatarBridge.setFlightJavaScript(phase: "flying", tiltDegrees: .nan, durationMs: 0) == nil)
    }

    // MARK: - Flight log

    @Test func everyFlightRecordsItsReasonLocally() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fatcat-flight-log-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let log = FatCatFlightLog(fileURL: url)
        let entry = FatCatFlightLogEntry(reason: .playfulAfterInactivity, date: Date(timeIntervalSince1970: 500), from: CGPoint(x: 1, y: 2), to: CGPoint(x: 3, y: 4))
        try log.append(entry)
        let reloaded = FatCatFlightLog(fileURL: url)
        #expect(reloaded.entries == [entry])
    }
}
