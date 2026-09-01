# FatCat Electron Deslop Design

## Scope

This is a visual refinement of the Electron full workspace only. The native pet and native mini-chat are explicitly unchanged. Existing chat, persistence, connection, and settings behavior remain unchanged.

## Design direction

The workspace should feel quiet, precise, and product-made rather than generated. Keep the existing monochrome light/dark palette and blue accent, but reduce visual noise through a single radius scale, hairline borders, muted sentence-case labels, and restrained surface shadows.

## Rules

- Use 0.5px-equivalent hairlines through the existing border tokens.
- Use 10px as the primary rounded-container radius; use 8px only for compact controls where needed.
- Set Phosphor icon weight to regular/1px-equivalent rather than bold defaults.
- Align titles and labels to the text column inside rounded containers.
- Add 1% letter spacing to body copy.
- Make search and navigation controls 36px tall with 10px radius.
- Use sentence-case group captions; remove all-caps UI labels.
- Give real cards a subtle tinted surface and resting shadow.
- Demote section captions to 12px muted labels; use 13px row titles with line-height instead of extra vertical gaps.
- Increase content top padding to 48px, use 12px heading-to-card gaps, and keep section rhythm at 32px.

## Files and verification

The implementation is limited to `electron/src/renderer/src/styles.css` and the Electron renderer components that currently define shell spacing. Existing component tests will gain stable class/label assertions only where they prevent regression. Verification uses the Electron Vitest suite, typecheck, production build, and a running `npm --prefix electron run dev` smoke check.
