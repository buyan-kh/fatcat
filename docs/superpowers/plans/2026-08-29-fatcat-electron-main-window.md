# FatCat Electron Main Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a separate, solid Electron desktop client with a Codex-inspired React interface that owns a real Hermes agent process and supports persistent, streaming FatCat conversations.

**Architecture:** Electron's main process supervises the existing Python `PeppaAgent`, speaks the versioned newline-delimited JSON protocol over a private Unix socket, and exposes a validated, context-isolated preload API. The React renderer depends only on that typed API, keeps deterministic chat state in a reducer, and composes shadcn primitives with adapted Beautiful UI chat, prompt, thinking, and tool-row patterns.

**Tech Stack:** Electron, electron-vite, React 19, TypeScript, Tailwind CSS 4, shadcn/ui primitives, Radix UI, Phosphor Icons, Vitest, Testing Library, Zod, Node Unix sockets.

---

## File Structure

Create a self-contained `electron/` package:

```text
electron/
  package.json                         # Electron scripts and dependencies
  electron.vite.config.ts              # main/preload/renderer build config
  tsconfig.json                        # project references
  tsconfig.node.json                   # main/preload compiler config
  tsconfig.web.json                    # renderer compiler config
  components.json                      # shadcn registry configuration
  index.html                           # renderer entry document
  src/main/index.ts                    # app lifecycle and BrowserWindow creation
  src/main/window-state.ts             # validated bounds persistence
  src/main/agent/agent-supervisor.ts    # PeppaAgent child lifecycle
  src/main/agent/socket-transport.ts    # Unix socket framing and handshake
  src/main/agent/fatcat-service.ts      # conversation/session orchestration
  src/main/persistence/conversations.ts # atomic local conversation metadata
  src/preload/index.ts                  # narrow contextBridge implementation
  src/shared/api.ts                     # renderer-facing API types
  src/shared/protocol.ts                # protocol schemas and message types
  src/shared/chat.ts                    # conversation, message, and activity types
  src/renderer/src/main.tsx             # React entry point
  src/renderer/src/App.tsx              # app composition and bridge subscription
  src/renderer/src/styles.css           # Tailwind theme and desktop design tokens
  src/renderer/src/lib/utils.ts         # shadcn class merger
  src/renderer/src/lib/chat-reducer.ts  # deterministic renderer state
  src/renderer/src/components/ui/*      # owned shadcn primitives
  src/renderer/src/components/app-sidebar.tsx
  src/renderer/src/components/conversation-header.tsx
  src/renderer/src/components/transcript.tsx
  src/renderer/src/components/message-row.tsx
  src/renderer/src/components/turn-activity.tsx
  src/renderer/src/components/prompt-bar.tsx
  src/renderer/src/components/settings-dialog.tsx
  src/test/fake-agent.ts                # deterministic Unix socket fixture
  src/**/*.test.ts(x)                   # colocated unit/component tests
```

Modify top-level files only to expose convenient Electron commands and document development startup:

```text
package.json
README.md
.gitignore
```

### Task 1: Scaffold the Electron package and test runner

**Files:**
- Create: `electron/package.json`
- Create: `electron/electron.vite.config.ts`
- Create: `electron/tsconfig.json`
- Create: `electron/tsconfig.node.json`
- Create: `electron/tsconfig.web.json`
- Create: `electron/components.json`
- Create: `electron/index.html`
- Create: `electron/src/renderer/src/main.tsx`
- Create: `electron/src/renderer/src/styles.css`
- Create: `electron/src/renderer/src/lib/utils.ts`
- Modify: `.gitignore`

- [ ] **Step 1: Add the Electron package manifest**

