import { EventEmitter } from 'node:events'
import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { AgentEvent, ClientCommand } from '../../shared/protocol'
import { ConversationRepository } from '../persistence/conversations'
import { FatCatService } from './fatcat-service'

class TestTransport extends EventEmitter {
  isConnected = true
  commands: ClientCommand[] = []
  send(command: ClientCommand) { this.commands.push(command) }
  event(event: AgentEvent) { this.emit('event', event) }
}

describe('FatCatService', () => {
  let transport: TestTransport
  let service: FatCatService

  beforeEach(async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-service-'))
    transport = new TestTransport()
    const repository = await ConversationRepository.open(join(root, 'conversations.json'))
    service = new FatCatService({
      repository,
      transport,
      chooseWorkspace: async () => '/tmp/chosen-workspace',
      diagnostics: async () => ({ agentPath: '/agent', socketPath: '/socket', running: true, lines: [] }),
    })
  })

  it('creates a Hermes session before sending a real streamed turn', async () => {
    const record = await service.createConversation('/tmp/project')
    const creation = transport.commands.at(-1)
    expect(creation).toMatchObject({ type: 'new_session', conversation_id: record.id, cwd: '/tmp/project' })

    transport.event({ version: 1, type: 'session_ready', request_id: requestId(creation!), conversation_id: record.id, session_id: 's1' })
    await vi.waitFor(async () => expect((await service.snapshot()).conversations[0]?.hermesSessionId).toBe('s1'))

    await service.sendMessage('Hello Hermes')
    const turn = transport.commands.at(-1)
    expect(turn).toMatchObject({ type: 'user_message', session_id: 's1', text: 'Hello Hermes' })
    expect((await service.snapshot()).messages.at(-1)).toMatchObject({ role: 'user', text: 'Hello Hermes' })

    transport.event({ version: 1, type: 'assistant_delta', request_id: requestId(turn!), session_id: 's1', text: 'Hello ' })
    transport.event({ version: 1, type: 'assistant_delta', request_id: requestId(turn!), session_id: 's1', text: 'back.' })
    transport.event({ version: 1, type: 'tool_call', request_id: 'tool-1', name: 'read_file', arguments: { path: 'README.md' } })
    transport.event({ version: 1, type: 'action_result', request_id: 'tool-1', success: true, detail: 'Read complete.' })
    transport.event({ version: 1, type: 'state', state: 'completed', session_id: 's1', request_id: requestId(turn!) })

    await vi.waitFor(async () => {
      const snapshot = await service.snapshot()
      expect(snapshot.isGenerating).toBe(false)
      expect(snapshot.messages.at(-1)).toMatchObject({ role: 'assistant', text: 'Hello back.', isStreaming: false })
      expect(snapshot.messages.at(-1)?.activities.find((activity) => activity.label === 'read_file')).toMatchObject({ status: 'completed' })
    })
  })

  it('enforces one turn and ignores late deltas after cancellation', async () => {
    const record = await service.createConversation('/tmp/project')
    const creation = transport.commands.at(-1)!
    transport.event({ version: 1, type: 'session_ready', request_id: requestId(creation), conversation_id: record.id, session_id: 's1' })
    await vi.waitFor(async () => expect((await service.snapshot()).conversations[0]?.hermesSessionId).toBe('s1'))
    await service.sendMessage('First')
    const turn = transport.commands.at(-1)!
    await expect(service.sendMessage('Second')).rejects.toThrow('already running')

    await service.cancelTurn()
    transport.event({ version: 1, type: 'assistant_delta', request_id: requestId(turn), session_id: 's1', text: 'too late' })
    await new Promise((resolve) => setTimeout(resolve, 0))
    const snapshot = await service.snapshot()
    expect(snapshot.isGenerating).toBe(false)
    expect(snapshot.messages.some((message) => message.text.includes('too late'))).toBe(false)
  })

  it('loads authoritative history and rejects mismatched sessions', async () => {
    const record = await service.createConversation('/tmp/project')
    const creation = transport.commands.at(-1)!
    transport.event({ version: 1, type: 'session_ready', request_id: requestId(creation), conversation_id: record.id, session_id: 's1' })
    await vi.waitFor(async () => expect((await service.snapshot()).conversations[0]?.hermesSessionId).toBe('s1'))
    await service.selectConversation(record.id)
    expect(transport.commands.at(-1)).toMatchObject({ type: 'load_session', session_id: 's1' })

    transport.event({ version: 1, type: 'session_history', conversation_id: record.id, session_id: 'wrong', role: 'assistant', text: 'Ignore me' })
    transport.event({ version: 1, type: 'session_history', conversation_id: record.id, session_id: 's1', role: 'assistant', text: 'Restored' })
    await vi.waitFor(async () => expect((await service.snapshot()).messages.map((message) => message.text)).toEqual(['Restored']))
  })

  it('uses the native workspace chooser to create a new conversation', async () => {
    const workspace = await service.chooseWorkspace()
    expect(workspace).toBe('/tmp/chosen-workspace')
    if (!workspace) throw new Error('Expected a workspace')
    const record = await service.createConversation(workspace)
    expect(record.workspacePath).toBe('/tmp/chosen-workspace')
  })
})

function requestId(command: ClientCommand): string {
  if (!('request_id' in command)) throw new Error(`Command ${command.type} has no request ID`)
  return command.request_id
}
