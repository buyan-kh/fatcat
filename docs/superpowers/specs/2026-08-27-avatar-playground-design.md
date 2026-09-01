# Bible Strong Avatar Playground Design

## Goal

Create an isolated, light-theme browser playground under `fatcat.com/animations` for exploring Bible Strong avatar definitions, expressions, and animation timelines without touching the PrepSt landing page.

## User experience

The first screen is a workbench rather than a marketing page:

- A large central preview renders the active avatar with the selected expression or looping animation.
- A compact definition rail identifies the loaded avatar, body type, colors, expression count, and animation count.
- An expression gallery exposes every expression from the loaded definition. Selecting one immediately switches the preview to that direct pose.
- An animation gallery exposes every timeline. Selecting one starts that animation and shows its metadata, step count, timing, and blink configuration.
- A pause/resume control and replay control make timing easy to inspect.
- A JSON import drop zone and file picker load additional valid `*.avatar.json` definitions in the browser. Invalid files produce an inline error and leave the current avatar untouched.
- A small notes field persists experiment notes to `localStorage` for the current browser session.

The initial bundled definition is the supplied FatCat definition, with the display name set to FatCat. The lab must preserve the definition's real semantic keys and metadata; it must not fabricate extra avatars or reactions.

## Architecture

Use a standalone Vite + React + TypeScript app with its own `package.json`, `src`, and `public` directories. The app imports `Avatar` from `@bible-strong/avatar-react` and uses the supplied definition as the bundled fixture. A small validation adapter calls `parseAvatarDefinition` from `@bible-strong/avatar-core` for imported JSON, while the React component receives the validated definition.

Keep the main component split into focused pieces:

- `App` owns loaded definitions, active definition, selected target, playback controls, import errors, and notes.
- `AvatarPreview` renders the avatar and its status summary.
- `DefinitionRail` renders avatar metadata and file import controls.
- `ExpressionGallery` and `AnimationGallery` render selectable real keys.
- `Inspector` renders details for the active expression or animation.
- `storage` contains notes persistence only.

The browser is the source of truth for import state. No server, database, or external API is needed.

## Visual direction

Use the approved light “instrument panel” direction from the mockup: paper-white page, cool ink text, thin blue-grey borders, one cobalt accent, restrained shadows, and dense-but-readable controls. No dark mode, purple glow, decorative gradients, emoji, or landing-page assets. The avatar is the visual focus. Use a consistent 12px surface radius, 8px control radius, and clear focus-visible states.

## Interaction details

- Selecting an expression clears the active animation and calls the avatar controller's `setExpression` behavior through controlled props.
- Selecting an animation clears the direct expression and starts the controlled animation.
- Pause/resume and replay use the avatar controller ref where supported; controls are disabled or labeled appropriately when no animation is active.
- Keyboard users can navigate all galleries with native buttons; the import area is also reachable through a labeled file input.
- `prefers-reduced-motion` disables decorative transitions in app CSS; the avatar library remains usable for direct inspection.
- The active item is visually distinct and announced with `aria-pressed`.

## Testing and verification

- Unit test pure storage helpers and imported-definition normalization with Vitest.
- Run TypeScript checking, the production Vite build, and focused ESLint.
- Run the dev server and verify the page renders, a supplied expression changes the avatar, an animation can be selected, and invalid JSON shows an inline error without replacing the current definition.