Use `electron-vite` for the three-process build. Include scripts `dev`, `build`, `preview`, `typecheck`, and `test`. Runtime dependencies are React, Radix dialog/dropdown/scroll-area/tooltip, `class-variance-authority`, `clsx`, `tailwind-merge`, `zod`, `react-markdown`, `remark-gfm`, and `@phosphor-icons/react`. Development dependencies include Electron, electron-vite, Vite, the React plugin, Tailwind 4 and its Vite plugin, TypeScript, Vitest, jsdom, and Testing Library.

- [ ] **Step 2: Add failing renderer smoke test**

Create `electron/src/renderer/src/app-smoke.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

describe('FatCat Electron shell', () => {
  it('renders the application identity', () => {
    render(<App />)
    expect(screen.getByRole('heading', { name: 'FatCat' })).toBeInTheDocument()
  })
})
```

- [ ] **Step 3: Run the test and confirm the missing app failure**

Run: `npm --prefix electron test -- --run src/renderer/src/app-smoke.test.tsx`

Expected: FAIL because `App.tsx` does not exist.

- [ ] **Step 4: Add the minimal renderer entry and theme foundation**

Create a temporary `App.tsx` that renders `<h1>FatCat</h1>`, wire `main.tsx`, configure electron-vite aliases for `@renderer`, `@shared`, and `@main`, and define shadcn-compatible Tailwind theme variables for light/dark solid surfaces.

- [ ] **Step 5: Install and verify the scaffold**

Run:

```bash
npm --prefix electron install
npm --prefix electron test -- --run src/renderer/src/app-smoke.test.tsx
npm --prefix electron run typecheck
```

Expected: the smoke test and TypeScript check pass.

- [ ] **Step 6: Commit**

```bash
git add .gitignore electron
git commit -m "build: scaffold FatCat Electron client"
```

### Task 2: Define and validate the FatCat protocol

**Files:**
- Create: `electron/src/shared/protocol.ts`
- Create: `electron/src/shared/protocol.test.ts`
- Create: `electron/src/shared/chat.ts`

- [ ] **Step 1: Write protocol validation tests**

Test that `decodeAgentEvent` accepts `hello_ack`, `session_ready`, `session_loaded`, `session_history`, `assistant_delta`, `plan`, `tool_call`, `action_result`, `state`, `error`, and provider inventory/status events. Test that it rejects an unknown version, unknown type, missing required fields, and any nested credential-like key.

```ts
expect(decodeAgentEvent('{"version":1,"type":"assistant_delta","request_id":"r1","session_id":"s1","text":"Hi"}')).toMatchObject({ type: 'assistant_delta' })
expect(() => decodeAgentEvent('{"version":2,"type":"hello_ack","agent_version":"x"}')).toThrow('Unsupported protocol version')
expect(() => encodeClientCommand({ version: 1, type: 'user_message', request_id: 'r', session_id: 's', text: 'x', api_key: 'no' } as never)).toThrow('Credential field')
```

- [ ] **Step 2: Run the protocol test and verify it fails**

Run: `npm --prefix electron test -- --run src/shared/protocol.test.ts`

Expected: FAIL because the protocol module does not exist.

- [ ] **Step 3: Implement discriminated protocol schemas**

Define Zod schemas and inferred TypeScript types for every client command and agent event used by the Swift codec. Export:

```ts
export type ClientCommand = z.infer<typeof clientCommandSchema>
export type AgentEvent = z.infer<typeof agentEventSchema>
export function decodeAgentEvent(line: string): AgentEvent
export function encodeClientCommand(command: ClientCommand): string
export function assertNoCredentials(value: unknown): void
```

`encodeClientCommand` returns one compact JSON object followed by `\n`. Credential rejection recursively blocks `api_key`, `access_token`, `refresh_token`, `cookie`, `password`, and `secret`.

- [ ] **Step 4: Add shared chat types**

Define `ConversationRecord`, `ChatMessage`, `TurnActivity`, `ConnectionStatus`, and `AppearancePreference`. IDs are strings, dates cross IPC as ISO strings, activity is correlated by `requestId`, and only JSON-serializable fields are allowed.

