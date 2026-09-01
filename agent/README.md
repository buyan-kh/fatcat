# FatCat Agent

FatCat Agent is the product-specific, headless adapter around Hermes. Hermes
owns sessions, history, planning, provider routing, skills, memory, and tools.
FatCat owns channel routing, native permissions, approval continuations, and
verification at the macOS boundary. FatCat talks to Hermes over a private Unix
domain socket using the versioned protocol and forwards generic lifecycle
events to every connected surface.

Conversation records are metadata-only handles. The daemon never persists
message bodies, transcript deltas, memory, goals, or tool state. Reloading a
conversation asks Hermes for its session history; local state is limited to
window/UI preferences, connection state, and approval/audit metadata.

Hermes ACP's persistent session manager is used for `session/new`,
`session/load`, `session/list`, and `session/cancel`. The build stages the
pinned Hermes source and Python runtime inside the app.

## Persistent shared daemon

For local development, register the one user-scoped agent with:

```bash
./scripts/install-fatcat-launch-agent.sh
```

Both the native pet and Electron connect to
`~/Library/Application Support/FatCat/runtime/fatcat-agent.sock`. Closing either
client leaves the agent and the other client running. Remove only the launchd
registration with `./scripts/uninstall-fatcat-launch-agent.sh`; the uninstall
script preserves conversations and Hermes data.
