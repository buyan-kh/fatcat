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
        .init(id: "codex", displayName: "Codex", transport: .officialCLI, capabilities: ["coding", "computer_tasks"], privacy: "provider_account", costType: "subscription_or_cli"),
        .init(id: "claude-code", displayName: "Claude Code", transport: .officialCLI, capabilities: ["coding", "research"], privacy: "provider_account", costType: "subscription_or_cli"),
        .init(id: "gemini-cli", displayName: "Gemini CLI", transport: .officialCLI, capabilities: ["coding", "research"], privacy: "provider_account", costType: "subscription_or_cli"),
        .init(id: "copilot-cli", displayName: "GitHub Copilot CLI", transport: .officialCLI, capabilities: ["coding"], privacy: "provider_account", costType: "subscription_or_cli"),
        .init(id: "hermes", displayName: "Hermes provider", transport: .hermes, capabilities: ["conversation", "planning"], privacy: "configured_provider", costType: "configured"),
        .init(id: "ollama", displayName: "Ollama", transport: .localDaemon, capabilities: ["conversation", "private_classification"], privacy: "local", costType: "local"),
        .init(id: "mlx", displayName: "MLX", transport: .localDaemon, capabilities: ["conversation", "private_classification"], privacy: "local", costType: "local"),
        .init(id: "lm-studio", displayName: "LM Studio", transport: .localDaemon, capabilities: ["conversation"], privacy: "local", costType: "local"),
        .init(id: "llama.cpp", displayName: "llama.cpp", transport: .localDaemon, capabilities: ["conversation"], privacy: "local", costType: "local"),
        .init(id: "openai-api", displayName: "OpenAI API", transport: .apiKey, capabilities: ["conversation", "coding"], privacy: "provider_account", costType: "metered"),
        .init(id: "anthropic-api", displayName: "Anthropic API", transport: .apiKey, capabilities: ["conversation", "coding"], privacy: "provider_account", costType: "metered"),
        .init(id: "openrouter", displayName: "OpenRouter", transport: .apiKey, capabilities: ["routing"], privacy: "provider_account", costType: "metered")
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
        case "ollama": return daemon(named: "ollama", arguments: ["list"], detail: "Local Ollama daemon")
        case "lm-studio": return daemon(named: "lms", arguments: ["ls"], detail: "Local LM Studio daemon")
        case "mlx": return checkExecutable(named: "mlx_lm", versionArguments: ["--help"], detail: "Local MLX tooling")
        case "llama.cpp": return daemon(named: "llama-server", arguments: ["--version"], detail: "Local llama.cpp server tooling")
        case "codex": return cli(named: "codex", versionArguments: ["--version"], authArguments: ["login", "status"])
        case "claude-code": return cli(named: "claude", versionArguments: ["--version"], authArguments: ["auth", "status"])
        case "gemini-cli": return cli(named: "gemini", versionArguments: ["--version"], authArguments: ["auth", "status"])
        case "copilot-cli": return cli(named: "gh", versionArguments: ["copilot", "--version"], authArguments: ["auth", "status"])
        case "openai-api": return environment(named: "OPENAI_API_KEY")
        case "anthropic-api": return environment(named: "ANTHROPIC_API_KEY")
        case "openrouter": return environment(named: "OPENROUTER_API_KEY")
        case "hermes": return ProviderCheckResult(installed: true, authenticated: true, detail: "Configured inside PeppaAgent")
        default: return ProviderCheckResult(installed: false, authenticated: false, detail: "Unsupported provider")
        }
    }

    private static func cli(named executable: String, versionArguments: [String], authArguments: [String]) -> ProviderCheckResult {
        guard let version = run(executable: executable, arguments: versionArguments) else {
            return ProviderCheckResult(installed: false, authenticated: false, detail: "\(executable) is not installed")
        }
        let auth = run(executable: executable, arguments: authArguments)
        return ProviderCheckResult(installed: true, authenticated: auth != nil, detail: auth ?? "Installed \(version)")
    }

    private static func checkExecutable(named executable: String, versionArguments: [String], detail: String) -> ProviderCheckResult {
        guard let version = run(executable: executable, arguments: versionArguments) else { return ProviderCheckResult(installed: false, authenticated: false, detail: "\(detail) not found") }
        return ProviderCheckResult(installed: true, authenticated: true, detail: "\(detail) available (\(version))")
    }

    private static func daemon(named executable: String, arguments: [String], detail: String) -> ProviderCheckResult {
        checkExecutable(named: executable, versionArguments: arguments, detail: detail)
    }

    private static func environment(named key: String) -> ProviderCheckResult {
        let configured = !(ProcessInfo.processInfo.environment[key] ?? "").isEmpty
        return ProviderCheckResult(installed: configured, authenticated: configured, detail: configured ? "Configured via environment" : "API key not configured")
    }

    private static func run(executable: String, arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return "Installed" }
        return String(text.prefix(160))
    }
}
