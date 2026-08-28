import { describe, expect, it } from 'vitest'
import {
  appendMemory,
  createEmptyMemory,
  deleteMemory,
  readMemory,
  writeMemory,
  type MemoryEntry,
} from './memory'
import { addGoal, createGoal, readGoals, writeGoals } from './goals'
import { createLearningRecord, readLearningRecords, writeLearningRecords, type LearningRecord } from './learning'

function createMemoryStorage(initial = ''): Storage {
  let value = initial
  return {
    getItem: () => value,
    setItem: (_key, next) => { value = next },
    removeItem: () => { value = '' },
    clear: () => { value = '' },
    key: () => null,
    length: 0,
  }
}

describe('local Peppa memory and goals', () => {
  it('persists inspectable entries in each memory layer', () => {
    const storage = createMemoryStorage()
    const entry: MemoryEntry = {
      id: 'pref-1',
      content: 'Prefers concise summaries',
      createdAt: '2026-08-28T12:00:00.000Z',
      source: 'user_correction',
    }
    const next = appendMemory(createEmptyMemory(), 'semantic', entry)

    writeMemory(storage, next)
    expect(readMemory(storage).semantic).toEqual([entry])
    expect(readMemory(storage).procedural).toEqual([])
  })

  it('deletes a memory entry without touching other layers', () => {
    const memory = appendMemory(
      appendMemory(createEmptyMemory(), 'episodic', { id: 'e1', content: 'Solved build issue', createdAt: 'now', source: 'system' }),
      'semantic',
      { id: 's1', content: 'Uses Vite', createdAt: 'now', source: 'user_correction' },
    )

    const next = deleteMemory(memory, 'e1')
    expect(next.episodic).toEqual([])
    expect(next.semantic).toHaveLength(1)
  })

  it('persists goals with their permission policy and current progress', () => {
    const storage = createMemoryStorage()
    const goal = createGoal({ goal: 'Keep the study session moving', priority: 'high', successCondition: 'A next question is ready' })
    const updated = addGoal([], goal)
    writeGoals(storage, updated)

    expect(readGoals(storage)).toEqual(updated)
    expect(readGoals(storage)[0]).toMatchObject({
      goal: 'Keep the study session moving',
      currentState: 'active',
      nextAction: 'Observe local context',
      permissionPolicy: 'ask_for_medium_and_high_risk',
    })
  })

  it('stores a complete learning record for later reuse', () => {
    const storage = createMemoryStorage()
    const record: LearningRecord = createLearningRecord({
      plan: 'Inspect the current study context',
      action: 'Read structured screen metadata',
      observedResult: 'Context structured locally',
      expectedResult: 'Context structured locally',
      difference: '',
      correction: 'Keep raw screenshots disabled',
      reusableLesson: 'A local observation is enough for this check',
    })

    writeLearningRecords(storage, [record])
    expect(readLearningRecords(storage)).toEqual([record])
    expect(record).toMatchObject({ plan: expect.any(String), action: expect.any(String), observedResult: expect.any(String), expectedResult: expect.any(String), difference: expect.any(String), correction: expect.any(String), reusableLesson: expect.any(String) })
  })
})
