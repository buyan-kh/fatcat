# FatCat Internal Life Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the native FatCat pet a local internal-life overlay so the face stays causally alive when chat is quiet, without rewriting completed chat work.

**Architecture:** Add a pure `FatCatLife` reducer in `FatCatCore`. `PetModel` publishes life and applies events. `PetWindowController` maps UI, deduped observations, and Hermes IPC to those events and ticks once a second. The WKWebView still receives an animation key.

**Tech Stack:** Swift 6, Swift Testing, AppKit/SwiftUI pet shell, existing FatCat IPC and avatar bridge.

---

### File map

- Create: `macos/FatCat/Sources/FatCatCore/FatCatLife.swift`
- Create: `macos/FatCat/Tests/FatCatCoreTests/FatCatLifeTests.swift`
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift` (`PetModel`, observation callback, chat/Hermes handlers, tick timer, `PetRootView`)

Do not modify `FatCatChatState.swift`, `FatCatIPC.swift` message cases, or the Python agent.

### Task 1: Life reducer tests and implementation

- [ ] Write `FatCatLifeTests` for default idle, observation curiosity, tick decay, sleep, send overlay, Hermes causes, celebration gate, ignored agent-idle, pause, task continuity, new chat.
- [ ] Run `swift test --package-path macos/FatCat --filter FatCatLifeTests` and confirm it fails because `FatCatLife` is missing.
- [ ] Implement `FatCatLife.swift` with the event model and timing constants from the spec.
- [ ] Re-run focused tests, then `swift test --package-path macos/FatCat`.
- [ ] Commit the reducer and tests before wiring the UI.

### Task 2: Wire the native pet

- [ ] Replace `PetModel.setState` with `handleLife`.
- [ ] Drive `FatCatAvatarView` from `model.life.animationKey`.
- [ ] Emit life events from send/stop/new chat/open/close, deduped observation changes, pause/resume, and Hermes handlers. Ignore agent `idle`/`listening`.
- [ ] Start a 1s tick timer on the pet window controller.
- [ ] Run Swift tests and `swift build --package-path macos/FatCat`.
- [ ] Commit the wiring.

### Task 3: Verify

- [ ] Run `swift test --package-path macos/FatCat` and `swift build --package-path macos/FatCat`.
- [ ] Run packaging/verify script if it still applies to this tree.
- [ ] Confirm chat send/stream/stop/new-chat paths still compile against the same transcript/session helpers.
