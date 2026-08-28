export type LearningRecord = {
  id: string
  createdAt: string
  plan: string
  action: string
  observedResult: string
  expectedResult: string
  difference: string
  correction: string
  reusableLesson: string
  reliable: boolean
}

export const LEARNING_STORAGE_KEY = 'peppa-anywhere-learning-v1'

export function createLearningRecord(input: Omit<LearningRecord, 'id' | 'createdAt' | 'reliable'>): LearningRecord {
  return { ...input, id: `learning-${Date.now()}`, createdAt: new Date().toISOString(), reliable: input.difference.trim().length === 0 }
}

export function writeLearningRecords(storage: Pick<Storage, 'setItem'>, records: LearningRecord[]): void {
  try { storage.setItem(LEARNING_STORAGE_KEY, JSON.stringify(records)) } catch { /* local-only records are best effort */ }
}

export function readLearningRecords(storage: Pick<Storage, 'getItem'>): LearningRecord[] {
  try {
    const raw = storage.getItem(LEARNING_STORAGE_KEY)
    if (!raw) return []
    const parsed: unknown = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed as LearningRecord[] : []
  } catch { return [] }
}

