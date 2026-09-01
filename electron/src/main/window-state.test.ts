import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import { DEFAULT_WINDOW_BOUNDS, WindowStateStore, isVisibleBounds, type DisplayBounds } from './window-state'

const displays: DisplayBounds[] = [{ x: 0, y: 0, width: 1440, height: 900 }]

describe('window state', () => {
  it('recognizes bounds that intersect a display and rejects off-screen bounds', () => {
    expect(isVisibleBounds({ x: 100, y: 80, width: 1180, height: 760 }, displays)).toBe(true)
    expect(isVisibleBounds({ x: 2000, y: 100, width: 900, height: 620 }, displays)).toBe(false)
  })

  it('enforces the minimum window size', async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-window-'))
    const store = await WindowStateStore.open(join(root, 'window.json'))
    await store.save({ x: 10, y: 10, width: 400, height: 300 })

    expect(store.resolve(displays)).toEqual({ x: 10, y: 10, width: 900, height: 620 })
  })

  it('falls back to defaults for absent, corrupt, or off-screen state', async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-window-'))
    const store = await WindowStateStore.open(join(root, 'window.json'))
    expect(store.resolve(displays)).toEqual(DEFAULT_WINDOW_BOUNDS)

    await store.save({ x: 2200, y: 100, width: 1000, height: 700 })
    expect(store.resolve(displays)).toEqual(DEFAULT_WINDOW_BOUNDS)
  })
})
