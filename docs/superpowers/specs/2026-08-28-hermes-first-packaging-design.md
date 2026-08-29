# FatCat Hermes-First Packaging and Provider Setup Design

## Decision

FatCat will be a Hermes-first product distribution. Hermes remains the agent
runtime responsible for the agent loop, model calls, provider routing, tools,
skills, memory, and session persistence. FatCat owns the native macOS shell:
avatar, chat surface, screen observation, permissions, native action policy,
settings, and packaging.

FatCat will maintain an in-repository, pinned Hermes fork under
`vendor/hermes/`. The initial fork will preserve Hermes internals and apply
only the adapter and credential changes needed by the FatCat product. This is
not a from-scratch rewrite. Hermes's MIT license and copyright notice will be
included in the source distribution and the packaged app's third-party
notices.

## Goal

A user can download and install a FatCat `.dmg`, launch the app without a
separate Hermes installation, connect a supported model provider, explicitly
choose a default provider and model, chat through Hermes, and relaunch while
retaining the Hermes session and user data.

The first supported setup slice is:

- Hermes as the embedded runtime health surface, not a model-provider row.
- OpenAI Codex subscription authentication, detected through the official
  Codex CLI/auth store with explicit user consent to connect or import it.
- OpenAI-compatible API endpoints with a display name, base URL, model, and
  API key.
- Anthropic API credentials, labeled as Anthropic API rather than implying
  that a consumer Claude subscription grants API access.

FatCat will not silently auto-route requests or fall back to another provider.
The user selects one explicit default `provider + model` pair.

## Architecture

```text
FatCat.app
├── Swift UI, avatar, screen permissions, and native action policy
├── FatCatAgent product adapter
├── vendored Hermes fork
├── bundled Python runtime and locked dependencies
└── user data in ~/Library/Application Support/FatCat/Hermes
    ├── config.yaml
    ├── sessions/
    ├── skills/
    └── memory/
```

At build time, the project will stage only the Hermes runtime files needed for
headless ACP operation, the compatible Python runtime, locked dependencies,
the FatCat adapter, and non-secret metadata recording the Hermes commit and
dependency versions. It must never copy the developer's personal Hermes data,
auth files, or API keys into the app bundle.

At runtime, FatCat starts the embedded agent with a private per-app
`HERMES_HOME` under Application Support. Hermes owns its config, sessions,
memory, and skills there. Swift owns only UI state and the stable conversation
IDs required to reconnect to Hermes.

The process boundary remains narrow:

```text
Swift Settings ──non-secret control messages──> FatCatAgent ──> Hermes APIs
Swift Chat      ──session messages────────────> FatCatAgent ──> Hermes
Swift actions   <──typed proposals/results──── FatCatAgent
Keychain        <──credential resolver──────── FatCatAgent/Hermes transport
```

The existing `agent/peppa_agent` layer becomes the product adapter around the
vendored Hermes runtime rather than a second agent implementation. Existing
ACP/session behavior remains the source of truth for conversation lifecycle.

## Settings and provider flow

Settings will expose a compact Hermes-first surface:

- A top-level Default Model control showing the selected provider and model.
- A Connections list for Codex, OpenAI-compatible API, and Anthropic API.
- FatCat Agent health shown separately from model-provider connections.
- Status values of detected, configured, needs login, needs API key,
  unavailable, or error.
- Refresh for detection and model discovery.
- Provider-specific setup forms and an explicit Set as Default action.

Model and provider inventory will come from Hermes's provider/model inventory,
not from a duplicated Swift catalog. Custom OpenAI-compatible endpoints may
accept a manually entered model when model listing is unavailable.

First launch will start the embedded agent, inspect supported local/provider
state without exposing secrets, show what was found, and ask the user to
choose a default model. If nothing is configured, it will present the setup
choices without inventing a default.

Codex setup will detect the official CLI and auth store, show only safe account
and source metadata, request explicit user consent, import/connect the
credential, discover available models, and test the selected model through
Hermes before marking the connection usable.

OpenAI-compatible and Anthropic API setup will save provider metadata and a
Keychain reference, validate the credential through Hermes, and only then mark
the connection usable. Anthropic UI copy will use “Anthropic API”; Claude Code
OAuth can be added later as a separate auth mode.

## Credential and security design

The existing rule rejecting `api_key`, `access_token`, `refresh_token`,
`password`, `cookie`, and `secret` fields in the public FatCat IPC remains in
place.

Swift stores API keys and imported OAuth credentials in macOS Keychain.
Hermes config stores only non-secret provider metadata and a credential
reference. A local credential resolver backed by Keychain supplies secrets to
provider transports in memory. Secrets must not travel through chat messages,
normal JSON events, logs, or YAML config.

Provider removal deletes the Keychain item and non-secret Hermes config entry.
Uninstall leaves user data recoverable unless the user explicitly chooses to
remove FatCat data.

Credential detection is not the same as authentication. A provider is marked
usable only after a provider/model test succeeds. Expired, invalid, missing,
or rate-limited credentials produce safe status details without exposing token
contents.

## Error handling

- Missing or corrupt agent bundle: explain that FatCat Agent could not start
  and provide diagnostics.
- No provider configured: open setup guidance rather than emitting only a
  generic provider error.
- Missing Codex CLI: provide installation guidance and API-key alternatives.
- Expired Codex auth: offer reconnect/import again.
- Invalid API key: show provider-safe validation failure and keep the key only
  according to the user's explicit save choice.
- Model discovery unavailable: permit manual model entry and label discovery
  as offline.
- Unavailable selected default: preserve the user's choice, explain the
  failure, and ask for repair or an explicit change; never silently switch.
- Provider request failure: surface a retryable provider-safe error while
  keeping Hermes alive.

## Testing and verification

Hermes-fork tests will cover provider inventory, default-model persistence,
credential references, Codex detection/import, Keychain resolution behavior,
and model validation results.

FatCat agent tests will cover non-secret control messages, safe error events,
and the existing session/ACP behavior.

Swift tests will cover settings state, provider-status rendering data, IPC
round trips, and preservation of the credential-field rejection rule.

Packaging verification will:

- Build the exact `.app` and `.dmg` with no external Hermes checkout.
- Run from a clean temporary `HERMES_HOME` with no developer config.
- Assert that personal paths, auth files, API-key literals, and developer
  Hermes data are absent from the bundle.
- Launch the packaged app, connect one supported provider, choose a default,
  send a chat, restart, resume the session, and remove/re-add a credential.

The implementation is complete only when a clean-machine simulation proves
that the `.dmg` alone supports install, provider setup, explicit model choice,
chat, and session resume.

## Scope boundaries

This phase does not rewrite Hermes's agent loop, add silent provider routing,
bundle every Hermes surface such as the gateway or desktop UI, add more model
providers beyond the stated slice, or implement voice. The vendored fork may
remove unused packaging surfaces, but it must preserve the runtime modules
required by FatCat's headless agent, providers, tools, skills, memory, and
ACP/session integration.
