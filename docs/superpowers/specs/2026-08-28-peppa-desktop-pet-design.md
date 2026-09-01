# FatCat Anywhere Desktop Pet Design

## Decision

FatCat Anywhere will be a menu-bar companion with a small, transparent, always-on-top pet panel. Launching the app presents only the real FatCat avatar. Clicking FatCat opens a compact native speech bubble attached to her; closing it returns to the pet-only state. A right-click context menu and the menu-bar item expose privacy, pause, settings, memory, action history, and quit without turning the normal experience into a dashboard.

The existing React dashboard and its large Swift `WindowGroup` are prototype code, not the visible product path. Useful capture/privacy and avatar-state behavior will be retained behind smaller native boundaries.

## Architecture

### Native shell

`FatCatApp` owns an `NSApplicationDelegate` and creates:

- a borderless, transparent `NSPanel` for the pet and chat bubble;
- an `NSStatusItem` for privacy/settings controls;
- a small native settings window and native history/memory views opened on demand.

The pet panel uses `.floating`, `.canJoinAllSpaces`, and `.fullScreenAuxiliary`, has no title bar or shadow, and persists its top-left position in `UserDefaults`. The panel is draggable from the avatar surface and remains in front of normal app windows. The panel resizes between pet-only and chat modes while keeping the pet anchored to the same desktop position.

### Avatar surface

The real `strobI.avatar.json` definition and `@bible-strong/avatar-react` renderer remain the avatar implementation. The renderer is hosted in a transparent, non-navigable `WKWebView` sized only for FatCat. Its HTML, body, root, and canvas backgrounds are transparent. It has no dashboard components, page chrome, status text, or Vite dependency at runtime.

The native shell owns semantic state (`idle`, `listening`, `understanding`, `planning`, `askingPermission`, `acting`, `verifying`, `celebrating`, `recovering`, `suspicious`, `sleeping`) and maps those states to the real animation keys. Celebration is selected only by an explicit verified-success transition.

### Chat and menus

The speech bubble is native SwiftUI so text input, send, close, error display, and the optional expand control do not depend on the web renderer. Chat sends through `HermesACPClient`; it renders actual streamed assistant text and exposes a disconnected/error state rather than placeholder responses. Right-clicking the pet and clicking the status item share the same native command actions.

### Hermes

`HermesACPClient` launches the installed `hermes acp` executable, keeps stdin/stdout as newline-delimited JSON-RPC, initializes once, creates one session, and sends every message through that session. It parses streamed `session/update` agent-message chunks and terminal prompt responses. The executable path is configurable for tests and may be overridden by `FATCAT_HERMES_PATH`; model/provider configuration remains Hermes-owned and is not silently replaced by app defaults. Process launch, protocol, and provider failures are surfaced in the bubble and status item.

ACP is used because the installed Hermes CLI and authoritative Hermes documentation define it as a supported programmatic integration with session creation, prompt submission, streaming messages, tool events, and permission requests. The app will not call undocumented Python modules or imitate Hermes responses.

### Observation and safety

`CaptureCoordinator` remains the ScreenCaptureKit boundary. It requests Screen Recording permission from the packaged FatCat Anywhere process, emits structured active-app/window metadata, discards pixel buffers, and redacts configured private apps before data leaves the native process. Pause/resume is visible in FatCat’s state and the menu-bar status.

The current phase does not execute computer actions. The risk policy remains explicit: observation may run automatically, medium-risk actions require an approval surface, and high-risk actions stay blocked until an execution-time approval path exists. Verified-success state is unavailable to the UI unless verification reports success.

## Testing and verification

- Swift unit tests cover pet-state-to-animation mapping, position persistence, panel configuration, context-menu commands, Hermes JSON-RPC decoding, and no-celebration-before-verification.
- TypeScript tests cover the avatar-only web surface, transparent document styles, real animation-key usage, and absence of `CompanionDashboard` from the normal entrypoint.
- `npm test`, `npm run lint`, `npm run build`, `swift test`, and `swift build` run before packaging.
- The packaging script creates `FatCat Anywhere.app` with bundle identifier `com.buyan.fatcat`, embeds the production avatar assets, and never starts Vite.
- Runtime smoke launches the packaged app, captures pet-only and open-chat screenshots, verifies transparency around the pet, drags and relaunches to verify position persistence, opens/closes chat, and confirms observation pause is visible.

## Limitations for this phase

Hermes must already be installed and configured on the Mac for real responses. Voice, OCR, raw screenshot understanding, and native computer-action execution remain outside this phase. Settings, memory, and history are intentionally small native secondary surfaces rather than a dashboard.
