# Peppa Anywhere

## FatCat/Hermes boundary

In the FatCat product, this avatar is a surface for Hermes rather than a
second agent. Hermes is the source of truth for sessions, history, memory,
planning, and tools. FatCat adapts Hermes events to the pet, mini chat,
Electron, and other channels, while enforcing native macOS permissions,
approval, execution, and independent verification. Local FatCat storage is
limited to UI/session metadata; legacy local memory, goals, learning, and
transcript content are retired and are never imported into Hermes.

Peppa is a portable Bible Strong avatar definition. This guide shows how to put the same little blue pet into other React projects: assistants, empty states, onboarding, buttons, loading screens, docs, and prototypes.

The source of truth is [`public/strobi.avatar.json`](../public/strobi.avatar.json). The filename is kept for compatibility with the original lab export; the definition itself is named `Peppa`.

## What travels with Peppa

Copy these two things into another project:

1. The avatar definition JSON.
2. The React renderer package and its stylesheet.

Install the runtime packages in the destination project:

```bash
npm install @bible-strong/avatar-react react react-dom
```

The React package depends on `@bible-strong/avatar-core` automatically. Use React 19 or a compatible React setup.

## The smallest useful component

Copy the JSON into a source folder, for example `src/avatars/peppa.avatar.json`, then create a reusable component:

```tsx
import { createAvatar } from '@bible-strong/avatar-react'
import peppaDefinition from './avatars/peppa.avatar.json'

const PeppaAvatar = createAvatar(peppaDefinition)

export function PeppaIdle() {
  return (
    <PeppaAvatar
      defaultAnimation="idle"
      size={160}
      ariaLabel="Peppa, your study companion"
    />
  )
}
```

Import the package stylesheet once at the application entry point. Do this once per app, not once per avatar instance:

```tsx
import '@bible-strong/avatar-react/styles.css'
```

`createAvatar` reads the definition's real keys, so editors can autocomplete values such as `idle`, `thinking`, `happy`, and `curious`.

## The two display modes

An avatar can show one direct expression or play one animation timeline. They are mutually exclusive; never pass `expression` and `animation` together.

### A direct expression

Use a direct expression when Peppa is reacting to a specific UI state:

```tsx
<PeppaAvatar
  expression="curious-left"
  size={96}
  ariaLabel="Peppa looks curious"
/>
```

Useful expression keys in this definition include:

| Moment | Expression |
| --- | --- |
| Default | `neutral` |
| Listening | `attentive-left` |
| Curious | `curious-left` |
| Happy | `joyful-wide` |
| Sleepy | `sleepy-squint` |
| Suspicious | `suspicious-right` |
| Surprised | `surprised-left` |
| Eyes closed | `eyes-closed` |

The lab shows every expression and its underlying head/eye values.

### A looping animation

Use an animation when Peppa should feel alive over time:

```tsx
<PeppaAvatar
  defaultAnimation="thinking"
  size="min(42vw, 280px)"
  ariaLabel="Peppa is thinking"
/>
```

Good starting states:

| Product moment | Animation |
| --- | --- |
| Quiet presence | `idle` |
| Waiting for a response | `listening` |
| Considering a question | `thinking` |
| Finding something | `searching` |
| Doing work | `working` |
| Finished or excited | `happy` or `celebrate` |
| Sleeping / low activity | `sleeping` |
| Suspicious result | `suspicious` |

All 23 timelines are explicit in the JSON. They include their expression order, hold duration, transition type, playback mode, blink behavior, and optional metadata.

## A shared component for many placements

Most projects only need one wrapper with a small set of semantic states:

```tsx
import type { ComponentProps } from 'react'
import { createAvatar } from '@bible-strong/avatar-react'
import peppaDefinition from './avatars/peppa.avatar.json'

const PeppaAvatar = createAvatar(peppaDefinition)

type PeppaProps = {
  state?: 'idle' | 'listening' | 'thinking' | 'curious' | 'working' | 'happy' | 'sleeping'
  size?: ComponentProps<typeof PeppaAvatar>['size']
  className?: string
  ariaLabel?: string
}

const animationForState = {
  idle: 'idle',
  listening: 'listening',
  thinking: 'thinking',
  curious: 'curious',
  working: 'working',
  happy: 'happy',
  sleeping: 'sleeping',
} as const

export function Peppa({
  state = 'idle',
  size = 128,
  className,
  ariaLabel = `Peppa is ${state}`,
}: PeppaProps) {
  return (
    <PeppaAvatar
      defaultAnimation={animationForState[state]}
      size={size}
      className={className}
      ariaLabel={ariaLabel}
    />
  )
}
```

Then every product surface stays simple:

```tsx
<Peppa state="idle" size={72} />
<Peppa state="listening" size={120} />
<Peppa state="thinking" size={180} />
<Peppa state="happy" size={64} />
```

Keep the wrapper semantic. Product copy should explain what Peppa is doing; the avatar should support the moment, not become the entire message.

## Product placement recipes

### Empty state

