# FatCat Hermes-First Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship FatCat with an in-repository Hermes runtime, native provider setup for Codex/OpenAI-compatible/Anthropic connections, explicit default-model selection, and a self-contained packaged app.

**Architecture:** Vendor the pinned Hermes source without build artifacts, keep Hermes responsible for model/provider/runtime behavior, and extend the existing FatCat agent adapter with non-secret control operations. Swift owns the native Settings UI and Keychain references; Hermes owns provider inventory, auth tests, model discovery, and default configuration.

**Tech Stack:** Swift 6/macOS SwiftUI/AppKit, Python 3.11 runtime, Hermes Python agent, Unix-domain newline-delimited JSON IPC, macOS Keychain, Swift Testing, Python unittest, shell packaging scripts.

---

## File map

- Create `vendor/hermes/`: tracked Hermes source snapshot at commit `533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9`, excluding `.git`, `node_modules`, `venv`, `.hermes-runtime`, tests, desktop/web/gateway packaging surfaces, and user data.
- Create `vendor/hermes/LICENSE`: upstream MIT license and copyright notice.
- Create `scripts/vendor-hermes.sh`: repeatable source-sync script that refuses a mismatched source commit unless explicitly overridden.
- Modify `scripts/build-fatcat-agent.sh`: use the tracked vendor source by default, stage only runtime files plus bundled Python/dependencies, and write commit/dependency metadata.
- Modify `scripts/verify-fatcat-macos-app.sh`: verify the bundle has the vendored runtime and no external Hermes path or developer auth/data.
- Create `scripts/package-fatcat-dmg.sh`: verify a signed `FatCat.app` and create `dist/FatCat.dmg` with the self-contained app.
- Modify `agent/fatcat_agent/server.py`: add Hermes-owned non-secret provider inventory, model listing, validation, default selection, and credential-reference operations.
- Create `agent/fatcat_agent/config_bridge.py`: narrow Python adapter around Hermes config/auth/model APIs; no UI or socket parsing.
- Modify `agent/tests/test_server.py`: test control messages and safe error events.
- Create `agent/tests/test_config_bridge.py`: test provider filtering, default persistence, credential references, and secret redaction.
- Modify `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift`: add non-secret control request/response messages while preserving credential rejection.
- Create `macos/FatCat/Sources/FatCatCore/FatCatCredentials.swift`: Keychain-backed credential references and redacted status values.
- Create `macos/FatCat/Sources/FatCatCore/FatCatProviderSetup.swift`: testable provider/default state model and status mapping.
- Modify `macos/FatCat/Sources/FatCat/AppMain.swift`: connect the settings window to the agent control channel and credential store; remove the hand-maintained provider catalog from the visible setup surface.
- Modify `macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift`: round-trip all control messages and verify secret fields remain rejected.
- Create `macos/FatCat/Tests/FatCatCoreTests/FatCatProviderSetupTests.swift`: test setup-state transitions, explicit default selection, validation failure preservation, and redacted credentials.
- Modify `macos/FatCat/Tests/FatCatCoreTests/ProviderDiscoveryTests.swift`: replace the broad provider catalog contract with the Hermes-first supported slice.
- Add `scripts/test-hermes-bundle.sh`: build a clean temporary staging directory, start the staged runtime, and assert it contains no personal paths, auth files, or key literals.
- Modify `README.md`: document the vendored Hermes runtime, provider setup, MIT attribution, and clean packaging verification.

### Task 1: Vendor the pinned Hermes runtime source

**Files:** `vendor/hermes/`, `vendor/hermes/LICENSE`, `scripts/vendor-hermes.sh`, `scripts/build-fatcat-agent.sh`, `scripts/verify-fatcat-macos-app.sh`.

- [ ] **Step 1: Write the failing packaging contract test**

Create `scripts/test-hermes-bundle.sh` with assertions for the tracked source, pinned commit metadata, required runtime modules, and absence of build artifacts:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/hermes"

