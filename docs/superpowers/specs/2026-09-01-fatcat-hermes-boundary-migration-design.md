# FatCat–Hermes Boundary Migration Design

## Decision

FatCat is the body, interface, and safety boundary around Hermes. It is not a
second agent framework. Hermes is the sole source of truth for sessions,
conversation history, memory, planning, provider selection, tool selection,
browser/email/web/file work, and skills.

FatCat owns surfaces, channel routing, presence, native macOS permissions,
approval UI, native execution, independent verification, and a thin local
store for UI/device state. The migration covers the daemon, native pet,
mini-chat, Electron, and the legacy browser-facing agent prototype.

Existing FatCat-local memories and transcript copies are retired without
import into Hermes. They must not be read, summarized, or used as a fallback.

## Goals

- Attach every channel to the correct Hermes session and keep attached clients
  synchronized.
- Forward Hermes ACP events through one generic, versioned event model.
- Render tool lifecycle state without custom FatCat implementations for
  individual Hermes tools.
- Enforce native macOS permissions, target validation, approval, execution, and
  independent verification at the FatCat boundary.
- Keep the local store limited to UI preferences, native permission state,
  channel connection state, selected session handles, and approval/audit
  metadata.
- Retire duplicate local memory, planning, goals, learning, and transcript
  state safely and observably.

## Non-goals

- Reimplementing Hermes memory, planning, browser automation, email, web
  research, file operations, or task execution.
- Building a FatCat tool registry or bespoke UI flow for each Hermes tool.
- Silently switching providers or creating a local model fallback.
- Allowing Hermes or a tool to bypass macOS permissions or FatCat approval.

## Runtime topology

```text
FatCat surfaces
  native pet · mini chat · Electron · future iMessage/voice
        │ messages, subscriptions, approval responses
        ▼
FatCat daemon / Hermes adapter
  channel routing · session attachment · event fan-out
  reconnect cursors · approval/audit correlation
        │ ACP prompts, session calls, permission outcomes
        ▼
Hermes
  sessions · history · memory · planning · providers · tools · skills
        │ typed native proposals and tool lifecycle events
        ▼
FatCat native executor
  macOS permissions · Accessibility · approval · execution · verification
```

Hermes `session_id` is canonical. FatCat retains only a conversation handle as
UI/channel metadata pointing to that Hermes session; it is never a second
history record. Hermes ACP owns
session creation, loading, listing, cancellation, and history replay.

## Ownership contract

| Concern | Owner | FatCat behavior |
| --- | --- | --- |
| Session lifecycle and history | Hermes ACP | Attach, load, and display; never duplicate transcript bodies |
| User memory | Hermes memory system | Display Hermes memory notifications when useful |
| Planning and goals | Hermes | Render generic plan/activity events |
| Provider and tool choice | Hermes | Forward and render generic lifecycle events |
| Browser, email, web, and file work | Hermes tools | No parallel FatCat engines |
| Surface/channel state | FatCat | Route messages and synchronize clients |
| UI/device preferences | FatCat local store | Persist only non-content settings |
| Native permissions and approvals | FatCat | Enforce immediately before risky work |
| Native execution and verification | FatCat native executor | Execute only approved, verified proposals |

## Adapter protocol

Commands from every surface include a `channel_id`, canonical `session_id`,
request/correlation ID, and either user text or privacy-filtered screen
context. The daemon forwards prompts to Hermes ACP and broadcasts events to all
subscribed channels for that session.

Normalized events use a versioned envelope:

```json
{
  "version": 2,
  "event_id": "…",
  "kind": "tool.needs_approval",
  "session_id": "…",
  "request_id": "…",
  "summary": "Send email to Sarah",
  "details": {"tool": "send_email", "risk": "high"}
}
```

Supported lifecycle kinds are:

- `message.started`, `message.delta`, `message.completed`
- `tool.started`, `tool.progress`, `tool.needs_approval`,
  `tool.completed`, `tool.failed`
- `native_action.proposed`, `native_action.approval_requested`,
  `native_action.result`
