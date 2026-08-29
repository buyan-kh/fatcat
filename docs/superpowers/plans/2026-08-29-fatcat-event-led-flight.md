# FatCat Event-Led Desktop Flight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the repeating grounded grow/shrink loop with neutral idle presentation, event-driven reactions, and safe event-led desktop flights.

**Architecture:** Keep native Swift responsible for desktop window movement and safety policy. Add a small pure event-to-cue policy and one-cue queue in `PeppaAnywhereCore`; have `FatCatFlightController` consume those cues from `PetModel` life events. Add a separate reaction cue bridge to the avatar web surface, whose grounded frame stays at neutral body scale while flight/reaction phases remain composed.

**Tech Stack:** Swift 6 / Swift Testing / AppKit / SwiftUI / WKWebView, TypeScript / React / Vitest / Vite.

---

## File map

- Modify `src/lib/fatcat-motion.ts`: add a neutral grounded pose and event reaction pose; retain flight helpers.
- Modify `src/lib/fatcat-motion.test.ts`: replace idle whole-body loop assertions with neutral-grounded and event-reaction assertions.
- Modify `src/avatar-main.tsx`: remove grounded use of the repeating scale track, add `setReaction` bridge state, and compose reaction scale with flight transforms.
- Modify `src/lib/fatcat-flight-surface.test.ts`: assert the reaction bridge and no grounded timer-scale call.
- Modify `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatFlight.swift`: define testable event cues and a one-pending-cue queue.
- Modify `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatAvatarNavigation.swift`: encode reaction JavaScript safely.
- Modify `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`: publish life events/reaction cues, wire the avatar bridge, and make the controller event-led instead of timer-led.
- Modify `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatFlightTests.swift`: test event mapping, queue debouncing, and reaction bridge JavaScript.
- Modify `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatAvatarContractTests.swift`: cover the production reaction bridge contract.

### Task 1: Make grounded web motion neutral

**Files:**
- Modify: `src/lib/fatcat-motion.ts`
- Test: `src/lib/fatcat-motion.test.ts`

- [ ] **Step 1: Write the failing tests.** Replace the current `FatCat idle life loop` body-scale expectations with these behaviors:

```ts
it('keeps the whole body neutral while grounded', () => {
  for (const t of [0, 500, 1200, 2400, 5000, 12000]) {
    const pose = groundedLifePose(t)
    expect(pose.bodyScale).toBe(1)
    expect(pose.eyeScaleX).toBe(1)
    expect(pose.eyeScaleY).toBe(1)
  }
})

it('allows grounded attention without resizing the body', () => {
  const early = groundedLifePose(700)
  expect(Math.abs(early.eyeRotationDeg)).toBeGreaterThan(0)
  expect(early.bodyScale).toBe(1)
})

it('creates a bounded event reaction that settles to neutral', () => {
  expect(eventReactionPose(100, 1).bodyScale).toBeGreaterThan(1)
  expect(eventReactionPose(EVENT_REACTION_DURATION_MS, 1).bodyScale).toBeCloseTo(1, 3)
  expect(eventReactionPose(EVENT_REACTION_DURATION_MS, 1).earPerk).toBeCloseTo(0, 3)
})
```

Update imports to use `EVENT_REACTION_DURATION_MS`, `eventReactionPose`, and `groundedLifePose`.

- [ ] **Step 2: Run the focused test and verify it fails for the missing neutral/reaction API.**

Run: `npm test -- src/lib/fatcat-motion.test.ts`

Expected: FAIL because the new helpers do not exist and the old loop assertions still expect body scaling.

- [ ] **Step 3: Implement the smallest motion API.** Add a grounded pose with `bodyScale`, `eyeScaleX`, and `eyeScaleY` fixed at `1`, retaining only the existing eye rotation/offset tracks. Add:

```ts
export const EVENT_REACTION_DURATION_MS = 650

export function groundedLifePose(tMs: number): IdleLifePose {
  return {
    bodyScale: 1,
    bodyRotationDeg: 0,
    eyeScaleX: 1,
    eyeScaleY: 1,
    eyeRotationDeg: track(EYE_ROTATION, tMs),
    eyeOffsetX: track(EYE_OFFSET_X, tMs),
  }
}

export function eventReactionPose(sinceEventMs: number, intensity = 1): ClickReactionPose {
  const progress = Math.min(1, Math.max(0, sinceEventMs / EVENT_REACTION_DURATION_MS))
  const pulse = Math.sin(progress * Math.PI) * Math.min(1, Math.max(0, intensity))
  return { bodyScale: 1 + pulse * 0.05, earPerk: pulse, eyeScaleY: 1 + pulse * 0.08 }
}
```

Keep `clickReactionPose` as a compatibility wrapper calling `eventReactionPose(sinceClickMs)` until all callers are migrated.

- [ ] **Step 4: Run the focused tests and verify they pass.**

Run: `npm test -- src/lib/fatcat-motion.test.ts`

Expected: PASS, with no remaining assertions requiring the grounded body to grow or shrink.

- [ ] **Step 5: Commit the motion helper change.**

```bash
git add src/lib/fatcat-motion.ts src/lib/fatcat-motion.test.ts
git commit -m "fix: keep FatCat grounded scale neutral"
```

### Task 2: Add the event reaction bridge and remove the web idle scale loop

**Files:**
- Modify: `src/avatar-main.tsx`
- Modify: `src/lib/fatcat-flight-surface.test.ts`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatAvatarNavigation.swift`
- Modify: `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatAvatarContractTests.swift`

- [ ] **Step 1: Write failing source/bridge tests.** Add checks that `avatar-main.tsx` exposes `setReaction`, uses `groundedLifePose`, and does not call `idleLifePose` for the grounded frame. Add a Swift test:

```swift
@Test func reactionCueJavaScriptIsWellFormedAndEscaped() {
    #expect(FatCatAvatarBridge.setReactionJavaScript(intensity: 0.8, durationMs: 650) == "window.fatCatAvatar?.setReaction(0.8, 650.0);")
    #expect(FatCatAvatarBridge.setReactionJavaScript(intensity: .nan, durationMs: 650) == nil)
}
```

- [ ] **Step 2: Run the focused TypeScript and Swift tests to verify red.**

Run: `npm test -- src/lib/fatcat-flight-surface.test.ts` and `swift test --package-path macos/PeppaAnywhere --filter PeppaAnywhereCoreTests.FatCatAvatarContractTests`

Expected: FAIL because the bridge and grounded implementation are not present.

- [ ] **Step 3: Implement the web bridge and presentation composition.** Extend `fatCatAvatar` with `setReaction(intensity?: number, durationMs?: number)`. Store `reactionStartedAt`, `reactionIntensity`, and `reactionDurationMs` in refs. In the animation frame, use `groundedLifePose(elapsed)` only while idle and grounded, use `eventReactionPose(now - reactionStartedAt, reactionIntensity)` when active, and multiply reaction scale into the existing flight/settling scale. Keep Reduce Motion suppressing both idle and reaction transforms.

Replace the idle branch:

```ts
if (!reduceMotion.matches && isIdle && !flightActive) {
  pose = groundedLifePose(elapsed)
  follow = followThroughPose(elapsed)
  twitch = earTwitchRotation(elapsed % earTwitchWindowMs, earTwitches)
}
```

Add `setReaction` validation for finite intensity/duration, and let a new cue replace the previous reaction rather than stacking timers.

Add `setReactionJavaScript` to `FatCatAvatarBridge` with JSON-safe numeric validation matching `setFlightJavaScript`.

- [ ] **Step 4: Run focused tests and the TypeScript build.**

Run: `npm test -- src/lib/fatcat-motion.test.ts src/lib/fatcat-flight-surface.test.ts && npm run lint`

Expected: PASS and TypeScript compilation succeeds.

- [ ] **Step 5: Commit the avatar bridge change.**

```bash
git add src/avatar-main.tsx src/lib/fatcat-motion.test.ts src/lib/fatcat-flight-surface.test.ts macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatAvatarNavigation.swift macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatAvatarContractTests.swift
git commit -m "feat: add event reaction bridge to FatCat avatar"
```

### Task 3: Add pure native event-to-cue policy and one-cue debouncing

**Files:**
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatFlight.swift`
- Test: `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatFlightTests.swift`