[[ -f "$VENDOR/run_agent.py" ]]
[[ -f "$VENDOR/hermes_cli/auth.py" ]]
[[ -f "$VENDOR/hermes_cli/models.py" ]]
[[ -f "$VENDOR/acp_adapter/server.py" ]]
[[ -f "$VENDOR/plugins/model-providers/openai-codex/__init__.py" ]]
[[ -f "$VENDOR/LICENSE" ]]
[[ "$(cat "$VENDOR/FATCAT_HERMES_COMMIT")" == "533886c8b8eb67ff8b389b7f48e7d5e5d9c575b9" ]]
[[ ! -d "$VENDOR/.git" ]]
[[ ! -d "$VENDOR/node_modules" ]]
[[ ! -d "$VENDOR/venv" ]]
[[ ! -d "$VENDOR/.hermes-runtime" ]]
! find "$VENDOR" -type f \( -name 'auth.json' -o -name '.env' \) -print -quit | rg .
echo "Vendored Hermes source contract passed"
```

- [ ] **Step 2: Run the contract to verify it fails**

Run `bash scripts/test-hermes-bundle.sh`.

Expected: fail because `vendor/hermes/` and its metadata do not yet exist.

- [ ] **Step 3: Add the repeatable vendor sync script**

Create `scripts/vendor-hermes.sh` that resolves `PEPPA_HERMES_SOURCE`, checks out exactly the pinned commit, refuses dirty source by default, copies source with `rsync`, excludes build artifacts and unused distribution surfaces, copies `LICENSE`, and writes `FATCAT_HERMES_COMMIT`. The script must refuse to overwrite a non-empty vendor tree unless `PEPPA_ALLOW_VENDOR_OVERWRITE=1` is set.

- [ ] **Step 4: Populate the tracked source snapshot**

Run `PEPPA_HERMES_SOURCE=/Users/buyan/.hermes/hermes-agent scripts/vendor-hermes.sh` and inspect the resulting tree with `find vendor/hermes -maxdepth 2 -type f` and `du -sh vendor/hermes`.

- [ ] **Step 5: Run the contract to verify it passes**

Run `bash scripts/test-hermes-bundle.sh`.

Expected: exit 0 with `Vendored Hermes source contract passed`.

- [ ] **Step 6: Switch app staging to the tracked source**

Update `scripts/build-fatcat-agent.sh` so its default source is `$REPO_ROOT/vendor/hermes`, it validates `FATCAT_HERMES_COMMIT`, and it stages `vendor/hermes` plus the local adapter. Keep `PEPPA_HERMES_SOURCE` as an explicit developer override for refreshing the vendor snapshot, not as a release-time dependency.

- [ ] **Step 7: Add packaging exclusions and provenance checks**

Update `scripts/verify-fatcat-macos-app.sh` to assert `PEPPA_HERMES_COMMIT` matches the source metadata, `node_modules`, `.git`, `.env`, `auth.json`, and developer absolute paths are absent from `Contents/Resources/FatCatAgent`, and the MIT license is present.

- [ ] **Step 8: Run the packaging contract and commit**

Run `bash scripts/test-hermes-bundle.sh` and `git diff --stat`.

Commit with:

```bash
git add vendor/hermes scripts/vendor-hermes.sh scripts/build-fatcat-agent.sh scripts/verify-fatcat-macos-app.sh scripts/test-hermes-bundle.sh
git commit -m "build: vendor Hermes runtime for FatCat"
```

### Task 2: Add the Hermes configuration bridge

**Files:** `agent/fatcat_agent/config_bridge.py`, `agent/fatcat_agent/server.py`, `agent/tests/test_config_bridge.py`, `agent/tests/test_server.py`.

- [ ] **Step 1: Write failing bridge tests**

Test that `ProviderInventory` returns only the supported slice, strips secret-shaped fields, persists one explicit `{provider, model}`, preserves an unavailable default, and returns validation errors without secret contents.

Use fakes for Hermes imports so tests do not require the full packaged runtime:

```python
def test_supported_inventory_is_hermes_owned():
    bridge = ConfigBridge(fake_config(), fake_auth(), fake_models())
    rows = bridge.inventory()
    assert [row["slug"] for row in rows] == ["openai-codex", "openai-api", "anthropic"]

