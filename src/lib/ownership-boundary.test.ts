import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const sourceRoot = fileURLToPath(new URL('../', import.meta.url))

describe('FatCat ownership boundary', () => {
  it('does not put local agent systems in the browser product surface', () => {
    const source = readFileSync(`${sourceRoot}/components/CompanionDashboard.tsx`, 'utf8')
    expect(source).not.toMatch(/from ['"]\.\.\/lib\/(memory|goals|learning|brain)['"]/)
  })

  it('does not persist transcripts from the daemon', () => {
    const source = readFileSync(`${sourceRoot}/../agent/peppa_agent/server.py`, 'utf8')
    expect(source).not.toMatch(/append_(message|assistant_delta)|merge_history/)
  })
})
