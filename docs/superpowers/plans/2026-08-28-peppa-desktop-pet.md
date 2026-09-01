# FatCat Anywhere Desktop Pet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dashboard prototype with a packaged, transparent native FatCat desktop pet whose attached chat uses the installed Hermes Agent runtime.

**Architecture:** AppKit owns a borderless transparent `NSPanel`, status item, native SwiftUI bubble, and menus. A transparent WKWebView renders only the real FatCat avatar definition; a native ACP stdio client launches `hermes acp` and preserves one session. ScreenCaptureKit remains native and emits privacy-filtered structured metadata.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ScreenCaptureKit, WebKit, Hermes ACP JSON-RPC over stdio, React 19, Vite, Vitest, Swift Testing.

---

### Task 1: Establish testable pet contracts

**Files:**
- Modify: `macos/FatCat/Sources/FatCatCore/NativeDomain.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/NativeDomainTests.swift`
- Create: `src/lib/pet-surface.test.ts`
- Create: `src/lib/pet-surface.ts`

- [ ] Write failing Swift tests for the complete semantic state list, real animation-key mapping, verified-only celebration, and clamped persisted panel coordinates.
- [ ] Run `swift test --package-path macos/FatCat --filter NativeDomainTests` and confirm failure is caused by missing contracts.
- [ ] Write failing Vitest checks that the production entrypoint renders `FatCatAvatar` only, references transparent root styling, and contains no `CompanionDashboard` import.
- [ ] Run `npm test -- src/lib/pet-surface.test.ts` and confirm the expected failure.
- [ ] Implement the minimal public Swift value types and TypeScript surface contract needed by those tests.
- [ ] Re-run both focused test commands and then the existing native/web suites.

### Task 2: Implement real Hermes ACP client

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/HermesACP.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/NativeDomain.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/HermesACPTests.swift`

- [ ] Write failing decoder tests for ACP `session/update` agent-message chunks, prompt completion, JSON-RPC errors, and disconnected process output.
- [ ] Run the focused Swift tests and confirm they fail before the adapter exists.
- [ ] Implement a dependency-injected line transport plus a production `Process` transport that launches `hermes acp`, sends `initialize`, `session/new`, and `session/prompt`, and retains the session id.
- [ ] Add `FATCAT_HERMES_PATH` override support and resolve `/Users/buyan/.local/bin/hermes` only as a development-machine discovery fallback; never fabricate assistant text.
- [ ] Implement streamed text accumulation, state callbacks, cancellation/termination, and honest error values.
- [ ] Re-run the Hermes focused tests and all Swift tests.

### Task 3: Replace dashboard web entrypoint with transparent avatar-only renderer

**Files:**
- Modify: `src/App.tsx`
- Modify: `src/components/FatCatCompanionAvatar.tsx`
- Modify: `src/styles.css`
- Modify: `index.html`
- Modify: `src/main.tsx`
- Modify: `src/lib/pet-surface.ts`
- Test: `src/lib/pet-surface.test.ts`

- [ ] Write or extend failing tests for real animation keys and transparent document styles.
- [ ] Run the focused Vitest test and verify it fails against the dashboard entrypoint.
- [ ] Make `App.tsx` render only the real avatar wrapper, with native bridge messages for click and context-menu intent; remove the dashboard import from the normal path.
- [ ] Keep all avatar definition data sourced from `public/fatcat.avatar.json` and remove lab/dashboard-only layout from the production path.
- [ ] Set `html`, `body`, `#root`, and avatar host backgrounds to transparent with zero page margins and no scrolling.
- [ ] Build the web bundle and run web tests.

### Task 4: Build the transparent native pet panel and state bridge

**Files:**
- Replace: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/NativeDomain.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/NativeDomainTests.swift`

- [ ] Write failing tests for transparent panel configuration, `.canJoinAllSpaces`, `.fullScreenAuxiliary`, floating level, position persistence, and pet/chat mode sizing.
- [ ] Run focused Swift tests and confirm the expected failures.
- [ ] Implement `PetPanel`, `PetWindowController`, and `PetRootView` with a borderless clear `NSPanel`, no title bar/shadow, explicit drag handling, and persisted position.
- [ ] Host the bundled avatar-only WKWebView with clear `WKWebView`/scroll/background layers and no normal webpage navigation.
- [ ] Map native semantic states into avatar animation keys and route avatar click to opening the native bubble.
- [ ] Re-run all Swift tests and build the executable.

### Task 5: Add native speech bubble, menus, privacy controls, and status item

**Files:**
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/NativeDomain.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/NativeDomainTests.swift`

- [ ] Write failing tests for chat open/close transitions and the required menu command labels.
- [ ] Run the focused tests and confirm failure.
- [ ] Implement the compact attached SwiftUI bubble with conversation transcript, text field, send, close, and expand controls; send through the real Hermes client and show disconnected/error states.
- [ ] Add right-click menu and `NSStatusItem` menu entries for Pause Observation, Settings, Memory, Action History, and Quit.
- [ ] Wire pause/resume to `CaptureCoordinator` and expose status visibly in both FatCat and the status item.
- [ ] Keep settings/memory/history in small native popovers or secondary windows and do not reintroduce dashboard components.
- [ ] Run all Swift tests and a release build.

### Task 6: Package and verify the actual app

**Files:**
- Modify: `scripts/run-fatcat-macos.sh`
- Modify: `scripts/verify-fatcat-macos-app.sh`
- Modify: `macos/FatCat/AppInfo.plist`
- Create or modify: `scripts/smoke-fatcat-macos.sh`
- Test: `src/lib/web-bundle.test.ts`

- [ ] Write failing packaging assertions for stable bundle name/id, no Vite runtime dependency, and avatar-only WebApp assets.
- [ ] Run the focused checks and confirm the current dashboard/package behavior fails them.
- [ ] Update packaging to build `FatCat Anywhere.app`, copy resources, set `CFBundleIdentifier=com.buyan.fatcat`, preserve Screen Recording usage text, and sign consistently when possible.
- [ ] Make verification launch the packaged executable, inspect bundle metadata/resources, and avoid treating file existence alone as success.
- [ ] Add runtime smoke capture steps for pet-only and open-chat modes, plus drag/relaunch position persistence and visible pause state.
- [ ] Run `npm test`, `npm run lint`, `npm run build`, `swift test --package-path macos/FatCat`, `swift build --package-path macos/FatCat`, packaging, verification, and the smoke script.

### Task 7: Concise handoff documentation and completion audit

**Files:**
- Modify: `README.md`

- [ ] Replace the dashboard-oriented README with concise run, architecture, current limitations, and verification sections.
- [ ] Confirm no animation source files outside this repository were modified.
- [ ] Confirm no normal app path imports or displays `CompanionDashboard`.
- [ ] Review screenshot evidence for transparent pet-only and open-chat states, real Hermes response, position persistence, and visible pause state.
- [ ] Report remaining limitations honestly and wait for explicit approval before any commit or push.