def test_default_selection_persists_provider_and_model_only():
    config = fake_config()
    ConfigBridge(config, fake_auth(), fake_models()).set_default("openai-codex", "gpt-5")
    assert config.saved["model"] == {"provider": "openai-codex", "default": "gpt-5"}
    assert "api_key" not in repr(config.saved)
```

- [ ] **Step 2: Run focused tests to verify failure**

Run `PYTHONPATH=agent python3 -m unittest agent.tests.test_config_bridge -v`.

Expected: import or behavior failures because `config_bridge.py` and control operations are absent.

- [ ] **Step 3: Implement the minimal bridge**

Implement `ConfigBridge` with these methods (plus `set_base_url` for OpenAI-compatible endpoints):

```python
class ConfigBridge:
    def inventory(self) -> list[dict[str, object]]: ...
    def models(self, provider: str) -> list[str]: ...
    def status(self, provider: str) -> dict[str, object]: ...
    def set_default(self, provider: str, model: str) -> dict[str, str]: ...
    def set_credential_ref(self, provider: str, ref: str) -> dict[str, str]: ...
    def validate(self, provider: str, model: str) -> dict[str, object]: ...
```

Use Hermes `provider_catalog`, `get_auth_status`, `provider_model_ids`, `load_config`, and `save_config` through lazy imports. Filter to `openai-codex`, `openai-api`, and `anthropic`; return safe status fields only; reject empty provider/model values; never accept raw secret values.

- [ ] **Step 4: Add control messages to the agent server**

Add message types `provider_inventory`, `provider_models`, `provider_set_default`, `provider_set_credential_ref`, `provider_set_base_url`, and `provider_validate` to `FatCatAgentServer.handle_message`. Responses are `provider_inventory_result`, `provider_configured`, and `provider_validation_result`; failures use the existing safe `error` event.

- [ ] **Step 5: Run Python tests to verify green**

Run `PYTHONPATH=agent python3 -m unittest discover -s agent/tests -v`.

Expected: all Python tests pass, including existing session/cancellation coverage.

- [ ] **Step 6: Commit the bridge**

```bash
git add agent/fatcat_agent/config_bridge.py agent/fatcat_agent/server.py agent/tests/test_config_bridge.py agent/tests/test_server.py
git commit -m "feat: expose Hermes provider setup through FatCat agent"
```

### Task 3: Extend the Swift control protocol and credentials

**Files:** `macos/FatCat/Sources/FatCatCore/FatCatIPC.swift`, `macos/FatCat/Sources/FatCatCore/FatCatCredentials.swift`, `macos/FatCat/Sources/FatCatCore/FatCatProviderSetup.swift`, `macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift`, `macos/FatCat/Tests/FatCatCoreTests/FatCatProviderSetupTests.swift`.

- [ ] **Step 1: Write failing Swift tests**

Add tests for non-secret control-message round trips, credential field rejection, Keychain reference naming, and provider setup state transitions:

```swift
@Test func providerDefaultRoundTripsWithoutCredentialFields() throws {
    let message = FatCatIPCMessage.providerSetDefault(providerID: "openai-codex", model: "gpt-5")
    let decoded = try FatCatIPCCodec.decodeLine(FatCatIPCCodec.encode(message: message))
    #expect(decoded == message)
}

