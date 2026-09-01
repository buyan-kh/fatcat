# FatCat Electron Workspace Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open or focus the full Electron workspace from the native avatar or native menu without changing single-click behavior, restarting the daemon, or losing the selected Hermes session.

**Architecture:** Put path policy and click interpretation in `FatCatCore` so they are deterministic and testable without AppKit. Keep one AppKit bridge in the executable target that resolves `FATCAT_ELECTRON_APP_PATH` or the packaged sibling app, focuses a running Electron process, or launches it once with `NSWorkspace`; all UI entry points call that same helper.

**Tech Stack:** Swift 6/Foundation/AppKit/SwiftUI/WebKit, Swift Testing, shell packaging checks, Electron/Vite packaging metadata.

---

## File map

- Create `macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift`: pure app-path resolution, error values, and click interpretation contracts.
- Create `macos/FatCat/Tests/FatCatCoreTests/FatCatElectronLauncherTests.swift`: resolver, click, and no-relaunch policy tests.
- Modify `macos/FatCat/Sources/FatCat/AppMain.swift`: AppKit activation helper, avatar double-click wiring, and menu/context action.
- Modify `macos/FatCat/Tests/FatCatCoreTests/FatCatAvatarContractTests.swift` only for source-contract checks that the single helper is wired to both entry points.
- Modify `scripts/verify-fatcat-macos-app.sh` and/or add `scripts/test-fatcat-electron-launcher.sh`: validate packaged sibling naming and bounded real activation checks without embedding developer paths.
- Modify `README.md`: document `FATCAT_ELECTRON_APP_PATH`, packaged sibling layout, and the no-second-daemon guarantee.

### Task 1: Define and test path/click policy in FatCatCore

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatElectronLauncherTests.swift`

- [ ] **Step 1: Write failing pure tests for resolution and click classification.** Test that a valid override wins, a malformed/missing override returns a typed unavailable error, a packaged sibling URL is selected from the native bundle parent, and no absolute developer path is synthesized. Test single click versus a second click inside `doubleClickInterval`, plus a third click after the interval as a new single click.

```swift
@Test func overridePathWinsOverPackagedSibling() throws {
    let result = FatCatElectronPathResolver.resolve(
        overridePath: "/tmp/Dev Electron.app",
        nativeBundleURL: URL(fileURLWithPath: "/tmp/FatCat.app"),
        exists: { $0 == "/tmp/Dev Electron.app" }
    )
    #expect(result == .success(URL(fileURLWithPath: "/tmp/Dev Electron.app")))
}

@Test func doubleClickSuppressesSingleAction() {
    var interpreter = FatCatAvatarClickInterpreter(doubleClickInterval: 0.25)
    #expect(interpreter.recordClick(at: 10) == .pendingSingle)
    #expect(interpreter.recordClick(at: 10.1) == .double)
}
```

- [ ] **Step 2: Run the focused Swift tests and verify they fail because the contracts do not exist.**

Run: `./scripts/swift-test.sh --filter FatCatElectronLauncherTests` (or the full `./scripts/swift-test.sh` runner if filtering is unavailable).

Expected: compile/test failure naming the missing resolver/interpreter.

- [ ] **Step 3: Implement deterministic policy types.** Define:

```swift
public enum FatCatElectronPathResolution: Equatable, Sendable {
    case success(URL)
    case unavailable(String)
}

public enum FatCatAvatarClickResult: Equatable, Sendable { case pendingSingle, single, double }
```

`FatCatElectronPathResolver.resolve` must check `overridePath` first, require a `.app` directory, then check `nativeBundleURL.deletingLastPathComponent()/FatCat Electron.app`; return a message instructing the user to set `FATCAT_ELECTRON_APP_PATH` when neither exists. `FatCatAvatarClickInterpreter` must use an injected interval and never invoke both single and double actions for one pair.

- [ ] **Step 4: Run tests and commit the pure contract.**

Run: `./scripts/swift-test.sh`.

Expected: all Swift tests pass, including resolver and click tests.

Commit: `git add macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift macos/FatCat/Tests/FatCatCoreTests/FatCatElectronLauncherTests.swift && git commit -m "feat: define Electron launcher path policy"`

### Task 2: Implement one AppKit launcher that focuses or launches exactly once

**Files:**
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatAvatarContractTests.swift`

- [ ] **Step 1: Add source-contract tests for one launcher and both call sites.** Assert AppMain contains one launcher type, reads `FATCAT_ELECTRON_APP_PATH`, uses the sibling name `FatCat Electron.app`, calls `NSWorkspace.shared.runningApplications`, and exposes both a double-click closure and an “Open Electron Workspace” menu item. Assert no `Process`, `pkill`, LaunchAgent restart, or hardcoded `/Users/` path is introduced.