```tsx
<section className="empty-state">
  <Peppa state="curious" size={112} ariaLabel="Peppa is curious" />
  <h2>No practice set yet</h2>
  <p>Pick a subject and Peppa will help you find a useful next question.</p>
</section>
```

### Loading state

```tsx
<div className="loading-state" role="status" aria-live="polite">
  <Peppa state="working" size={88} ariaLabel="Peppa is working" />
  <span>Building your next practice set…</span>
</div>
```

### Onboarding card

```tsx
<article className="welcome-card">
  <Peppa state="happy" size={144} ariaLabel="Peppa welcomes you" />
  <div>
    <p className="eyebrow">Meet your study companion</p>
    <h1>Let’s find your next win.</h1>
    <button type="button">Start a short set</button>
  </div>
</article>
```

### Small status marker

At small sizes, prefer a direct expression instead of a busy timeline:

```tsx
<PeppaAvatar
  expression="attentive-left"
  size={32}
  ariaLabel="Peppa is listening"
/>
```

## Buttons and programmatic reactions

For a component that changes Peppa in response to events, use `Avatar` with an `AvatarController` ref:

```tsx
import { useRef } from 'react'
import { Avatar, type AvatarController } from '@bible-strong/avatar-react'
import peppaDefinition from './avatars/peppa.avatar.json'

export function PeppaControls() {
  const avatar = useRef<AvatarController>(null)

  return (
    <div>
      <Avatar
        ref={avatar}
        definition={peppaDefinition}
        defaultAnimation="idle"
        size={180}
        ariaLabel="Peppa study companion"
      />
      <button type="button" onClick={() => avatar.current?.play('thinking')}>
        Think
      </button>
      <button type="button" onClick={() => avatar.current?.play('happy')}>
        Celebrate
      </button>
      <button type="button" onClick={() => avatar.current?.setExpression('neutral')}>
        Reset face
      </button>
      <button type="button" onClick={() => avatar.current?.pause()}>
        Pause
      </button>
    </div>
  )
}
```

The controller methods return a typed success/error result for `play` and `setExpression`. If the avatar target comes from React props, change the prop instead of trying to replace it imperatively.

## Vite and Next.js notes

### Vite

Vite supports JSON imports by default in a TypeScript app. Keep the stylesheet import in `src/main.tsx` or your shared app entry point.

### Next.js App Router

The avatar is interactive, so render it from a Client Component:

```tsx
// app/components/peppa.tsx
'use client'

import { createAvatar } from '@bible-strong/avatar-react'
import peppaDefinition from '@/avatars/peppa.avatar.json'
import '@bible-strong/avatar-react/styles.css'

const PeppaAvatar = createAvatar(peppaDefinition)

export function Peppa() {
  return <PeppaAvatar defaultAnimation="idle" size={144} ariaLabel="Peppa" />
}
```

Importing the stylesheet in the Client Component is safe; importing it once in the root layout is also fine if the project’s CSS rules prefer that arrangement.

## Loading another definition at runtime

For user-selected or remote JSON, validate the text before rendering it:

```tsx
import { parseAvatarDefinition } from '@bible-strong/avatar-core'

const result = parseAvatarDefinition(await file.text())

if (!result.ok) {
  throw new Error(result.errors[0]?.message ?? 'Invalid avatar definition')
}

// result.value is validated and safe to pass to <Avatar definition={...} />.
```

Do not trust arbitrary JSON just because it has an `expressions` field. `parseAvatarDefinition` enforces the Bible Strong schema and returns a typed, deeply frozen definition.

## Sizing and CSS

The `size` prop accepts a number or CSS size string:

```tsx
<PeppaAvatar size={64} />
<PeppaAvatar size="clamp(96px, 20vw, 240px)" />
```

The renderer exposes `.bs-avatar` and `.bs-avatar__svg`. Add your own class for layout, not for changing the avatar’s internal geometry:

```css
.peppa-slot {
  display: grid;
  place-items: center;
  width: 9rem;
  height: 9rem;
}

.peppa-slot .bs-avatar {
  filter: drop-shadow(0 14px 18px rgb(44 63 105 / 12%));
}
```

Use one calm placement per surface. Peppa works best as a clear focal object or a small status companion; avoid stacking multiple decorative glows around it.

## Accessibility checklist

- Give every visible avatar an `ariaLabel` that describes its role or state.
- Keep adjacent copy available; do not rely on the face as the only explanation.
- Use a direct `expression` for tiny status icons where motion would be distracting.
- Respect `prefers-reduced-motion` in surrounding UI transitions.
- Keep buttons that control Peppa as native `<button>` elements with visible focus states.

## License note

The installed `@bible-strong/avatar-react` package declares `AGPL-3.0-only`. Before embedding Peppa into a distributed or hosted product, review the package license and your project’s obligations with the person responsible for legal/compliance. Keep the package license and attribution with copied assets.

## Explore before choosing

Run this lab and use the expression/animation galleries to find the right personality for each product moment:

```bash
cd animations
npm install
npm run dev
```

The lab is intentionally the catalog: it shows the actual 28 expressions and 23 animation timelines available in Peppa’s definition, without inventing aliases that are not in the JSON.
