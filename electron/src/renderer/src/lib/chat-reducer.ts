import type { AppSnapshot, FatCatEvent } from '@shared/api'

export type RendererNotice = { level: 'info' | 'error'; message: string }

export type RendererState = {
  phase: 'loading' | 'ready' | 'failed'
  snapshot: AppSnapshot | null
  notice: RendererNotice | null
}

export type RendererAction =
  | { type: 'loaded'; snapshot: AppSnapshot }
  | { type: 'bridge'; event: FatCatEvent }
  | { type: 'failed'; message: string }
  | { type: 'clear-notice' }

export const initialRendererState: RendererState = {
  phase: 'loading',
  snapshot: null,
  notice: null,
}

export function chatReducer(state: RendererState, action: RendererAction): RendererState {
  switch (action.type) {
    case 'loaded':
      if (state.snapshot) return { ...state, phase: 'ready' }
      return { phase: 'ready', snapshot: action.snapshot, notice: null }
    case 'bridge':
      if (action.event.type === 'snapshot') return { ...state, phase: 'ready', snapshot: action.event.snapshot }
      return { ...state, notice: { level: action.event.level, message: action.event.message } }
    case 'failed':
      return { phase: 'failed', snapshot: state.snapshot, notice: { level: 'error', message: action.message } }
    case 'clear-notice':
      return { ...state, notice: null }
  }
}