- [ ] **Step 2: Implement `FatCatElectronLauncher` in the executable target.** Make it `@MainActor`, inject `NSWorkspace`-equivalent closures for tests where possible, and:

```swift
func openOrFocus() {
    switch resolver.resolve(overridePath: ProcessInfo.processInfo.environment["FATCAT_ELECTRON_APP_PATH"], nativeBundleURL: Bundle.main.bundleURL, exists: fileExists) {
    case .unavailable(let message): presentError(message)
    case .success(let appURL):
        if let running = workspace.runningApplications.first(where: { $0.bundleURL?.standardizedFileURL == appURL.standardizedFileURL }) {
            running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
        workspace.openApplication(at: appURL, configuration: configuration) { app, error in
            if let error { presentError("Could not open Electron workspace: \(error.localizedDescription)") }
            else { app?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) }
        }
    }
}
```

Use `NSAlert` on the main actor for unavailable/launch errors. Do not call the agent client, socket reconnect, or daemon lifecycle APIs from this helper.

- [ ] **Step 3: Run Swift tests and commit.**

Run: `./scripts/swift-test.sh`.

Expected: resolver/source-contract tests pass and the app target compiles.

Commit: `git add macos/FatCat/Sources/FatCat/AppMain.swift macos/FatCat/Tests/FatCatCoreTests/FatCatAvatarContractTests.swift && git commit -m "feat: focus or launch Electron workspace"`

### Task 3: Wire double-click and native menu/context action without changing single-click semantics

**Files:**
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift` only if the interaction adapter needs a shared callback type

- [ ] **Step 1: Add failing interaction tests.** Verify a single avatar click still calls the existing `toggleMiniChat` path, a double click calls only `openOrFocusElectron`, and the menu action calls the exact same launcher closure. Verify `agent.petClicked`, `agent.send`, `agent.stopGeneration`, and `agent.restart` are not called by either Electron action.

- [ ] **Step 2: Wire the avatar surface.** Extend `FatCatAvatarView`/`PetRootView` with `onDoubleClick`. Have the WebKit/AppKit surface use `NSEvent.clickCount` or the pure interpreter so a second click cancels the pending single action. Keep drag callbacks independent. `buildPanel` passes `onClick: toggleMiniChat` and `onDoubleClick: openOrFocusElectron`.

- [ ] **Step 3: Add the explicit menu action.** Insert `Open Electron Workspace` in `makeMenu()`, target it to `openElectronWorkspaceFromMenu`, and implement that method as a direct call to the same `openOrFocusElectron()` helper. If the avatar has a context menu surface, dispatch its action through the same method rather than creating another launcher.

- [ ] **Step 4: Run focused tests and commit.**

Run: `./scripts/swift-test.sh`.

Expected: single/double/menu tests pass; the mini-chat toggle remains unchanged for single clicks.

Commit: `git add macos/FatCat/Sources/FatCat/AppMain.swift macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift && git commit -m "feat: add avatar and menu Electron actions"`

### Task 4: Verify packaged/dev resolution and real reuse behavior

**Files:**
- Modify: `README.md`
- Modify: `scripts/verify-fatcat-macos-app.sh` if the packaged sibling assertion belongs in the release gate
- Create: `scripts/test-fatcat-electron-launcher.sh`

- [ ] **Step 1: Document the supported layout.** State that a release install places `FatCat Electron.app` beside `FatCat.app`; development/tests set `FATCAT_ELECTRON_APP_PATH` to a valid app bundle. Explain that the native daemon is persistent and the launcher only focuses/starts Electron.

- [ ] **Step 2: Add a bounded real launcher smoke script.** The script must require an explicit `FATCAT_ELECTRON_APP_PATH`, validate it is a `.app`, launch the native app fixture, invoke the menu/double-click path through the app’s test hook or AppleScript, poll `pgrep` for exactly one Electron PID, invoke it a second time, assert the PID count remains one, and clean up only the PIDs it started. If Accessibility automation is unavailable, exit with a clear skipped status rather than killing unrelated processes.

- [ ] **Step 3: Run package/build checks.**

Run:

```bash
swift build --configuration release --package-path macos/FatCat
./scripts/verify-fatcat-macos-app.sh macos/FatCat/.build/FatCat.app
FATCAT_ELECTRON_APP_PATH="/absolute/path/to/FatCat Electron.app" ./scripts/test-fatcat-electron-launcher.sh
git diff --check
```

Expected: release native bundle verifies, the override path opens/focuses the same Electron process on repeated actions, and no daemon restart occurs.

- [ ] **Step 4: Commit docs and verification tooling.**

Commit: `git add README.md scripts/verify-fatcat-macos-app.sh scripts/test-fatcat-electron-launcher.sh && git commit -m "test: verify packaged Electron launcher reuse"`
