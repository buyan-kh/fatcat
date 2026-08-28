# Peppa Anywhere

Peppa Anywhere is a local-first macOS companion MVP built around the real Peppa avatar definition in [`public/strobi.avatar.json`](public/strobi.avatar.json). The JSON filename remains `strobi` for compatibility; the definition itself is Peppa. The original avatar playground is preserved below the companion surface.

## Run the local companion surface

```bash
cd /Users/buyan/Projects/Fatcat
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

Open `http://127.0.0.1:5173`. This browser MVP runs without paid model APIs. **Observe now** uses a deterministic local context example; it never uploads a screenshot. The buttons exercise the real state machine, risk gates, approval queue, verification gate, action history, goals, and local memory.

## Run the native macOS host

The native host wraps the production Vite companion surface in a small floating SwiftUI window and provides the opt-in ScreenCaptureKit path. The normal run path builds and copies the web assets into the Swift package, so no web server is required:

```bash
cd /Users/buyan/Projects/Fatcat
./scripts/run-peppa-macos.sh
```

The script runs `npm run build`, copies `dist/` into the Swift package resource bundle, then launches `swift run`. Click **Request Screen Recording** in the web surface, approve the request in **System Settings → Privacy & Security → Screen Recording**, then click **Observe now**. The host extracts only active app/window metadata. Screen frames are configured at 2×2 pixels, never read or encoded, and never retained or uploaded. Use **Pause observation** whenever Peppa should be quiet; pausing stops the native `SCStream`, and resuming starts it again only after authorization.

For Xcode development, open `macos/PeppaAnywhere/Package.swift` after running the asset preparation step. To use a local Vite server instead of bundled files, set `PEPPA_DEV_SERVER_URL`:

```bash
./scripts/prepare-peppa-web-assets.sh
PEPPA_DEV_SERVER_URL=http://127.0.0.1:5173 swift run --package-path macos/PeppaAnywhere
```

The source is an executable Swift package intended for Xcode or Swift 6 on macOS with ScreenCaptureKit available. On this checkout, the native package is verified with `swift build`, `swift test` with the installed Command Line Tools’ Swift Testing framework path, and a bounded `swift run` launch smoke.

On a full Xcode toolchain, the native tests run with the normal command:

```bash
swift test
```

This machine’s Command Line Tools install keeps `Testing.framework` outside SwiftPM’s default runner search path. The equivalent authoritative local command is:

```bash
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

## Architecture

- `src/lib/companion.ts` — semantic state machine and exact Peppa animation mapping.
- `src/lib/observation.ts` — structured screen observation schema and private-app redaction.
- `src/lib/risk.ts` — low/medium/high action classification and approval enforcement.
- `src/lib/interruption.ts` — actionable-only interruption policy with confidence, busy-state, and cooldown gates.
- `src/lib/verification.ts` — expected-vs-observed critic; celebration requires verified success.
- `src/lib/memory.ts` and `src/lib/goals.ts` — inspectable, deletable local stores persisted through browser local storage.
- `src/lib/native-bridge.ts` — small event/message seam between the web surface and native host.
- `macos/PeppaAnywhere/Sources/PeppaAnywhere/main.swift` — SwiftUI/WKWebView host with explicit ScreenCaptureKit permission flow.

The loop is `observe → interpret → check goals → decide whether to respond → plan → request permission → act → verify → remember → update Peppa state`. Specialized seams are represented by the observation, local classifier, dialogue/UI, planning/state, action/risk, verification, and memory modules; a paid model provider is not required.

### Privacy guarantees and limitations

- Local-only by default; no network calls or model API keys are required.
- Screenshot retention is permanently disabled in this MVP; the native host discards pixel buffers immediately and the bridge exposes no retention-enabling command.
- Private-app exclusions are edited in the web UI and propagated to the native host; the active app, window, and task are redacted before structured observations leave the host.
- Medium-risk actions are prepared and require approval. High-risk actions always remain blocked in this MVP, even after a queue click; destructive behavior is never silently enabled.
- Safe local actions currently include structured-context inspection and explanation/history updates. Typing into another app, file mutation, sending/publishing, spending, and destructive commands are deliberately adapter seams, not hidden capabilities.
- The browser fallback is a deterministic demo because browsers cannot call ScreenCaptureKit directly. The native Swift host is the capture path.
- Local storage is user-visible through the memory panel and can be deleted entry-by-entry. Corrections are stored as explicit semantic or procedural records; the app does not rewrite its own code or policies.
- Interruption is suppressed while typing or in a meeting, at low confidence, for non-actionable events, and during cooldown.

### Avatar and license

Peppa’s semantic states use the real animation keys: `idle`, `listening`, `thinking`, `working`, `searching`, `happy`/`celebrate`, `suspicious`, and `sleeping`, with real expression fallbacks such as `attentive-left`, `suspicious-right`, and `sleepy-squint`. No replacement art or generic emoji is used.

The installed `@bible-strong/avatar-react` package declares **AGPL-3.0-only**. Before distributing or hosting Peppa, keep the package license and attribution with the copied avatar assets and review the project’s obligations with legal/compliance.

## Checks

```bash
npm install
npm test
npm run lint
npm run build
```

The lab starts with the supplied `Peppa` definition (28 expressions and 23 animations). Use **Import avatar JSON** to load another valid Bible Strong definition into the same session. Imported definitions stay in browser memory only and can be removed from the definition rail. Notes are saved to this browser's local storage.

For copy-paste integration patterns across future React projects, read [`docs/PEPPA-ANYWHERE.md`](docs/PEPPA-ANYWHERE.md).
