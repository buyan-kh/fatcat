import Testing
@testable import PeppaAnywhereCore

struct ProviderDiscoveryTests {
    @Test func catalogContainsOnlyTheInitialHermesProviders() {
        let ids = Set(ProviderCatalog.supported.map(\.id))

        #expect(ids == ["openai-codex", "openai-api", "anthropic"])
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
        #expect(ProviderCatalog.provider(id: "openai-codex")?.transport == .hermes)
        #expect(ProviderCatalog.provider(id: "openai-api")?.transport == .apiKey)
        #expect(ProviderCatalog.provider(id: "anthropic")?.transport == .apiKey)
    }
}