- [ ] **Step 5: Run protocol tests and typecheck**

Run:

```bash
npm --prefix electron test -- --run src/shared/protocol.test.ts
npm --prefix electron run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add electron/src/shared
git commit -m "feat: define Electron Hermes protocol"
```

### Task 3: Persist conversation metadata and window state

**Files:**
- Create: `electron/src/main/persistence/conversations.ts`
- Create: `electron/src/main/persistence/conversations.test.ts`
- Create: `electron/src/main/window-state.ts`
- Create: `electron/src/main/window-state.test.ts`

- [ ] **Step 1: Write failing repository tests**

Use temporary directories to test create, select, attach session, rename, preview update, search, delete, atomic persistence, missing files, and corrupt-file quarantine. Verify new records are ordered newest first and preserve `workspacePath`.

```ts
const repository = await ConversationRepository.open(join(root, 'conversations.json'))
const record = await repository.create('New chat', '/tmp/project')
await repository.attachSession(record.id, 'session-1')
expect((await repository.snapshot()).records[0]).toMatchObject({ hermesSessionId: 'session-1' })
```

- [ ] **Step 2: Run repository tests and verify failure**

Run: `npm --prefix electron test -- --run src/main/persistence/conversations.test.ts src/main/window-state.test.ts`

Expected: FAIL because the modules do not exist.

- [ ] **Step 3: Implement atomic conversation persistence**

Implement `ConversationRepository.open(filePath)` and serialized mutation methods. Write to `<file>.tmp`, fsync/close, and rename into place. When JSON is invalid, rename it to `conversations.corrupt-<timestamp>.json` and start with an empty document.

- [ ] **Step 4: Implement validated window bounds**

Export pure `isVisibleBounds(bounds, displays)` and a `WindowStateStore` that defaults to `{ width: 1180, height: 760 }`, enforces `{ width: 900, height: 620 }`, and ignores saved bounds that do not intersect any display work area.

- [ ] **Step 5: Run tests and typecheck**

Run:

```bash
npm --prefix electron test -- --run src/main/persistence/conversations.test.ts src/main/window-state.test.ts
npm --prefix electron run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add electron/src/main/persistence electron/src/main/window-state*
git commit -m "feat: persist Electron conversations and bounds"
```

### Task 4: Supervise PeppaAgent and implement the socket transport

**Files:**
- Create: `electron/src/main/agent/socket-transport.ts`
- Create: `electron/src/main/agent/socket-transport.test.ts`
- Create: `electron/src/main/agent/agent-supervisor.ts`
- Create: `electron/src/main/agent/agent-supervisor.test.ts`
- Create: `electron/src/test/fake-agent.ts`

- [ ] **Step 1: Write failing framing and lifecycle tests**

Test partial lines, multiple lines per packet, malformed JSON, handshake timeout, queued writes before connection, disconnect events, bounded reconnect delays, graceful shutdown acknowledgement, and child-only termination. The fake agent must listen on a temporary Unix socket and emit deterministic protocol events.

- [ ] **Step 2: Run the transport tests and verify failure**

Run: `npm --prefix electron test -- --run src/main/agent`

Expected: FAIL because transport and supervisor do not exist.

- [ ] **Step 3: Implement `SocketTransport`**

The transport wraps `node:net.Socket`, buffers UTF-8 input until newline, validates every event, emits typed `event`, `status`, and `diagnostic` callbacks, and performs `hello`/`hello_ack` before accepting application commands. It rejects writes while disconnected and never logs message text or credential-shaped fields.

- [ ] **Step 4: Implement `AgentSupervisor`**

Resolve `FATCAT_AGENT_PATH` first. In repository development, fall back to `agent/peppa_agent/PeppaAgent` only when it is executable; otherwise report an actionable missing-runtime error. Spawn with `--socket` and `--hermes-home`, use a unique socket below Electron `userData`, inherit the current environment, and keep stdout/stderr in a bounded redacted diagnostic ring buffer.