- [ ] **Step 1: Write failing Swift tests for the approved mapping.** Add tests for the exact table:

```swift
@Test func salientEventsMapToExplicitPresenceCues() {
    #expect(FatCatFlightEventPolicy.cue(for: .userClickedAvatar) == FatCatEventCue(reaction: .perk, flightReason: nil))
    #expect(FatCatFlightEventPolicy.cue(for: .hermes(.thought)) == FatCatEventCue(reaction: .attention, flightReason: nil))
    #expect(FatCatFlightEventPolicy.cue(for: .hermes(.toolCall(name: "search"))) == FatCatEventCue(reaction: .perk, flightReason: .stayNearActiveWork))
    #expect(FatCatFlightEventPolicy.cue(for: .hermes(.permissionRequested)) == FatCatEventCue(reaction: .perk, flightReason: .makeRoomForNotification))
    #expect(FatCatFlightEventPolicy.cue(for: .hermes(.verifiedSuccess)) == FatCatEventCue(reaction: .celebrate, flightReason: .verifiedSuccess))
    #expect(FatCatFlightEventPolicy.cue(for: .hermes(.turnFailed)) == FatCatEventCue(reaction: .recoil, flightReason: nil))
    #expect(FatCatFlightEventPolicy.cue(for: .observationChanged(app: "Xcode", window: nil, redacted: false)) == FatCatEventCue(reaction: .attention, flightReason: nil))
}

@Test func pendingFlightCueKeepsOnlyTheMostRecentSalientReason() {
    var queue = FatCatFlightCueQueue()
    queue.enqueue(.stayNearActiveWork)
    queue.enqueue(.verifiedSuccess)
    #expect(queue.take() == .verifiedSuccess)
    #expect(queue.take() == nil)
}
```

- [ ] **Step 2: Run the focused Swift tests and verify red.**

Run: `swift test --package-path macos/PeppaAnywhere --filter PeppaAnywhereCoreTests.FatCatFlightTests`

Expected: FAIL because the cue types, mapper, and queue do not exist.

- [ ] **Step 3: Implement the pure types.** Add `FatCatReaction` (`attention`, `perk`, `recoil`, `celebrate`), `FatCatEventCue`, and:

```swift
public struct FatCatFlightCueQueue: Equatable, Sendable {
    private var pending: FatCatFlightReason?
    public init() {}
    public mutating func enqueue(_ reason: FatCatFlightReason) { pending = reason }
    public mutating func take() -> FatCatFlightReason? { defer { pending = nil }; return pending }
}
```

Implement `FatCatFlightEventPolicy.cue(for:)` with no cue for `.tick`, `.userSentMessage`, `.userStoppedGeneration`, `.userStartedNewChat`, pause/resume, and non-salient Hermes stream/completion events; map the approved salient events explicitly. Keep the existing flight policy safety checks unchanged.

- [ ] **Step 4: Run all native core flight tests and verify green.**

Run: `swift test --package-path macos/PeppaAnywhere --filter PeppaAnywhereCoreTests.FatCatFlightTests`

Expected: PASS, including all existing planner/policy/animator tests.

- [ ] **Step 5: Commit the pure event policy.**

```bash
git add macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatFlight.swift macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatFlightTests.swift
git commit -m "feat: model event-led FatCat flight cues"
```

### Task 4: Wire life events into the native controller and disable timer-only roaming

