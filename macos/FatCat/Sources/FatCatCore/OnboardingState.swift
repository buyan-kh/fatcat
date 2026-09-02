import Foundation

public enum OnboardingStep: Int, CaseIterable, Codable, Sendable {
    case meetFatCat
    case provider
    case privacy
    case interaction
    case connection
    case usefulTask
}

public struct OnboardingState: Codable, Equatable, Sendable {
    public private(set) var step: OnboardingStep
    public private(set) var isComplete: Bool

    public init(step: OnboardingStep = .meetFatCat, isComplete: Bool = false) {
        self.step = step
        self.isComplete = isComplete
    }

    public mutating func advance() {
        guard !isComplete else { return }
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            isComplete = true
            return
        }
        step = next
    }

    public mutating func goBack() {
        guard !isComplete, let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    public mutating func finish() { isComplete = true }
}

public struct OnboardingStore {
    public static let completionKey = "FatCat.onboarding.completed.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var shouldPresent: Bool { !defaults.bool(forKey: Self.completionKey) }
    public func markComplete() { defaults.set(true, forKey: Self.completionKey) }
}
