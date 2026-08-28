import { describe, expect, it } from 'vitest'
import { NOTES_STORAGE_KEY, readNotes, writeNotes } from './storage'

function createMemoryStorage(initial?: string): Storage {
  let value = initial ?? null

  return {
    getItem: () => value,
    setItem: (_key, nextValue) => {
      value = nextValue
    },
    removeItem: () => {
      value = null
    },
    clear: () => {
      value = null
    },
    key: () => null,
    get length() {
      return value === null ? 0 : 1
    },
  }
}

describe('notes storage helpers', () => {
  it('returns an empty string when no notes exist', () => {
    expect(readNotes(createMemoryStorage())).toBe('')
  })

  it('writes and reads notes under the shared key', () => {
    const storage = createMemoryStorage()

    writeNotes(storage, 'Try the curious expression next.')

    expect(storage.getItem(NOTES_STORAGE_KEY)).toBe(
      JSON.stringify({ notes: 'Try the curious expression next.' }),
    )
    expect(readNotes(storage)).toBe('Try the curious expression next.')
  })

  it('ignores malformed stored data', () => {
    expect(readNotes(createMemoryStorage('{broken'))).toBe('')
  })
})
