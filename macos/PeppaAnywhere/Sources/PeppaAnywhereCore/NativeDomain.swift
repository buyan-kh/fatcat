import Foundation

public enum PeppaState: String, CaseIterable, Equatable, Sendable {
    case idle
    case listening
    case understanding
    case planning
    case askingPermission
    case acting
    case verifying
    case celebrating
    case recovering
    case suspicious
    case sleeping

    public var animationKey: String {
        switch self {
        case .idle: return "idle"
        case .listening, .askingPermission: return "listening"
        case .understanding, .planning, .verifying: return "thinking"
        case .acting: return "working"
        case .celebrating: return "celebrate"
        case .recovering, .suspicious: return "suspicious"
        case .sleeping: return "sleeping"
        }
    }

    public var label: String {
        switch self {
        case .idle: return "Quietly present"
        case .listening: return "Listening"
        case .understanding: return "Understanding"
        case .planning: return "Planning"
        case .askingPermission: return "Asking permission"
        case .acting: return "Acting"
        case .verifying: return "Verifying"
        case .celebrating: return "Verified success"
        case .recovering: return "Recovering"
        case .suspicious: return "Suspicious"
        case .sleeping: return "Sleeping"
        }
    }
}

public struct PeppaStateTransition: Equatable, Sendable {
    public let accepted: Bool
    public let state: PeppaState
    public let from: PeppaState
    public let to: PeppaState
    public let reason: String

    public init(accepted: Bool, state: PeppaState, from: PeppaState, to: PeppaState, reason: String) {
        self.accepted = accepted
        self.state = state
        self.from = from
        self.to = to
        self.reason = reason
    }
}

public struct PeppaStateMachine: Equatable, Sendable {
    public private(set) var state: PeppaState

    public init(state: PeppaState = .idle) {
        self.state = state
    }

    @discardableResult
    public mutating func transition(to next: PeppaState, verified: Bool = false, reason: String = "") -> PeppaStateTransition {
        let accepted = Self.canTransition(from: state, to: next, verified: verified)
        let previous = state
        if accepted { state = next }
        return PeppaStateTransition(
            accepted: accepted,
            state: state,
            from: previous,
            to: next,
            reason: reason
        )
    }

    private static func canTransition(from: PeppaState, to: PeppaState, verified: Bool) -> Bool {
        if from == to { return true }
        if to == .celebrating { return from == .verifying && verified }
        switch from {
        case .idle: return [.listening, .understanding, .planning, .verifying, .askingPermission, .sleeping].contains(to)
        case .listening: return [.understanding, .idle, .sleeping, .recovering].contains(to)
        case .understanding: return [.planning, .askingPermission, .idle, .recovering, .suspicious].contains(to)
        case .planning: return [.askingPermission, .acting, .idle, .recovering, .suspicious].contains(to)
        case .askingPermission: return [.acting, .idle, .recovering, .listening].contains(to)
        case .acting: return [.verifying, .recovering, .suspicious].contains(to)
        case .verifying: return [.recovering, .idle, .suspicious].contains(to)
        case .celebrating: return [.idle, .sleeping].contains(to)
        case .recovering: return [.planning, .askingPermission, .idle, .sleeping, .suspicious].contains(to)
        case .suspicious: return [.planning, .askingPermission, .idle, .sleeping, .recovering].contains(to)
        case .sleeping: return [.idle, .listening].contains(to)
        }
    }
}

public struct PanelBounds: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PetPosition: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func clamped(to bounds: PanelBounds) -> PetPosition {
        PetPosition(x: min(max(x, 0), max(bounds.width, 0)), y: min(max(y, 0), max(bounds.height, 0)))
    }

    public static func dragging(origin: PetPosition, startMouse: PetPosition, mouse: PetPosition) -> PetPosition {
        PetPosition(x: origin.x + mouse.x - startMouse.x, y: origin.y + mouse.y - startMouse.y)
    }
}

public final class PetPositionStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "peppa.pet.position"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(_ position: PetPosition) {
        defaults.set(try? JSONEncoder().encode(position), forKey: key)
    }

    public func load() -> PetPosition? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PetPosition.self, from: data)
    }
}

public enum PetPanelMode: Equatable, Sendable {
    case petOnly
    case chat

    public var width: Double {
        switch self {
        case .petOnly: return 220
        case .chat: return 550
        }
    }

    public var height: Double {
        switch self {
        case .petOnly: return 220
        case .chat: return 330
        }
    }
}

public enum PetMenuCommand: String, CaseIterable, Equatable, Sendable {
    case pauseObservation
    case settings
    case memory
    case actionHistory
    case quit

