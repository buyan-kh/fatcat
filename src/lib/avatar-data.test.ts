import bundledDefinition from '../../public/strobi.avatar.json'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { describe, expect, it } from 'vitest'
import { normalizeImportedDefinition, summarizeDefinition } from './avatar-data'

describe('avatar data helpers', () => {
  it('summarizes the bundled definition using its real catalog', () => {
    const summary = summarizeDefinition(bundledDefinition as unknown as AvatarDefinition)

    expect(summary).toEqual({
      name: 'Peppa',
      bodyType: 'sphere',
      dimensions: '240 × 240 × 240',
      bodyColor: '#5b7fe5',
      eyeColor: '#111316',
      expressionCount: 28,
      animationCount: 23,
    })
  })

  it('normalizes valid JSON text into a validated definition', () => {
    const result = normalizeImportedDefinition(JSON.stringify(bundledDefinition))

    expect(result.ok).toBe(true)
    if (result.ok) {
      expect(result.definition.name).toBe('Peppa')
      expect(result.definition.animationOrder).toContain('thinking')
    }
  })

  it('rejects JSON that is not an avatar definition', () => {
    const result = normalizeImportedDefinition(JSON.stringify({ name: 'Not an avatar' }))

    expect(result).toEqual({
      ok: false,
      message: 'This file is not a valid Bible Strong avatar definition.',
    })
  })
})
