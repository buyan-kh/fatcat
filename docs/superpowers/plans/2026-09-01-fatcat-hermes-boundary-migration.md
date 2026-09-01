# FatCat–Hermes Boundary Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hermes the sole owner of FatCat sessions, history, memory, planning, and tools while FatCat owns surfaces, channel routing, native permissions, approvals, execution, and verification.

**Architecture:** Replace the daemon’s transcript-owning store with metadata-only session indexing and normalize Hermes ACP updates into a generic lifecycle event protocol. All surfaces consume the same events; risky Hermes proposals pause for FatCat-local permission/target/approval checks and native execution before outcomes return to Hermes.

**Tech Stack:** Python 3 asyncio/Unix sockets, Hermes ACP, TypeScript/Zod/Vitest, React/Electron, Swift/AppKit/ApplicationServices, Swift Testing, SQLite/JSON local UI state.

---

## File map and ownership boundaries

- `agent/peppa_agent/server.py`: Hermes ACP adapter, session attachment, event normalization, channel fan-out, and approval continuations. It must not write transcript bodies.
- `agent/peppa_agent/conversations.py`: metadata-only FatCat session index during migration; remove message storage and history merge methods.
- `agent/tests/test_server.py`, `agent/tests/test_conversations.py`: daemon/session/retirement contract tests.
- `electron/src/shared/protocol.ts`, `electron/src/shared/chat.ts`: v2 event envelope and renderer activity types.
- `electron/src/renderer/src/lib/chat-reducer.ts`, `electron/src/renderer/src/hooks/use-fatcat.ts`, `electron/src/renderer/src/components/turn-activity.tsx`: generic event reduction and display.
- `electron/src/shared/protocol.test.ts`, `electron/src/renderer/src/lib/chat-reducer.test.ts`, related Electron tests: protocol and synchronization coverage.
- `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/PeppaIPC.swift`: Swift codec parity with the v2 protocol and metadata-only conversation records.
- `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/NativeActionPolicy.swift`, `macos/PeppaAnywhere/Sources/PeppaAnywhere/NativeActionExecutor.swift`: native safety enforcement and verification.
- `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`, `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatChatState.swift`: Hermes history/event-driven surface state; no persisted transcript source.
- `src/components/CompanionDashboard.tsx`, `src/components/HermesEventActivity.tsx`, `src/lib/brain.ts`, `src/lib/memory.ts`, `src/lib/goals.ts`, `src/lib/learning.ts`, and their tests: remove the legacy local agent path from the product build.
- `src/lib/retirement.ts` and `src/lib/retirement.test.ts`: one-time, idempotent local content retirement.

### Task 1: Add failing protocol and ownership guard tests

**Files:**
- Create: `electron/src/shared/hermes-events.test.ts`
- Modify: `electron/src/shared/protocol.test.ts`
- Create: `src/lib/ownership-boundary.test.ts`

- [ ] **Step 1: Write failing event-envelope tests.** Assert that a v2 event requires `event_id`, `kind`, `session_id`, `request_id`, `summary`, and `details`, accepts all listed lifecycle kinds, and rejects credential keys recursively.

```ts
expect(() => decodeAgentEvent(JSON.stringify({ version: 2, kind: 'tool.started' }))).toThrow()
expect(() => decodeAgentEvent(JSON.stringify({
  version: 2, event_id: 'e1', kind: 'tool.started', session_id: 's1', request_id: 'r1',
  summary: 'Search', details: { api_key: 'never' },
}))).toThrow(/credential/i)
```

- [ ] **Step 2: Write failing ownership scan test.** Add a test helper that reads only active product source paths and fails if `CompanionDashboard.tsx` imports `memory`, `goals`, `learning`, or `brain`, or if daemon code calls `append_message`, `append_assistant_delta`, or `merge_history`.

- [ ] **Step 3: Run the focused tests.**

Run: `npm test -- electron/src/shared/hermes-events.test.ts src/lib/ownership-boundary.test.ts`

