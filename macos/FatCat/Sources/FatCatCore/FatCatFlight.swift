import CoreGraphics
import Foundation

// MARK: - Flight states

public enum FatCatFlightState: String, CaseIterable, Equatable, Sendable {
    case grounded
    case preparingToFly
    case flying
    case landing
    case settling
}

public struct FatCatFlightStateMachine: Equatable, Sendable {
    public private(set) var state: FatCatFlightState = .grounded

    public init() {}

    @discardableResult
    public mutating func transition(to next: FatCatFlightState) -> Bool {
        guard Self.allows(from: state, to: next) else { return false }
        state = next
        return true
    }

    /// Cancelling never teleports: mid-air cancellation settles in place,
    /// while a cancelled anticipation simply returns to grounded.
    public mutating func cancel() {
        switch state {
        case .flying, .landing:
            state = .settling
        case .preparingToFly:
            state = .grounded
        case .grounded, .settling:
            break
        }
    }

    private static func allows(from: FatCatFlightState, to: FatCatFlightState) -> Bool {
        switch from {
        case .grounded: return to == .preparingToFly
        case .preparingToFly: return to == .flying || to == .grounded
        case .flying: return to == .landing || to == .settling
        case .landing: return to == .settling
        case .settling: return to == .grounded
        }
    }
}

// MARK: - Seeded randomness

/// SplitMix64. Deterministic movement for tests; no uncontrolled randomness.
public struct SeededRandomSource: Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    public mutating func nextUnitDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    public mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnitDouble() * (range.upperBound - range.lowerBound)
    }

    public mutating func pickIndex(count: Int) -> Int {
        count <= 1 ? 0 : Int(next() % UInt64(count))
    }
}

// MARK: - Flight reasons and policy

public enum FatCatFlightReason: String, CaseIterable, Codable, Equatable, Sendable {
    case idleReposition
    case returnToPreferredAnchor
    case avoidOccupiedRegion
    case makeRoomForNotification
    case playfulAfterInactivity
    case verifiedSuccess
    case returnAfterChatClosed
    case stayNearActiveWork
}

public enum FatCatReaction: String, Equatable, Sendable {
    case attention
    case perk
    case recoil
    case celebrate
}

public struct FatCatEventCue: Equatable, Sendable {
    public let reaction: FatCatReaction
    public let flightReason: FatCatFlightReason?

    public init(reaction: FatCatReaction, flightReason: FatCatFlightReason?) {
        self.reaction = reaction
        self.flightReason = flightReason
    }
}

public enum FatCatFlightEventPolicy {
    public static func cue(for event: FatCatLifeEvent) -> FatCatEventCue? {
        switch event {
        case .userClickedAvatar:
            return FatCatEventCue(reaction: .perk, flightReason: nil)
        case .userClosedChat:
            return FatCatEventCue(reaction: .attention, flightReason: .returnAfterChatClosed)
        case .observationChanged:
            return FatCatEventCue(reaction: .attention, flightReason: nil)
        case .hermes(.streamDelta), .hermes(.thought), .hermes(.plan):
            return FatCatEventCue(reaction: .attention, flightReason: nil)
        case .hermes(.toolCall):
            return FatCatEventCue(reaction: .perk, flightReason: .stayNearActiveWork)
        case .hermes(.permissionRequested):
            return FatCatEventCue(reaction: .perk, flightReason: .makeRoomForNotification)
        case .hermes(.verifiedSuccess):
            return FatCatEventCue(reaction: .celebrate, flightReason: .verifiedSuccess)
        case .hermes(.actionFailed), .hermes(.verifiedFailure), .hermes(.turnFailed), .hermes(.disconnected):
            return FatCatEventCue(reaction: .recoil, flightReason: nil)
        case .tick, .userOpenedChat, .userSentMessage, .userStoppedGeneration, .userStartedNewChat,
             .observationPaused, .observationResumed, .hermes(.actionSucceeded), .hermes(.turnCompleted):
            return nil
        }
    }
}

public struct FatCatFlightCueQueue: Equatable, Sendable {
    private var pending: FatCatFlightReason?

    public init() {}

    public var pendingReason: FatCatFlightReason? { pending }

    public mutating func enqueue(_ reason: FatCatFlightReason) {
        pending = reason
    }

    public mutating func take() -> FatCatFlightReason? {
        defer { pending = nil }
        return pending
    }
}

public struct FatCatFlightContext: Equatable, Sendable {
    public var isTyping = false
    public var isDraggingPet = false
    public var isChatFocused = false
    public var isSpeaking = false
    public var isListening = false
    public var isWaitingForPermission = false
    public var isMeetingActive = false
    public var isFullscreenMediaActive = false
    public var isScreenSharing = false
    public var hasImportantDialog = false
    public var isMovementPaused = false
    public var isPositionLocked = false
    public var isAsleep = false
    public var isReduceMotionEnabled = false
    public var isHermesDelicate = false
    public var secondsSinceLastFlight: TimeInterval = .infinity
    public var secondsSinceManualDrag: TimeInterval = .infinity
    public var secondsSinceUserActivity: TimeInterval = 0

