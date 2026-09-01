import Foundation

public enum FatCatAvatarNavigation {
    public static func allows(_ url: URL?) -> Bool {
        guard let url else { return true }
        switch url.scheme?.lowercased() {
        case "file", "about", "blob", "data":
            return true
        default:
            return false
        }
    }
}

public enum FatCatAvatarBridge {
    public static func setAnimationJavaScript(_ animationKey: String) -> String? {
        guard let encoded = try? JSONEncoder().encode(animationKey),
              let value = String(data: encoded, encoding: .utf8) else { return nil }
        return "window.fatCatAvatar?.setAnimation(\(value));"
    }

    public static func setFlightJavaScript(phase: String, tiltDegrees: Double, durationMs: Double) -> String? {
        guard let encoded = try? JSONEncoder().encode(phase),
              let value = String(data: encoded, encoding: .utf8),
              tiltDegrees.isFinite, durationMs.isFinite else { return nil }
        return "window.fatCatAvatar?.setFlight(\(value), \(tiltDegrees), \(durationMs));"
    }

    public static func setReactionJavaScript(intensity: Double, durationMs: Double) -> String? {
        guard intensity.isFinite, durationMs.isFinite, durationMs > 0 else { return nil }
        return "window.fatCatAvatar?.setReaction(\(intensity), \(durationMs));"
    }
}
