import { describe, expect, it } from 'vitest'
import type { AppSnapshot } from '@shared/api'
import { chatReducer, initialRendererState } from './chat-reducer'

const snapshot: AppSnapshot = {
  conversations: [],
  selectedId: null,
  messages: [],
  connection: { phase: 'connected', detail: 'Connected' },
  activeRequestId: null,
  isGenerating: false,
  resumeError: null,
  providers: [],
  appearance: 'system',
}

describe('chatReducer', () => {
  it('loads the initial snapshot', () => {
    const state = chatReducer(initialRendererState, { type: 'loaded', snapshot })
    expect(state).toEqual({ phase: 'ready', snapshot, notice: null })
  })

  it('replaces state from authoritative snapshot events', () => {
    const loaded = chatReducer(initialRendererState, { type: 'loaded', snapshot })
    const streaming: AppSnapshot = {
      ...snapshot,
      activeRequestId: 'r1',
      isGenerating: true,
      messages: [{ id: 'm1', role: 'assistant', text: 'Hello', requestId: 'r1', isStreaming: true, activities: [] }],
    }
    const state = chatReducer(loaded, { type: 'bridge', event: { type: 'snapshot', snapshot: streaming } })
    expect(state.snapshot).toBe(streaming)
    expect(state.snapshot?.messages[0]?.text).toBe('Hello')
  })

  it('does not let a delayed initial load overwrite a live bridge snapshot', () => {
    const live: AppSnapshot = {
      ...snapshot,
      activeRequestId: 'r1',
      isGenerating: true,
      messages: [{ id: 'm1', role: 'assistant', text: 'partial', requestId: 'r1', isStreaming: true, activities: [] }],
    }
    const afterBridge = chatReducer(initialRendererState, { type: 'bridge', event: { type: 'snapshot', snapshot: live } })
    const afterDelayedLoad = chatReducer(afterBridge, { type: 'loaded', snapshot })
    expect(afterDelayedLoad.snapshot).toBe(live)
    expect(afterDelayedLoad.snapshot?.messages[0]?.text).toBe('partial')
  })

  it('keeps transient notices separate from chat data', () => {
    const loaded = chatReducer(initialRendererState, { type: 'loaded', snapshot })
    const state = chatReducer(loaded, { type: 'bridge', event: { type: 'notice', level: 'error', message: 'Disconnected' } })
    expect(state.notice).toEqual({ level: 'error', message: 'Disconnected' })
    expect(state.snapshot).toBe(snapshot)
  })

  it('represents bridge startup failure explicitly', () => {
    const state = chatReducer(initialRendererState, { type: 'failed', message: 'Bridge unavailable' })
    expect(state).toEqual({ phase: 'failed', snapshot: null, notice: { level: 'error', message: 'Bridge unavailable' } })
  })
})