Expected: FAIL because the v2 schema and ownership cleanup do not exist.

- [ ] **Step 4: Commit the red tests.**

```bash
git add electron/src/shared/hermes-events.test.ts electron/src/shared/protocol.test.ts src/lib/ownership-boundary.test.ts
git commit -m "test: define Hermes ownership boundary"
```

### Task 2: Implement the v2 generic event protocol

**Files:**
- Modify: `electron/src/shared/protocol.ts`
- Modify: `electron/src/shared/chat.ts`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/PeppaIPC.swift`
- Test: `electron/src/shared/hermes-events.test.ts`, `electron/src/shared/protocol.test.ts`, `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/PeppaIPCTests.swift`

- [ ] **Step 1: Define the exact TypeScript schema.** Add a discriminated `hermesEvent` schema with `version: 2`, `event_id`, `kind`, `session_id`, optional nullable `request_id`, `summary`, and `details: record(string, primitive|string arrays)`. Enumerate the lifecycle kinds from the design spec. Keep the v1 decoder isolated and marked compatibility-only.

- [ ] **Step 2: Define renderer types.** Add `HermesEventKind`, `HermesEvent`, and `ToolLifecycleState` to `electron/src/shared/chat.ts`. Map event kinds to `TurnActivity` without tool-specific branches.

- [ ] **Step 3: Mirror the codec in Swift.** Add Codable `FatCatHermesEvent`, `FatCatHermesEventKind`, and a `.hermesEvent` IPC case. Decode v2 and preserve v1 decoding for the rollout window. Apply the existing recursive credential rejection before decoding.

- [ ] **Step 4: Run protocol tests.**

Run: `npm --prefix electron test -- src/shared/hermes-events.test.ts src/shared/protocol.test.ts`

Expected: PASS, including malformed-version, unknown-kind, and credential rejection cases.

- [ ] **Step 5: Run Swift IPC tests.**

Run: `./scripts/swift-test.sh --filter PeppaIPC`

Expected: PASS with v2 round-trip parity and v1 compatibility coverage.

- [ ] **Step 6: Commit the protocol.**

```bash
git add electron/src/shared/protocol.ts electron/src/shared/chat.ts macos/PeppaAnywhere/Sources/PeppaAnywhereCore/PeppaIPC.swift
git commit -m "feat: add generic Hermes event protocol"
```

### Task 3: Convert the Python daemon to metadata-only session routing

**Files:**
- Modify: `agent/peppa_agent/conversations.py`
- Modify: `agent/peppa_agent/server.py`
- Modify: `agent/tests/test_conversations.py`, `agent/tests/test_server.py`

- [ ] **Step 1: Write failing metadata-only store tests.** Assert normalized records contain only `id`, `title`, `workspace_path`, and `session_id`; legacy `messages` are discarded on load; no public append/merge methods exist; selecting/attaching a session remains idempotent.

- [ ] **Step 2: Write failing server tests.** With a fake Hermes session, assert `user_message` forwards exactly once, emits a live message event, and never calls a transcript persistence method. Assert load/reconnect calls Hermes ACP history and does not create a new session.

- [ ] **Step 3: Remove transcript persistence.** Delete `append_message`, `append_assistant_delta`, and `merge_history`; update `_normalize_document` to drop `messages`; remove those calls from `broadcast`, `load_session`, and `user_message`. Keep only session-handle metadata and selection.

- [ ] **Step 4: Route v2 events.** Update `_FatCatACPBridge` and `PeppaAgentSession` to emit the generic envelope for message, tool, permission, state, and verification events. Every event must include the Hermes session ID and a stable event ID.

- [ ] **Step 5: Add session-scoped fan-out.** Track channel subscriptions by session, broadcast only to subscribed clients, deduplicate by `event_id`, and keep a bounded in-memory buffer for currently active requests. Never write that buffer to disk.

- [ ] **Step 6: Run agent tests.**

Run: `PYTHONPATH=agent python3 -m unittest agent/tests/test_conversations.py agent/tests/test_server.py`

Expected: PASS with assertions that the JSON store contains no `messages` key and Hermes owns history replay.

- [ ] **Step 7: Commit daemon routing.**

```bash
git add agent/peppa_agent/conversations.py agent/peppa_agent/server.py agent/tests/test_conversations.py agent/tests/test_server.py
git commit -m "refactor: make FatCat daemon a Hermes session adapter"
```

### Task 4: Implement approval continuations and native-result routing

**Files:**
- Modify: `agent/peppa_agent/server.py`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/NativeActionPolicy.swift`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhere/NativeActionExecutor.swift`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`
- Test: `agent/tests/test_server.py`, `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/NativeActionTests.swift`

