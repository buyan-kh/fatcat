import Testing
@testable import PeppaAnywhereCore

struct ProviderDiscoveryTests {
    @Test func catalogIncludesSubscriptionAndLocalBrains() {
        let ids = Set(ProviderCatalog.supported.map(\.id))

        #expect(ids.contains("codex"))
        #expect(ids.contains("claude-code"))
        #expect(ids.contains("gemini-cli"))
        #expect(ids.contains("copilot-cli"))
        #expect(ids.contains("ollama"))
        #expect(ids.contains("mlx"))
        #expect(ids.contains("lm-studio"))
        #expect(ids.contains("llama.cpp"))
        #expect(ids.contains("openrouter"))
    }

    @Test func discoveryReportsPresenceWithoutCopyingCredentials() async throws {
        let discovery = ProviderDiscovery(check: { provider in
            ProviderCheckResult(
                installed: provider.id == "codex",
                authenticated: provider.id == "codex",
                detail: "Authenticated CLI"
            )
        })

        let results = await discovery.scan()
        let codex = try #require(results.first(where: { $0.id == "codex" }))

        #expect(codex.authenticated)
        #expect(codex.detail == "Authenticated CLI")
        #expect(codex.secret == nil)
    }

    @Test func subscriptionProvidersUseOfficialCliIdentifiers() {
        #expect(ProviderCatalog.provider(id: "codex")?.transport == .officialCLI)
        #expect(ProviderCatalog.provider(id: "claude-code")?.transport == .officialCLI)
        #expect(ProviderCatalog.provider(id: "gemini-cli")?.transport == .officialCLI)
        #expect(ProviderCatalog.provider(id: "copilot-cli")?.transport == .officialCLI)
    }
}
