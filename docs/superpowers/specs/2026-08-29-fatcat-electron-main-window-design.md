# FatCat Electron Main Window Design

**Date:** 2026-08-29  
**Status:** Approved for implementation planning

## Summary

FatCat will gain a separate Electron desktop application that provides a solid, resizable, Codex-inspired main window for real Hermes conversations. The existing native macOS floating companion remains unchanged and continues to open only its compact Swift chat bubble.

The Electron application is a second client, not a replacement for the native pet. It runs independently during this phase, owns its own Hermes agent process, and uses the existing versioned Unix-socket protocol. The code will be structured so a future shared daemon or combined package can replace the direct process ownership without rewriting the React interface.

## Goals

- Provide a conventional desktop window with a conversation sidebar and focused chat surface.
- Connect to the existing FatCat/Hermes runtime for real sessions and streamed replies.
- Reuse the current socket protocol and preserve Hermes as the source of truth for model history.
- Use shadcn for accessible application primitives and Beautiful UI patterns for AI-specific surfaces.
- Render Hermes plan and tool activity in compact, expandable rows inspired by the supplied Tool Chips component.
- Keep renderer privileges narrow and credentials outside the renderer.
- Establish typed boundaries that support later integration with the native pet or a shared daemon.

## Non-goals

- Replacing or changing the native floating pet.
- Sharing a live Hermes process or active session between Electron and the native pet.
- A terminal, file editor, source-control UI, or diff application workflow.
- Approval flows or native operating-system actions.
- Attachments, voice, or screen observation in the Electron client.
- A combined distributable DMG in this phase.
- Pixel-for-pixel reproduction of Codex. Codex supplies the application layout and interaction reference.

## Chosen Architecture

### Application structure

A new `electron/` application will contain:

- An Electron main process responsible for the window, Hermes process lifecycle, socket transport, persistence, and privileged operations.
- A context-isolated preload bridge that exposes a small typed API.
- A React and TypeScript renderer built with Vite, Tailwind, shadcn, and selected Beautiful UI component patterns.
- A TypeScript protocol layer that mirrors the existing FatCat protocol version and message types.
- Test fixtures shared across the transport, state reducers, and integration harness.

The existing top-level React avatar playground and the native Swift package remain separate. The new application may reuse repository assets, but it must not make the current Vite playground the production renderer entry point.

### Process ownership

Each Electron application instance owns one `PeppaAgent` process and one private Unix socket. The main process:

1. Resolves development paths for the Python entry point, vendored Hermes source, and Hermes home.
2. Creates an app-owned socket directory and removes only its own validated stale socket.
3. Launches `PeppaAgent` with the existing `--socket` and `--hermes-home` arguments.
4. Connects and completes the version-1 `hello` handshake.
5. Routes typed requests and events between the socket and renderer.
6. Requests graceful shutdown on quit and force-terminates only the child process it spawned if the grace period expires.

The renderer never spawns processes, reads arbitrary files, or opens the socket directly.

### Future transport replacement

Renderer state depends on an application-facing `FatCatClient` interface rather than Electron IPC details. The first implementation is backed by the preload bridge. A future shared local daemon can implement the same interface and allow the native pet and Electron window to coordinate without changing chat components.

## Security Boundary

- `contextIsolation` is enabled.
- Node integration is disabled in the renderer.
- Renderer sandboxing is enabled unless a documented Electron limitation requires a narrower exception.
- The preload bridge exposes explicit methods and event subscriptions; it does not expose raw `ipcRenderer`.
- IPC payloads are runtime-validated before crossing process boundaries.
- External HTTP and HTTPS links open in the system browser.
- New-window creation and unexpected navigation are denied.
- API keys, cookies, tokens, passwords, and raw credential fields are rejected consistently with the existing protocol.
- Existing Hermes configuration and official Codex authentication are reused. Provider credentials are not collected by the Electron renderer in this phase.

## Window and Visual Design

### Window

The application uses a normal solid Electron window with native macOS traffic lights and a restrained draggable title-bar region. Its default content size is 1180 by 760 pixels and its minimum content size is 900 by 620 pixels. It remembers its last non-maximized size and position. Invalid or off-screen saved bounds are discarded.

The visual language follows Codex's compact desktop patterns: neutral surfaces, subtle separators, restrained corner radii, high information clarity, and system light and dark themes. The floating panel's glass material and oversized avatar treatment do not carry into the main window.

### Sidebar

The left sidebar contains:

- FatCat identity and a collapse control.
- A prominent New Chat action.
- Searchable conversation history.
- Clear selected, hovered, and keyboard-focused states.
- Context actions for rename and delete.
- A bottom settings/status area.

The collapsed sidebar retains recognizable controls and tooltips. Conversation deletion requires confirmation. Search filters titles and previews without mutating stored ordering.

Settings opens a focused dialog for appearance preference, read-only provider/model status, agent connection diagnostics, and app version. Appearance defaults to System with optional Light and Dark overrides. Provider credentials and provider mutation remain outside the renderer in this phase.

### Main header

The main header shows the current conversation title, workspace path, Hermes connection state, and an overflow menu. It remains visually quiet so the transcript is primary. Long paths and titles truncate with accessible full-value tooltips.

New Chat uses the last selected workspace, falling back to the repository root in development and the user's home directory in a packaged build. A workspace control opens a native directory picker through the preload bridge. Changing the workspace creates a new conversation; it never changes the working directory beneath an existing Hermes session.

### Conversation surface

The transcript uses a centered readable column within the available main pane. User messages are visually distinct but understated. Assistant messages render supported markdown, code blocks, links, selection, and copy controls.

Streaming appends text to a stable assistant message. The view follows new content only while the user is near the bottom. Scrolling away reveals a Jump to Latest control and never steals the reading position.

Empty, loading, offline, failed-resume, failed-turn, and cancelled states are designed explicitly. Every error state offers the next safe action.

### Plan and tool activity

Hermes `plan`, `tool_call`, `action_result`, and turn-state events attach to the active turn by session and request identifiers. They render as compact expandable activity rows using the supplied Tool Chips interaction model and Beautiful UI's thinking/tool conventions.

The rows show safe names, arguments, status, and completion detail already allowed by the protocol. They are informational in this release. The Electron app does not claim that it can apply diffs, execute native actions, or grant approvals.

### Composer

The composer uses a Beautiful UI-inspired prompt bar built from owned components and shadcn primitives. It includes:

- A multiline text area.
- Send and Stop actions.
- Current workspace context.
- Disabled, offline, sending, and streaming states.
- Return to send and Shift-Return for a newline.
- Draft preservation across transient failures and conversation switches.

Only one turn may run in a conversation. While a turn is active, sending another prompt is disabled until the turn completes, fails, or is cancelled.

## Data Model and Flow

### Conversation metadata

Electron stores a local conversation index under its own application-data directory. Each record contains:

- Stable FatCat conversation ID.
- Optional Hermes session ID.
- Title.
- Created and updated timestamps.
- Last preview.
- Workspace path.

Writes are atomic. Electron owns this metadata, ordering, and selected-conversation state. Hermes remains the source of truth for conversation messages and model state.

The Electron index is intentionally separate from the native Swift store in this phase. A later migration can introduce a shared store or daemon after cross-client ownership rules are defined.

### Launch flow

1. Create the application window and render a connecting state.
2. Start the Hermes bridge and complete the protocol handshake.
3. Load the local conversation index.
4. Restore the previously selected conversation if it exists.
5. Send `load_session` and rebuild the transcript from `session_history` events.
6. Show a recoverable failure state if the session no longer loads.

### New conversation flow

1. Create and select local metadata with no Hermes session ID.
2. Send `new_session` with the conversation ID and workspace path.
3. Attach the returned Hermes session ID atomically.
4. Enable the composer after the session is ready.

### Turn flow

1. Validate and normalize non-empty composer text.
2. Append the user message optimistically and preserve it as retry state.
3. Create a request ID and send `user_message` for the active Hermes session.
4. Reduce `state`, `assistant_delta`, `plan`, `tool_call`, `action_result`, and `error` events into the active turn.
5. Update the conversation preview and timestamp as content arrives.
6. Mark the assistant message completed, failed, or cancelled without discarding partial content.

Session ID and request ID checks prevent events from an abandoned or previously selected conversation from changing the visible transcript.

## Failure and Recovery

### Startup failure

If the agent executable, Python runtime, Hermes source, or socket connection is unavailable, the main surface shows a clear startup failure with Retry and Copy Diagnostics actions. Diagnostics omit secrets and include only actionable paths, exit state, and protocol detail.

### Disconnect and reconnect

Socket loss leaves the current transcript visible, disables sending, and marks the app offline. The main process retries with bounded exponential backoff and a visible attempt state. Reconnection performs a fresh handshake and reloads the selected Hermes session before re-enabling input.

### Session restoration failure

