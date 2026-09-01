export const RETIRED_CONTENT_KEYS = [
  // Legacy namespaces are read only for this one-time retirement. FatCat
  // never writes user content to these keys again.
  'peppa-anywhere-memory-v1',
  'peppa-anywhere-goals-v1',
  'peppa-anywhere-learning-v1',
  'prepst-avatar-lab-notes',
] as const

export const RETIREMENT_MARKER = 'fatcat-content-retirement-v1'

type RetirementStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>

export function retireFatCatContent(storage: RetirementStorage): boolean {
  if (storage.getItem(RETIREMENT_MARKER) !== null) return false
  RETIRED_CONTENT_KEYS.forEach((key) => storage.removeItem(key))
  storage.setItem(RETIREMENT_MARKER, JSON.stringify({ version: 1, retiredAt: new Date().toISOString() }))
  return true
}
