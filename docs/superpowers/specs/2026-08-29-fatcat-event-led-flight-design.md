# FatCat Event-Led Desktop Flight Design

## Goal

Make FatCat feel like an active desktop agent: it should stay mostly still when nothing salient is happening, fly to a safe desktop position in response to meaningful agent or user events, and stop repeating whole-body grow/shrink motion as its idle loop.

## Approved behavior

The motion personality is a reactive drifter. Desktop flights are event-led rather than continuously chained or timer-driven. FatCat may remain grounded for long periods, then move purposefully when the agent or user gives it a meaningful reason to react.

While grounded, the whole-body scale remains neutral at `1.0`. The existing avatar animation, eye attention, ear twitches, and non-scaling posture details may continue. Body scale changes are short reactions to events and are never produced by the idle timer loop.

### Event mapping

| Event | Visual reaction | Desktop flight |
| --- | --- | --- |
| User clicks FatCat | Brief perk/bounce and small size increase | No flight |
| User opens chat | Wake/listening pose | No flight |
| User closes chat | Return-to-anchor movement when safe | Optional short flight |
| Agent starts thinking/planning | Attention reaction | No flight by itself |
| Tool call begins | Purposeful movement cue | Queue a flight until movement is safe |
| Permission requested | Noticeable perk/size reaction | Queue a flight until movement is safe |
| Verified success | Celebration pulse | Purposeful flight when safe |
| Failure/disconnect | Brief uneasy recoil | No flight |
| Screen/app change | Eye/attention shift | No flight by itself |

Repeated streamed updates must be debounced into at most one pending flight cue. A flight cannot start while chat is open, the user is typing, FatCat is being dragged, Reduce Motion is enabled, the pet is asleep, movement is paused/locked, or another policy block is active. A queued cue is consumed when the state becomes safe. Existing curved paths, edge margins, persistence, cancellation, and appendage follow-through remain in use.

The current timer evaluation remains available only for state maintenance and safety checks; it must not independently create idle reposition flights for this behavior. The existing long cooldown remains as a guard between event-led flights.

## Architecture

Native Swift remains responsible for panel movement and event policy. `FatCatFlightController` receives salient life/agent transitions, maps them to flight reasons, queues or starts a plan after checking `FatCatFlightPolicy`, and sends phase cues to the avatar web surface. The existing `FatCatMovementPlanner` and `FatCatWindowAnimator` remain unchanged unless tests identify a necessary correction.

The avatar web surface owns presentation-only reactions. It receives a new cancellable reaction cue through the existing native bridge, renders a short reaction pulse, and composes that pulse with flight phase transforms. Its grounded idle frame must not call the repeating `idleLifePose` body-scale track; the idle loop may retain non-scaling attention details.

The native event source remains `FatCatLife` and `FatCatAppDelegate` agent message handling. Event-to-flight mapping must be explicit and testable rather than inferred from arbitrary animation keys.

## Error handling and accessibility

If the avatar surface is not ready, native flight/reaction cues remain pending and are replayed once the bridge is ready. If a policy check fails, no window movement occurs; a safe pending cue may remain for a subsequent safety evaluation, but only one cue is retained. Cancelling, dragging, pausing movement, position locking, sleep, Reduce Motion, and chat focus must return the avatar to a neutral non-looping grounded presentation without teleporting the panel.

When Reduce Motion is enabled, the web surface suppresses flight and reaction transforms as it does today. Native policy continues to block autonomous movement.

## Testing and verification

TypeScript tests will prove that grounded idle presentation has neutral body scale, event reactions start and settle within their duration, reaction cues are exposed through the avatar bridge, and existing flight surface constraints remain intact.

Swift tests will prove the event-led decision table, suppression of timer-only idle flights, one-cue debouncing, deferral while unsafe, and execution when the context becomes safe. Existing flight planner, state-machine, life-state, chat, IPC, and attachment tests must continue to pass.

Verification will run the focused Vitest and Swift tests first, then the full `npm test`, TypeScript build/lint, and Swift test/build commands supported by the repository. A packaged runtime smoke check will confirm that FatCat stays visually still while idle, moves after a salient event, and no longer grows and shrinks every few seconds.
