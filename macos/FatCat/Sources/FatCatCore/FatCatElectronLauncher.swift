import Foundation

public enum FatCatElectronPathResolution: Equatable, Sendable {
    case success(URL)
    case unavailable(String)
}

public enum FatCatAvatarClickResult: Equatable, Sendable {
    case pendingSingle
    case single
    case double
}

public enum FatCatElectronPathResolver {
    public static let packagedSiblingName = "FatCat Electron.app"

    public static func resolve(
        overridePath: String?,
        nativeBundleURL: URL,
        exists: (String) -> Bool = { path in
            var isDirectory = ObjCBool(false)
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    ) -> FatCatElectronPathResolution {
        if let overridePath {
            let path = overridePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty, path.hasSuffix(".app"), exists(path) else {
                return .unavailable("Electron workspace override is unavailable at \(path.isEmpty ? "the configured path" : path). Set FATCAT_ELECTRON_APP_PATH to a valid .app bundle.")
            }
            return .success(URL(fileURLWithPath: path).standardizedFileURL)
        }

        let sibling = nativeBundleURL.deletingLastPathComponent().appendingPathComponent(packagedSiblingName)
        guard exists(sibling.path) else {
            return .unavailable("FatCat Electron.app is not installed beside FatCat.app. Set FATCAT_ELECTRON_APP_PATH to a valid .app bundle for development.")
        }
        return .success(sibling.standardizedFileURL)
    }
}

public struct FatCatAvatarClickInterpreter: Sendable {
    private let doubleClickInterval: TimeInterval
    private var lastClickAt: TimeInterval?

    public init(doubleClickInterval: TimeInterval) {
        self.doubleClickInterval = max(0, doubleClickInterval)
    }

    public mutating func recordClick(at time: TimeInterval) -> FatCatAvatarClickResult {
        if let lastClickAt, time - lastClickAt <= doubleClickInterval {
            self.lastClickAt = nil
            return .double
        }
        lastClickAt = time
        return .pendingSingle
    }

    public mutating func consumePendingSingle() -> FatCatAvatarClickResult {
        guard lastClickAt != nil else { return .single }
        lastClickAt = nil
        return .single
    }
}
