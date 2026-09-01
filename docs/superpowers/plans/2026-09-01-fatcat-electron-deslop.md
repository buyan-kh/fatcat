# FatCat Electron Deslop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refine the Electron full workspace into a quieter, sharper interface using the approved deslop prompt while leaving the native mini-chat unchanged.

**Architecture:** Keep component behavior and data flow unchanged. Centralize visual decisions in the renderer stylesheet and apply only targeted class adjustments to the sidebar, header, transcript, prompt, and settings surfaces.

**Tech Stack:** Electron, React, Tailwind CSS v4, Phosphor icons, Vitest, TypeScript.

---

### Task 1: Establish shared renderer tokens and base surface rules

**Files:**
- Modify: `electron/src/renderer/src/styles.css`

- [ ] **Step 1: Add the approved renderer tokens**

Set the radius token to `10px`, strengthen the light/dark border tokens while keeping contrast accessible, add a tinted resting surface shadow, and give body copy `letter-spacing: 0.01em`.

- [ ] **Step 2: Add shared utility classes**

Add `.hairline`, `.surface-card`, `.section-caption`, and `.nav-control` rules so shell components use one visual vocabulary instead of repeating ad hoc values.

- [ ] **Step 3: Run renderer tests**

Run `npm --prefix electron test -- src/renderer/src/components/app-shell.test.tsx src/renderer/src/components/conversation.test.tsx`.

Expected: existing tests pass; no behavior changes.

- [ ] **Step 4: Commit**

```bash
git add electron/src/renderer/src/styles.css
git commit -m "style: establish Electron deslop tokens"
```

### Task 2: Refine navigation and conversation shell spacing

**Files:**
- Modify: `electron/src/renderer/src/components/app-sidebar.tsx`
- Modify: `electron/src/renderer/src/components/conversation-header.tsx`
- Modify: `electron/src/renderer/src/App.tsx`

- [ ] **Step 1: Apply 36px controls and sentence-case hierarchy**

Use the shared nav class for New chat, search, settings, and conversation rows. Keep titles aligned to the inner text column, tighten icon gaps, and use 12px muted section captions where labels are needed.

- [ ] **Step 2: Increase content breathing room**

Set the main content top padding to 48px, use a 12px heading-to-content gap, and keep the shell rhythm at 32px without changing minimum window dimensions.

- [ ] **Step 3: Run component tests and typecheck**

Run `npm --prefix electron test -- src/renderer/src/components/app-shell.test.tsx src/renderer/src/components/conversation.test.tsx` and `npm --prefix electron run typecheck`.

Expected: all selected tests pass and TypeScript reports no errors.

- [ ] **Step 4: Commit**

```bash
git add electron/src/renderer/src/App.tsx electron/src/renderer/src/components/app-sidebar.tsx electron/src/renderer/src/components/conversation-header.tsx
git commit -m "style: tighten Electron navigation shell"
```

### Task 3: Refine transcript, prompt, and settings surfaces

**Files:**
- Modify: `electron/src/renderer/src/components/transcript.tsx`
- Modify: `electron/src/renderer/src/components/prompt-bar.tsx`
- Modify: `electron/src/renderer/src/components/settings-dialog.tsx`
- Modify: `electron/src/renderer/src/components/message-row.tsx`

- [ ] **Step 1: Apply card and typography rules**

Use explicit surfaces and resting shadows for real cards, demote section labels to 12px muted text, use 13px row titles with line-height, and keep body copy at the shared letter spacing.

- [ ] **Step 2: Make search/composer inputs deliberate**

Use 36px search controls, 10px radius, a visible hairline border, and a restrained focus shadow. Keep the composer readable, accessible, and behaviorally identical.

- [ ] **Step 3: Normalize icon weight and tactile states**

Remove bold icon weights where they are decorative, preserve bold only for the primary send affordance, and add a small pressed state to interactive controls without adding animation loops.

- [ ] **Step 4: Run the full Electron checks**

Run `npm --prefix electron test`, `npm --prefix electron run typecheck`, and `npm --prefix electron run build`.

Expected: all Electron tests pass, the real-agent smoke remains conditionally skipped unless configured, typecheck passes, and the production build completes.

- [ ] **Step 5: Commit**

```bash
git add electron/src/renderer/src/components/transcript.tsx electron/src/renderer/src/components/prompt-bar.tsx electron/src/renderer/src/components/settings-dialog.tsx electron/src/renderer/src/components/message-row.tsx
git commit -m "style: deslop Electron conversation surfaces"
```

### Task 4: Visual smoke and handoff

**Files:**
- Verify: Electron renderer through `npm --prefix electron run dev`

- [ ] **Step 1: Open the dev app**

Run `npm --prefix electron run dev` and confirm the Electron window opens against the running shared FatCat Agent.

- [ ] **Step 2: Check the approved viewport behaviors**

Confirm sidebar navigation stays single-line, search is 36px tall, cards have subtle surfaces/shadows, content starts with 48px breathing room, and the native mini-chat files are unchanged.

- [ ] **Step 3: Inspect the final diff**

Run `git diff --check`, `git status --short`, and `git diff --stat`.

- [ ] **Step 4: Commit any final visual-only correction**

Use a focused `style:` commit only if the smoke check reveals a concrete spacing or contrast regression.
