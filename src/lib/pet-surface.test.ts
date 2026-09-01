import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { avatarAnimationForPetState, petStates } from './pet-surface'

const appSource = readFileSync(fileURLToPath(new URL('../App.tsx', import.meta.url)), 'utf8')
const stylesheet = readFileSync(fileURLToPath(new URL('../styles.css', import.meta.url)), 'utf8')

describe('FatCat desktop pet web surface', () => {
  it('defines the complete semantic state vocabulary with real avatar animation keys', () => {
    expect(petStates).toEqual([
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
    ])
    expect(avatarAnimationForPetState.understanding).toBe('thinking')
    expect(avatarAnimationForPetState.acting).toBe('working')
    expect(avatarAnimationForPetState.celebrating).toBe('celebrate')
    expect(avatarAnimationForPetState.suspicious).toBe('suspicious')
  })

  it('keeps the normal entrypoint avatar-only and transparent', () => {
    expect(appSource).not.toContain('CompanionDashboard')
    expect(appSource).toContain('FatCatAvatar')
    expect(stylesheet).toMatch(/html,\s*body,\s*#root[\s\S]*background:\s*transparent/)
    expect(stylesheet).toMatch(/overflow:\s*hidden/)
  })
})
