# Peppa Anywhere App Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and launch a signed `Peppa Anywhere.app` so macOS assigns Screen Recording permission to the companion instead of Terminal.

**Architecture:** `run-peppa-macos.sh` will build the Swift executable in release mode, assemble a standard macOS app bundle with its generated SwiftPM resource bundle and explicit `Info.plist`, ad-hoc sign when no identity is available, verify the result, and open it. A separate verifier will deterministically inspect bundle metadata, executable/resource paths, signature, and the executable’s own bundled-resource smoke mode.

**Tech Stack:** zsh, SwiftPM, SwiftUI/AppKit, Foundation `Bundle`, `codesign`, `plutil`, Vitest.

---

### Task 1: Add the failing packaging verifier

**Files:**
- Create: `scripts/verify-peppa-macos-app.sh`

- [x] **Step 1: Write the failing verifier**

Make the verifier accept an optional app path and otherwise inspect `macos/PeppaAnywhere/.build/Peppa Anywhere.app`. It must require `Contents/Info.plist`, `Contents/MacOS/PeppaAnywhere`, `Contents/Resources/PeppaAnywhere_PeppaAnywhere.bundle`, `index.html`, one JavaScript asset, one CSS asset, and `strobi.avatar.json`; assert bundle identifier `com.buyan.peppa-anywhere`; verify the code signature; and invoke the executable with `--verify-bundled-assets`.

- [x] **Step 2: Run the verifier and confirm RED**

Run `./scripts/verify-peppa-macos-app.sh` and expect a missing app-bundle failure because the current runner only invokes `swift run`.

### Task 2: Assemble and launch the signed app bundle

**Files:**
- Modify: `scripts/run-peppa-macos.sh`
- Create: `macos/PeppaAnywhere/Resources/AppInfo.plist`

- [x] **Step 1: Build release output and copy resources**

Have the runner invoke `./scripts/prepare-peppa-web-assets.sh`, build SwiftPM with `swift build --configuration release --package-path macos/PeppaAnywhere`, copy the release executable to `Contents/MacOS/PeppaAnywhere`, and copy the generated `PeppaAnywhere_PeppaAnywhere.bundle` into `Contents/Resources`.

- [x] **Step 2: Add metadata and signing**

Write `AppInfo.plist` with `CFBundleIdentifier=com.buyan.peppa-anywhere`, `CFBundleExecutable=PeppaAnywhere`, `CFBundleName`/`CFBundleDisplayName=Peppa Anywhere`, `CFBundlePackageType=APPL`, version `0.1.0`, minimum macOS `13.0`, high-resolution support, and `NSScreenCaptureUsageDescription`. Use an available developer identity when present and `codesign --force --deep --sign -` otherwise.

- [x] **Step 3: Verify then open**

Run the verifier against the assembled app and launch it with `open -a "$APP_BUNDLE"`, leaving the app owned by macOS as Peppa Anywhere.

### Task 3: Make executable resource lookup package-safe

**Files:**
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/NativeDomain.swift`
- Modify: `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/NativeDomainTests.swift`

- [x] **Step 1: Add a failing native resource lookup test**

Test that the bundled-resource smoke contract reports success only when `index.html`, JavaScript, CSS, and `strobi.avatar.json` exist under the SwiftPM resource bundle.

- [x] **Step 2: Implement the smoke mode and package-safe bundle lookup**

Resolve the nested SwiftPM resource bundle from the app’s resources, preserve SwiftPM’s development fallback, and exit through `--verify-bundled-assets` only after checking all bundled assets.

- [x] **Step 3: Run the native test and executable smoke**

Run the documented Swift Testing command and the verifier; both must pass before the full matrix.

### Task 4: Run the complete verification matrix and document concise run instructions

**Files:**
- Modify: `README.md` only if the current worktree documentation does not already contain the app-bundle run path.

- [x] **Step 1: Run web checks**

Run `npm test`, `npm run lint`, and `npm run build`.

- [x] **Step 2: Run native checks**

Run `swift build --package-path macos/PeppaAnywhere`, the Command Line Tools Swift Testing command, and `./scripts/run-peppa-macos.sh` with a bounded launch smoke.

- [x] **Step 3: Audit the diff**

Run `git diff --check`, `git status --short`, and confirm no commit or push occurred.
