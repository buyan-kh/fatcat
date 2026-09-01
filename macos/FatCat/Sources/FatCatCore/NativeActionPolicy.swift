import Foundation

public enum NativeAction: Equatable, Sendable {
    case readScreenContext
    case inspectAccessibilityTree
    case openApplication(bundleIdentifier: String)
    case openFile(path: String)
    case highlightElement(identifier: String)
    case typeText(String)
    case clickElement(identifier: String)
    case moveWindow(identifier: String, x: Double, y: Double)
    case runProcess(executable: String, arguments: [String])
    case sendAppleEvent(target: String, event: String)
}

public enum NativeActionRisk: String, Equatable, Sendable {
    case low
    case medium
    case high
}

public enum NativeActionApproval: Equatable, Sendable {
    case notRequired
    case pending
    case approved
    case denied
}

public enum NativeActionValidation: Equatable, Sendable {
    case ready
    case needsApproval
    case rejected
}

public struct NativeActionProposal: Equatable, Sendable {
    public let id: String
    public let action: NativeAction
    public let reason: String

    public init(id: String, action: NativeAction, reason: String) {
        self.id = id
        self.action = action
        self.reason = reason
    }
}

public enum NativeActionPolicy {
    public static func risk(for action: NativeAction) -> NativeActionRisk {
        switch action {
        case .readScreenContext, .inspectAccessibilityTree, .openApplication, .openFile, .highlightElement, .moveWindow:
            return .low
        case .typeText, .clickElement:
            return .medium
        case .runProcess, .sendAppleEvent:
            return .high
        }
    }

    public static func requiresApproval(for action: NativeAction) -> Bool {
        risk(for: action) != .low
    }

    public static func validate(_ proposal: NativeActionProposal, approval: NativeActionApproval) -> NativeActionValidation {
        guard requiresApproval(for: proposal.action) else { return .ready }
        switch approval {
        case .approved: return .ready
        case .denied: return .rejected
        case .pending, .notRequired: return .needsApproval
        }
    }
}
