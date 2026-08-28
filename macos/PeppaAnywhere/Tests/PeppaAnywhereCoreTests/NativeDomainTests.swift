import Testing
@testable import PeppaAnywhereCore

struct NativeDomainTests {
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
