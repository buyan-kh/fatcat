import { EventEmitter } from 'node:events'
import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import type { ChildProcess } from 'node:child_process'
import { describe, expect, it, vi } from 'vitest'
import { FakeAgent } from '../../test/fake-agent'
import { AgentSupervisor, redactDiagnostic } from './agent-supervisor'

describe('AgentSupervisor', () => {
  it('reports a missing executable with an actionable message', async () => {
    const supervisor = new AgentSupervisor({
      agentPath: '/missing/PeppaAgent',
      socketPath: '/tmp/fatcat-missing.sock',
      hermesHome: '/tmp/fatcat-hermes',
    })
    await expect(supervisor.start()).rejects.toThrow('FATCAT_AGENT_PATH')
  })

  it('spawns the configured agent and connects through its private socket', async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-supervisor-'))
    const socketPath = join(root, 'agent.sock')
    const agent = new FakeAgent(socketPath)
    const child = new EventEmitter() as ChildProcess
    child.kill = vi.fn(() => true)
    const spawnProcess = vi.fn(() => {
      void agent.start((command, current) => {
        if (command.type === 'shutdown') {
          current.send({ version: 1, type: 'shutdown_ack' })
          queueMicrotask(() => child.emit('exit', 0, null))
        }
      })
      return child
    })
    const supervisor = new AgentSupervisor({
      agentPath: process.execPath,
      socketPath,
      hermesHome: join(root, 'hermes'),
      spawnProcess,
      connectAttempts: 20,
      connectDelayMs: 10,
    })

    const transport = await supervisor.start()
    expect(spawnProcess).toHaveBeenCalledWith(
      process.execPath,
      ['--socket', socketPath, '--hermes-home', join(root, 'hermes')],
      expect.objectContaining({ stdio: ['ignore', 'pipe', 'pipe'] }),
    )
    expect(transport.isConnected).toBe(true)
    await supervisor.stop(200)
    expect(child.kill).not.toHaveBeenCalledWith('SIGKILL')
    await agent.stop()
  })

  it('redacts secrets and bounds diagnostic output', () => {
    const long = `OPENAI_API_KEY=secret ${'x'.repeat(6000)}`
    const redacted = redactDiagnostic(long)
    expect(redacted).not.toContain('secret')
    expect(redacted.length).toBeLessThanOrEqual(4096)
  })
})
