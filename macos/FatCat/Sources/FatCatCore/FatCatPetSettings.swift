import Foundation

public enum FatCatMovementMode: String, Codable, CaseIterable, Sendable {
    case off
    case calm
    case playful

    public var title: String {
        switch self {
        case .off: return "Off"
        case .calm: return "Calm"
        case .playful: return "Playful"
        }
    }

    public var idleInterval: TimeInterval {
        switch self {
        case .off: return .infinity
        case .calm: return 300
        case .playful: return 90
        }
    }
}

public struct FatCatPetSettings: Codable, Equatable, Sendable {
    public static let minimumSize = 120.0
    public static let maximumSize = 360.0
    public static let defaultSize = 220.0
    public static let animationKeys = [
        "idle", "curious", "drowsy", "sleeping", "listening",
        "thinking", "working", "searching", "suspicious", "celebrate",
    ]

    public var petSize: Double
    public var movementMode: FatCatMovementMode
    public var spokenReplies: Bool
    public var previewAnimationKey: String?

    public init(
        petSize: Double = defaultSize,
        movementMode: FatCatMovementMode = .calm,
        spokenReplies: Bool = true,
        previewAnimationKey: String? = nil
    ) {
        self.petSize = min(max(petSize, Self.minimumSize), Self.maximumSize)
        self.movementMode = movementMode
        self.spokenReplies = spokenReplies
        self.previewAnimationKey = previewAnimationKey.flatMap(Self.animationKeys.contains) == true
            ? previewAnimationKey
            : nil
    }

    public static func resizedOrigin(from origin: PetPosition, oldSize: Double, newSize: Double) -> PetPosition {
        let inset = (newSize - oldSize) / 2
        return PetPosition(x: origin.x - inset, y: origin.y - inset)
    }
}

public final class FatCatPetSettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "fatcat.pet.settings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(_ settings: FatCatPetSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: key)
    }

    public func load() -> FatCatPetSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(FatCatPetSettings.self, from: data) else {
            return FatCatPetSettings()
        }
        return FatCatPetSettings(
            petSize: decoded.petSize,
            movementMode: decoded.movementMode,
            spokenReplies: decoded.spokenReplies,
            previewAnimationKey: decoded.previewAnimationKey
        )
    }
}

public struct FatCatVoiceState: Equatable, Sendable {
    public private(set) var isListening = false
    public private(set) var isSpeaking = false

    public init() {}

    public mutating func beginListening() {
        isListening = true
        isSpeaking = false
    }

    public mutating func endListening() {
        isListening = false
    }

    public mutating func accept(transcript: String, isFinal: Bool) -> String? {
        guard isFinal else { return nil }
        isListening = false
        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    public mutating func beginSpeaking() {
        isListening = false
        isSpeaking = true
    }

    public mutating func endSpeaking() {
        isSpeaking = false
    }
}
