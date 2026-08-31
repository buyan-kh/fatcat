# FatCat Shared Agent and Native Mini-Chat MVP

## Goal

Deliver one coherent FatCat: a persistent native pet, a lightweight native
mini-chat, a full Electron conversation workspace, and one shared Hermes
runtime. Both clients must show the same active conversation without starting
duplicate agents or sessions.

## MVP scope

The MVP includes:

- one user-scoped FatCat Agent managed by a macOS LaunchAgent;
- one Unix socket, Hermes home, conversation index, and Hermes session per
  conversation;
- simultaneous native Swift and Electron clients;
- a native latest-exchange mini-chat with text input, microphone, close, and
  spoken-reply controls;
- a pet-size setting from 120 to 360 points, persisted with 220 as the default;
- autonomous movement modes: Off, Calm, and Playful;
- automatic emotion animations plus an Advanced animation preview picker;
- clear disconnected states and reconnect without silent conversation creation.

The MVP does not redesign Electron's full conversation workspace, add cloud
sync, add a third-party TTS model, or add a full transcript/history browser to
the native pet.

## Architecture

The per-user LaunchAgent owns the only FatCat Agent process. The agent accepts
multiple local clients on a versioned newline-delimited JSON Unix socket. Each
client identifies itself as `native_pet` or `electron_chat` during the hello
handshake. Disconnecting either client removes only that connection; it never
shuts down Hermes.

The agent owns canonical conversation metadata under
`~/Library/Application Support/FatCat/`, including the selected conversation,
the Hermes session ID attached to each conversation, and the latest transcript
items needed by clients. Hermes keeps its existing persistent session data in
the shared FatCat Hermes home.

Swift and Electron may cache presentation state, but neither may create a
replacement conversation during reconnect. `new_conversation` is the only
operation that creates a new Hermes session.

## Client responsibilities

### Native Swift pet

The native pet retains the transparent floating panel, dragging, screen
observation, movement, permissions, menu-bar controls, voice input, and avatar.
Its pet panel remains square and is never resized to render chat.

Clicking the avatar toggles a separate borderless native mini-chat panel beside
the pet. The mini-chat shows the latest user message, the current/latest FatCat
reply, a concise connection or thinking state, a text composer, and three round
controls: microphone, close, and spoken replies. A second pet click hides this
panel. The close button does the same. The mini-chat has no history, expansion,
maximize, or full-screen control.

Speech input uses Apple's Speech framework and microphone APIs. Spoken replies
use `AVSpeechSynthesizer`, so the MVP adds no model process or network service.
Listening and speaking are explicit, visible states and pause autonomous flight.

### Electron chat

Electron remains the full workspace for transcript, markdown, conversation
history/search, session switching, retry, stop, providers, and settings that
belong to chat. It connects to the shared socket and no longer supervises or
terminates a FatCat Agent. Its conversation repository becomes a client of the
agent-owned store rather than an independent source of truth.

## IPC and data flow

The protocol adds typed client identity, conversation snapshots, conversation
selection/creation, pet clicks, and a shared stream of conversation and Hermes
state events. Commands that mutate a conversation carry a request ID and
conversation ID. The agent broadcasts resulting events to every connected
client.

Native click flow:

1. Swift toggles the native mini-chat immediately.
2. Swift sends `pet_clicked` with `pet_id: primary` and the selected
   conversation ID when available.
3. The agent broadcasts the typed event for shared state/diagnostics.
4. Electron stays open or closed as the user left it; the click does not focus
   Electron.

Message flow:

1. Either client sends `send_message` for the selected conversation.
2. The agent resolves the existing Hermes session; it does not create one
   implicitly during reconnect.
3. The agent broadcasts the user message, Hermes state, streaming reply, and
   completion to both clients.
4. Swift renders only the latest exchange. Electron renders the full transcript.

## Pet size, movement, and emotions

Native Settings persists the pet size and movement mode. Resizing preserves the
pet's on-screen anchor and clamps the resulting frame to the visible display.
The mini-chat positions itself from the actual pet frame and flips sides near a
screen edge.

Calm and Playful modes use the existing flight planner and safety policy with
different idle intervals and travel distances. Flight remains blocked while
the user is typing, dragging, listening, speaking, viewing mini-chat, handling
a permission, screen sharing, watching full-screen media, or using Reduce
Motion. Off disables autonomous movement but keeps manual dragging.

The avatar continues to choose animations from typed life and Hermes events:
`idle`, `curious`, `drowsy`, `sleeping`, `listening`, `thinking`, `working`,
`searching`, `suspicious`, and `celebrate`. Advanced Settings can temporarily
preview a selected animation without changing conversation or Hermes state.

## LaunchAgent lifecycle

Development installation uses a repository script that writes a user LaunchAgent
property list with explicit executable, socket, and Hermes-home paths, then
bootstraps it with `launchctl`. Both clients connect to the shared socket and may
request a LaunchAgent kickstart when it is registered but unavailable. Neither
client sends `shutdown` during normal app termination.

Release bundling of both application bundles and automatic runtime installation
is a follow-up packaging task. The MVP proves the real per-user LaunchAgent
lifecycle locally and keeps paths/configuration structured for packaging.

## Error handling

- Socket loss sets both clients to a clear disconnected state and starts bounded
  reconnect attempts.
- Reconnect reloads the selected conversation and existing Hermes session.
- Missing sessions produce an explicit recovery error; they never cause silent
  session replacement.
- Duplicate `pet_clicked`, snapshots, and completion events are idempotent.
- A second agent start is rejected by the LaunchAgent/singleton socket contract.
- Microphone or speech-recognition denial shows a native permission message and
  leaves text chat usable.
- TTS failure stops the speaking state without affecting the reply.

## Verification

Automated tests cover multi-client connection and broadcast, one agent process,
shared session identity, reconnect without session creation, idempotent events,
client-independent shutdown, pet panel size/position invariants, mini-chat
toggle/latest exchange, settings persistence, movement safety, voice state, and
Swift/Electron protocol parity.

Manual verification covers crisp mini-chat layout at several pet sizes and
screen edges, microphone permission and transcription, spoken replies, Calm and
Playful movement, animation preview, Electron/native live synchronization, and
closing each client independently.
