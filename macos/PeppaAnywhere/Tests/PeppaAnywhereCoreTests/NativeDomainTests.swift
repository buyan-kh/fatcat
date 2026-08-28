import Foundation
import Testing
@testable import PeppaAnywhereCore

struct NativeDomainTests {
    @Test func petStatesUseTheRealAvatarAnimationKeys() {
        #expect(PeppaState.allCases == [
            .idle,
            .listening,
            .understanding,
            .planning,
            .askingPermission,
            .acting,
            .verifying,
            .celebrating,
            .recovering,
            .suspicious,
            .sleeping,
        ])
        #expect(PeppaState.understanding.animationKey == "thinking")
        #expect(PeppaState.askingPermission.animationKey == "listening")
        #expect(PeppaState.acting.animationKey == "working")
        #expect(PeppaState.celebrating.animationKey == "celebrate")
        #expect(PeppaState.suspicious.animationKey == "suspicious")
        #expect(PeppaState.sleeping.animationKey == "sleeping")
    }

    @Test func celebrationRequiresVerifiedSuccess() {
        var machine = PeppaStateMachine()
        #expect(!machine.transition(to: .celebrating, verified: false).accepted)
        #expect(machine.state == .idle)

        #expect(machine.transition(to: .verifying).accepted)
        #expect(!machine.transition(to: .celebrating, verified: false).accepted)
        #expect(machine.state == .verifying)
        #expect(machine.transition(to: .celebrating, verified: true).accepted)
        #expect(machine.state == .celebrating)
    }

    @Test func petPositionPersistsAndClampsToVisibleScreen() {
        let suiteName = "PeppaAnywhereTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PetPositionStore(defaults: defaults)
        store.save(PetPosition(x: 940, y: -40))
        #expect(store.load() == PetPosition(x: 940, y: -40))
        #expect(store.load()?.clamped(to: PanelBounds(width: 800, height: 600)) == PetPosition(x: 800, y: 0))
    }

    @Test func petPanelModesAndMenusDescribeTheSmallNativeSurface() {
        #expect(PetPanelMode.petOnly.width == 220)
        #expect(PetPanelMode.petOnly.height == 220)
        #expect(PetPanelMode.chat.width == 550)
        #expect(PetPanelMode.chat.height == 330)
        #expect(PetMenuCommand.allCases.map(\.title) == [
            "Pause Observation",
            "Settings",
            "Memory",
            "Action History",
            "Quit FatCat",
        ])
    }

    @Test func privateAppsAreRedactedWithoutRetainingRawScreenshots() {
        let policy = PrivacyPolicy(privateApps: ["1Password"])
        let result = ObservationFactory.make(
            application: ActiveApplication(pid: 42, name: "1Password"),
            window: WindowCandidate(ownerPID: 42, ownerName: "1Password", layer: 0, onScreen: true, title: "Vault", order: 0),
            policy: policy,
            timestamp: "now"
        )

        #expect(result.activeApp == "[private app]")
        #expect(result.visibleWindow == "[redacted]")
        #expect(!result.privacy.rawScreenshotRetained)
    }

    @Test func pauseStopsCaptureAndResumeRequiresAnAuthorizedStart() {
        var state = CaptureState()
        state.authorize()
        state.started()
        #expect(state.isCapturing)

        state.pause()
        #expect(state.isPaused)
        #expect(!state.isCapturing)

        state.resume()
        #expect(!state.isPaused)
        #expect(!state.isCapturing)
        state.started()
        #expect(state.isCapturing)
    }

    @Test func windowSelectionMatchesFrontmostOwnerAndHighestRelevantLayer() {
        let candidates = [
            WindowCandidate(ownerPID: 7, ownerName: "Other", layer: 99, onScreen: true, title: "Overlay", order: 0),
            WindowCandidate(ownerPID: 42, ownerName: "Safari", layer: 0, onScreen: true, title: "Study tab", order: 2),
            WindowCandidate(ownerPID: 42, ownerName: "Safari", layer: 8, onScreen: true, title: "Safari toolbar", order: 1),
            WindowCandidate(ownerPID: 42, ownerName: "Safari", layer: 10, onScreen: false, title: "Hidden", order: 0),
        ]

        #expect(WindowSelector.frontmostWindowName(candidates, application: ActiveApplication(pid: 42, name: "Safari")) == "Safari toolbar")
    }
}