Expose:

```ts
start(): Promise<SocketTransport>
restart(): Promise<SocketTransport>
stop(graceMs?: number): Promise<void>
getDiagnostics(): AgentDiagnostics
```

- [ ] **Step 5: Run focused tests and typecheck**

Run:

```bash
npm --prefix electron test -- --run src/main/agent
npm --prefix electron run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add electron/src/main/agent electron/src/test
git commit -m "feat: supervise Hermes from Electron"
```

### Task 5: Add the FatCat main-process service and secure preload API

**Files:**
- Create: `electron/src/shared/api.ts`
- Create: `electron/src/main/agent/fatcat-service.ts`
- Create: `electron/src/main/agent/fatcat-service.test.ts`
- Create: `electron/src/main/index.ts`
- Create: `electron/src/preload/index.ts`
- Create: `electron/src/preload/index.d.ts`

- [ ] **Step 1: Write failing orchestration tests**

Test launch restoration, new session attachment, load history, optimistic sends, single-turn enforcement, cancel/late-delta suppression, preview updates, session mismatch rejection, retry, workspace changes creating a new conversation, and reconnect reload.

- [ ] **Step 2: Run service tests and verify failure**

Run: `npm --prefix electron test -- --run src/main/agent/fatcat-service.test.ts`

Expected: FAIL because `FatCatService` does not exist.

- [ ] **Step 3: Implement the service API**

Expose commands through `FatCatService`:

```ts
snapshot(): Promise<AppSnapshot>
createConversation(workspacePath?: string): Promise<ConversationRecord>
selectConversation(id: string): Promise<void>
renameConversation(id: string, title: string): Promise<void>
deleteConversation(id: string): Promise<void>
sendMessage(text: string): Promise<void>
cancelTurn(): Promise<void>
retryLastTurn(): Promise<void>
chooseWorkspace(): Promise<string | null>
restartAgent(): Promise<void>
getDiagnostics(): Promise<AgentDiagnostics>
```

Emit one serializable `FatCatEvent` stream for connection, snapshot, protocol activity, and diagnostics. Enforce active conversation/session/request correlation in the service rather than trusting the renderer.

- [ ] **Step 4: Register allow-listed Electron IPC**

Create an 1180 by 760 BrowserWindow with minimum 900 by 620, context isolation, sandbox, disabled Node integration, denied navigation/new windows, safe external HTTP(S) opening, native directory selection, window-bound restoration, and graceful app shutdown.

The preload exposes `window.fatcat` with named methods and `subscribe(listener): unsubscribe`; never expose raw Electron IPC objects.

- [ ] **Step 5: Run service tests, typecheck, and main-process build**

Run:

```bash
npm --prefix electron test -- --run src/main/agent/fatcat-service.test.ts
npm --prefix electron run typecheck
npm --prefix electron run build
```

Expected: PASS and electron-vite produces main, preload, and renderer outputs.

- [ ] **Step 6: Commit**

```bash
git add electron/src/main electron/src/preload electron/src/shared/api.ts
git commit -m "feat: expose secure FatCat Electron bridge"
```

### Task 6: Build deterministic renderer state

**Files:**
- Create: `electron/src/renderer/src/lib/chat-reducer.ts`
- Create: `electron/src/renderer/src/lib/chat-reducer.test.ts`
- Create: `electron/src/renderer/src/hooks/use-fatcat.ts`

- [ ] **Step 1: Write failing reducer tests**

Cover initial snapshot, conversation selection, history replacement, stable assistant streaming, plan/tool correlation, action completion, cancel/error preservation, ignored late requests, connection changes, and unread-below behavior.

- [ ] **Step 2: Run reducer tests and verify failure**

Run: `npm --prefix electron test -- --run src/renderer/src/lib/chat-reducer.test.ts`

Expected: FAIL because the reducer does not exist.

- [ ] **Step 3: Implement reducer and hook**