**Files:**
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`
- Modify: `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatAvatarContractTests.swift`

- [ ] **Step 1: Add a failing source contract for event-led scheduling.** Assert that `AppMain.swift` contains the life-event callback/controller handler and does not use `.idleReposition` from the periodic evaluator as its default branch. Keep the existing surface test that window movement stays native.

- [ ] **Step 2: Run the contract test and verify red.**

Run: `swift test --package-path macos/PeppaAnywhere --filter PeppaAnywhereCoreTests.FatCatAvatarContractTests`

Expected: FAIL because the controller is still timer-selected and `PetModel` has no event callback/reaction cue.

- [ ] **Step 3: Implement native wiring.**

1. Add `ReactionCue` next to `FlightCue` with intensity, duration, and revision. Add `@Published var reactionCue: ReactionCue?` to `PetModel`.
2. Add `var onLifeEvent: ((FatCatLifeEvent) -> Void)?` to `PetModel`; after reducing `life`, call the callback. This keeps every existing event source centralized without duplicating calls at each call site.
3. Extend `FatCatAvatarView` with `reactionCue`, and its coordinator with `lastReactionRevision`, `pendingReactionCue`, `pushReactionCueIfReady`, and replay on surface-ready. Send `FatCatAvatarBridge.setReactionJavaScript` to the web view.
4. In `FatCatFlightController`, install the callback in `init`, add `private var pendingFlight = FatCatFlightCueQueue()`, and add `handleLifeEvent(_:)`:

```swift
private func handleLifeEvent(_ event: FatCatLifeEvent) {
    guard let cue = FatCatFlightEventPolicy.cue(for: event) else {
        flushPendingFlightIfSafe()
        return
    }
    sendReaction(cue.reaction)
    if let reason = cue.flightReason { pendingFlight.enqueue(reason) }
    flushPendingFlightIfSafe()
}
```

5. Change the 20-second task to call `flushPendingFlightIfSafe()` only. Remove the fallback that chooses `.idleReposition` or `.playfulAfterInactivity` solely from elapsed time. Preserve the `verifiedSuccess` path only when it came from a queued event cue.
6. `flushPendingFlightIfSafe()` must require `machine.state == .grounded`, a panel, closed chat, and `FatCatFlightPolicy.evaluate(reason: context:) == .allowed`; it then takes one queued reason, builds the existing plan, and calls `beginFlight`. If blocked, leave the reason queued. Do not enqueue more than one reason.
7. `sendReaction` increments a separate revision and publishes a 650ms cue. Use intensities `1.0` for perk/celebrate and `0.65` for attention/recoil, with recoil represented by the same bounded pulse until a separate transform is justified.
8. Make `openChat()` publish the click reaction before opening chat, and let `closeChat()` publish `.userClosedChat`; map close to `.returnAfterChatClosed` only if the policy allows it.

- [ ] **Step 4: Run focused tests, full TypeScript checks, and native tests.**

Run: `npm test && npm run lint && swift test --package-path macos/PeppaAnywhere`

Expected: all TypeScript and Swift tests pass, and no timer-only idle flight remains in the controller.

- [ ] **Step 5: Commit the event-led controller wiring.**

```bash
git add macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatAvatarNavigation.swift macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatAvatarContractTests.swift
git commit -m "fix: make FatCat desktop movement event led"
```

### Task 5: Build and verify the complete behavior

**Files:**
- No production files expected; inspect the diff and generated artifacts only.

- [ ] **Step 1: Run the complete automated verification.**

Run:

```bash
npm test
npm run lint
npm run build
swift test --package-path macos/PeppaAnywhere
swift build --package-path macos/PeppaAnywhere
```

Expected: every command exits `0` with no test failures or TypeScript errors.

- [ ] **Step 2: Run the repository’s packaged-app verification path.** Use the existing packaging/runtime scripts documented in `README.md` and `docs/PEPPA-ANYWHERE.md`; capture the pet-only app and exercise click, chat close, a tool/verification event, drag, pause, and Reduce Motion.

Expected: idle FatCat does not visibly grow/shrink on a timer; salient events create bounded reactions; safe event cues move the native panel along a curved path; active chat/typing/dragging/pause/Reduce Motion prevent movement.

- [ ] **Step 3: Inspect the final diff and status.**

Run: `git diff --check`, `git diff --stat`, and `git status --short`

Expected: only the planned files plus the already-existing user changes are present; no generated visual companion files are added to the worktree.

- [ ] **Step 4: Commit any final test-only adjustment if required.** Do not stage or modify the pre-existing `agent/` changes, `artifacts/`, or unrelated files.

