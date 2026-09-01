import { describe, expect, it } from 'vitest'
import { RETIRED_CONTENT_KEYS, RETIREMENT_MARKER, retireFatCatContent } from './retirement'

function storage(initial: Record<string, string>) {
  const values = new Map(Object.entries(initial))
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => { values.set(key, value) },
    removeItem: (key: string) => { values.delete(key) },
    values,
  }
}

describe('FatCat content retirement', () => {
  it('removes legacy content keys and writes one migration marker', () => {
    const target = storage(Object.fromEntries(RETIRED_CONTENT_KEYS.map((key) => [key, 'legacy content'])))

    expect(retireFatCatContent(target)).toBe(true)
    RETIRED_CONTENT_KEYS.forEach((key) => expect(target.values.has(key)).toBe(false))
    expect(target.values.has(RETIREMENT_MARKER)).toBe(true)
  })

  it('is idempotent and does not call Hermes import logic', () => {
    const target = storage({ [RETIREMENT_MARKER]: '{"version":1}' })

    expect(retireFatCatContent(target)).toBe(false)
    expect(retireFatCatContent(target)).toBe(false)
    expect(target.values.get(RETIREMENT_MARKER)).toBe('{"version":1}')
  })
})
