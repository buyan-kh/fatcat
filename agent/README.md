# FatCat Agent

FatCat Agent is the product-specific, headless Hermes distribution boundary. It
owns conversation, planning, provider routing, skills, memory, and goals. FatCat
talks to it over a private Unix domain socket using the versioned protocol.

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
