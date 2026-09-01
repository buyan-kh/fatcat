import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

describe('Electron renderer visual system', () => {
  it('defines the approved deslop tokens and shared surface primitives', () => {
    const stylesheet = readFileSync(resolve('src/renderer/src/styles.css'), 'utf8')

    expect(stylesheet).toContain('--radius: 10px')
    expect(stylesheet).toContain('letter-spacing: 0.01em')
    expect(stylesheet).toContain('.hairline')
    expect(stylesheet).toContain('.surface-card')
    expect(stylesheet).toContain('.section-caption')
    expect(stylesheet).toContain('.nav-control')
  })
})
