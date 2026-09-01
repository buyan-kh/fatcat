import Testing
@testable import PeppaAnywhereCore

struct FatCatProviderSetupTests {
    @Test func unavailableValidationPreservesExplicitDefault() {
        var state = FatCatProviderSetupState(defaultProvider: "openai-codex", defaultModel: "gpt-5")
        state.applyInventory([
            ["slug": "openai-codex", "name": "OpenAI Codex", "status": "connected", "detail": "Logged in"]
        ])
        state.applyValidation(FatCatProviderValidation(providerID: "openai-codex", model: "gpt-5", usable: false, detail: "Credential expired"))

        #expect(state.defaultProvider == "openai-codex")
        #expect(state.defaultModel == "gpt-5")
        #expect(state.connection(providerID: "openai-codex")?.status == .error)
        #expect(state.connection(providerID: "openai-codex")?.detail == "Credential expired")
    }

    @Test func inventoryAndModelsUpdateOnlyTheMatchingConnection() {
        var state = FatCatProviderSetupState()
        state.applyInventory([
            ["slug": "openai-codex", "name": "OpenAI Codex", "status": "connected", "detail": "Logged in"],
            ["slug": "anthropic", "name": "Anthropic API", "status": "needs_setup", "detail": "API key required"]
        ])
        state.applyModels(providerID: "openai-codex", models: ["gpt-5", "gpt-5"])

        #expect(state.connections.count == 2)
        #expect(state.connection(providerID: "openai-codex")?.models == ["gpt-5"])
        #expect(state.connection(providerID: "anthropic")?.status == .needsSetup)
    }

    @Test func credentialReferenceNeverContainsTheSecretValue() {
        let credentials = FatCatCredentials(service: "com.buyan.fatcat.tests")
        let reference = credentials.reference(providerID: "openai-api")

        #expect(reference == "fatcat-key:openai-api")
        #expect(!reference.contains("sk-live"))
    }
}
