# FatCat Shared Agent and Native Mini-Chat MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the native pet and Electron chat to one persistent FatCat Agent, then add a compact native latest-exchange chat with voice, size, movement, and animation controls.

**Architecture:** A user LaunchAgent owns the sole Python FatCat Agent. The Python server accepts multiple identified clients, owns canonical conversation metadata, and broadcasts session and Hermes events. Swift and Electron connect without spawning or shutting down the daemon; Swift renders a separate mini-chat panel while Electron retains the full workspace.

**Tech Stack:** Python asyncio and unittest, Unix sockets and launchd, Swift 6/AppKit/SwiftUI/Speech/AVFoundation, Electron 44/TypeScript/React/Vitest, newline-delimited JSON.

---

## File map

- `agent/fatcat_agent/server.py` — multi-client server, broadcasts, canonical conversations, singleton-safe lifecycle.
- `agent/fatcat_agent/conversations.py` — atomic canonical conversation index and explicit session attachment.
- `agent/tests/test_server.py` — multi-client, broadcast, reconnect, and explicit-session behavior.
- `agent/tests/test_conversations.py` — conversation persistence and no-duplicate-session rules.
- `protocol/fatcat-events.schema.json` — shared protocol source of truth.
- `scripts/install-fatcat-launch-agent.sh` — install/bootstrap the user LaunchAgent with explicit local paths.
- `scripts/uninstall-fatcat-launch-agent.sh` — boot out and remove only FatCat's plist.
- `electron/src/shared/protocol.ts` — TypeScript schemas for client identity and shared conversation events.
- `electron/src/main/agent/socket-transport.ts` — identified reconnecting connection to shared socket.
- `electron/src/main/index.ts` — connect-only Electron bootstrap; no process ownership.
- `electron/src/main/agent/fatcat-service.ts` — agent-owned conversation snapshots and shared transcript events.
- `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift` — Swift protocol parity.
- `macos/FatCat/Sources/FatCatCore/FatCatPetSettings.swift` — persisted size, movement, speech, and preview settings.
- `macos/FatCat/Sources/FatCatCore/FatCatMiniChat.swift` — pure latest-exchange and toggle state.
- `macos/FatCat/Sources/FatCat/AppMain.swift` — connect-only Swift client, mini-chat panel, settings UI, movement cadence, speech input, and TTS.
- matching Python, Vitest, and Swift test files — behavior contracts.

### Task 1: Canonical conversations and multi-client agent

**Files:**
- Create: `agent/fatcat_agent/conversations.py`
- Create: `agent/tests/test_conversations.py`
- Modify: `agent/fatcat_agent/server.py`
- Modify: `agent/tests/test_server.py`

- [ ] **Step 1: Write failing persistence tests**

Add tests proving that `create()` is the only operation that creates a record,
`attach_session()` is idempotent for the same ID and rejects replacement, and a
reopened store preserves selection/session IDs.

```python
with tempfile.TemporaryDirectory() as root:
    store = ConversationStore(Path(root) / "conversations.json")
    record = store.create("conversation-1", "New chat", root)
    store.attach_session(record["id"], "session-1")
    store.attach_session(record["id"], "session-1")
    with self.assertRaises(SessionConflict):
        store.attach_session(record["id"], "session-2")
    self.assertEqual(ConversationStore(store.path).snapshot()["records"][0]["session_id"], "session-1")
```

- [ ] **Step 2: Run tests and verify RED**

Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_conversations -v`
Expected: import failure for `fatcat_agent.conversations`.

- [ ] **Step 3: Implement the atomic store**

Use a lock, write JSON to a sibling temporary file, `os.replace`, normalize
titles/workspaces, and expose `snapshot`, `create`, `select`, `attach_session`,
`rename`, and `delete`. Never replace a nonempty session ID.

- [ ] **Step 4: Write failing multi-client tests**

Start `FatCatAgentServer` with a fake session manager, connect native and Electron
clients, hello as distinct roles, send `pet_clicked`, and assert both receive it.
Disconnect one and assert the other remains connected. Send duplicate
`pet_clicked` event IDs and assert one broadcast.

- [ ] **Step 5: Run server tests and verify RED**

Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_server -v`
Expected: second client is rejected and shared event types are unsupported.

- [ ] **Step 6: Implement multi-client routing**

Replace `active_writer` with client records keyed by generated connection ID.
Require `hello.client` to be `native_pet` or `electron_chat`; return
`hello_ack.client_id`. Broadcast Hermes events, state, conversation snapshots,
and `pet_clicked`. Dedupe event IDs with a bounded 256-entry set. Make
`shutdown` test-only/admin-only so a normal client cannot terminate the daemon.

- [ ] **Step 7: Run Python tests and commit**

