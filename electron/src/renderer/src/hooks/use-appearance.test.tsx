import { act, renderHook } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { AppearancePreference } from '@shared/chat'
import { useAppearance } from './use-appearance'

describe('useAppearance', () => {
  afterEach(() => document.documentElement.classList.remove('dark'))

  it('tracks system appearance changes and detaches when an override is selected', () => {
    const listeners = new Set<() => void>()
    let matches = false
    const removeEventListener = vi.fn((_event: string, listener: () => void) => listeners.delete(listener))
    vi.stubGlobal('matchMedia', vi.fn(() => ({
      get matches() { return matches },
      addEventListener: (_event: string, listener: () => void) => listeners.add(listener),
      removeEventListener,
    })))

    const { rerender } = renderHook(({ appearance }: { appearance: AppearancePreference }) => useAppearance(appearance), {
      initialProps: { appearance: 'system' as AppearancePreference },
    })
    expect(document.documentElement).not.toHaveClass('dark')

    matches = true
    act(() => listeners.forEach((listener) => listener()))
    expect(document.documentElement).toHaveClass('dark')

    rerender({ appearance: 'light' })
    expect(document.documentElement).not.toHaveClass('dark')
    expect(removeEventListener).toHaveBeenCalled()
  })
})
