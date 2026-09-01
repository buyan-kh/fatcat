import { constants, accessSync } from 'node:fs'
import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import type { AgentEvent } from '../../shared/protocol'
import { AgentSupervisor } from './agent-supervisor'

const agentPath = process.env.FATCAT_AGENT_PATH
const hasBundledAgent = Boolean(agentPath && isExecutable(agentPath))
const smokeTest = hasBundledAgent ? it : it.skip

describe('bundled FatCat Agent smoke test', () => {
  smokeTest(
    hasBundledAgent
      ? 'handshakes, creates a no-prompt Hermes session, and shuts down'
      : 'skipped: set FATCAT_AGENT_PATH to an executable bundled agent',
    async () => {
      const root = await mkdtemp(join(tmpdir(), 'fatcat-real-agent-'))
      const supervisor = new AgentSupervisor({
        agentPath: agentPath!,
        socketPath: join(root, 'agent.sock'),
        hermesHome: join(root, 'hermes'),
      })

      try {
        const transport = await supervisor.start()
        expect(transport.isConnected).toBe(true)

        const sessionReady = waitForEvent(
          transport,
          (event): event is Extract<AgentEvent, { type: 'session_ready' }> => 'type' in event && event.type === 'session_ready',
        )
        transport.send({
          version: 1,
          type: 'new_session',
          request_id: 'smoke-session',
          conversation_id: 'smoke-conversation',
          cwd: root,
        })
        await expect(sessionReady).resolves.toMatchObject({
          request_id: 'smoke-session',
          conversation_id: 'smoke-conversation',
        })
      } finally {
        await supervisor.stop(2_000)
        await rm(root, { recursive: true, force: true })
      }
    },
    20_000,
  )
})

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK)
    return true
  } catch {
    return false
  }
}

function waitForEvent<T extends AgentEvent>(
  transport: NodeJS.EventEmitter,
  predicate: (event: AgentEvent) => event is T,
): Promise<T> {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      transport.off('event', listener)
      reject(new Error('Timed out waiting for bundled agent event'))
    }, 10_000)
    const listener = (event: AgentEvent) => {
      if (!predicate(event)) return
      clearTimeout(timeout)
      transport.off('event', listener)
      resolve(event)
    }
    transport.on('event', listener)
  })
}