- [ ] **Step 1: Write failing approval tests.** Assert a risky proposal emits `tool.needs_approval`, blocks the Hermes continuation, and resumes with an explicit approved/denied result keyed by proposal ID. Assert timeout and stale proposal IDs are denied.

- [ ] **Step 2: Add typed proposal details.** Define a sanitized proposal payload containing proposal ID, action name, risk, human-readable summary, expected result, and target metadata. Reject credentials and missing IDs before UI display.

- [ ] **Step 3: Add pending continuations.** Store one in-memory future per proposal ID, expose approve/deny commands, clear it in all completion/error paths, and send ACP permission outcomes back to Hermes. No approval may be inferred from tool arguments or a previous decision.

- [ ] **Step 4: Tighten native policy.** Classify `type_text`, `click_element`, `send_email`, `open_file`, and `run_process` according to risk; require current Accessibility/Apple Events permission and immediate target validation for mutations; keep high-risk actions approval-gated.

- [ ] **Step 5: Return independent verification.** Make `NativeActionExecutor` emit a result and a separate verification result. Distinguish permission failure, target mismatch, execution failure, and verification failure.

- [ ] **Step 6: Run focused safety tests.**

Run: `PYTHONPATH=agent python3 -m unittest agent/tests/test_server.py` and `./scripts/swift-test.sh --filter NativeAction`

Expected: PASS; no test may execute a mutation without an approval and current permission check.

- [ ] **Step 7: Commit the safety handshake.**

```bash
git add agent/peppa_agent/server.py macos/PeppaAnywhere/Sources/PeppaAnywhereCore/NativeActionPolicy.swift macos/PeppaAnywhere/Sources/PeppaAnywhere/NativeActionExecutor.swift macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift
git commit -m "feat: enforce FatCat native approval boundary"
```

### Task 5: Replace Electron activity handling with generic Hermes events

**Files:**
- Modify: `electron/src/renderer/src/lib/chat-reducer.ts`
- Modify: `electron/src/renderer/src/hooks/use-fatcat.ts`
- Modify: `electron/src/renderer/src/components/turn-activity.tsx`
- Modify: `electron/src/shared/api.ts`
- Test: `electron/src/renderer/src/lib/chat-reducer.test.ts`, `electron/src/renderer/src/components/turn-activity.test.tsx`

- [ ] **Step 1: Write failing reducer tests.** Feed `tool.started`, `tool.progress`, `tool.needs_approval`, `tool.completed`, `tool.failed`, and `verification.completed` events and assert one generic activity row transitions through the expected states without inspecting the tool name.

- [ ] **Step 2: Reduce v2 events.** Add a single event reducer keyed by `session_id`/`request_id`/tool ID. Keep message deltas volatile in renderer state and source reloads from Hermes history.

- [ ] **Step 3: Render approval generically.** Update `TurnActivity` and the approval surface to show summary, risk, and sanitized details with Approve/Deny actions that send the proposal ID back to the daemon.

- [ ] **Step 4: Remove transcript assumptions.** Stop reading `conversation.messages` from the daemon snapshot. On selection/reconnect, request Hermes session history and rebuild the renderer transcript from `session_history` events.

- [ ] **Step 5: Run Electron tests/build.**