- `verification.completed`
- `session.state`, `session.error`
- `memory.updated` (display-only Hermes notification)

Structured details are sanitized and can never contain API keys, access or
refresh tokens, cookies, passwords, secrets, or equivalent credential fields.
Clients render the tool name, human-readable summary, and current state from
this generic model. They do not infer tool behavior or select tools.

Hermes history is the only durable replay source. The daemon may retain a
bounded in-memory fan-out buffer for connected clients, but it never persists
message bodies, assistant deltas, plans, tool arguments, or tool results.
Reconnect reattaches to the existing Hermes session, reloads Hermes history,
and receives available in-flight state. A disconnect never shuts down Hermes
or creates a replacement session.

## Native safety handshake

Hermes may propose `type_text`, `click_element`, `send_email`, `open_file`,
`run_process`, or another supported action, but it cannot execute the mutation
directly.

1. Hermes emits a proposal with a stable proposal ID and expected result.
2. FatCat classifies risk, checks relevant macOS permission, and validates the
   target immediately before execution.
3. Medium/high-risk work emits `tool.needs_approval` and the surface shows the
   exact action summary. Approval is one-shot and tied to the proposal ID.
4. FatCat executes only an approved, locally valid proposal through the native
   executor.
5. FatCat emits execution result and independently probes the expected state,
   then emits `verification.completed`.
6. The adapter returns the outcome to Hermes so Hermes can continue, retry, or
   decide whether the result is memory-worthy.

Denial, timeout, missing permission, target mismatch, executor failure, and
verification failure are explicit typed outcomes. Approval cannot be inferred
from a prior action or from a tool argument.

## Local-data retirement

At the migration schema/version bump:

- stop reading the layered-memory key and local goals/learning state;
- retire the FatCat transcript payload and assistant-delta fields;
- remove active copies of those content records and write only a migration
  marker/audit timestamp;
- retain only non-content UI/session metadata needed to reconnect to Hermes;
- never import, summarize, or silently merge retired content into Hermes.

The migration is idempotent. A restarted client cannot resurrect retired data.
Hermes memory and history remain untouched and are never overwritten by the
retirement step.

## Migration sequence

1. Freeze protocol schemas and contract tests, with a temporary v1 decoder for
   already-released clients.
2. Convert the daemon conversation store to metadata-only session indexing;
   source listing and history from Hermes ACP.
3. Normalize Hermes ACP updates into the generic lifecycle event model and
   implement session-scoped fan-out/reconnect.
4. Add approval continuations and native executor/verification result routing.
5. Replace native pet, mini-chat, and Electron reducers/views with generic
   Hermes event consumption.
6. Remove the legacy browser prototype's local memory, planner, dialogue,
   critic, goals, and learning paths from the product build.
7. Run the data-retirement migration and remove obsolete content persistence.
8. Remove the v1 compatibility path after all supported clients use v2.

## Error handling

- Hermes startup/provider/tool errors pass through as retryable, typed events;
  FatCat does not invent a local fallback.
- Approval cancellation or timeout returns a denied outcome to Hermes.
- Permission and target failures stop execution before mutation.
- Verification failure is distinct from execution failure and is shown as such.
- Duplicate event IDs are ignored; stale session events cannot update another
  session's clients.
- A channel closing leaves Hermes and other channels running.

## Verification and acceptance criteria

Python tests cover Hermes session routing, no transcript writes, event
normalization, approval continuations, credential rejection, and idempotent
retirement. TypeScript tests cover protocol schemas, generic activity
reduction, reconnect/session identity, and the absence of local agent imports.
Swift tests cover native policy, permissions, target validation, execution,
verification, and approval state. End-to-end tests attach two clients to one
Hermes session, stream a response, show tool progress, approve and deny risky
actions, reconnect, and restart/resume from Hermes history.

The full repository matrix must pass, and a code search must show no active
FatCat memory/planner/tool registry or transcript fallback. The runtime proof
is complete only when Hermes is the sole authority for intelligence and data,
while FatCat remains the sole authority for presence, channels, permissions,
approvals, native execution, and trust.
