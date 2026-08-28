export const petStates = [
  'idle',
  'listening',
  'understanding',
  'planning',
  'askingPermission',
  'acting',
  'verifying',
  'celebrating',
  'recovering',
  'suspicious',
  'sleeping',
] as const

export type PetState = (typeof petStates)[number]

export const avatarAnimationForPetState: Record<PetState, string> = {
  idle: 'idle',
  listening: 'listening',
  understanding: 'thinking',
  planning: 'thinking',
  askingPermission: 'listening',
  acting: 'working',
  verifying: 'thinking',
  celebrating: 'celebrate',
  recovering: 'suspicious',
  suspicious: 'suspicious',
  sleeping: 'sleeping',
}
