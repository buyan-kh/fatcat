// @vitest-environment node
import { describe, expect, it } from 'vitest'
import config from '../../electron.vite.config'

describe('sandboxed preload contract', () => {
  it('builds the preload as CommonJS for Electron sandbox compatibility', () => {
    expect(config).toHaveProperty('preload.build.rollupOptions.output', {
      format: 'cjs',
      entryFileNames: '[name].cjs',
    })
  })
})
