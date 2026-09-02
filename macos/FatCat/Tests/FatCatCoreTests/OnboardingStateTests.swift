import Testing
import Foundation
@testable import FatCatCore

@Test func onboardingAdvancesWithoutMixingPresentationAndPetState() {
    var state = OnboardingState()
    #expect(state.step == .meetFatCat)
    state.advance()
    #expect(state.step == .provider)
    state.goBack()
    #expect(state.step == .meetFatCat)
    for _ in OnboardingStep.allCases { state.advance() }
    #expect(state.isComplete)
}

@Test func onboardingCompletionIsPersistedOnlyWhenFinished() {
    let suite = "FatCatCoreTests.onboarding.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = OnboardingStore(defaults: defaults)
    #expect(store.shouldPresent)
    store.markComplete()
    #expect(!store.shouldPresent)
}