A conversation whose Hermes session cannot be loaded remains in the sidebar. The transcript shows the failure and offers Retry or Start New Chat. FatCat never silently substitutes a new session beneath an existing conversation.

### Turn failure and cancellation

Failed turns preserve the prompt and any partial assistant content, display an inline reason, and offer Retry. Stop sends `cancel` for the active session and ignores late deltas associated with the cancelled request.

### Shutdown

On app quit, active turns are cancelled, the agent receives `shutdown`, and the main process waits for its acknowledgement. After a bounded grace period, Electron terminates only the child process it created and removes only the validated app-owned socket.

## Component Boundaries

- `FatCatClient`: renderer-facing conversation and turn operations.
- `AgentSupervisor`: child-process startup, health, restart, and shutdown.
- `SocketTransport`: newline-delimited JSON framing, handshake, validation, and reconnect.
- `ConversationRepository`: atomic metadata persistence and search.
- `ChatController`: conversation selection, session lifecycle, and command coordination.
- `chatReducer`: deterministic renderer state transitions for protocol events.
- `AppSidebar`: navigation, search, and conversation actions.
- `ConversationHeader`: title, workspace, connection state, and menu.
- `Transcript`: scroll policy and message composition.
- `AssistantMessage`: markdown, streaming, errors, and actions.
- `TurnActivity`: plan, state, and tool rows.
- `PromptBar`: draft, keyboard behavior, send, and stop.

Each boundary has a typed interface and can be tested without launching the full Electron application.

## Component Sources

shadcn supplies owned, accessible primitives such as buttons, sidebar elements, menus, dialogs, tooltips, scroll areas, skeletons, and text inputs. Components are added to the repository and themed for FatCat rather than treated as a runtime black box.

Beautiful UI supplies MIT-licensed reference implementations and interaction patterns for Chat, Prompt Bar, Sidebar Nav, Streaming Text, Thinking, and Tool Chips. Only components needed by the approved scope are adapted. The supplied Tool Chips source is treated as the primary interaction reference for Hermes activity rows.

## Testing Strategy

### Unit tests

- Protocol encoding, decoding, and forbidden-field rejection.
- Newline framing and partial socket reads.
- Conversation repository creation, selection, mutation, search, atomic writes, and corrupt-file recovery.
- Turn reducer behavior for streaming, failure, cancellation, late events, and session mismatch.
- Agent supervisor retry, stale-socket handling, and bounded shutdown.

### Renderer tests

- Sidebar selection, search, rename, delete confirmation, and collapse behavior.
- Composer keyboard shortcuts, disabled states, draft preservation, send, and stop.
- Stable streaming messages and scroll-follow behavior.
- Markdown, copy, retry, tool-row expansion, and safe external links.
- Empty, connecting, offline, failed-resume, failed-turn, and cancelled states.
- Keyboard navigation, accessible names, focus restoration, and system-theme changes.

### Electron integration tests

A deterministic fake Unix-socket agent verifies:

- Process startup and handshake.
- Session creation and restoration.
- History reconstruction.
- Streamed assistant, plan, and tool events.
- Cancellation and ignored late events.
- Disconnect, reconnect, and graceful shutdown.

### Real-agent smoke test

A smoke test launches the existing Python bridge, completes the handshake and a no-model session lifecycle, then shuts it down. It does not require a paid inference call.

### Regression gate

The Electron test suite, TypeScript checks, renderer build, existing Vite tests, Swift tests, Python agent tests, and Hermes bundle verification must pass. Browser-level visual checks cover the minimum window size and representative laptop and large-window dimensions in both system themes.

## Acceptance Criteria

- The Electron application starts independently without changing native pet behavior.
- A user can create, select, rename, search, and delete local conversations.
- A user can load a Hermes session, send a prompt, see streamed output, stop the turn, and retry a failure.
- Hermes plan and tool events appear as expandable informational activity rows.
- The window is usable at the minimum size and restores valid bounds across launches.
- Light and dark appearances follow the operating-system setting.
- Renderer code has no direct Node, filesystem, process, socket, or credential access.
- Agent startup, disconnect, failed resume, failed turn, cancellation, and shutdown all have explicit tested behavior.
- Existing native FatCat and agent regression suites remain green.

## Deferred Integration Path

The next architectural step, outside this implementation, is a single user-scoped FatCat daemon that owns Hermes and supports authenticated multiple clients. The native pet and Electron app would both implement the existing `FatCatClient` semantics over that daemon. Session ownership, simultaneous input, shared conversation metadata, and permission routing must be designed before that migration.
