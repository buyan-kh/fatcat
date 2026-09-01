import { describe, expect, it } from 'vitest'
import { decodeAgentEvent } from './protocol'

describe('Hermes v2 event envelope', () => {
  it('requires the generic correlation and presentation fields', () => {
    expect(() => decodeAgentEvent(JSON.stringify({ version: 2, kind: 'tool.started' }))).toThrow()
  })

  it('accepts a sanitized generic tool lifecycle event', () => {
    const event = decodeAgentEvent(JSON.stringify({
      version: 2,
      event_id: 'e1',
      kind: 'tool.started',
      session_id: 's1',
      request_id: 'r1',
      summary: 'Search the web',
      details: { tool: 'web_search', risk: 'low' },
    }))
    expect(event).toMatchObject({ event_id: 'e1', kind: 'tool.started', session_id: 's1' })
  })

  it('rejects credential-shaped details recursively', () => {
    expect(() => decodeAgentEvent(JSON.stringify({
      version: 2,
      event_id: 'e1',
      kind: 'tool.started',
      session_id: 's1',
      request_id: 'r1',
      summary: 'Search',
      details: { nested: [{ api_key: 'never' }] },
    }))).toThrow(/credential/i)
  })
})
