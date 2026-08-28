export const companionStates = [
  'idle',
  'listening',
  'understanding',
  'planning',
  'searching',
  'asking_permission',
  'acting',
  'verifying',
  'celebrating',
  'recovering',
  'sleeping',
] as const

export type CompanionState = (typeof companionStates)[number]

export type AvatarStateMapping = {
  animation: string
  expression?: string
  label: string
}

export const avatarAnimationForState: Record<CompanionState, AvatarStateMapping> = {
  idle: { animation: 'idle', label: 'Quietly present' },
  listening: { animation: 'listening', expression: 'attentive-left', label: 'Listening' },
  understanding: { animation: 'thinking', label: 'Understanding' },
  planning: { animation: 'thinking', label: 'Planning' },
  searching: { animation: 'searching', label: 'Searching' },
  asking_permission: { animation: 'listening', expression: 'attentive-left', label: 'Asking permission' },
  acting: { animation: 'working', label: 'Acting' },
  verifying: { animation: 'thinking', label: 'Verifying' },
  celebrating: { animation: 'celebrate', label: 'Verified success' },
  recovering: { animation: 'suspicious', expression: 'suspicious-right', label: 'Uncertain / recovering' },
  sleeping: { animation: 'sleeping', expression: 'sleepy-squint', label: 'Sleeping' },
}

const allowedTransitions: Record<CompanionState, CompanionState[]> = {
  idle: ['listening', 'understanding', 'asking_permission', 'sleeping'],
  listening: ['understanding', 'idle', 'sleeping'],
  understanding: ['planning', 'asking_permission', 'idle', 'recovering'],
  planning: ['asking_permission', 'acting', 'idle', 'recovering'],
  searching: ['planning', 'acting', 'recovering', 'idle'],
  asking_permission: ['acting', 'idle', 'recovering', 'listening'],
  acting: ['verifying', 'recovering'],
  verifying: ['celebrating', 'recovering', 'idle'],
  celebrating: ['idle', 'sleeping'],
  recovering: ['planning', 'asking_permission', 'idle', 'sleeping'],
  sleeping: ['idle', 'listening'],
}

export function canTransition(from: CompanionState, to: CompanionState): boolean {
  return from === to || allowedTransitions[from].includes(to)
}

export type StateTransition = {
  accepted: boolean
  state: CompanionState
  from: CompanionState
  to: CompanionState
  reason: string
}

export function transitionState(from: CompanionState, to: CompanionState, reason: string): StateTransition {
  const accepted = canTransition(from, to)
  return { accepted, state: accepted ? to : from, from, to, reason }
}
