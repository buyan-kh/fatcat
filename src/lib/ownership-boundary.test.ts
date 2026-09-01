import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const sourceRoot = fileURLToPath(new URL('../', import.meta.url))

describe('FatCat ownership boundary', () => {
  it('does not put local agent systems in the browser product surface', () => {
    const source = readFileSync(`${sourceRoot}/App.tsx`, 'utf8')
    expect(source).not.toMatch(/memory|goals|learning|brain|PlannerAdapter|MemoryAdapter/)
  })

  it('does not persist transcripts from the daemon', () => {
    const source = readFileSync(`${sourceRoot}/../agent/peppa_agent/server.py`, 'utf8')
    expect(source).not.toMatch(/append_(message|assistant_delta)|merge_history/)
  })
})