    public var title: String {
        switch self {
        case .pauseObservation: return "Pause Observation"
        case .settings: return "Settings"
        case .memory: return "Memory"
        case .actionHistory: return "Action History"
        case .quit: return "Quit FatCat"
        }
    }
}

public struct ActiveApplication: Equatable {
    public let pid: Int32
    public let name: String

    public init(pid: Int32, name: String) {
        self.pid = pid
        self.name = name
    }
}

public struct WindowCandidate: Equatable {
    public let ownerPID: Int32
    public let ownerName: String
    public let layer: Int
    public let onScreen: Bool
    public let title: String
    public let order: Int

    public init(ownerPID: Int32, ownerName: String, layer: Int, onScreen: Bool, title: String, order: Int) {
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.layer = layer
        self.onScreen = onScreen
        self.title = title
        self.order = order
    }
}

public enum WindowSelector {
    public static func frontmostWindow(_ candidates: [WindowCandidate], application: ActiveApplication) -> WindowCandidate? {
        candidates
            .filter { $0.onScreen && ($0.ownerPID == application.pid || $0.ownerName.caseInsensitiveCompare(application.name) == .orderedSame) }
            .sorted { lhs, rhs in lhs.layer == rhs.layer ? lhs.order < rhs.order : lhs.layer > rhs.layer }
            .first(where: { !$0.title.isEmpty })
    }

    public static func frontmostWindowName(_ candidates: [WindowCandidate], application: ActiveApplication) -> String? {
        frontmostWindow(candidates, application: application)?.title
    }
}

public struct PrivacyPolicy: Equatable {
    public let privateApps: Set<String>

    public init(privateApps: Set<String>) {
        self.privateApps = Set(privateApps.map { $0.lowercased() })
    }

    public func redacts(applicationName: String) -> Bool {
        privateApps.contains(applicationName.lowercased())
    }
}

public struct PrivacyPayload: Equatable, Codable {
    public let redacted: Bool
    public let reason: String
    public let rawScreenshotRetained: Bool

    public init(redacted: Bool, reason: String, rawScreenshotRetained: Bool = false) {
        self.redacted = redacted
        self.reason = reason
        self.rawScreenshotRetained = rawScreenshotRetained
    }
}

public struct ObservationPayload: Equatable, Codable {
    public let activeApp: String
    public let visibleWindow: String
    public let task: String
    public let detectedEvent: String
    public let repeatedActivity: String
    public let likelyUserState: String
    public let confidence: Double
    public let timestamp: String
    public let privacy: PrivacyPayload
    public let visibleText: [String]

    public init(activeApp: String, visibleWindow: String, task: String, detectedEvent: String, repeatedActivity: String, likelyUserState: String, confidence: Double, timestamp: String, privacy: PrivacyPayload, visibleText: [String] = []) {
        self.activeApp = activeApp
        self.visibleWindow = visibleWindow
        self.task = task
        self.detectedEvent = detectedEvent
        self.repeatedActivity = repeatedActivity
        self.likelyUserState = likelyUserState
        self.confidence = confidence
        self.timestamp = timestamp
        self.privacy = privacy
        self.visibleText = visibleText
    }
}

public enum ObservationFactory {
    public static func make(application: ActiveApplication, window: WindowCandidate?, policy: PrivacyPolicy, timestamp: String) -> ObservationPayload {
        let redacted = policy.redacts(applicationName: application.name)
        return ObservationPayload(
            activeApp: redacted ? "[private app]" : application.name,
            visibleWindow: redacted ? "[redacted]" : (window?.title.isEmpty == false ? window!.title : "Visible window"),
            task: redacted ? "[redacted]" : "Local screen context",
            detectedEvent: redacted ? "private context" : "none",
            repeatedActivity: "not retained by native host",
            likelyUserState: "unknown",
            confidence: redacted ? 0.99 : 0.76,
            timestamp: timestamp,
            privacy: PrivacyPayload(
                redacted: redacted,
                reason: redacted ? "Active app is on the private-app exclusion list." : "Structured metadata only; raw screenshot retention is disabled."
            ),
            visibleText: []
        )
    }
}

public struct CaptureState: Equatable {
    public private(set) var isAuthorized = false
    public private(set) var isPaused = false
    public private(set) var isCapturing = false

    public init() {}
    public mutating func authorize() { isAuthorized = true }
    public mutating func started() { if isAuthorized && !isPaused { isCapturing = true } }
    public mutating func stopped() { isCapturing = false }
    public mutating func pause() { isPaused = true; isCapturing = false }
    public mutating func resume() { isPaused = false }
}
