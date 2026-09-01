# FatCat Incremental Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hermes assistant output arrive and render incrementally in the native mini-chat and Electron workspace without session jumping, duplicate assistant messages, or history replay being mistaken for a live turn.

**Architecture:** Keep the daemon as the single Hermes owner and emit ordered, request/session-tagged chunks for ACP and legacy Hermes callbacks. Serialize and guard those events in the Electron service and native handler, then publish each accepted update to the existing renderer/native transcript state. Protect the renderer’s initial snapshot race so a delayed load cannot overwrite an already-received live update.

**Tech Stack:** Python `asyncio`/unittest, TypeScript/Zod/Vitest, React/Vitest Testing Library, Swift 6/SwiftUI/custom Testing runner.

---

## File map

- Modify `agent/fatcat_agent/server.py`: emit explicit live message lifecycle events for ACP and legacy streams and preserve request IDs through completion/failure.
- Modify `agent/tests/test_server.py`: delayed ACP/legacy stream fixtures and ordering/failure assertions.
- Modify `electron/src/main/agent/fatcat-service.ts`: reject stale Hermes request/session events, deduplicate event IDs, and complete/fail one assistant message.
- Modify `electron/src/main/agent/fatcat-service.test.ts`: incremental v1/v2, stale-event, completion, failure, and history-isolation tests.
- Modify `electron/src/renderer/src/hooks/use-fatcat.ts` and `electron/src/renderer/src/lib/chat-reducer.ts`: prevent the startup snapshot from replacing a live bridge update.
- Modify `electron/src/renderer/src/lib/chat-reducer.test.ts` and add/update `electron/src/renderer/src/hooks/use-fatcat.test.tsx`: delayed snapshot/live event race coverage.
- Modify `macos/FatCat/Sources/FatCat/AppMain.swift`: preserve the selected native conversation across shared snapshots, gate history replay, and enforce live request/session matching.
- Modify `macos/FatCat/Sources/FatCatCore/FatCatChatState.swift` only if a small pure guard is needed by the native handler; keep transcript mutation in the existing state type.
- Modify `macos/FatCat/Tests/FatCatCoreTests/FatCatChatStateTests.swift`: stable-message, stale-request, and replay-isolation tests for the pure transcript policy.
- Modify `README.md`: document the incremental stream contract and verification commands.

### Task 1: Lock down delayed daemon streaming behavior

**Files:**
- Test: `agent/tests/test_server.py`
- Modify: `agent/fatcat_agent/server.py`

- [ ] **Step 1: Add failing delayed-stream tests.** Create fake agents whose first chunk is released by an `asyncio.Event`, record `time.monotonic()` in the async emitter, and assert the first `message.delta` precedes the second chunk and completion by at least the controlled delay. Cover both `stream_delta_callback` (legacy) and ACP `agent_message_chunk`.

```python
async def wait_for_kind(events, kind):
    while True:
        for event in events:
            if event.get("kind") == kind:
                return event
        await asyncio.sleep(0)

async def test_legacy_chunks_are_emitted_before_turn_completion(self):
    release = threading.Event()
    times = []

    class Agent:
        def run_conversation(self, *args, **kwargs):
            self.stream_delta_callback("first ")
            release.wait(1)
            self.stream_delta_callback("second")
            return {"messages": [], "final_response": "first second"}

    async def emit(event):
        times.append((event.get("kind"), event.get("details", {}).get("text"), time.monotonic()))

    state = SimpleNamespace(agent=Agent(), history=[], cancel_event=threading.Event())
    session = FatCatAgentSession("s1", ".", emit, asyncio.get_running_loop(), state)
    task = asyncio.create_task(session.prompt("r1", "hello"))
    await asyncio.sleep(0.02)
    self.assertEqual([item[1] for item in times if item[0] == "message.delta"], ["first "])
    release.set()
    await task
    self.assertEqual([item[1] for item in times if item[0] == "message.delta"], ["first ", "second"])
    self.assertEqual(times[-1][0], "session.state")
```

