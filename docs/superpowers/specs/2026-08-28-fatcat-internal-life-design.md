# FatCat Internal Life Design

## Decision

FatCat’s face is driven by a local event-sourced creature in `PeppaAnywhereCore`, not by Hermes session state. Hermes, the user, the clock, and observation deltas are causes. Chat transcript, session resume, pending prompts, and Peppa IPC stay as they are.

Approach: native overlay engine. `FatCatLife` reduces events into mood, attention, work, and an optional current task, then derives an animation key for the existing WKWebView bridge.

## Architecture

`FatCatLife` is a pure Swift value type: `(life, event, now) → life`. The app injects time. A 1-second timer in `PetWindowController` sends `tick`. Observation only emits `observationChanged` when app or window actually changes.

Work from a chat turn overlays life. When the turn ends, work clears and mood/attention/task continue. Agent `idle` and `listening` are not events; they must not freeze the cat into `idle`.

`PeppaState` remains a derived label for existing UI copy. `PeppaStateMachine` and its celebration tests stay. The avatar is driven by `life.animationKey`, which may use `curious` and `drowsy` in addition to the current eight work keys.

## Event model

```text
FatCatLifeEvent
  tick
  userClickedAvatar | userOpenedChat | userClosedChat
  userSentMessage(requestID, conversationID)
  userStoppedGeneration | userStartedNewChat
  observationChanged(app, window, redacted)
  observationPaused | observationResumed
  hermes(FatCatHermesCause)
```

Hermes causes: `streamDelta`, `thought`, `plan`, `toolCall`, `permissionRequested`, `actionSucceeded`, `actionFailed`, `verifiedSuccess`, `verifiedFailure`, `turnCompleted`, `turnFailed`, `disconnected`.

Life fields: `mood` (calm, curious, pleased, uneasy, tired), `attention` (none, user, screen(app)), `work` (none, listening, thinking, acting, asking, verifying, celebrating), `task` (optional conversationID), `observationPaused`, `asleep`, `lastCause`, `lastSalientAt`.

## Display

Work wins while a turn is active, except pause/asleep which force `sleeping`.

| Condition | Animation |
| --- | --- |
| paused or asleep | `sleeping` |
| work listening / asking | `listening` |
| work thinking / verifying | `thinking` |
| work acting | `working` |
| work celebrating | `celebrate` |
| work none + uneasy | `suspicious` |
| work none + curious | `curious` |
| work none + tired (awake) | `drowsy` |
| otherwise | `idle` |

`verifiedSuccess` is accepted only when `work == verifying`. Celebrating auto-clears after 2 seconds to `work none` and mood `pleased`.

## Loops

- Curiosity from a non-redacted observation change while `work == none`; fades to calm after 20 seconds.
- No salient event for 3 minutes → tired/`drowsy`; 8 minutes → `asleep`.
- User send → listening, attend user, remember conversation.
- New chat clears task.
- `turnCompleted` clears work and keeps task.
- Redacted observation changes do not spark curiosity.

## Out of scope

Python observation consumption, native action execution, permission approval handshake, IPC schema changes, and rewriting `FatCatChatState`.

## Testing

Swift tests in `FatCatLifeTests` cover idle default, observation curiosity, tick decay, sleep, send overlay, Hermes mapping, celebration gate, agent-idle ignored, pause override, task continuity, and new-chat clear. Existing chat, IPC, and `PeppaStateMachine` tests must keep passing.
