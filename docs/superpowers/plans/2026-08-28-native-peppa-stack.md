# Native FatCat Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans (inline execution). Steps use checkbox (`- [ ]`) syntax.

**Goal:** Replace the prototype’s WebKit/React surface and external ACP launch with a native Swift FatCat pet backed by a bundled FatCatAgent Hermes distribution over a Unix domain socket.

**Architecture:** The Swift app owns the transparent AppKit panel, native SwiftUI Canvas avatar, perception, privacy/risk engine, local audit database, and action executor. A bundled Python FatCatAgent process owns the Hermes agent loop, providers, skills, memory, and model routing; Swift and the agent exchange versioned newline-delimited JSON messages over a private Unix socket. The existing avatar JSON remains the source data, but the renderer is ported to native Swift.

**Tech Stack:** Swift 6, SwiftUI Canvas, Core Animation/TimelineView, AppKit, ScreenCaptureKit, Accessibility, Vision, NSWorkspace, Swift Testing/XCTest, Python, pinned Hermes source, Unix sockets, GRDB/SQLite with a Keychain-held database key, PyInstaller or an equivalent self-contained Python bundle.

---

### Task 1: Add failing native avatar, IPC, and provider-discovery contracts

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/FatCatAvatar.swift`
- Create: `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift`
- Create: `macos/FatCat/Sources/FatCatCore/ProviderDiscovery.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/NativeAvatarTests.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/ProviderDiscoveryTests.swift`

- [ ] Write tests that load the real avatar JSON, preserve all 23 animation keys and 28 expression keys, produce a nonempty native frame for `idle`, and interpolate `thinking` without changing the definition.
- [ ] Write tests for versioned typed messages, newline-delimited encoding, malformed-message rejection, and provider records that never contain credentials.
- [ ] Run the focused Swift tests and confirm they fail because the native contracts do not exist.
- [ ] Implement the minimal Codable models, native frame model, IPC envelope, and provider model needed by the tests.
- [ ] Re-run the focused tests and the existing core tests.

### Task 2: Port the real FatCat renderer to SwiftUI Canvas

**Files:**
- Modify: `macos/FatCat/Sources/FatCatCore/FatCatAvatar.swift`
- Create: `macos/FatCat/Sources/FatCat/FatCatAvatarView.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/NativeAvatarTests.swift`
- Modify: `macos/FatCat/Package.swift`

- [ ] Add regression tests for sphere projection, eye rounded-rectangle geometry, head orientation, blink height, expression colors, and real animation transitions.
- [ ] Port the JSON’s sphere surface, perspective projection, quaternion orientation, expression interpolation, looping animation timelines, and blink behavior from the avatar-core reference implementation.
- [ ] Draw head and eyes with SwiftUI `Canvas`/`Path`, use `TimelineView` for animation ticks, and keep the view’s hit testing suitable for dragging/clicking.
- [ ] Load `fatcat.avatar.json` as a packaged native resource; do not import React, JavaScript, CSS, or WebKit.
- [ ] Add a native snapshot/render test at a fixed frame and compare nontransparent pixels and geometry invariants.

### Task 3: Define and test the FatCatAgent Unix-socket protocol

**Files:**
- Create: `protocol/fatcat-events.schema.json`
- Modify: `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift`
- Create: `macos/FatCat/Sources/FatCatCore/FatCatAgentClient.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift`
- Create: `agent/fatcat_agent/protocol.py`
- Create: `agent/fatcat_agent/server.py`
- Create: `agent/fatcat_agent/config.py`

- [ ] Define protocol version 1 messages for hello, observation, user message, assistant delta, state, plan, tool call, permission request, proposed action, action result, verification result, memory update, provider status, error, and shutdown.
- [ ] Implement Swift length-safe line framing, request IDs, session IDs, event decoding, and reconnect/error behavior.
- [ ] Implement the Python Unix-socket server with `0600` socket permissions, one client, schema validation, and no stdout protocol output.
- [ ] Add a fake sidecar integration test that streams a response and a state transition through the same socket path.
- [ ] Add a real Hermes adapter boundary that can be backed by the pinned Hermes source without scraping terminal output.

### Task 4: Build the bundled FatCatAgent distribution

**Files:**
- Create: `agent/pyproject.toml`
- Create: `agent/fatcat_agent/hermes_runtime.py`
- Create: `agent/fatcat_agent/providers.py`
- Create: `agent/fatcat_agent/tools.py`
- Create: `agent/fatcat_agent/personality.py`
- Create: `agent/default-skills/`
- Create: `scripts/build-fatcat-agent.sh`
- Modify: `scripts/run-fatcat-macos.sh`
- Modify: `macos/FatCat/Package.swift`

- [ ] Pin the Hermes upstream revision in the agent build metadata and record the source revision in the packaged manifest.
- [ ] Add the FatCat system prompt, interruption/privacy/risk/state policies, and FatCat-specific tools.
- [ ] Reuse Hermes agent loop, provider integrations, tool dispatch, skills, compression, sessions, memory, routing, credentials, and MCP support through a narrow adapter.
- [ ] Start a headless `FatCatAgent` daemon using `~/Library/Application Support/FatCat/Hermes/` as its isolated home.
- [ ] Package Python and dependencies inside `Contents/Resources/FatCatAgent`; the release app must not require Python, npm, Terminal, or a separately installed Hermes.
- [ ] Add a subprocess smoke test proving the bundled agent creates a socket and returns an actual configured-provider response.

### Task 5: Add provider discovery and routing

**Files:**
- Modify: `agent/fatcat_agent/providers.py`
- Modify: `macos/FatCat/Sources/FatCatCore/ProviderDiscovery.swift`
- Create: `macos/FatCat/Sources/FatCat/ProviderSettingsView.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/ProviderDiscoveryTests.swift`

- [ ] Discover only executable presence, documented version/auth status, and opt-in health checks for Codex CLI, Claude Code, Gemini CLI, Copilot CLI, Hermes configuration, Ollama, LM Studio, MLX, llama.cpp, and user API-key presence.
- [ ] Never read browser cookies, copy OAuth tokens, or call undocumented subscription endpoints.
- [ ] Model each provider with ID, display name, auth status, capabilities, privacy, cost type, context window, and external session ID only.
- [ ] Implement Automatic, named-provider, Local-only, and specific-model routing while displaying the selected brain in the chat/status UI.
- [ ] Add small native provider settings and test-connection controls without recreating a dashboard.

### Task 6: Replace WebKit/ACP app integration with native components

**Files:**
- Replace: `macos/FatCat/Sources/FatCat/AppMain.swift`
- Modify: `macos/FatCat/Sources/FatCatCore/NativeDomain.swift`
- Modify: `macos/FatCat/Tests/FatCatCoreTests/NativeDomainTests.swift`
- Remove from target: `macos/FatCat/Sources/FatCatCore/HermesACP.swift`
- Remove from target: all `WebApp` resources and WebKit imports

- [ ] Wire the native `FatCatAvatarView` into the transparent borderless panel and preserve click, drag, Spaces, position, menu-bar, speech-bubble, pause, and state behavior.
- [ ] Replace `HermesProcessClient` with `FatCatAgentClient` and route all messages through the Unix socket.
- [ ] Keep ScreenCaptureKit, NSWorkspace, Accessibility, and Vision behind privacy-filtered observation services.
- [ ] Add native action executor boundaries for open app/file, type text, click/highlight, move window, and accessibility inspection; enforce low/medium/high-risk policy before execution.
- [ ] Gate celebrating on an independent verification result and send all action/verification/memory events to the agent and local audit store.

### Task 7: Add local audit storage and Keychain integration

**Files:**
- Create: `macos/FatCat/Sources/FatCatCore/FatCatDatabase.swift`
- Create: `macos/FatCat/Sources/FatCatCore/KeychainStore.swift`
- Test: `macos/FatCat/Tests/FatCatCoreTests/FatCatDatabaseTests.swift`
- Modify: `macos/FatCat/Package.swift`

- [ ] Add GRDB-backed SQLite migrations for observations, actions, approvals, verification results, goals, privacy decisions, and Hermes/provider sessions.
- [ ] Store only structured/redacted metadata and configurable transcript references; never store raw screenshots by default.
- [ ] Generate/retrieve the database key through Keychain and configure SQLCipher-backed storage, with an explicit fail-closed error if encrypted storage cannot initialize.
- [ ] Test migrations, deletion/export boundaries, privacy redaction, and crash-safe transaction behavior.

### Task 8: Package, visually verify, and document the complete product

**Files:**
- Modify: `scripts/run-fatcat-macos.sh`
- Modify: `scripts/verify-fatcat-macos-app.sh`
- Create: `scripts/smoke-fatcat-macos.sh`
- Modify: `macos/FatCat/AppInfo.plist`
- Modify: `README.md`

- [ ] Package `FatCat Anywhere.app` with a stable bundle identifier, native executable, `FatCatAgent`, default skills, protocol schema, avatar JSON, and no WebKit/Vite runtime dependency.
- [ ] Verify code signing, resource containment, socket permissions, isolated Hermes home, Screen Recording attribution, and no dashboard/browser assets.
- [ ] Run a real packaged smoke flow: pet-only screenshot, chat screenshot, real provider response, pause/resume, drag/relaunch persistence, right-click menu, and close-to-pet-only.
- [ ] Run `npm test`, `npm run lint`, `npm run build`, Swift tests/build, Python tests, agent packaging, app verification, and runtime smoke.
- [ ] Keep README limited to run instructions, architecture, limitations, and verification.
- [ ] Confirm the animations repository is unchanged and do not commit or push without explicit approval.