Add the analogous ACP test with an async fake `prompt` that calls the bridge with two delayed `agent_message_chunk` updates. Add a partial-failure assertion that already-emitted text remains observable and the terminal state is `failed`.

- [ ] **Step 2: Run the focused tests and verify they expose the missing lifecycle/order behavior.**

Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_server.ServerTests.test_legacy_chunks_are_emitted_before_turn_completion -v` (and the ACP test name).

Expected: the new tests fail until the event lifecycle is made explicit and deterministic.

- [ ] **Step 3: Implement the minimal daemon lifecycle.** In `FatCatAgentSession.prompt`, emit `message.started` immediately after the `sending` state and emit `message.completed` immediately before a successful completed state. On failure emit `session.error`/v1 `error` as currently appropriate, then emit `message.completed` only for success and `session.state(failed)` for failure. Keep each delta emitted at callback arrival; do not accumulate text. Ensure the legacy callback is cleared in a `finally` block so a later request cannot receive an old callback.

```python
await self.emit(self._state_event("sending", request_id))
await self.emit(_hermes_event("message.started", self.session_id, request_id, "Assistant response started"))
try:
    if self.acp_agent is not None:
        response = await self.acp_agent.prompt(prompt=[TextContentBlock(type="text", text=text)], session_id=self.session_id)
        succeeded = getattr(response, "stop_reason", None) == "end_turn"
    else:
        succeeded = await asyncio.to_thread(self._run, request_id, text)
    if succeeded:
        await self.emit(_hermes_event("message.completed", self.session_id, request_id, "Assistant response completed"))
    await self.emit(self._state_event("completed" if succeeded else "failed", request_id))
finally:
    if self.agent is not None:
        self.agent.stream_delta_callback = None
    self.current_request_id = None
```

Preserve the existing v1 compatibility events and credential filtering. Keep `message.started`/`message.completed` request- and session-tagged so native and Electron can share the same lifecycle.

- [ ] **Step 4: Run daemon tests and commit.**

Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_server -v`

Expected: all server tests pass, including the new delayed ACP/legacy and partial-failure cases.

Commit: `git add agent/fatcat_agent/server.py agent/tests/test_server.py && git commit -m "feat: emit incremental Hermes message lifecycle"`

### Task 2: Make Electron service request-safe and incrementally observable

**Files:**
- Test: `electron/src/main/agent/fatcat-service.test.ts`
- Modify: `electron/src/main/agent/fatcat-service.ts`
- Test: `electron/src/main/agent/socket-transport.test.ts` if a decoder assertion is required

- [ ] **Step 1: Add failing service tests for each accepted snapshot.** After starting one session and sending one prompt, emit v1 deltas and v2 `message.started`/`message.delta` events with `await vi.waitFor` after each event. Assert the first snapshot contains only the first chunk, the second contains the concatenation, and both have one assistant row. Add tests for a delayed initial `conversation_snapshot`/`session_history`, a v2 delta from another request, a duplicate `event_id`, v2 completion, and partial v2 failure.

```ts
transport.event({ version: 2, event_id: 'd1', kind: 'message.delta', session_id: 's1', request_id: request, summary: 'A', details: { text: 'A' } })
await vi.waitFor(async () => expect((await service.snapshot()).messages.at(-1)?.text).toBe('A'))
transport.event({ version: 2, event_id: 'd2', kind: 'message.delta', session_id: 's1', request_id: request, summary: 'AB', details: { text: 'B' } })
await vi.waitFor(async () => expect((await service.snapshot()).messages.at(-1)?.text).toBe('AB'))
expect((await service.snapshot()).messages.filter((item) => item.role === 'assistant')).toHaveLength(1)
```

Assert that a stale request delta does not create or mutate an assistant, a completion for an unknown request is ignored, duplicate `event_id` appends once, and a failure keeps partial text plus `errorMessage`.

- [ ] **Step 2: Run the focused service tests to confirm the stale v2 behavior fails.**

