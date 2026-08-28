# Bible Strong Avatar Playground Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone light-theme Vite/React playground in `prepst.com/animations` for inspecting supplied Bible Strong avatar expressions, animation timelines, imported definitions, and experiment notes.

**Architecture:** A small client-only React app owns the active definition, selected target, playback controls, import errors, and notes. Focused components render the preview, definition rail, expression gallery, animation gallery, inspector, and import controls. Pure helpers normalize imported JSON and persist notes so the test suite does not depend on the DOM.

**Tech Stack:** React 19, TypeScript, Vite, `@bible-strong/avatar-react`, `@bible-strong/avatar-core`, Vitest, native CSS.

---

### Task 1: Scaffold the isolated Vite app

**Files:**
- Create: `package.json`
- Create: `package-lock.json` via npm install
- Create: `index.html`
- Create: `tsconfig.json`
- Create: `tsconfig.node.json`
- Create: `vite.config.ts`
- Create: `src/vite-env.d.ts`
- Create: `src/main.tsx`
- Copy: `public/strobi.avatar.json` from the supplied landing asset, preserving the Peppa display name already used by the project

- [ ] **Step 1: Create the package manifest with exact scripts and dependencies**

```json
{
  "name": "prepst-avatar-playground",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "tsc -b --pretty false"
  },
  "dependencies": {
    "@bible-strong/avatar-core": "^0.1.0",
    "@bible-strong/avatar-react": "^0.1.0",
    "react": "^19.2.0",
    "react-dom": "^19.2.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^5.0.0",
    "typescript": "^5.0.0",
    "vite": "^7.0.0",
    "vitest": "^3.0.0"
  }
}
```

- [ ] **Step 2: Add the Vite and TypeScript configuration**

`vite.config.ts` must export `defineConfig({ plugins: [react()] })`. `tsconfig.json` must reference `tsconfig.app.json` and `tsconfig.node.json`; `tsconfig.app.json` must enable strict JSX compilation with `moduleResolution: "bundler"`, `noEmit: true`, `lib: ["ES2022", "DOM", "DOM.Iterable"]`, and include `src`. `tsconfig.node.json` must include `vite.config.ts` with Node types.

- [ ] **Step 3: Add the HTML entry point and React mount**

`index.html` must set the title to `Bible Strong Avatar Lab`, include a `meta name="theme-color" content="#f7f9fc"`, and mount `<div id="root"></div>` through `/src/main.tsx`. `src/main.tsx` must import React, `createRoot`, the avatar package stylesheet, and `./styles.css`, then render `<App />`.

- [ ] **Step 4: Copy and validate the bundled definition**

Copy the already renamed `public/strobi.avatar.json` from the landing project. Validate it with `parseAvatarDefinition` in a one-line Node check and expect `Peppa`, 28 expressions, and 23 animations.

- [ ] **Step 5: Commit the scaffold**

```bash
git add package.json package-lock.json index.html tsconfig.json tsconfig.app.json tsconfig.node.json vite.config.ts src/vite-env.d.ts src/main.tsx public/strobi.avatar.json
git commit -m "chore: scaffold avatar playground"
```

### Task 2: Add pure data and persistence helpers test-first

**Files:**
- Create: `src/lib/avatar-data.ts`
- Create: `src/lib/avatar-data.test.ts`
- Create: `src/lib/storage.ts`
- Create: `src/lib/storage.test.ts`

- [ ] **Step 1: Write failing tests for definition summaries and import normalization**

Tests must assert that `summarizeDefinition` returns the display name, body type, body dimensions, colors, and real expression/animation counts from the bundled definition, and that `normalizeImportedDefinition` returns a valid parsed definition for the same JSON while rejecting an object without the avatar schema. Use `parseAvatarDefinition` only inside the implementation, not as the test oracle for the summary fields.

- [ ] **Step 2: Run the focused tests and confirm the expected missing-module failure**

Run `npm test -- src/lib/avatar-data.test.ts`. Expect Vitest to fail because `src/lib/avatar-data.ts` does not exist yet.

- [ ] **Step 3: Implement the minimal data helpers**

Export `type AvatarDefinition`, `type DefinitionSummary`, `summarizeDefinition(definition)`, and `normalizeImportedDefinition(value)`. `normalizeImportedDefinition` must return `{ ok: true, definition }` for valid input and `{ ok: false, message }` for invalid input. Messages must be suitable for inline UI display.

- [ ] **Step 4: Write failing tests for notes persistence**

Test `readNotes` with an empty storage object, `writeNotes` with a string, and malformed stored JSON. Use a small in-memory `Storage` double with `getItem` and `setItem`; test that malformed data safely returns an empty string.

- [ ] **Step 5: Run the storage tests and confirm the expected missing-module failure**

Run `npm test -- src/lib/storage.test.ts`. Expect a missing-module failure for `src/lib/storage.ts`.

