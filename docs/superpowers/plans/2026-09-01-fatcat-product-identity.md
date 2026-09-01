# FatCat Product Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make FatCat the only product identity, make Electron the primary app, and remove misleading demo/trust claims while preserving the Hermes boundary.

**Architecture:** Rename active runtime/package/native identities in one branch, keep old strings only in explicit retirement migrations, and expose the Vite avatar build as an internal lab. Improve the shared Electron/native event presentation and add deterministic workflow checks so the primary loop is clearly connected, approved, executed, and verified.

**Tech Stack:** TypeScript/Vite/Vitest, Electron/Vitest, Swift Package Manager/Swift Testing, Python unittest, JSON/SQLite local metadata.

---

### Task 1: Lock the identity boundary with failing tests

**Files:**
- Create: `electron/src/shared/product-identity.test.ts`
- Modify: `src/lib/pet-surface.test.ts`
- Modify: `electron/package.json`, `package.json`

- [ ] Assert new package/script names and active source contain FatCat identity.
- [ ] Assert the product entry does not expose the avatar lab or companion dashboard.
- [ ] Assert old identity strings are permitted only in explicit migration/history paths.
- [ ] Run focused tests and commit the red tests.

### Task 2: Rename package, native, Python, protocol, and storage identities

**Files:**
- Modify: `package.json`, `package-lock.json`, `electron/package.json`
- Rename: `src/components/FatCatCompanionAvatar.tsx` to `src/components/FatCatAvatar.tsx`
- Rename: `macos/FatCat` target/package paths and Swift symbols/files to FatCat names
- Rename: `agent/fatcat_agent` runtime package and executable references
- Modify: `protocol/*`, scripts, plist, storage service/account names

- [ ] Rename active identifiers and update imports/tests/build scripts.
- [ ] Update new storage namespaces and add one-time retirement aliases for old keys.
- [ ] Update active docs and generated asset references; retain no old user-facing labels.
- [ ] Run root, Electron, Swift, and Python focused tests; commit the rename.

### Task 3: Make Electron the primary product surface

**Files:**
- Modify: root `README.md`, `agent/README.md`, `docs/PEPPA-ANYWHERE.md`
- Modify: root scripts and Electron launch scripts
- Modify: `src/avatar-main.tsx`, `vite.avatar.config.ts`, `src/App.tsx`

- [ ] Add explicit `avatar:lab` and `electron:typecheck` commands.
- [ ] Label the Vite build as internal FatCat Avatar Lab and keep it out of the product path.
- [ ] Make Electron launch instructions primary and describe the native pet as a companion surface.
- [ ] Commit the surface/product documentation update.

### Task 4: Make trust/status claims reflect real behavior

**Files:**
- Modify: Electron status components and native status copy
- Modify: tests covering status/permission/observation language

- [ ] Replace absolute or simulated claims with Demo/Native/Hermes connected/Unavailable labels.
- [ ] Expose generic permission, proposed-action, action-result, and verification events in the main activity flow.
- [ ] Ensure unavailable native observation is clearly unavailable rather than silently simulated.
- [ ] Run focused UI/native tests and commit.

### Task 5: Fix pause and event identity rough edges

**Files:**
- Modify: `src/components/FatCatAvatar.tsx`
- Modify: `electron/src/main/agent/fatcat-service.ts`
- Modify: related renderer tests

- [ ] Make `paused` stop animation work and invoke `onPauseChange` through the control.
- [ ] Generate activity IDs from `event_id` plus lifecycle/tool correlation, with stable updates for the same tool.
- [ ] Add tests for pause behavior and repeated request IDs across tools/events.
- [ ] Commit the fixes.

### Task 6: Add deterministic integration verification

**Files:**
- Create/modify: Electron shared-session smoke test
- Modify: `package.json`, `electron/package.json`, CI/test scripts

- [ ] Add a no-credential smoke test connecting two clients to one fake Hermes session, replaying history, streaming a message, approving a proposal, and receiving verification.
- [ ] Keep the paid real-agent smoke test conditional, but make the deterministic smoke test always run.
- [ ] Expose root `electron:typecheck` and run it in the final matrix.
- [ ] Commit verification workflow changes.

### Task 7: Full verification and integration

- [ ] Run root, Electron, Swift, Python, Hermes bundle, Electron build, and typecheck commands.
- [ ] Run identity/trust code-search acceptance checks.
- [ ] Review the complete diff and commit any documentation fixes.
- [ ] Push `codex/hermes-boundary-migration`, open a PR including the prior Hermes migration commits, wait for CI, and merge after checks pass.
