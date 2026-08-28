export const NOTES_STORAGE_KEY = 'prepst-avatar-lab-notes'

type NotesStorage = Pick<Storage, 'getItem' | 'setItem'>

export function readNotes(storage: Pick<Storage, 'getItem'>): string {
  try {
    const stored = storage.getItem(NOTES_STORAGE_KEY)
    if (!stored) return ''

    const parsed: unknown = JSON.parse(stored)
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      'notes' in parsed &&
      typeof parsed.notes === 'string'
    ) {
      return parsed.notes
    }
  } catch {
    return ''
  }

  return ''
}

export function writeNotes(storage: NotesStorage, notes: string): void {
  try {
    storage.setItem(NOTES_STORAGE_KEY, JSON.stringify({ notes }))
  } catch {
    // Storage can be unavailable in private browsing; notes remain usable in memory.
  }
}
