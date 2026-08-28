export type Goal = {
  id: string
  goal: string
  priority: 'low' | 'medium' | 'high'
  currentState: 'active' | 'blocked' | 'complete'
  nextAction: string
  blockingReason: string
  lastProgress: string
  successCondition: string
  permissionPolicy: 'ask_for_medium_and_high_risk'
}

export const GOALS_STORAGE_KEY = 'peppa-anywhere-goals-v1'

export function createGoal(input: Pick<Goal, 'goal' | 'priority' | 'successCondition'>): Goal {
  return {
    ...input,
    id: `goal-${Date.now()}`,
    currentState: 'active',
    nextAction: 'Observe local context',
    blockingReason: '',
    lastProgress: 'Not started',
    permissionPolicy: 'ask_for_medium_and_high_risk',
  }
}

export function addGoal(goals: Goal[], goal: Goal): Goal[] { return [...goals, goal] }

export function readGoals(storage: Pick<Storage, 'getItem'>): Goal[] {
  try {
    const raw = storage.getItem(GOALS_STORAGE_KEY)
    if (!raw) return []
    const parsed: unknown = JSON.parse(raw)
    return Array.isArray(parsed) ? parsed as Goal[] : []
  } catch { return [] }
}

export function writeGoals(storage: Pick<Storage, 'setItem'>, goals: Goal[]): void {
  try { storage.setItem(GOALS_STORAGE_KEY, JSON.stringify(goals)) } catch { /* local-only goals are best effort */ }
}