- [ ] **Step 6: Implement storage helpers**

Export `NOTES_STORAGE_KEY`, `readNotes(storage)`, and `writeNotes(storage, notes)`. Store JSON `{ notes: string }`; catch read and write errors so private browsing or disabled storage cannot crash the app.

- [ ] **Step 7: Run both focused test files and confirm green**

Run `npm test -- src/lib/avatar-data.test.ts src/lib/storage.test.ts`. Expect all tests to pass.

- [ ] **Step 8: Commit the tested helpers**

```bash
git add src/lib/avatar-data.ts src/lib/avatar-data.test.ts src/lib/storage.ts src/lib/storage.test.ts
git commit -m "test: add avatar data and notes helpers"
```

### Task 3: Build the interactive React workbench

**Files:**
- Create: `src/App.tsx`
- Create: `src/components/AvatarPreview.tsx`
- Create: `src/components/DefinitionRail.tsx`
- Create: `src/components/ExpressionGallery.tsx`
- Create: `src/components/AnimationGallery.tsx`
- Create: `src/components/Inspector.tsx`
- Create: `src/components/ImportAvatar.tsx`

- [ ] **Step 1: Add the preview component**

Render `Avatar` from `@bible-strong/avatar-react` with the active definition and either `expression` or `animation`, never both. Attach a controller ref, show status text, and expose `onPause`, `onResume`, and `onReplay` callbacks. Use `ariaLabel` with the active definition name.

- [ ] **Step 2: Add definition metadata and import controls**

Render the summary fields, a hidden labeled file input accepting `.json` and `.avatar.json`, a visible import button, and an inline error region. Parse file text with `JSON.parse`, pass it through `normalizeImportedDefinition`, and call `onImport` only on success. The current definition must remain unchanged after invalid input.

- [ ] **Step 3: Add expression and animation galleries**

Render native buttons from `expressionOrder` and `animationOrder`. Each button must use the real key, have `aria-pressed`, show active state, and call a typed callback. Animation rows must display metadata label, group, step count, and playback mode when available.

- [ ] **Step 4: Add inspector details**

When an expression is selected, show its head coordinates, eye sizes, eye spacing, and motion fields. When an animation is selected, show its description, steps with expression names and hold/transition durations, and blink settings. Keep this information compact and scrollable.

- [ ] **Step 5: Compose App state and interactions**

Bundle the Peppa definition as the initial state. Track `activeDefinition`, `selectedExpression`, `selectedAnimation`, `notes`, and import error. Expression selection sets only `selectedExpression`; animation selection sets only `selectedAnimation`. Load notes once from `localStorage` and persist on change. Show a definition tab strip if multiple imported definitions exist, with remove controls for imported definitions only.

- [ ] **Step 6: Commit the interactive components**

```bash
git add src/App.tsx src/components
git commit -m "feat: add avatar exploration workbench"
```

### Task 4: Apply the approved light visual system

**Files:**
- Create: `src/styles.css`

- [ ] **Step 1: Implement the light theme tokens and layout**

Use paper `#f7f9fc`, ink `#182235`, muted `#5d6879`, line `#d9e0eb`, and cobalt `#5b7fe5`. Build a responsive two-column workbench on desktop, stacking preview, rail, and galleries on narrow screens. Use 12px surface corners, 8px control corners, thin borders, and restrained cool-tinted shadows.

- [ ] **Step 2: Style interaction states and accessibility**

Style hover, active, selected, disabled, focus-visible, error, and empty states. Keep all controls keyboard-visible and ensure the cobalt buttons have readable white text. Add a reduced-motion media query that removes decorative transitions.

- [ ] **Step 3: Add responsive gallery behavior**

Use horizontal overflow for expression/animation galleries on narrow screens, readable two-line metadata, and a sticky preview only above 900px. Do not add dark mode, purple glow, decorative gradients, emoji, or landing assets.

- [ ] **Step 4: Commit the visual system**

```bash
git add src/styles.css
git commit -m "style: add light avatar lab interface"
```

### Task 5: Verify behavior and production output

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add run instructions and feature notes**

Document `npm install`, `npm run dev`, `npm test`, and `npm run build`. Explain that the app starts with Peppa and accepts additional valid Bible Strong avatar definition JSON files.

- [ ] **Step 2: Run the full automated checks**

Run `npm test`, `npm run lint`, and `npm run build`. Expect all tests to pass, TypeScript to report no errors, and Vite to emit the production bundle in `dist`.

- [ ] **Step 3: Run a dev-server smoke test**

Start `npm run dev -- --host 127.0.0.1`, load the page in the available browser tool, and verify the page title, Peppa preview, expression count, animation count, and controls are visible. Click one expression, click one animation, and verify the selected states update. Uploading malformed JSON must show an error and preserve Peppa.

- [ ] **Step 4: Commit verification documentation**

```bash
git add README.md
git commit -m "docs: add avatar playground usage"
```