Run: `PYTHONPATH=agent python3 -m unittest discover -s agent/tests -v`
Expected: all tests pass.

Commit: `feat: make FatCat Agent a shared conversation daemon`

### Task 2: Install the persistent user LaunchAgent

**Files:**
- Create: `scripts/install-fatcat-launch-agent.sh`
- Create: `scripts/uninstall-fatcat-launch-agent.sh`
- Create: `agent/tests/test_launch_agent_scripts.py`
- Modify: `agent/README.md`

- [ ] **Step 1: Write failing script contract tests**

Assert the installer uses label `com.fatcat.agent`, writes beneath
`~/Library/LaunchAgents`, passes the shared socket and Hermes home, sets
`RunAtLoad` and `KeepAlive`, and uses `launchctl bootstrap`/`kickstart`. Assert
the uninstaller targets only that exact label/plist.

- [ ] **Step 2: Run tests and verify RED**

Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_launch_agent_scripts -v`
Expected: scripts are missing.

- [ ] **Step 3: Implement safe install/uninstall scripts**

Resolve the repository and executable to absolute paths, create only
`~/Library/Application Support/FatCat/{runtime,Hermes}`, render a plist with
escaped values, validate it with `plutil -lint`, then bootstrap/kickstart the
current GUI domain. The uninstall script boots out and removes only
`com.fatcat.agent.plist`; it preserves Hermes and conversations.

- [ ] **Step 4: Verify and commit**

Run: `bash -n scripts/install-fatcat-launch-agent.sh scripts/uninstall-fatcat-launch-agent.sh`
Run: `PYTHONPATH=agent python3 -m unittest agent.tests.test_launch_agent_scripts -v`
Expected: both pass.

Commit: `feat: install FatCat Agent as a user LaunchAgent`

### Task 3: Align TypeScript and Swift protocols

**Files:**
- Modify: `electron/src/shared/protocol.ts`
- Modify: `electron/src/shared/protocol.test.ts`
- Modify: `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift`
- Modify: `protocol/fatcat-events.schema.json`

- [ ] **Step 1: Add failing codec tests**

Cover identified hello/ack, `pet_clicked`, `conversation_snapshot`,
`conversation_selected`, `message_added`, and an agent state carrying
conversation/session/request IDs. Verify credential rejection remains intact.

- [ ] **Step 2: Run both protocol suites and verify RED**

Run: `npm --prefix electron test -- src/shared/protocol.test.ts`
Run: `swift test --package-path macos/FatCat --filter FatCatIPCTests`
Expected: new messages are rejected/unknown.

- [ ] **Step 3: Implement protocol parity**

Add strict Zod schemas and Swift enum/codec cases with identical snake-case wire
names and required fields. Update the JSON schema union to match.

- [ ] **Step 4: Verify and commit**

Run the two commands from Step 2.
Expected: both pass.

Commit: `feat: define shared FatCat client protocol`

### Task 4: Make Electron a connect-only shared client

**Files:**
- Modify: `electron/src/main/agent/socket-transport.ts`
- Modify: `electron/src/main/agent/socket-transport.test.ts`
- Modify: `electron/src/main/agent/fatcat-service.ts`
- Modify: `electron/src/main/agent/fatcat-service.test.ts`
- Modify: `electron/src/main/index.ts`
- Modify: `electron/src/shared/api.ts`

- [ ] **Step 1: Write failing connection/lifecycle tests**

Assert Electron sends `hello.client = electron_chat`, reconnects to the shared
socket, applies an agent conversation snapshot, and closing Electron calls only
`transport.close()`—never `shutdown`, child kill, socket removal, or session
creation.

- [ ] **Step 2: Run targeted Vitest and verify RED**

Run: `npm --prefix electron test -- src/main/agent/socket-transport.test.ts src/main/agent/fatcat-service.test.ts`
Expected: private supervisor ownership and local repository assumptions fail.

- [ ] **Step 3: Implement connect-only bootstrap/service**

Use `~/Library/Application Support/FatCat/runtime/fatcat-agent.sock` unless
`FATCAT_AGENT_SOCKET` is set. Keep bounded reconnect. Make daemon snapshots the
source for conversations and selected ID. Continue rendering the full transcript
from shared message/state events.

- [ ] **Step 4: Verify Electron and commit**

Run: `npm --prefix electron test`
Run: `npm --prefix electron run typecheck`
Run: `npm --prefix electron run build`
Expected: all pass.

Commit: `feat: connect Electron to shared FatCat Agent`

### Task 5: Make Swift connect-only and preserve the pet panel

**Files:**
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/FatCatAvatarContractTests.swift`

- [ ] **Step 1: Write failing lifecycle/window tests**

Assert `FatCatAgentClient` contains no `Process`, `process.run`, `terminate`,
`shutdown`, or socket deletion. Assert the pet panel is created at the persisted
square size and no click path calls `setContentSize`. Assert stop closes only the
client socket.

