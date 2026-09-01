# FatCat Incremental Streaming and Electron Launcher Design

**Status:** Approved for implementation

**Scope:** Latest merged FatCat branch (`origin/main` at `20898cc`)

## Problem

The native mini-chat can appear to jump between sessions and repaint the display repeatedly because live Hermes output, restored conversation snapshots, and assistant-message state are not treated as one ordered request stream. The native avatar also has no reliable way to open the full Electron workspace while preserving the existing daemon and selected Hermes session.

## Goals

1. Deliver assistant text incrementally from both Hermes ACP and the legacy Hermes path through the existing daemon/protocol/socket/preload/service/renderer pipeline.
2. Keep one assistant message per active request, append chunks in order, preserve Markdown rendering and the streaming cursor, and finish or fail the same message deterministically.
3. Prevent restored history or stale-session events from being shown as a new live stream.
4. Open/focus the existing Electron workspace from a native avatar double-click or an explicit native menu/context action.
5. Reuse an already-running Electron app, never start a second daemon, preserve the selected Hermes session, and report an actionable error when Electron is unavailable.
6. Add focused tests for timing, ordering, failure, selection, focus/reuse, and launch suppression, then run the requested project verification matrix.

## Non-goals

- Changing Hermes prompt semantics, conversation storage, or daemon ownership.
- Adding a second transport or a second agent process.
- Changing single-click mini-chat behavior.
- Adding browser, memory, email, or unrelated native actions.
- Redesigning the Electron workspace UI.

## Design

### Streaming contract

The daemon remains the sole Hermes owner. Each prompt has a request ID and session ID. Both ACP `agent_message_chunk` updates and legacy `stream_delta_callback` updates are converted into the existing `message.started`/`message.delta`/`message.completed` (or compatible v1 delta) event contract. A delta is emitted as soon as it is received; it is not buffered until completion.

Every live event carries the request ID and session ID. The Electron service accepts a delta only when it belongs to the currently selected session and active request (or starts that request), serializes event application, and emits a snapshot after each accepted delta. A new request replaces any prior active request for that conversation; late events from the old request are ignored.

The service creates the assistant message once, appends each chunk to its text, and marks it streaming. Completion marks the same message non-streaming and clears the active request. Failure preserves the partial text, marks the message non-streaming, and attaches the error. Conversation/history snapshots are treated as snapshots, never as live deltas, and cannot revive a completed request.

The renderer reducer applies snapshots/events with the same request/session guards. `StreamingText` continues to render the accumulated text and cursor, so Markdown remains valid as it grows without duplicating assistant rows or visibly switching sessions.

### Electron transport and renderer boundaries

- Keep protocol decoding strict and tolerant of both ACP Hermes events and legacy v1 assistant deltas.
- Preserve event order at the socket/service boundary with the existing serialized event chain.
- Ensure preload subscriptions forward each incremental snapshot/event without coalescing it into a completion-only update.
- Keep the selected conversation/session local to the Electron workspace; incoming history must not overwrite the user’s current selection during a live request.

### Native Electron launcher

Introduce one native helper responsible for resolution and activation (for example `FatCatElectronLauncher`). It must:

1. Check `FATCAT_ELECTRON_APP_PATH` first when set (used for development and tests), validating that it is an existing `.app` bundle.
2. In a packaged native build, resolve the Electron app as the documented sibling bundle (for example `FatCat Electron.app`) next to the native `FatCat.app`; do not embed a developer-specific absolute path.
3. Detect a matching running Electron application and activate/focus it instead of launching another instance.
4. Launch the resolved app through `NSWorkspace`, then activate/focus the resulting app/window when available.
5. Return a typed/result error that the native UI can present when no valid app is found or activation fails.

Avatar interaction is handled in one place: a double-click within the normal macOS interval invokes the launcher and suppresses the existing single-click mini-chat action for that click pair. A single click continues to call the existing mini-chat toggle. The native menu/context menu gets an “Open Electron Workspace” action wired to the same helper. Neither path starts, stops, or reconnects the FatCat daemon; the current Hermes session remains selected.

The development override and packaged sibling convention are documented in the README and are used by tests to point at a temporary fixture app bundle.

## Failure and edge-case behavior

- Empty chunks are ignored without creating a message.
- Duplicate/replayed chunks are rejected by request/session/order guards where the protocol provides an event identity; otherwise they are accepted only within the active request sequence.
- A completion for an unknown or stale request is ignored.
- A stream failure leaves all received text visible with an error state.
- A history snapshot received during streaming cannot replace the active assistant text.
- Missing Electron app, malformed override, launch failure, or missing activation target produces a clear native error and leaves mini-chat/daemon state unchanged.
- Double-clicking while Electron is already open only focuses it; it does not create another process or agent connection.

## Tests

### Python/daemon

- Legacy stream emits multiple deltas before completion; test with controlled delays and assert emission timestamps/order.
- ACP stream emits multiple chunks before completion with the same assertions.
- Stream failure after partial output preserves prior chunks and emits failure.

### Electron main/service/renderer

- Socket/protocol tests decode incremental events.
- Service tests assert one assistant row, ordered appends, cursor state, completion, partial failure, stale request/session rejection, and history isolation.
- Preload/reducer/component tests assert each update is visible incrementally, Markdown/cursor rendering remains stable, and restored history is not treated as live output.
- Verify both v1 legacy deltas and v2 Hermes events.

### Native

- Double-click triggers launcher and suppresses mini-chat; single click still toggles mini-chat.
- Menu/context action dispatches the same launcher.
- Existing Electron process is focused/reused; no second Electron or daemon launch occurs.
- Override and packaged sibling resolution succeed; missing/malformed app produces a clear error.
- Selected Hermes session is unchanged across launch/focus.

### Verification

Run focused tests while iterating, then the full matrix requested by the task: Python agent tests, Electron tests/typecheck/build/package checks, Swift tests, Hermes bundle checks, bounded smoke tests, real streaming verification, real double-click/menu verification, and `git diff --check`.

## Documentation and delivery

Document `FATCAT_ELECTRON_APP_PATH`, the packaged sibling layout, and the no-second-daemon behavior in the project README. Implementation will be performed from a separate plan after this spec review, with commits kept focused so the streaming and launcher changes can be inspected independently.
