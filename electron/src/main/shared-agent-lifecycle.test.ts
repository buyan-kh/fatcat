import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

describe('Electron shared-agent lifecycle', () => {
  it('connects to the shared socket without owning an agent process', async () => {
    const source = await readFile(resolve(__dirname, 'index.ts'), 'utf8')

    expect(source).toContain('fatcat-agent.sock')
    expect(source).toContain('new SocketTransport')
    expect(source).not.toContain('new AgentSupervisor')
    expect(source).not.toContain('supervisor?.stop')
    expect(source).not.toContain("from './agent/agent-supervisor'")
  })
})
