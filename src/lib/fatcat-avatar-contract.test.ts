import bundledDefinition from '../../public/strobi.avatar.json'
import type { AvatarDefinition } from '@bible-strong/avatar-core'
import { describe, expect, it } from 'vitest'

const definition = bundledDefinition as unknown as AvatarDefinition

describe('FatCat avatar visual contract', () => {
  it('keeps the original circular body geometry while changing only the palette and name', () => {
    expect(definition.name).toBe('FatCat')
    expect(definition.body.primary).toMatchObject({
      type: 'sphere',
      width: 240,
      height: 240,
      depth: 240.03671875,
      roundness: 1,
    })
    expect(definition.colors).toEqual({ body: '#f28c38', eyes: '#111316' })
  })

  it('preserves the original expression and animation catalog', () => {
    expect(definition.expressionOrder).toHaveLength(28)
    expect(definition.animationOrder).toHaveLength(23)
    expect(new Set(definition.expressionOrder)).toEqual(new Set(Object.keys(definition.expressions)))
    expect(new Set(definition.animationOrder)).toEqual(new Set(Object.keys(definition.animations)))
  })
})