Run: `npm --prefix electron test -- src/main/agent/fatcat-service.test.ts`

Expected: new request/session guard tests fail against the current v2 path, which appends any same-session request and can create an assistant on an unknown completion.

- [ ] **Step 3: Implement a single request acceptance gate.** Add a private method that accepts a Hermes event only when the selected conversation owns `event.session_id`, the request is active or is explicitly starting via `message.started`/first delta, and the request is not in `ignoredRequestIds`. Use it in every v2 branch. For `message.started`, establish `activeRequestId` and call `ensureAssistant` once; for `message.delta`, reject when an active different request exists; for `message.completed`, reject unknown/stale requests, mark the existing assistant non-streaming, update preview, and clear the active request. Keep v1 guards aligned with the same method. Continue serializing through `eventChain` and the existing `seenHermesEventIds` set.

```ts
private acceptsLiveRequest(sessionId: string, requestId: string | null): requestId is string {
  if (!requestId) return false
  const document = this.options.repository // use the selected record resolved by the caller
  if (this.ignoredRequestIds.has(requestId)) return false
  return this.activeRequestId === null || this.activeRequestId === requestId
}
```

The implementation must resolve and compare the selected Hermes session before calling this helper; never infer a request from a history event. Keep completion and failure terminal operations idempotent.

- [ ] **Step 4: Run the focused service suite and commit.**

Run: `npm --prefix electron test -- src/main/agent/fatcat-service.test.ts src/main/agent/socket-transport.test.ts`

Expected: all existing and new tests pass, with one assistant row and snapshots observable between delayed chunks.

Commit: `git add electron/src/main/agent/fatcat-service.ts electron/src/main/agent/fatcat-service.test.ts electron/src/main/agent/socket-transport.test.ts && git commit -m "fix: guard incremental Electron Hermes streams"`

### Task 3: Prevent the renderer startup snapshot from overwriting live output

**Files:**
- Modify: `electron/src/renderer/src/hooks/use-fatcat.ts`
- Modify: `electron/src/renderer/src/lib/chat-reducer.ts`
- Test: `electron/src/renderer/src/lib/chat-reducer.test.ts`
- Test: `electron/src/renderer/src/hooks/use-fatcat.test.tsx`

- [ ] **Step 1: Add a reducer/hook race test.** Use a deferred `snapshot()` promise. Subscribe first, dispatch a snapshot containing the first live chunk, then resolve the initial promise with an older empty snapshot; assert the live text remains. Add a reducer test that a `loaded` action after a bridge snapshot cannot replace it.

```ts
const deferred = Promise.withResolvers<AppSnapshot>()
const api = { ...fakeApi, snapshot: () => deferred.promise }
renderHook(() => useFatCat(), { wrapper: bridgeProvider(api) })
emit({ type: 'snapshot', snapshot: liveSnapshot('partial') })
deferred.resolve(emptySnapshot())
await waitFor(() => expect(result.current.state.snapshot?.messages.at(-1)?.text).toBe('partial'))
```

- [ ] **Step 2: Run the focused renderer tests and verify the race fails.**

Run: `npm --prefix electron test -- src/renderer/src/lib/chat-reducer.test.ts src/renderer/src/hooks/use-fatcat.test.tsx`

Expected: the delayed initial `loaded` action replaces the live bridge snapshot before the fix.

- [ ] **Step 3: Implement bridge precedence.** Track whether a bridge event has arrived during the current hook subscription (or encode the same precedence in reducer state). Dispatch the initial `loaded` snapshot only when no bridge event has arrived; bridge snapshots remain authoritative afterward. Keep unsubscribe/active guards and error handling unchanged.

- [ ] **Step 4: Run renderer tests and commit.**

Run: `npm --prefix electron test -- src/renderer/src/lib/chat-reducer.test.ts src/renderer/src/hooks/use-fatcat.test.tsx src/renderer/src/components/conversation.test.tsx`

Expected: the delayed snapshot cannot erase partial text; Markdown and cursor tests remain green.

