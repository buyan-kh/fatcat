import { useCallback, useEffect, useMemo, useReducer } from 'react'
import type { AppearancePreference } from '@shared/chat'
import { chatReducer, initialRendererState } from '@renderer/lib/chat-reducer'

export function useFatCat() {
  const [state, dispatch] = useReducer(chatReducer, initialRendererState)
  const api = typeof window === 'undefined' ? undefined : window.fatcat

  useEffect(() => {
    if (!api) {
      dispatch({ type: 'failed', message: 'The secure FatCat bridge is unavailable.' })
      return
    }
    let active = true
    const unsubscribe = api.subscribe((event) => {
      if (active) dispatch({ type: 'bridge', event })
    })
    void api.snapshot()
      .then((snapshot) => { if (active) dispatch({ type: 'loaded', snapshot }) })
      .catch((error) => { if (active) dispatch({ type: 'failed', message: errorMessage(error) }) })
    return () => {
      active = false
      unsubscribe()
    }
  }, [api])

  const run = useCallback(async <T,>(operation: () => Promise<T>): Promise<T | undefined> => {
    try {
      return await operation()
    } catch (error) {
      dispatch({ type: 'failed', message: errorMessage(error) })
      return undefined
    }
  }, [])

  const commands = useMemo(() => ({
    createConversation: (workspacePath?: string) => api && run(() => api.createConversation(workspacePath)),
    selectConversation: (id: string) => api && run(() => api.selectConversation(id)),
    renameConversation: (id: string, title: string) => api && run(() => api.renameConversation(id, title)),
    deleteConversation: (id: string) => api && run(() => api.deleteConversation(id)),
    sendMessage: (text: string) => api && run(() => api.sendMessage(text)),
    cancelTurn: () => api && run(() => api.cancelTurn()),
    retryLastTurn: () => api && run(() => api.retryLastTurn()),
    chooseWorkspace: () => api ? run(() => api.chooseWorkspace()) : Promise.resolve(undefined),
    setAppearance: (appearance: AppearancePreference) => api && run(() => api.setAppearance(appearance)),
    restartAgent: () => api && run(() => api.restartAgent()),
    getDiagnostics: () => api ? run(() => api.getDiagnostics()) : Promise.resolve(undefined),
    clearNotice: () => dispatch({ type: 'clear-notice' }),
  }), [api, run])

  return { state, commands }
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}
