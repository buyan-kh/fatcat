import Foundation

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
            )
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