Commit: `git add electron/src/renderer/src/hooks/use-fatcat.ts electron/src/renderer/src/lib/chat-reducer.ts electron/src/renderer/src/lib/chat-reducer.test.ts electron/src/renderer/src/hooks/use-fatcat.test.tsx && git commit -m "fix: preserve live renderer snapshots"`

### Task 4: Stop native mini-chat session jumps and replay duplication

**Files:**
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatChatStateTests.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/FatCatChatState.swift` only if the pure acceptance helper is added

- [ ] **Step 1: Add pure transcript acceptance tests.** Cover one assistant ID for multiple deltas, stale request rejection while another request is active, completion idempotency, and partial failure preservation. If the existing `FatCatTranscriptState` API is sufficient, keep tests at the mutation level and put session/request gating in a small pure helper with an explicit return value.

```swift
@Test func staleLiveRequestCannotChangeTheActiveTranscript() {
    var transcript = FatCatTranscriptState()
    _ = transcript.beginAssistant(requestID: "r1")
    transcript.appendAssistantDelta(requestID: "r1", text: "live")
    #expect(FatCatLiveRequestPolicy.accept(activeRequestID: "r1", incomingRequestID: "r2") == false)
    #expect(transcript.messages.last?.text == "live")
}
```

- [ ] **Step 2: Run the focused Swift tests before changing AppMain.**

Run: `./scripts/swift-test.sh --filter FatCatChatStateTests` (if the runner does not support filters, run `./scripts/swift-test.sh` and record the baseline).

Expected: the new policy test fails until the helper exists; existing transcript tests remain green.

- [ ] **Step 3: Preserve native selection and gate live events.** In `handleAgentMessage(.conversationSnapshot)`, update conversation metadata without clearing `model.messages` when the effective selected conversation and Hermes session are unchanged. Only clear/reload when the selected record/session actually changes. Require `sessionID == activeSessionID` for `sessionHistory`; accept history only while that session is being restored, deduplicate repeated role/text records during that restore, and stop accepting replay after `sessionLoaded`. For v1/v2 live messages, require the active selected session and either the current request or an explicit `message.started`; ignore stale/ignored request IDs. Route `message.completed`, `session.state(completed)`, and failures through the existing `PetModel` terminal methods so the partial text remains visible.

- [ ] **Step 4: Run Swift tests and a native bounded smoke check.**

Run: `./scripts/swift-test.sh` and `./scripts/run-fatcat-macos.sh` with a configured test provider or a fixture agent that emits two delayed chunks. Confirm the mini-chat stays on one selected conversation, displays the first chunk before the second, and does not duplicate restored history.

Expected: all Swift tests pass and the smoke transcript remains stable across shared conversation snapshots.

Commit: `git add macos/FatCat/Sources/FatCat/AppMain.swift macos/FatCat/Sources/FatCatCore/FatCatChatState.swift macos/FatCat/Tests/FatCatCoreTests/FatCatChatStateTests.swift && git commit -m "fix: isolate native incremental chat streams"`

### Task 5: Document and verify the streaming contract

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Document that both clients receive live request/session-tagged chunks, that history snapshots are not live deltas, and that the daemon remains single-owner.** Include focused commands for Python, Electron, and Swift tests.

- [ ] **Step 2: Run all focused suites plus static checks.**

Run:

```bash
PYTHONPATH=agent python3 -m unittest agent.tests.test_server -v
npm --prefix electron test -- src/main/agent/fatcat-service.test.ts src/renderer/src/lib/chat-reducer.test.ts src/renderer/src/components/conversation.test.tsx
npm --prefix electron run typecheck
./scripts/swift-test.sh
git diff --check
```

Expected: all focused tests pass, TypeScript typecheck succeeds, Swift tests pass, and `git diff --check` is clean.

- [ ] **Step 3: Commit documentation.**

Commit: `git add README.md && git commit -m "docs: describe incremental FatCat streaming"`
