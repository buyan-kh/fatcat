import { EventEmitter } from 'node:events'
import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { AgentEvent, ClientCommand } from '../../shared/protocol'
import { ConversationRepository } from '../persistence/conversations'
import { FatCatService } from './fatcat-service'

class SharedTransport extends EventEmitter {
  isConnected = true
  commands: ClientCommand[] = []
  send(command: ClientCommand) { this.commands.push(command) }
  event(event: AgentEvent) { this.emit('event', event) }
}

describe('deterministic shared Hermes session smoke', () => {
  let transport: SharedTransport
  let first: FatCatService
  let second: FatCatService

  beforeEach(async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-shared-session-'))
    transport = new SharedTransport()
    const build = async (suffix: string) => new FatCatService({
      repository: await ConversationRepository.open(join(root, `conversation-${suffix}.json`)),
      transport,
      chooseWorkspace: async () => '/tmp/project',
      diagnostics: async () => ({ agentPath: '/agent', socketPath: '/socket', running: true, lines: [] }),
    })
    first = await build('first')
    second = await build('second')
  })

  it('keeps two clients synchronized through history, approval, action, and verification', async () => {
    const snapshot: AgentEvent = {
      version: 1,
      type: 'conversation_snapshot',
      selected_id: 'conversation-1',
      records: [{ id: 'conversation-1', title: 'Shared', workspace_path: '/tmp/project', session_id: 'hermes-1' }],
    }
    transport.event(snapshot)
    await vi.waitFor(async () => {
      expect((await first.snapshot()).selectedId).toBe('conversation-1')
      expect((await second.snapshot()).selectedId).toBe('conversation-1')
    })

    transport.event({ version: 1, type: 'message_added', conversation_id: 'conversation-1', session_id: 'hermes-1', message: { id: 'request-1', role: 'user', text: 'Send the draft' } })
    transport.event({ version: 2, event_id: 'message-1', kind: 'message.delta', session_id: 'hermes-1', request_id: 'request-1', summary: 'Draft ready', details: { text: 'Draft ready' } })
    transport.event({ version: 2, event_id: 'approval-1', kind: 'tool.needs_approval', session_id: 'hermes-1', request_id: 'request-1', summary: 'Send email to Sarah', details: { proposal_id: 'proposal-1', risk: 'high' } })

    await vi.waitFor(async () => {
      const activity = (await first.snapshot()).messages.at(-1)?.activities.find((item) => item.approval?.proposalId === 'proposal-1')
      expect(activity).toMatchObject({ status: 'working', approval: { proposalId: 'proposal-1', risk: 'high' } })
      expect((await second.snapshot()).messages.at(-1)?.text).toBe('Draft ready')
    })

    await first.approveAction('proposal-1')
    expect(transport.commands.at(-1)).toMatchObject({ type: 'approve_action', proposal_id: 'proposal-1' })

    transport.event({ version: 2, event_id: 'action-1', kind: 'tool.completed', session_id: 'hermes-1', request_id: 'request-1', summary: 'Email sent', details: { tool_call_id: 'proposal-1' } })
    transport.event({ version: 2, event_id: 'verify-1', kind: 'verification.completed', session_id: 'hermes-1', request_id: 'request-1', summary: 'Verified sent email', details: { success: true } })

    await vi.waitFor(async () => {
      const left = (await first.snapshot()).messages.at(-1)
      const right = (await second.snapshot()).messages.at(-1)
      expect(left?.activities.find((item) => item.id === 'proposal-1')).toMatchObject({ status: 'completed' })
      expect(left?.activities.find((item) => item.id === 'proposal-1')?.approval).toBeUndefined()
      expect(right?.activities.find((item) => item.id === 'proposal-1')).toMatchObject({ status: 'completed' })
    })
  })
})
