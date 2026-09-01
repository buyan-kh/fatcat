import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

describe('FatCat product identity', () => {
  it('uses FatCat package metadata and explicit product scripts', async () => {
    const root = join(import.meta.dirname, '../../..')
    const packageJSON = JSON.parse(await readFile(join(root, 'package.json'), 'utf8')) as {
      name: string
      scripts?: Record<string, string>
    }
    expect(packageJSON.name).toBe('fatcat')
    expect(packageJSON.scripts?.['avatar:lab']).toBeDefined()
    expect(packageJSON.scripts?.['electron:typecheck']).toBeDefined()
  })

  it('keeps the product entry free of retired demo surfaces', async () => {
    const root = join(import.meta.dirname, '../../..')
    const app = await readFile(join(root, 'src/App.tsx'), 'utf8')
    expect(app).not.toContain('CompanionDashboard')
    expect(app).not.toContain('Peppa')
    expect(app).toContain('FatCat')
  })
})
