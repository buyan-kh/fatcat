import Foundation
import Testing
@testable import FatCatCore

struct FatCatElectronLauncherTests {
    @Test func overridePathWinsOverPackagedSibling() {
        let result = FatCatElectronPathResolver.resolve(
            overridePath: "/tmp/Dev Electron.app",
            nativeBundleURL: URL(fileURLWithPath: "/tmp/FatCat.app"),
            exists: { $0 == "/tmp/Dev Electron.app" }
        )
        #expect(result == .success(URL(fileURLWithPath: "/tmp/Dev Electron.app")))
    }

    @Test func missingOverrideReturnsAnActionableError() {
        let result = FatCatElectronPathResolver.resolve(
            overridePath: "/tmp/missing-electron.app",
            nativeBundleURL: URL(fileURLWithPath: "/tmp/FatCat.app"),
            exists: { _ in false }
        )
        guard case .unavailable(let message) = result else {
            Issue.record("Expected unavailable Electron path")
            return
        }
        #expect(message.contains("FATCAT_ELECTRON_APP_PATH"))
    }

    @Test func packagedSiblingIsResolvedBesideNativeBundle() {
        let result = FatCatElectronPathResolver.resolve(
            overridePath: nil,
            nativeBundleURL: URL(fileURLWithPath: "/Applications/FatCat.app"),
            exists: { $0 == "/Applications/FatCat Electron.app" }
        )
        #expect(result == .success(URL(fileURLWithPath: "/Applications/FatCat Electron.app")))
    }

    @Test func doubleClickSuppressesSingleAction() {
        var interpreter = FatCatAvatarClickInterpreter(doubleClickInterval: 0.25)
        #expect(interpreter.recordClick(at: 10) == .pendingSingle)
        #expect(interpreter.recordClick(at: 10.1) == .double)
        #expect(interpreter.consumePendingSingle() == .single)
    }

    @Test func clickAfterTheIntervalStartsANewSingleAction() {
        var interpreter = FatCatAvatarClickInterpreter(doubleClickInterval: 0.25)
        #expect(interpreter.recordClick(at: 10) == .pendingSingle)
        #expect(interpreter.recordClick(at: 10.3) == .pendingSingle)
        #expect(interpreter.consumePendingSingle() == .single)
    }
}
