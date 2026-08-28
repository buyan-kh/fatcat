import Foundation

public enum FatCatLifeTiming {
    public static let curiosityHold: TimeInterval = 20
    public static let tiredAfter: TimeInterval = 180
    public static let sleepAfter: TimeInterval = 480
    public static let celebrateHold: TimeInterval = 2
}

public enum FatCatMood: String, Equatable, Sendable {
    case calm
    case curious
    case pleased
    case uneasy
    case tired
}

public enum FatCatAttention: Equatable, Sendable {
    case none
    case user
    case screen(app: String)
}

public enum FatCatWork: String, Equatable, Sendable {
    case none
    case listening
    case thinking
    case acting
    case asking
    case verifying
    case celebrating
}

public struct FatCatTask: Equatable, Sendable {
    public var conversationID: String

    public init(conversationID: String) {
        self.conversationID = conversationID
    }
}

public enum FatCatHermesCause: Equatable, Sendable {
    case streamDelta
    case thought
    case plan
    case toolCall(name: String)
    case permissionRequested
    case actionSucceeded
    case actionFailed
    case verifiedSuccess
    case verifiedFailure
    case turnCompleted
    case turnFailed
    case disconnected

    public static func cause(forAgentState state: PeppaAgentState) -> FatCatHermesCause? {
        switch state {
        case .sending, .thinking, .streaming: return .thought
        case .working: return .toolCall(name: "")
        case .verifying: return .actionSucceeded
        case .waitingForApproval: return .permissionRequested
        case .completed: return .turnCompleted
        case .failed, .stopping, .error: return .turnFailed
        case .disconnected: return .disconnected
        case .idle, .listening, .connecting, .ready: return nil
        }
    }
}

public enum FatCatLifeEvent: Equatable, Sendable {
    case tick
    case userClickedAvatar
    case userOpenedChat
    case userClosedChat
    case userSentMessage(requestID: String, conversationID: String)
    case userStoppedGeneration
    case userStartedNewChat
    case observationChanged(app: String, window: String?, redacted: Bool)
    case observationPaused
    case observationResumed
    case hermes(FatCatHermesCause)
}

public struct FatCatLife: Equatable, Sendable {
    public var mood: FatCatMood
    public var attention: FatCatAttention
    public var work: FatCatWork
    public var task: FatCatTask?
    public var observationPaused: Bool
    public var asleep: Bool
    public var lastCause: FatCatLifeEvent?
    public var lastSalientAt: Date

    public init(now: Date = Date()) {
        mood = .calm
        attention = .none
        work = .none
        task = nil
        observationPaused = false
        asleep = false
        lastCause = nil
        lastSalientAt = now
    }

    public var animationKey: String {
        if observationPaused || asleep { return "sleeping" }
        switch work {
        case .listening, .asking: return "listening"
        case .thinking, .verifying: return "thinking"
        case .acting: return "working"
        case .celebrating: return "celebrate"
        case .none: break
        }
        switch mood {
        case .uneasy: return "suspicious"
        case .curious: return "curious"
        case .tired: return "drowsy"
        case .pleased, .calm: return "idle"
        }
    }

    public var peppaState: PeppaState {
        if observationPaused || asleep { return .sleeping }
        switch work {
        case .listening: return .listening
        case .thinking: return .understanding
        case .acting: return .acting
        case .asking: return .askingPermission
        case .verifying: return .verifying
        case .celebrating: return .celebrating
        case .none: break
        }
        switch mood {
        case .uneasy: return .recovering
        default: return .idle
        }
    }

    public mutating func handle(_ event: FatCatLifeEvent, at now: Date) {
        lastCause = event
        switch event {
        case .tick:
            applyTick(at: now)
        case .userClickedAvatar, .userOpenedChat:
            wake(at: now)
            attention = .user
        case .userClosedChat:
            if case .user = attention { attention = .none }
            lastSalientAt = now
        case .userSentMessage(_, let conversationID):
            wake(at: now)
            work = .listening
            attention = .user
            task = FatCatTask(conversationID: conversationID)
            mood = .calm
        case .userStoppedGeneration:
            wake(at: now)
            work = .none
            mood = .uneasy
        case .userStartedNewChat:
            wake(at: now)
            work = .none
            task = nil
            attention = .user
            mood = .calm
        case .observationChanged(let app, _, let redacted):
            lastSalientAt = now
            guard work == .none, !redacted else { return }
            wake(at: now)
            mood = .curious
            attention = .screen(app: app)
        case .observationPaused:
            observationPaused = true
            lastSalientAt = now
        case .observationResumed:
            observationPaused = false
            asleep = false
            lastSalientAt = now
        case .hermes(let cause):
            applyHermes(cause, at: now)
        }
    }

    private mutating func applyTick(at now: Date) {
        if work == .celebrating, now.timeIntervalSince(lastSalientAt) >= FatCatLifeTiming.celebrateHold {
            work = .none
            mood = .pleased
            return
        }
        guard work == .none, !observationPaused else { return }
        let elapsed = now.timeIntervalSince(lastSalientAt)
        if elapsed >= FatCatLifeTiming.sleepAfter {
            asleep = true
            mood = .tired
        } else if elapsed >= FatCatLifeTiming.tiredAfter {
            asleep = false
            mood = .tired
            attention = .none
        } else if mood == .curious, elapsed >= FatCatLifeTiming.curiosityHold {
            mood = .calm
            attention = .none
        }
    }

    private mutating func applyHermes(_ cause: FatCatHermesCause, at now: Date) {
        switch cause {
        case .streamDelta, .thought, .plan:
            wake(at: now)
            work = .thinking
        case .toolCall:
            wake(at: now)
            work = .acting
        case .permissionRequested:
            wake(at: now)
            work = .asking
        case .actionSucceeded:
            wake(at: now)
            work = .verifying
        case .actionFailed, .verifiedFailure, .turnFailed:
            wake(at: now)
            work = .none
            mood = .uneasy
        case .verifiedSuccess:
            guard work == .verifying else { return }
            wake(at: now)
            work = .celebrating
            mood = .pleased
        case .turnCompleted:
            wake(at: now)
            work = .none
            if mood == .curious || mood == .tired { mood = .calm }
        case .disconnected:
            wake(at: now)
            work = .none
            mood = .uneasy
        }
    }

    private mutating func wake(at now: Date) {
        asleep = false
        lastSalientAt = now
        if mood == .tired { mood = .calm }
    }
}