`chatReducer(state, event)` must be pure. `useFatCat()` loads `window.fatcat.snapshot()`, subscribes once, dispatches events, and returns state plus command wrappers. Subscriptions are removed on unmount and command failures become explicit renderer notices.

- [ ] **Step 4: Run tests and typecheck**

Run:

```bash
npm --prefix electron test -- --run src/renderer/src/lib/chat-reducer.test.ts
npm --prefix electron run typecheck
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add electron/src/renderer/src/lib electron/src/renderer/src/hooks
git commit -m "feat: model Electron chat state"
```

### Task 7: Add shadcn primitives and the Codex-inspired shell

**Files:**
- Create: `electron/src/renderer/src/components/ui/button.tsx`
- Create: `electron/src/renderer/src/components/ui/dialog.tsx`
- Create: `electron/src/renderer/src/components/ui/dropdown-menu.tsx`
- Create: `electron/src/renderer/src/components/ui/scroll-area.tsx`
- Create: `electron/src/renderer/src/components/ui/separator.tsx`
- Create: `electron/src/renderer/src/components/ui/textarea.tsx`
- Create: `electron/src/renderer/src/components/ui/tooltip.tsx`
- Create: `electron/src/renderer/src/components/app-sidebar.tsx`
- Create: `electron/src/renderer/src/components/conversation-header.tsx`
- Create: `electron/src/renderer/src/components/settings-dialog.tsx`
- Create: `electron/src/renderer/src/components/app-shell.test.tsx`

- [ ] **Step 1: Add failing shell interaction tests**

Verify visible FatCat identity, New Chat, searchable history, selection, collapse, rename/delete menus, workspace display, offline indicator, settings dialog, and keyboard-accessible controls.

- [ ] **Step 2: Run shell tests and verify failure**

Run: `npm --prefix electron test -- --run src/renderer/src/components/app-shell.test.tsx`

Expected: FAIL because shell components do not exist.

- [ ] **Step 3: Add owned shadcn components**

Add only the listed primitives using the current shadcn Vite/Tailwind 4 patterns. Use a single Phosphor icon family, a 10/12-pixel surface radius system, visible focus rings, and WCAG-AA color tokens.

- [ ] **Step 4: Build the solid desktop shell**

Implement a 256-pixel collapsible sidebar and flexible main pane. Use neutral zinc-like surfaces, one restrained blue status accent, hairline separators, no glass material, and compact Codex-like spacing. The title-bar drag region must mark interactive controls with `app-region: no-drag`.

- [ ] **Step 5: Run component tests and typecheck**

Run:

```bash
npm --prefix electron test -- --run src/renderer/src/components/app-shell.test.tsx
npm --prefix electron run typecheck
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add electron/components.json electron/src/renderer
git commit -m "feat: build FatCat Electron shell"
```

### Task 8: Build the Beautiful UI-inspired conversation experience

**Files:**
- Create: `electron/src/renderer/src/components/transcript.tsx`
- Create: `electron/src/renderer/src/components/message-row.tsx`
- Create: `electron/src/renderer/src/components/turn-activity.tsx`
- Create: `electron/src/renderer/src/components/prompt-bar.tsx`
- Create: `electron/src/renderer/src/components/conversation.test.tsx`
- Modify: `electron/src/renderer/src/App.tsx`
- Modify: `electron/src/renderer/src/styles.css`

- [ ] **Step 1: Write failing conversation tests**

Test empty suggestions, markdown and GFM rendering, streaming text, copy/retry controls, Thinking/plan/tool rows, expandable tool details, completed/failed states, prompt keyboard behavior, Stop, draft preservation, Jump to Latest, and safe link handling.

- [ ] **Step 2: Run conversation tests and verify failure**

Run: `npm --prefix electron test -- --run src/renderer/src/components/conversation.test.tsx`

Expected: FAIL because conversation components do not exist.

- [ ] **Step 3: Implement messages and scrolling**