Run: `npm --prefix electron test -- src/renderer/src/lib/chat-reducer.test.ts src/renderer/src/components/turn-activity.test.tsx` and `npm --prefix electron run build`

Expected: PASS and a production build with no local memory/planner imports.

- [ ] **Step 6: Commit Electron migration.**

```bash
git add electron/src/renderer/src electron/src/shared
git commit -m "refactor: render generic Hermes activity events"
```

### Task 6: Migrate native pet and mini-chat to Hermes history/events

**Files:**
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift`
- Modify: `macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatChatState.swift`
- Test: `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatChatStateTests.swift`, `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/FatCatMiniChatTests.swift`, `macos/PeppaAnywhere/Tests/PeppaAnywhereCoreTests/PeppaIPCTests.swift`

- [ ] **Step 1: Write failing Swift synchronization tests.** Assert a conversation snapshot cannot provide message bodies, Hermes session history reconstructs the visible transcript, duplicate events are ignored, and two subscribers receive the same session-scoped state.

- [ ] **Step 2: Make chat state volatile.** Keep current visible messages only in memory for rendering/TTS. Remove persistence and snapshot restoration from local records. Load/reload through Hermes `session_history` events.

- [ ] **Step 3: Map generic events to presence.** Map message/tool/approval/verification lifecycle to existing avatar states; do not add tool-specific branches. Keep pet click and mini-chat controls as FatCat surface commands.

- [ ] **Step 4: Run Swift chat tests.**

Run: `./scripts/swift-test.sh --filter FatCatChatState`

Expected: PASS with a clean relaunch restoring only the Hermes session and replayed history.

- [ ] **Step 5: Commit native surface migration.**

```bash
git add macos/PeppaAnywhere/Sources/PeppaAnywhere/AppMain.swift macos/PeppaAnywhere/Sources/PeppaAnywhereCore/FatCatChatState.swift
git commit -m "refactor: drive native chat from Hermes events"
```

### Task 7: Remove the legacy local agent framework from the browser product path

**Files:**
- Modify: `src/components/CompanionDashboard.tsx`
- Modify: product entry/routing files that mount `CompanionDashboard`
- Delete: `src/lib/brain.ts`, `src/lib/memory.ts`, `src/lib/goals.ts`, `src/lib/learning.ts`
- Delete: tests that assert local memory/goals/learning behavior
- Create: `src/components/HermesEventActivity.tsx`
- Create: `src/components/HermesEventActivity.test.tsx`

- [ ] **Step 1: Write failing source-boundary tests.** Assert the active product entry does not import the local memory, goals, learning, planner, dialogue, critic, or local tool policy modules.

- [ ] **Step 2: Replace the dashboard controls.** Remove local memory compose/delete, goal creation, learning-record writes, local planner/critic calls, and demo approval queue. Render screen context, Hermes event activity, and FatCat approval state from the shared adapter.

- [ ] **Step 3: Preserve the avatar lab only.** Keep reusable avatar preview/gallery code, but label it as a visual lab with no agent state, memory, or action execution.

- [ ] **Step 4: Remove obsolete modules/tests.** Delete the local agent modules and tests after all imports are removed; keep native privacy/observation helpers only where they feed Hermes as filtered context.

- [ ] **Step 5: Run root checks.**

Run: `npm test -- src/lib/ownership-boundary.test.ts`

Expected: PASS with no active product import or storage key for local agent state.

- [ ] **Step 6: Commit legacy cleanup.**

```bash
git add src/components src/lib package.json
git commit -m "refactor: remove FatCat local agent systems"
```

### Task 8: Retire existing local content data idempotently

**Files:**
- Create: `src/lib/retirement.ts`
- Create: `src/lib/retirement.test.ts`
- Modify: Electron/native startup migration entry points
- Modify: `agent/peppa_agent/conversations.py` migration marker handling

- [ ] **Step 1: Write failing retirement tests.** Given legacy localStorage keys and transcript JSON, assert the migration removes content keys/fields, preserves UI/session metadata, writes one schema marker, and produces the same result when run twice.

- [ ] **Step 2: Implement `retireFatCatContent`.** Accept explicit storage/filesystem adapters, remove `peppa-anywhere-memory-v1`, goals, learning, and transcript message arrays, retain only non-content session handles, and write a versioned timestamp marker. Never call Hermes import APIs.

- [ ] **Step 3: Gate startup on the marker.** Invoke the migration before any renderer/native state hydration. If retirement fails, surface a blocking migration error and do not load legacy content.

- [ ] **Step 4: Run migration tests.**

Run: `npm test -- src/lib/retirement.test.ts` and `PYTHONPATH=agent python3 -m unittest agent/tests/test_conversations.py`

Expected: PASS for first-run, already-retired, malformed, and interrupted migration cases.

- [ ] **Step 5: Commit data retirement.**

```bash
git add src/lib/retirement.ts src/lib/retirement.test.ts agent/peppa_agent/conversations.py
git commit -m "feat: retire duplicate FatCat content state"
```

### Task 9: Documentation, compatibility removal, and full verification

**Files:**
- Modify: `README.md`, `agent/README.md`, `docs/PEPPA-ANYWHERE.md`
- Modify: `docs/superpowers/specs/2026-09-01-fatcat-hermes-boundary-migration-design.md`
- Modify: `docs/superpowers/plans/2026-09-01-fatcat-hermes-boundary-migration.md`
- Delete: v1 compatibility code after supported-client cutover
- Test: repository verification scripts

- [ ] **Step 1: Update ownership documentation.** State Hermes as source of truth for sessions/history/memory/planning/tools and FatCat as source of truth for channels/presence/native safety. Document retired data and no local fallback.

- [ ] **Step 2: Run code-search acceptance checks.**

Run: `rg -n "append_message|append_assistant_delta|merge_history|peppa-anywhere-memory-v1|createGoal|PlannerAdapter|MemoryAdapter" agent electron/src macos/PeppaAnywhere/Sources src -g '!**/.build/**'`

Expected: only migration tests/docs or explicit retirement references remain; no active runtime path uses these symbols.

- [ ] **Step 3: Run the complete matrix.**

```bash
npm test
npm --prefix electron test
./scripts/swift-test.sh
PYTHONPATH=agent python3 -m unittest discover -s agent/tests
bash scripts/test-hermes-bundle.sh
```

Expected: all commands pass; bundle verification confirms no developer Hermes data, auth files, API-key literals, or transcript fallback are packaged.

- [ ] **Step 4: Run the shared-session smoke test.** Start one daemon, connect native and Electron clients to one Hermes session, stream a response, exercise tool progress, approve/deny one risky action, reconnect one client, restart the daemon, and verify history comes only from Hermes.

- [ ] **Step 5: Remove v1 compatibility.** After the smoke test proves all supported clients use v2, remove the v1 decoder and old event branches, then rerun the complete matrix.

- [ ] **Step 6: Commit release verification.**

```bash
git add README.md agent/README.md docs/PEPPA-ANYWHERE.md electron/src/shared macos/PeppaAnywhere/Sources/PeppaAnywhereCore
git commit -m "docs: finalize Hermes-first FatCat boundary"
```

## Plan self-review

- **Spec coverage:** Ownership/topology is covered by Tasks 1, 3, 5, 6, and 7; generic events by Tasks 1–6; native safety by Task 4; retirement by Task 8; errors/reconnect by Tasks 3–6; verification by Task 9.
- **Completeness:** Every spec requirement maps to concrete paths, symbols, tests, commands, expected outcomes, and commit points.
- **Type consistency:** The v2 envelope uses `event_id`, `kind`, `session_id`, `request_id`, `summary`, and `details` consistently across Python, TypeScript, and Swift. Approval correlation uses the same proposal ID through adapter, UI, executor, and Hermes outcome.
- **Scope:** The work is intentionally staged by subsystem, but every task produces a testable boundary and the final matrix verifies the complete migration.