    public init() {}
}

public enum FatCatFlightBlockReason: String, Equatable, Sendable {
    case typing
    case dragging
    case chatFocused
    case speaking
    case listening
    case waitingForPermission
    case meeting
    case fullscreen
    case screenSharing
    case importantDialog
    case movementPaused
    case positionLocked
    case sleeping
    case reduceMotion
    case hermesDelicate
    case flightCooldown
    case dragCooldown
    case userActive
}

public enum FatCatFlightDecision: Equatable, Sendable {
    case allowed
    case blocked(FatCatFlightBlockReason)
}

public enum FatCatFlightPolicy {
    public static let minimumSecondsBetweenFlights: TimeInterval = 180
    public static let playfulMinimumSecondsBetweenFlights: TimeInterval = 90
    public static let manualDragCooldown: TimeInterval = 600
    public static let minimumIdleSeconds: TimeInterval = 45

    /// Reasons that exist purely to keep FatCat pleasant during idle time.
    /// These additionally require a quiet stretch without user activity.
    private static let idleOnlyReasons: Set<FatCatFlightReason> = [
        .idleReposition, .playfulAfterInactivity, .returnToPreferredAnchor,
    ]

    public static func evaluate(
        reason: FatCatFlightReason,
        context: FatCatFlightContext,
        bypassIdleAndCooldown: Bool = false
    ) -> FatCatFlightDecision {
        if context.isDraggingPet { return .blocked(.dragging) }
        if context.isPositionLocked { return .blocked(.positionLocked) }
        if context.isMovementPaused { return .blocked(.movementPaused) }
        if context.isReduceMotionEnabled { return .blocked(.reduceMotion) }
        if context.isTyping { return .blocked(.typing) }
        if context.isChatFocused { return .blocked(.chatFocused) }
        if context.isSpeaking { return .blocked(.speaking) }
        if context.isListening { return .blocked(.listening) }
        if context.isWaitingForPermission { return .blocked(.waitingForPermission) }
        if context.isMeetingActive { return .blocked(.meeting) }
        if context.isFullscreenMediaActive { return .blocked(.fullscreen) }
        if context.isScreenSharing { return .blocked(.screenSharing) }
        if context.hasImportantDialog { return .blocked(.importantDialog) }
        if context.isAsleep { return .blocked(.sleeping) }
        if context.isHermesDelicate { return .blocked(.hermesDelicate) }
        let cooldown = reason == .playfulAfterInactivity
            ? playfulMinimumSecondsBetweenFlights
            : minimumSecondsBetweenFlights
        if !bypassIdleAndCooldown, context.secondsSinceLastFlight < cooldown { return .blocked(.flightCooldown) }
        if !bypassIdleAndCooldown, context.secondsSinceManualDrag < manualDragCooldown { return .blocked(.dragCooldown) }
        if !bypassIdleAndCooldown, idleOnlyReasons.contains(reason), context.secondsSinceUserActivity < minimumIdleSeconds {
            return .blocked(.userActive)
        }
        return .allowed
    }

    public static func allowsAutonomousFlight(for state: FatCatState) -> Bool {
        state == .idle || state == .celebrating
    }
}

// MARK: - Movement planning

public struct FatCatFlightPlan: Equatable, Sendable {
    public var origin: CGPoint
    public var destination: CGPoint
    public var control1: CGPoint
    public var control2: CGPoint
    public var duration: TimeInterval
    public var anticipationDelay: TimeInterval
    public var settleDuration: TimeInterval
    public var maxTiltDegrees: Double
    public var reason: FatCatFlightReason

    public func position(at fraction: Double) -> CGPoint {
        let clamped = min(1, max(0, fraction))
        let t = clamped * clamped * (3 - 2 * clamped)
        let inverse = 1 - t
        let x = inverse * inverse * inverse * origin.x
            + 3 * inverse * inverse * t * control1.x
            + 3 * inverse * t * t * control2.x
            + t * t * t * destination.x
        let y = inverse * inverse * inverse * origin.y
            + 3 * inverse * inverse * t * control1.y
            + 3 * inverse * t * t * control2.y
            + t * t * t * destination.y
        return CGPoint(x: x, y: y)
    }

    public func tilt(at fraction: Double) -> Double {
        let clamped = min(1, max(0, fraction))
        let direction: Double = destination.x >= origin.x ? 1 : -1
        return maxTiltDegrees * direction * sin(clamped * .pi)
    }
}

public enum FatCatMovementPlanner {
    public static let edgeMargin: Double = 24

