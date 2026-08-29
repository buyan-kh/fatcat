# FatCat Product Design

## Decision

FatCat is a visual, voice-enabled, screen-aware interface for Hermes. It gives Hermes a face, eyes on the screen, and presence. It is not a second intelligence, not a Codex clone, not a browser-automation product, and not a replacement for Hermes.

Hermes already has conversation, tools, memory, skills, models, coding, and web access. FatCat adds embodiment: a transparent avatar, privacy-filtered screen context, chat as a polished Hermes ACP session, and later voice. Avatar animations are driven by real Hermes state plus local presence (idle, eyes-on-screen, inactive sleep).

## Architecture

```text
                 ┌───────────────────┐
                 │       Hermes      │
                 │ intelligence      │
                 │ memory            │
                 │ tools             │
                 │ skills            │
                 │ models            │
                 └─────────┬─────────┘
                           │ ACP
                 ┌─────────▼─────────┐
                 │      FatCat       │
                 │ native macOS app  │
                 └──────┬────┬───────┘
                        │    │
                 screen │    │ voice
          ┌─────────────▼┐  ┌▼─────────────┐
          │ScreenCapture │  │STT and TTS   │
          │Vision and AX │  │microphone    │
          └──────────────┘  └──────────────┘
```

`FatCatLife` in `PeppaAnywhereCore` is a display reducer, not an agent. It maps user, screen, clock, and Hermes causes onto an animation key for the existing WKWebView avatar. Chat transcript, Hermes sessions, pending prompts, and Peppa IPC stay as they are. Memory stays in Hermes; FatCat only displays and selects sessions.

## Hermes state → face

| Hermes / presence | Animation |
| --- | --- |
| Waiting | `idle` |
| User speaking / send / permission | `listening` |
| Reasoning | `thinking` |
| Using a tool | `working` |
| Searching | `searching` |
| Uncertain | `suspicious` |
| Failed | `suspicious` (semantic recovering; JSON has no recovering timeline) |
| Verified | `celebrate` |
| Inactive / observation paused | `sleeping` |
| Active app changed, no turn | `curious` (eyes on the screen) |

`verifiedSuccess` is accepted only from `verifying`. Celebrating is not cancelled by Hermes `completed`; it clears after 2 seconds. Agent `idle` / `listening` are not events — waiting is `work == none` → `idle`, unless the cat is watching the screen or inactive.

Search tool names (containing `search`) set `work = searching`. Other tools set `acting`.

## Screen

FatCat does not constantly analyze everything. This slice emits a life event when the active app or window actually changes, and still inlines privacy-filtered app/window context into a user message. Raw screenshots are not retained. Streaming observation IPC remains unused by the agent.

Later: selected text, visible errors, dialogs, OCR when useful, and observation only when the user asks about the screen, a dialog appears, a click causes a major change, Hermes needs context, or proactive observation is on.

## Out of scope

Voice STT/TTS, Python observation consumption, native action execution, permission approval handshake, IPC schema changes, rewriting `FatCatChatState`, rebuilding Hermes memory, browser agents, coding-agent identity, computer-use benchmarks.

## Testing

Swift tests in `FatCatLifeTests` cover idle default, screen curiosity, inactivity sleep, send overlay, Hermes mapping including search tools, celebration gate, ignored agent-idle, pause, task continuity, and new-chat clear. Existing chat, IPC, and `PeppaStateMachine` tests must keep passing.
