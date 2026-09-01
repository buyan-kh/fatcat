import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { FakeAgent } from '../../test/fake-agent'
import { SocketTransport } from './socket-transport'

describe('SocketTransport', () => {
  let agent: FakeAgent
  let transport: SocketTransport | undefined

  beforeEach(async () => {
    const root = await mkdtemp(join(tmpdir(), 'fatcat-socket-'))
    agent = new FakeAgent(join(root, 'agent.sock'))
    await agent.start()
  })

  afterEach(async () => {
    transport?.close()
    await agent.stop()
  })

  it('handshakes before sending application commands', async () => {
    transport = new SocketTransport(agent.socketPath, { handshakeTimeoutMs: 500 })
    await transport.connect()
    transport.send({ version: 1, type: 'new_session', request_id: 'r1', conversation_id: 'c1', cwd: '/tmp' })
    await vi.waitFor(() => expect(agent.commands.map((command) => command.type)).toEqual(['hello', 'new_session']))
  })

  it('frames partial and multiple events', async () => {
    transport = new SocketTransport(agent.socketPath, { handshakeTimeoutMs: 500 })
    const events: string[] = []
    transport.on('event', (event) => events.push(event.type))
    await transport.connect()

    agent.send({ version: 1, type: 'assistant_delta', request_id: 'r', session_id: 's', text: 'Hi' }, 18)
    agent.sendRaw('{"version":1,"type":"state","state":"completed","session_id":"s","request_id":"r"}\n{"version":1,"type":"shutdown_ack"}\n')

    await vi.waitFor(() => expect(events).toEqual(['hello_ack', 'assistant_delta', 'state', 'shutdown_ack']))
  })

  it('surfaces malformed events without logging their payload', async () => {
    transport = new SocketTransport(agent.socketPath, { handshakeTimeoutMs: 500 })
    const diagnostics: string[] = []
    transport.on('diagnostic', (value) => diagnostics.push(value))
    await transport.connect()
    agent.sendRaw('{broken\n')

    await vi.waitFor(() => expect(diagnostics).toEqual(['Agent sent an invalid protocol event.']))
  })

  it('reconnects and handshakes again after an unexpected disconnect', async () => {
    transport = new SocketTransport(agent.socketPath, { handshakeTimeoutMs: 500, reconnectDelayMs: 10 })
    await transport.connect()

    agent.disconnect()

    await vi.waitFor(() => expect(agent.commands.filter((command) => command.type === 'hello')).toHaveLength(2))
    await vi.waitFor(() => expect(transport?.isConnected).toBe(true))
  })

  it('rejects writes while disconnected', () => {
    transport = new SocketTransport(agent.socketPath)
    expect(() => transport!.send({ version: 1, type: 'shutdown' })).toThrow('not connected')
  })

  it('times out when the agent never acknowledges hello', async () => {
    await agent.stop()
    const root = await mkdtemp(join(tmpdir(), 'fatcat-socket-timeout-'))
    agent = new FakeAgent(join(root, 'agent.sock'), false)
    await agent.start((command) => {
      if (command.type === 'hello') agent.disconnect()
    })
    transport = new SocketTransport(agent.socketPath, { handshakeTimeoutMs: 80 })
    await expect(transport.connect()).rejects.toThrow(/handshake|disconnected/i)
  })
})
