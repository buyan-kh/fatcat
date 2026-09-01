import CoreGraphics
import Foundation

public struct FatCatAttentionTarget: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case click
        case chatSurface
        case permissionPrompt
        case dialog
        case screenRegion
        case attention
    }

    public var kind: Kind
    public var position: CGPoint
    public var createdAt: Date

    public init(kind: Kind, position: CGPoint, createdAt: Date) {
        self.kind = kind
        self.position = position
        self.createdAt = createdAt
    }
}

public enum FatCatAttentionState: Equatable, Sendable {
    case none
    case active(FatCatAttentionTarget)
    case stale
}

public enum FatCatGaze: Equatable, Sendable {
    case neutral
    case down
}

/// FatCat only ever looks somewhere because an explicit target was registered.
/// There is deliberately no cursor input: clicks elsewhere never create targets
/// unless a caller decides they are meaningful and calls `focus(on:)`.
public struct FatCatAttentionEngine: Equatable, Sendable {
    public static let targetLifetime: TimeInterval = 0.9

    private var target: FatCatAttentionTarget?

    public init() {}

    public mutating func focus(on target: FatCatAttentionTarget) {
        self.target = target
    }

    public mutating func clear() {
        target = nil
    }

    public func state(at now: Date) -> FatCatAttentionState {
        guard let target else { return .none }
        return now.timeIntervalSince(target.createdAt) <= Self.targetLifetime ? .active(target) : .stale
    }

    /// Looking down requires a real, still-active target below the pet.
    public func gaze(petPosition: CGPoint, at now: Date) -> FatCatGaze {
        guard case .active(let target) = state(at: now) else { return .neutral }
        return target.position.y < petPosition.y ? .down : .neutral
    }
}