- [ ] **Step 2: Run tests and verify RED**

Run: `swift test --package-path macos/FatCat --filter FatCatAvatarContractTests`
Expected: existing process ownership and resize-to-chat code violate contracts.

- [ ] **Step 3: Implement connect-only Swift client**

Connect to the shared socket, hello as `native_pet`, retry with bounded delay,
and expose clear connection state. Remove native process ownership and full-chat
resizing. Keep the pet panel visible and unchanged through click/message flows.

- [ ] **Step 4: Verify and commit**

Run the command from Step 2.
Expected: pass.

Commit: `feat: connect native pet to shared FatCat Agent`

### Task 6: Build the native latest-exchange mini-chat

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/FatCatMiniChat.swift`
- Create: `macos/FatCat/Tests/FatCatCoreTests/FatCatMiniChatTests.swift`
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`

- [ ] **Step 1: Write failing pure-state tests**

Test click toggling, duplicate click idempotence, latest user/assistant exchange,
stream accumulation, disconnected state, and close behavior.

- [ ] **Step 2: Run and verify RED**

Run: `swift test --package-path macos/FatCat --filter FatCatMiniChatTests`
Expected: type is missing.

- [ ] **Step 3: Implement state and separate panel**

Add a borderless non-fullscreen `NSPanel` positioned beside the pet and flipped
at screen edges. Render only the latest exchange, concise state, compact composer,
and round microphone/close/speaker buttons. Pet click toggles the panel locally
and sends `pet_clicked`; a second click hides it. Never resize or move the pet.

- [ ] **Step 4: Verify and commit**

Run: `swift test --package-path macos/FatCat`
Expected: pass.

Commit: `feat: add native FatCat mini chat`

### Task 7: Add size, movement, emotions, and voice

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/FatCatPetSettings.swift`
- Create: `macos/FatCat/Tests/FatCatCoreTests/FatCatPetSettingsTests.swift`
- Modify: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Package.swift`

- [ ] **Step 1: Write failing settings tests**

Test size clamping/default/persistence, Off/Calm/Playful cadence, speech flags,
preview animation validation, and preservation of the pet's anchor while sizing.

- [ ] **Step 2: Run and verify RED**

Run: `swift test --package-path macos/FatCat --filter FatCatPetSettingsTests`
Expected: settings types are missing.

- [ ] **Step 3: Implement settings and UI**

Add native Settings with a 120–360 slider, movement picker, spoken-reply toggle,
and Advanced animation preview. Persist values in `UserDefaults`. Feed Calm and
Playful cadence/distance into the existing safe flight policy; Off disables only
autonomous flights.

- [ ] **Step 4: Add speech and TTS test seams**

Define small protocols around recognition and synthesis. Test that mic toggles
listening, final transcription sends once, denial reports a clear status, reply
completion speaks only when enabled, and flight pauses while listening/speaking.

- [ ] **Step 5: Implement native voice**

Use Speech + AVFoundation, request permissions explicitly, show listening and
speaking states, and stop cleanly on panel close or user toggle.

- [ ] **Step 6: Verify and commit**

Run: `swift test --package-path macos/FatCat`
Run: `swift build --package-path macos/FatCat`
Expected: both pass.

Commit: `feat: add FatCat pet controls and voice`

### Task 8: Integration verification and docs

**Files:**
- Modify: `agent/tests/test_server.py`
- Modify: `electron/src/test/fake-agent.ts`
- Modify: `README.md`
- Modify: `agent/README.md`

- [ ] **Step 1: Add end-to-end fixture assertions**

Connect simulated native and Electron clients, select one conversation, send
from native, assert both receive the same session/message/state stream, disconnect
each client independently, reconnect, and prove no new conversation/session.

- [ ] **Step 2: Run the full verification matrix**

Run:

```bash
PYTHONPATH=agent python3 -m unittest discover -s agent/tests -v
npm --prefix electron test
npm --prefix electron run typecheck
npm --prefix electron run build
swift test --package-path macos/FatCat
swift build --package-path macos/FatCat
bash -n scripts/install-fatcat-launch-agent.sh scripts/uninstall-fatcat-launch-agent.sh
git diff --check
```

Expected: every command exits zero with no test failures.

- [ ] **Step 3: Manual smoke test**

Install/kickstart the LaunchAgent, launch both clients, verify one agent PID,
native mini-chat toggle and latest exchange, live Electron synchronization,
voice input/output, size range, movement modes, animation preview, disconnect
states, and independent client closure.

- [ ] **Step 4: Document and commit**

Document install, run, connection paths, voice permissions, settings, and safe
uninstall without claiming release packaging.

Commit: `docs: explain shared FatCat MVP workflow`
