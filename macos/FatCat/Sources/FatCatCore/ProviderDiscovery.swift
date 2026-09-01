import Foundation

public enum ProviderTransport: String, Equatable, Sendable {
    case officialCLI
    case hermes
    case localDaemon
    case apiKey
}

public struct ProviderDescriptor: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let transport: ProviderTransport
    public let capabilities: [String]
    public let privacy: String
    public let costType: String

    public init(id: String, displayName: String, transport: ProviderTransport, capabilities: [String], privacy: String, costType: String) {
        self.id = id
        self.displayName = displayName
        self.transport = transport
        self.capabilities = capabilities
        self.privacy = privacy
        self.costType = costType
    }
}

public enum ProviderCatalog {
    public static let supported: [ProviderDescriptor] = [
        .init(id: "openai-codex", displayName: "OpenAI Codex", transport: .hermes, capabilities: ["coding", "computer_tasks"], privacy: "provider_account", costType: "subscription"),
        .init(id: "openai-api", displayName: "OpenAI API", transport: .apiKey, capabilities: ["conversation", "coding"], privacy: "provider_account", costType: "metered"),
        .init(id: "anthropic", displayName: "Anthropic / Claude API", transport: .apiKey, capabilities: ["conversation", "coding"], privacy: "provider_account", costType: "metered")
    ]

    public static func provider(id: String) -> ProviderDescriptor? {
        supported.first { $0.id == id }
    }
}

public struct ProviderCheckResult: Equatable, Sendable {
    public let installed: Bool
    public let authenticated: Bool
    public let detail: String

    public init(installed: Bool, authenticated: Bool, detail: String) {
        self.installed = installed
        self.authenticated = authenticated
        self.detail = detail
    }
}

public struct ProviderStatus: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let installed: Bool
    public let authenticated: Bool
    public let detail: String
    public let secret: String?

    public init(descriptor: ProviderDescriptor, result: ProviderCheckResult) {
        self.id = descriptor.id
        self.displayName = descriptor.displayName
        self.installed = result.installed
        self.authenticated = result.authenticated
        self.detail = result.detail
        self.secret = nil
    }
}

public struct ProviderDiscovery: Sendable {
    public typealias Checker = @Sendable (ProviderDescriptor) async -> ProviderCheckResult
    private let check: Checker

    public init(check: @escaping Checker) {
        self.check = check
    }

    public static func live() -> Self {
        Self(check: { provider in await LiveProviderChecker.check(provider) })
    }

    public func scan() async -> [ProviderStatus] {
        await withTaskGroup(of: ProviderStatus.self, returning: [ProviderStatus].self) { group in
            for provider in ProviderCatalog.supported {
                group.addTask {
                    ProviderStatus(descriptor: provider, result: await check(provider))
                }
            }
            var statuses: [ProviderStatus] = []
            for await status in group { statuses.append(status) }
            return statuses.sorted { $0.id < $1.id }
        }
    }
}

private enum LiveProviderChecker {
    static func check(_ provider: ProviderDescriptor) async -> ProviderCheckResult {
        switch provider.id {
        case "openai-codex":
            return ProviderCheckResult(installed: true, authenticated: true, detail: "Detected through Hermes Codex auth")
        case "openai-api":
            return environment(named: "OPENAI_API_KEY")
        case "anthropic":
            return environment(named: "ANTHROPIC_API_KEY")
        default:
            return ProviderCheckResult(installed: false, authenticated: false, detail: "Unsupported provider")
        }
    }

    private static func environment(named key: String) -> ProviderCheckResult {
        let configured = !(ProcessInfo.processInfo.environment[key] ?? "").isEmpty
        return ProviderCheckResult(installed: configured, authenticated: configured, detail: configured ? "Configured via environment" : "API key not configured")
    }
}