@Test func unavailableDefaultIsPreservedUntilUserChangesIt() {
    var state = FatCatProviderSetupState(defaultProvider: "openai-codex", defaultModel: "gpt-5")
    state.applyValidation(.init(providerID: "openai-codex", model: "gpt-5", usable: false, detail: "expired"))
    #expect(state.defaultProvider == "openai-codex")
    #expect(state.defaultModel == "gpt-5")
}
```

- [ ] **Step 2: Run focused Swift tests to verify failure**

Run `swift test --package-path macos/FatCat --filter FatCatIPCTests` and `swift test --package-path macos/FatCat --filter FatCatProviderSetupTests`.

Expected: compile failures because the new message cases and setup types are absent.

- [ ] **Step 3: Implement non-secret IPC cases**

Add the request/result enum cases, JSON encoding/decoding, and strict string/list validation. Do not weaken `rejectCredentials`; nested keys named `api_key`, `access_token`, `refresh_token`, `password`, `cookie`, or `secret` must still throw.

- [ ] **Step 4: Implement Keychain credential references**

Create `FatCatCredentials` with a testable service/account namespace, `save(providerID:secret:)`, `read(providerID:)`, `delete(providerID:)`, and `reference(providerID:)`. Store secret bytes using `SecItemAdd`/`SecItemUpdate`; expose only the opaque reference in setup state and IPC.

- [ ] **Step 5: Implement the setup state model**

Create `FatCatProviderSetupState`, `FatCatProviderConnection`, and `FatCatProviderValidation` as `Codable`, `Equatable`, `Sendable` value types. State must hold provider/model metadata and safe detail strings, never secret values.

- [ ] **Step 6: Run all Swift core tests and commit**

Run `swift test --package-path macos/FatCat`.

Commit:

```bash
git add macos/FatCat/Sources/FatCatCore/FatCatIPC.swift macos/FatCat/Sources/FatCatCore/FatCatCredentials.swift macos/FatCat/Sources/FatCatCore/FatCatProviderSetup.swift macos/FatCat/Tests/FatCatCoreTests/FatCatIPCTests.swift macos/FatCat/Tests/FatCatCoreTests/FatCatProviderSetupTests.swift
git commit -m "feat: add secure provider setup state and control protocol"
```

### Task 4: Replace the hand-maintained settings surface

**Files:** `macos/FatCat/Sources/FatCat/AppMain.swift`, `macos/FatCat/Sources/FatCatCore/ProviderDiscovery.swift`, `macos/FatCat/Tests/FatCatCoreTests/ProviderDiscoveryTests.swift`.

- [ ] **Step 1: Write failing settings-state tests**

Test that the visible connections are exactly Hermes Agent health plus Codex, OpenAI-compatible API, and Anthropic API; test that the default selector sends an explicit provider/model request; test that no provider fallback is selected when validation fails.

- [ ] **Step 2: Run focused tests to verify failure**

Run `swift test --package-path macos/FatCat --filter ProviderDiscoveryTests`.

Expected: failures against the existing broad catalog and missing control-backed settings state.

- [ ] **Step 3: Narrow provider discovery to safe product descriptors**

Keep the generic Hermes data model reusable, but make the FatCat visible catalog contain only the supported first slice. Replace the current hard-coded “Hermes provider” authenticated result with an agent-health status supplied by `FatCatAgentClient`.

- [ ] **Step 4: Add control calls to `FatCatAgentClient`**

Implement asynchronous request methods for inventory, model listing, default selection, credential-reference binding, base URL configuration, and validation. Route incoming result messages to the app model; keep chat handling unchanged.

- [ ] **Step 5: Build the native Settings UI**

Replace `SettingsView` with a Hermes-first layout: FatCat Agent health, Default Model picker, Connections list, provider setup forms, refresh, connect/test, and explicit Set as Default. API keys use `SecureField` and Keychain; no key value is placed in an IPC message.

- [ ] **Step 6: Run Swift tests and build**

Run `swift test --package-path macos/FatCat` and `swift build --package-path macos/FatCat`.

- [ ] **Step 7: Commit the settings surface**

```bash
git add macos/FatCat/Sources/FatCat/AppMain.swift macos/FatCat/Sources/FatCatCore/ProviderDiscovery.swift macos/FatCat/Tests/FatCatCoreTests/ProviderDiscoveryTests.swift
git commit -m "feat: add Hermes-first native provider settings"
```

### Task 5: Make the packaged `.app` and `.dmg` self-contained

**Files:** `scripts/build-fatcat-agent.sh`, `scripts/run-fatcat-macos.sh`, `scripts/verify-fatcat-macos-app.sh`, `scripts/test-hermes-bundle.sh`, `README.md`.

- [ ] **Step 1: Write the clean-install packaging test**

Extend `scripts/test-hermes-bundle.sh` to build into a temporary directory with `FATCAT_HERMES_PATH` and `PEPPA_HERMES_SOURCE` unset, then assert that the staged Python launcher starts with a temporary `HERMES_HOME` and that its resource tree contains the vendored commit metadata.

- [ ] **Step 2: Run the test to verify failure**

Run `bash scripts/test-hermes-bundle.sh`.

Expected: failure if build scripts still require `/Users/<developer>/.hermes/hermes-agent`.

- [ ] **Step 3: Update release staging**

Ensure `scripts/run-fatcat-macos.sh` builds from the tracked source, places Hermes source/runtime/dependencies beneath `Contents/Resources/FatCatAgent`, preserves the app-local `HERMES_HOME`, and calls `scripts/package-fatcat-dmg.sh` without personal config. Do not copy `~/.hermes`, `~/.codex`, or any `.env` file.

- [ ] **Step 4: Add attribution and setup documentation**

Document the Hermes fork, MIT attribution, supported providers, Keychain behavior, first-launch setup, and commands for clean packaging.

- [ ] **Step 5: Run release verification**

Run:

```bash
bash scripts/test-hermes-bundle.sh
./scripts/run-fatcat-macos.sh
./scripts/verify-fatcat-macos-app.sh macos/FatCat/.build/FatCat.app
```

Expected: release bundle verification exits 0 and no external Hermes install is required by the build path.

- [ ] **Step 6: Commit packaging**

```bash
git add scripts README.md
git commit -m "build: package FatCat with embedded Hermes"
```

### Task 6: End-to-end clean-machine verification

**Files:** `README.md`, `scripts/test-hermes-bundle.sh`, `scripts/verify-fatcat-macos-app.sh`.

- [ ] **Step 1: Run all automated checks**

```bash
npm run build:avatar
swift build --package-path macos/FatCat
swift test --package-path macos/FatCat
PYTHONPATH=agent python3 -m unittest discover -s agent/tests -v
bash scripts/test-hermes-bundle.sh
```

- [ ] **Step 2: Run the packaged runtime smoke test**

Use a temporary Application Support directory and verify: agent starts, provider inventory contains only the supported slice, a default can be set explicitly, an invalid provider test preserves the default, and session state survives agent restart.

- [ ] **Step 3: Audit the final diff**

Run `git status --short`, `git diff --check`, `git diff --stat`, and inspect the bundle file list. Confirm existing user avatar changes are preserved and no credentials or unrelated generated files are staged.

- [ ] **Step 4: Commit verification/documentation updates**

```bash
git add README.md scripts docs/superpowers/plans/2026-08-28-hermes-first-packaging.md
git commit -m "test: verify self-contained FatCat Hermes distribution"
```

## Plan self-review

- Spec coverage: the plan covers vendoring/legal metadata, embedded runtime packaging, Hermes-owned provider inventory, explicit default selection, Codex detection/import boundary, OpenAI-compatible and Anthropic setup, Keychain storage, safe IPC, error events, no silent fallback, clean-install packaging, and session continuity.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation step is used; each task names files, tests, commands, expected outcomes, and commit boundaries.
- Type consistency: Python control operations are named consistently with Swift IPC cases; `provider_set_default`, `provider_set_credential_ref`, and `provider_validate` map to the corresponding bridge methods and result events. `FatCatProviderSetupState` owns only non-secret state, while `FatCatCredentials` owns Keychain I/O.
- Scope: the plan keeps Hermes core intact, removes only unused packaging surfaces, and limits visible provider setup to the approved first slice.
