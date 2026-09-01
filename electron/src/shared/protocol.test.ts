import { describe, expect, it } from 'vitest'
import { decodeAgentEvent, encodeClientCommand } from './protocol'

describe('FatCat socket protocol', () => {
  it.each([
    { version: 1, type: 'hello_ack', agent_version: '1.0', client_id: 'client-1' },
    { version: 1, type: 'pet_clicked', event_id: 'click-1', pet_id: 'primary', conversation_id: 'c1' },
    {
      version: 1,
      type: 'conversation_snapshot',
      selected_id: 'c1',
      records: [{ id: 'c1', title: 'First', workspace_path: '/tmp', session_id: 's1' }],
    },
    {
      version: 1,
      type: 'message_added',
      conversation_id: 'c1',
      session_id: 's1',
      message: { id: 'm1', role: 'user', text: 'Hello' },
    },
    { version: 1, type: 'session_ready', request_id: 'r1', conversation_id: 'c1', session_id: 's1' },
    { version: 1, type: 'session_loaded', request_id: 'r1', conversation_id: 'c1', session_id: 's1' },
    { version: 1, type: 'session_history', conversation_id: 'c1', session_id: 's1', role: 'assistant', text: 'Hello' },
    { version: 1, type: 'assistant_delta', request_id: 'r1', session_id: 's1', text: 'Hi' },
    { version: 1, type: 'plan', request_id: 'r1', session_id: 's1', steps: ['Read', 'Reply'] },
    { version: 1, type: 'tool_call', request_id: 'tool-1', name: 'read_file', arguments: { path: 'README.md' } },
    { version: 1, type: 'action_result', request_id: 'tool-1', success: true, detail: 'Done' },
    { version: 1, type: 'state', state: 'streaming', session_id: 's1', request_id: 'r1' },
    { version: 1, type: 'state', state: 'stopping', session_id: 's1', request_id: 'r1' },
    { version: 1, type: 'provider_status', provider_id: 'openai-codex', authenticated: true, detail: 'Ready' },
    { version: 1, type: 'error', request_id: 'r1', message: 'Failed' },
    { version: 1, type: 'shutdown_ack' },
  ])('decodes $type events', (event) => {
    expect(decodeAgentEvent(JSON.stringify(event))).toMatchObject(event)
  })

  it('rejects unsupported protocol versions', () => {
    expect(() => decodeAgentEvent('{"version":3,"type":"hello_ack","agent_version":"x"}')).toThrow(
      'Unsupported protocol version',
    )
  })

  it('rejects unknown event types and missing fields', () => {
    expect(() => decodeAgentEvent('{"version":1,"type":"mystery"}')).toThrow('Invalid agent event')
    expect(() => decodeAgentEvent('{"version":1,"type":"assistant_delta","request_id":"r","session_id":"s"}')).toThrow(
      'Invalid agent event',
    )
  })

  it('rejects credential-shaped fields at any depth', () => {
    expect(() =>
      decodeAgentEvent('{"version":1,"type":"error","request_id":null,"message":"x","detail":{"api_key":"no"}}'),
    ).toThrow('Credential field')

    expect(() =>
      encodeClientCommand({
        version: 1,
        type: 'user_message',
        request_id: 'r',
        conversation_id: 'c',
        session_id: 's',
        text: 'hello',
        nested: [{ access_token: 'no' }],
      } as never),
    ).toThrow('Credential field')
  })

  it('encodes one compact newline-delimited command', () => {
    expect(
      encodeClientCommand({ version: 1, type: 'user_message', request_id: 'r1', conversation_id: 'c1', session_id: 's1', text: 'Hello' }),
    ).toBe('{"version":1,"type":"user_message","request_id":"r1","conversation_id":"c1","session_id":"s1","text":"Hello"}\n')
  })

  it('identifies clients and encodes typed pet clicks', () => {
    expect(encodeClientCommand({ version: 1, type: 'hello', client: 'electron_chat' })).toBe(
      '{"version":1,"type":"hello","client":"electron_chat"}\n',
    )
    expect(
      encodeClientCommand({ version: 1, type: 'pet_clicked', event_id: 'click-1', pet_id: 'primary', conversation_id: 'c1' }),
    ).toContain('"type":"pet_clicked"')
  })

  it('encodes explicit one-shot approval decisions', () => {
    expect(encodeClientCommand({ version: 1, type: 'approve_action', request_id: 'r1', proposal_id: 'p1' })).toBe(
      '{"version":1,"type":"approve_action","request_id":"r1","proposal_id":"p1"}\n',
    )
    expect(encodeClientCommand({ version: 1, type: 'deny_action', request_id: 'r2', proposal_id: 'p1' })).toContain('deny_action')
  })
})