    public static func anchorPositions(visibleFrame: CGRect, petSize: CGSize, preferred: CGPoint?) -> [CGPoint] {
        let minX = visibleFrame.minX + edgeMargin
        let maxX = visibleFrame.maxX - edgeMargin - petSize.width
        let minY = visibleFrame.minY + edgeMargin
        let maxY = visibleFrame.maxY - edgeMargin - petSize.height
        let midY = visibleFrame.midY - petSize.height / 2
        var anchors = [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY),
            CGPoint(x: minX, y: midY),
            CGPoint(x: maxX, y: midY),
        ]
        if let preferred {
            anchors.append(nearestSafePosition(for: preferred, visibleFrame: visibleFrame, petSize: petSize))
        }
        return anchors
    }

    public static func nearestSafePosition(for origin: CGPoint, visibleFrame: CGRect, petSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visibleFrame.minX + edgeMargin), visibleFrame.maxX - edgeMargin - petSize.width),
            y: min(max(origin.y, visibleFrame.minY + edgeMargin), visibleFrame.maxY - edgeMargin - petSize.height)
        )
    }

    public static func planFlight(
        from origin: CGPoint,
        reason: FatCatFlightReason,
        visibleFrame: CGRect,
        petSize: CGSize,
        preferred: CGPoint?,
        random: inout SeededRandomSource
    ) -> FatCatFlightPlan {
        let anchors = anchorPositions(visibleFrame: visibleFrame, petSize: petSize, preferred: preferred)
            .filter { hypot($0.x - origin.x, $0.y - origin.y) > 80 }
        let destination: CGPoint
        if reason == .returnToPreferredAnchor, let preferred {
            destination = nearestSafePosition(for: preferred, visibleFrame: visibleFrame, petSize: petSize)
        } else if anchors.isEmpty {
            destination = nearestSafePosition(for: origin, visibleFrame: visibleFrame, petSize: petSize)
        } else {
            destination = anchors[random.pickIndex(count: anchors.count)]
        }

        let distance = hypot(destination.x - origin.x, destination.y - origin.y)
        let durationRange: ClosedRange<Double>
        if reason == .playfulAfterInactivity {
            durationRange = 3.0...4.8
        } else if distance < 300 {
            durationRange = 1.5...2.2
        } else {
            durationRange = 2.2...3.8
        }

        let chord = CGPoint(x: destination.x - origin.x, y: destination.y - origin.y)
        let length = max(1, distance)
        let normal = CGPoint(x: -chord.y / length, y: chord.x / length)
        let arc = max(40, distance * 0.22) * (random.nextUnitDouble() < 0.5 ? 1.0 : -1.0)
        let rawControl1 = CGPoint(x: origin.x + chord.x * 0.3 + normal.x * arc * 0.8, y: origin.y + chord.y * 0.3 + normal.y * arc * 0.8)
        let rawControl2 = CGPoint(x: origin.x + chord.x * 0.7 + normal.x * arc, y: origin.y + chord.y * 0.7 + normal.y * arc)

        return FatCatFlightPlan(
            origin: origin,
            destination: destination,
            control1: nearestSafePosition(for: rawControl1, visibleFrame: visibleFrame, petSize: petSize),
            control2: nearestSafePosition(for: rawControl2, visibleFrame: visibleFrame, petSize: petSize),
            duration: random.nextDouble(in: durationRange),
            anticipationDelay: random.nextDouble(in: 0.12...0.22),
            settleDuration: random.nextDouble(in: 0.18...0.4),
            maxTiltDegrees: random.nextDouble(in: 6...10),
            reason: reason
        )
    }
}

// MARK: - Window animation

public struct FatCatWindowFrame: Equatable, Sendable {
    public var position: CGPoint
    public var tiltDegrees: Double
    public var isFinished: Bool
}

public struct FatCatWindowAnimator: Equatable, Sendable {
    public private(set) var activePlan: FatCatFlightPlan?
    private var startedAt: Date?

    public init() {}

    public mutating func start(_ plan: FatCatFlightPlan, at date: Date) {
        activePlan = plan
        startedAt = date
    }

    public mutating func cancel() {
        activePlan = nil
        startedAt = nil
    }

    public func frame(at date: Date) -> FatCatWindowFrame? {
        guard let plan = activePlan, let startedAt else { return nil }
        let fraction = min(1, max(0, date.timeIntervalSince(startedAt) / plan.duration))
        return FatCatWindowFrame(
            position: plan.position(at: fraction),
            tiltDegrees: plan.tilt(at: fraction),
            isFinished: fraction >= 1
        )
    }
}

// MARK: - Flight log

public struct FatCatFlightLogEntry: Codable, Equatable, Sendable {
    public var reason: FatCatFlightReason
    public var date: Date
    public var from: CGPoint
    public var to: CGPoint

    public init(reason: FatCatFlightReason, date: Date, from: CGPoint, to: CGPoint) {
        self.reason = reason
        self.date = date
        self.from = from
        self.to = to
    }
}

public final class FatCatFlightLog {
    private let fileURL: URL
    public private(set) var entries: [FatCatFlightLogEntry]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([FatCatFlightLogEntry].self, from: data) {
            entries = stored
        } else {
            entries = []
        }
    }

    public func append(_ entry: FatCatFlightLogEntry) throws {
        entries.append(entry)
        try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }
}