Use `react-markdown` with `remark-gfm`, custom safe link/code renderers, stable message keys, and an intersection sentinel to follow output only when near the bottom. Empty, connecting, offline, resume-failed, and turn-failed states must each render a next action.

- [ ] **Step 4: Adapt Beautiful UI activity and prompt patterns**

Translate the supplied Tool Chips component into typed `TurnActivity` rows. Remove demo timers and mock diffs; drive animation and expansion from Hermes events. Build the prompt bar with a multiline textarea, workspace chip, Send/Stop control, Return-to-send, Shift-Return newline, and disabled/offline states.

- [ ] **Step 5: Compose the production App**

Replace the smoke-only `App.tsx` with `useFatCat`, `AppSidebar`, `ConversationHeader`, `Transcript`, `PromptBar`, and `SettingsDialog`. Render an actionable startup failure when `window.fatcat` is missing or the agent cannot start.

- [ ] **Step 6: Run focused tests, full tests, and build**

Run:

```bash
npm --prefix electron test -- --run src/renderer/src/components/conversation.test.tsx
npm --prefix electron test
npm --prefix electron run typecheck
npm --prefix electron run build
```

Expected: all tests pass and all Electron bundles build.

- [ ] **Step 7: Commit**

```bash
git add electron/src/renderer
git commit -m "feat: add Hermes conversation experience"
```

### Task 9: Verify real-agent startup and document development use

**Files:**
- Create: `electron/src/main/agent/real-agent-smoke.test.ts`
- Modify: `package.json`
- Modify: `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Add a conditional real-agent smoke test**

Launch only when `FATCAT_AGENT_PATH` points to an executable bundled agent. Create a temporary socket and Hermes home, verify `hello_ack`, request a new session without sending a paid prompt, then request shutdown. Skip with an explicit reason when the bundled runtime is unavailable.

- [ ] **Step 2: Add root convenience commands**

Add:

```json
"electron:dev": "npm --prefix electron run dev",
"electron:test": "npm --prefix electron test",
"electron:build": "npm --prefix electron run build"
```

- [ ] **Step 3: Document setup and known boundary**

Document `npm --prefix electron install`, `npm run electron:dev`, `FATCAT_AGENT_PATH`, separate app-data/session ownership, and that the native pet remains unchanged and cannot share the same live agent socket in this phase.

- [ ] **Step 4: Run the complete regression gate**

Run:

```bash
npm --prefix electron test
npm --prefix electron run typecheck
npm --prefix electron run build
npm test
npm run build
swift test --package-path macos/PeppaAnywhere
PYTHONPATH=agent python3 -m unittest discover -s agent/tests
bash scripts/test-hermes-bundle.sh
```

Expected: every available suite passes; the real-agent smoke test either passes with a configured executable or reports a documented skip.

- [ ] **Step 5: Launch and inspect the application**

Run `npm run electron:dev`. Verify the window at 1180 by 760 and 900 by 620 in system light and dark appearances. Confirm sidebar collapse, New Chat, workspace picker, composer, streaming fixture/real Hermes response, Stop, reconnect, menus, keyboard focus, and window-bounds restoration. Capture a screenshot under `docs/screenshots/electron/` for the handoff.

- [ ] **Step 6: Commit**

```bash
git add package.json README.md .gitignore electron/src/main/agent/real-agent-smoke.test.ts docs/screenshots/electron
git commit -m "docs: verify FatCat Electron client"
```

## Final Verification

- [ ] Run `git status --short` and confirm only intended changes remain.
- [ ] Run `git log --oneline` and confirm each task has a focused commit.
- [ ] Confirm no API keys, tokens, cookies, credentials, sockets, runtime bundles, generated Electron output, or developer-specific absolute paths are tracked.
- [ ] Compare the completed application against every acceptance criterion in `docs/superpowers/specs/2026-08-29-fatcat-electron-main-window-design.md`.
